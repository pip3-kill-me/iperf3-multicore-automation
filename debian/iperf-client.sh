#!/bin/bash
# Filename: iperf-multicore-client.sh

# Force C locale for predictable numeric formats (e.g., using . for decimals)
export LC_ALL=C

# --- Check for required commands ---
for cmd in bc jq iperf3; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please run:"
        echo "sudo apt update && sudo apt install -y bc jq iperf3"
        exit 1
    fi
done

# --- Default values ---
SERVER_IP=""
DURATION=30
WINDOW_SIZE="256k"
PACKET_SIZE="64K"
BASE_PORT=5201
CORES=$(nproc)
TIMEFORMAT="%R"
UDP_MODE=false
UDP_BANDWIDTH="1G" # Default UDP bandwidth per stream
REVERSE_MODE=false
BIDIRECTIONAL_MODE=false

# --- Function to display usage ---
usage() {
    echo "Usage: $0 -s <server_ip> [options]"
    echo "Options:"
    echo "  -s, --server <ip>      The IP address of the iperf3 server (required)."
    echo "  -t, --time <secs>      The duration of the test in seconds (default: $DURATION)."
    echo "  -w, --window <size>    The window size (e.g., 256k) (default: $WINDOW_SIZE)."
    echo "  -l, --length <size>    The packet size (e.g., 64K) (default: $PACKET_SIZE)."
    echo "  -U, --udp              Use UDP instead of TCP."
    echo "  -b, --bandwidth <rate> Target bandwidth for UDP tests (e.g., 100M, 1G) (default: $UDP_BANDWIDTH)."
    echo "  -R, --reverse          Run in reverse mode (server sends, client receives)."
    echo "  -d, --bidirectional    Run a bidirectional test simultaneously."
    exit 1
}

# --- Parse Command-Line Arguments ---
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -s|--server) SERVER_IP="$2"; shift 2 ;;
        -t|--time) DURATION="$2"; shift 2 ;;
        -w|--window) WINDOW_SIZE="$2"; shift 2 ;;
        -l|--length) PACKET_SIZE="$2"; shift 2 ;;
        -b|--bandwidth) UDP_BANDWIDTH="$2"; shift 2 ;;
        -U|--udp) UDP_MODE=true; shift ;;
        -R|--reverse) REVERSE_MODE=true; shift ;;
        -d|--bidirectional) BIDIRECTIONAL_MODE=true; shift ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
done

# --- Validate required arguments ---
if [ -z "$SERVER_IP" ]; then
    echo "Error: Server IP is a required argument."
    usage
fi

# --- Announce test type ---
TEST_TYPE="TCP"
if [ "$UDP_MODE" = true ]; then
    TEST_TYPE="UDP"
fi
if [ "$REVERSE_MODE" = true ]; then
    TEST_TYPE="$TEST_TYPE (Reverse)"
elif [ "$BIDIRECTIONAL_MODE" = true ]; then
    TEST_TYPE="$TEST_TYPE (Bidirectional)"
fi

echo "Starting $CORES parallel $TEST_TYPE clients to $SERVER_IP..."
echo "Test duration: $DURATION seconds per client"

# --- Create temp directory for results ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Function to display progress bar ---
progress_bar() {
    local duration=$1
    local elapsed=0
    local bar_length=50

    while [ "$elapsed" -le "$duration" ]; do
        # Calculate progress safely, avoiding division by zero
        if [ "$duration" -gt 0 ]; then
            local progress=$((elapsed * bar_length / duration))
        else
            local progress=$bar_length
        fi
        local remaining=$((bar_length - progress))

        # Build the bar string components
        local bar_filled
        bar_filled=$(printf "%${progress}s" | tr ' ' '=')
        local bar_empty
        bar_empty=$(printf "%${remaining}s" | tr ' ' ' ')

        # Print the bar in one go to be safe
        printf "\r[%s%s] %ds/%ds" "$bar_filled" "$bar_empty" "$elapsed" "$duration"

        sleep 1
        elapsed=$((elapsed + 1))
    done
    printf "\n"
}

# --- Run tests in parallel ---
IPERF_ARGS=("-c" "$SERVER_IP" "-t" "$DURATION" "--json")
if [ "$UDP_MODE" = true ]; then
    IPERF_ARGS+=("-u" "-b" "$UDP_BANDWIDTH")
else
    IPERF_ARGS+=("-w" "$WINDOW_SIZE" "-l" "$PACKET_SIZE")
fi
if [ "$REVERSE_MODE" = true ]; then
    IPERF_ARGS+=("-R")
fi
if [ "$BIDIRECTIONAL_MODE" = true ]; then
    IPERF_ARGS+=("-d")
fi

START_TIME=$(date +%s.%N)
for ((CORE=0; CORE<$CORES; CORE++)); do
    PORT=$((BASE_PORT + CORE))
    taskset -c $CORE iperf3 "${IPERF_ARGS[@]}" -p "$PORT" > "$TMPDIR/result-$PORT.json" &
done

progress_bar $DURATION &
PROGRESS_PID=$!
wait
kill $PROGRESS_PID 2>/dev/null
END_TIME=$(date +%s.%N)
# Use bc -l for floating point math
RAW_DURATION=$(echo "$END_TIME - $START_TIME" | bc -l)
ACTUAL_DURATION=$(printf "%.2f" "${RAW_DURATION:-0}")


# --- Process results ---
TOTAL_BW=0; RESULTS=()
for FILE in "$TMPDIR"/result-*.json; do
    PORT=$(basename "$FILE" | cut -d'-' -f2 | cut -d'.' -f1)
    if ! jq -e . "$FILE" >/dev/null 2>&1; then
        RESULTS+=("Port $PORT: ERROR - Invalid JSON output")
        continue
    fi

    if [ "$UDP_MODE" = true ]; then
        # UDP results parsing
        SUM_BLOCK=$(jq '.end.sum' "$FILE")
        if [ -z "$SUM_BLOCK" ] || [ "$SUM_BLOCK" = "null" ]; then
            RESULTS+=("Port $PORT: ERROR - No UDP summary")
            continue
        fi
        # Default to 0 if value is null, then format
        BPS_RAW=$(echo "$SUM_BLOCK" | jq -r '.bits_per_second // 0')
        JITTER_RAW=$(echo "$SUM_BLOCK" | jq -r '.jitter_ms // 0')
        LOST_RAW=$(echo "$SUM_BLOCK" | jq -r '.lost_percent // 0')

        BW=$(printf "%.2f" "$(echo "$BPS_RAW / 1e9" | bc -l)")
        JITTER=$(printf "%.3f" "$JITTER_RAW")
        LOST_PERCENT=$(printf "%.2f" "$LOST_RAW")

        RESULTS+=("Port $PORT: $BW Gbps | Jitter: $JITTER ms | Loss: $LOST_PERCENT%")
        # Safely add to total, using bc -l for floating point math
        if [[ "$BW" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            TOTAL_BW=$(echo "$TOTAL_BW + $BW" | bc -l)
        fi
    else
        # TCP results parsing
        SUM_BLOCK_PATH='.end.sum_received'
        if [ "$REVERSE_MODE" = true ]; then
            SUM_BLOCK_PATH='.end.sum_sent'
        fi
        SUM_BLOCK=$(jq "$SUM_BLOCK_PATH" "$FILE")
        if [ -z "$SUM_BLOCK" ] || [ "$SUM_BLOCK" = "null" ]; then
            RESULTS+=("Port $PORT: ERROR - No TCP summary")
            continue
        fi
        # Default to 0 if value is null, then format
        BPS_RAW=$(echo "$SUM_BLOCK" | jq -r '.bits_per_second // 0')
        BW=$(printf "%.2f" "$(echo "$BPS_RAW / 1e9" | bc -l)")
        RESULTS+=("Port $PORT: $BW Gbps")
        # Safely add to total, using bc -l for floating point math
        if [[ "$BW" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            TOTAL_BW=$(echo "$TOTAL_BW + $BW" | bc -l)
        fi
    fi
done

# --- Display summary ---
echo -e "\n=== Individual Results ==="
printf "%s\n" "${RESULTS[@]}"
echo -e "\n=== Summary ==="
echo "Cores used:      $CORES"
echo "Test type:       $TEST_TYPE"
echo "Target time:     $DURATION seconds"
echo "Actual time:     $ACTUAL_DURATION seconds"
echo "Total Bandwidth: $(printf "%.2f" "${TOTAL_BW:-0}") Gbps"
```powershell
# Filename: iperf-multicore-client.ps1

# --- Define Parameters ---
param(
    [string]$ServerIP,
    [int]$Duration = 30,
    [string]$WindowSize = "256k",
    [string]$PacketSize = "64K",
    [switch]$Udp,
    [string]$Bandwidth = "1G",
    [switch]$Reverse,
    [switch]$Bidirectional
)

# --- Verify required parameters ---
if (-not $ServerIP) {
    Write-Host "Usage: .\iperf-multicore-client.ps1 -ServerIP <ip> [options]"
    Write-Host "Options:"
    Write-Host "  -Duration <secs>      (Default: 30)"
    Write-Host "  -WindowSize <size>    (Default: 256k)"
    Write-Host "  -PacketSize <size>    (Default: 64K)"
    Write-Host "  -Udp                  Use UDP instead of TCP."
    Write-Host "  -Bandwidth <rate>     Target UDP bandwidth (e.g., 100M, 1G). Default: 1G."
    Write-Host "  -Reverse              Run in reverse mode (server sends)."
    Write-Host "  -Bidirectional        Run a bidirectional test."
    exit 1
}

# --- Script Configuration ---
$Cores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
$BasePort = 5201
$Processes = @()
$Results = @()
$TempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "iperf-results-$([System.Guid]::NewGuid())")

# --- Main Logic ---
try {
    $testType = "TCP"
    if ($Udp.IsPresent) { $testType = "UDP" }
    if ($Reverse.IsPresent) { $testType += " (Reverse)" }
    elseif ($Bidirectional.IsPresent) { $testType += " (Bidirectional)" }

    Write-Host "Starting $Cores parallel $testType clients to $ServerIP..."
    Write-Host "Test duration: $Duration seconds per client"

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # --- Build Argument List ---
    $baseArgs = @("-c", $ServerIP, "-t", $Duration, "--json")
    if ($Udp.IsPresent) {
        $baseArgs += @("-u", "-b", $Bandwidth)
    } else {
        $baseArgs += @("-w", $WindowSize, "-l", $PacketSize)
    }
    if ($Reverse.IsPresent) { $baseArgs += "-R" }
    if ($Bidirectional.IsPresent) { $baseArgs += "-d" }

    # --- Start iperf3 processes ---
    for ($i = 0; $i -lt $Cores; $i++) {
        $Port = $BasePort + $i
        $OutputFile = Join-Path $TempDir.FullName "result-$Port.json"
        $finalArgs = $baseArgs + @("-p", $Port, "--affinity", $i)
        
        $ProcessArgs = @{
            FilePath = "iperf3.exe"
            ArgumentList = $finalArgs
            NoNewWindow = $true
            PassThru = $true
            RedirectStandardOutput = $OutputFile
        }
        $Processes += Start-Process @ProcessArgs
    }

    # --- Progress Bar ---
    for ($elapsed = 1; $elapsed -le $Duration; $elapsed++) {
        Write-Progress -Activity "Running iperf3 Tests" -Status "$elapsed / $Duration seconds" -PercentComplete (($elapsed / $Duration) * 100)
        Start-Sleep -Seconds 1
    }
    Write-Progress -Activity "Running iperf3 Tests" -Completed

    Write-Host "Waiting for all tests to complete..."
    $Processes | Wait-Process -Timeout (10)
    $Stopwatch.Stop()

    # --- Process Results ---
    $TotalBandwidthGbps = 0.0
    Get-ChildItem -Path $TempDir.FullName -Filter "*.json" | ForEach-Object {
        $port = $_.BaseName -replace 'result-'
        try {
            $jsonContent = Get-Content $_.FullName -Raw
            if (-not [string]::IsNullOrWhiteSpace($jsonContent)) {
                $json = $jsonContent | ConvertFrom-Json
                if ($Udp.IsPresent) {
                    $sum = $json.end.sum
                    $gbps = [math]::Round(($sum.bits_per_second | Out-Null; $sum.bits_per_second) / 1e9, 2)
                    $jitter = [math]::Round(($sum.jitter_ms | Out-Null; $sum.jitter_ms), 3)
                    $loss = [math]::Round(($sum.lost_percent | Out-Null; $sum.lost_percent), 2)
                    $Results += "Port $port`: $gbps Gbps | Jitter: $jitter ms | Loss: $loss`%"
                    $TotalBandwidthGbps += $gbps
                } else {
                    $sumBlock = if ($Reverse.IsPresent) { $json.end.sum_sent } else { $json.end.sum_received }
                    $gbps = [math]::Round(($sumBlock.bits_per_second | Out-Null; $sumBlock.bits_per_second) / 1e9, 2)
                    $Results += "Port $port`: $gbps Gbps"
                    $TotalBandwidthGbps += $gbps
                }
            } else { throw "Empty file" }
        } catch {
            $Results += "Port $port`: ERROR - Could not parse result file."
        }
    }

    # --- Display Summary ---
    Write-Host "`n=== Individual Results ===" -ForegroundColor Yellow
    $Results | ForEach-Object { Write-Host $_ }
    Write-Host "`n=== Summary ===" -ForegroundColor Yellow
    Write-Host ("Cores used:      {0}" -f $Cores)
    Write-Host ("Test type:       {0}" -f $testType)
    Write-Host ("Target time:     {0} seconds" -f $Duration)
    Write-Host ("Actual time:     {0:N2} seconds" -f $Stopwatch.Elapsed.TotalSeconds)
    Write-Host ("Total Bandwidth: {0:N2} Gbps" -f $TotalBandwidthGbps)

} finally {
    # --- Cleanup ---
    if (Test-Path $TempDir.FullName) {
        Remove-Item -Recurse -Force $TempDir.FullName
    }
}
