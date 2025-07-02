# --- Define Parameters ---
param(
    [string]$ServerIP,
    [int]$Duration = 30,
    [string]$WindowSize = "256k",
    [string]$PacketSize = "64K"
)

# --- Verify required parameters ---
if (-not $ServerIP) {
    Write-Host "Usage: .\iperf-multicore-client.ps1 -ServerIP <server_ip> [-Duration 30] [-WindowSize 256k] [-PacketSize 64K]"
    exit 1
}

# --- Script Configuration ---
$Cores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
$BasePort = 5201
$Processes = @()
$Results = @()

# Create a temporary directory for result files
$TempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "iperf-results-$([System.Guid]::NewGuid())")
Write-Host "Temp directory for results: $TempDir"

# --- Main Logic ---
try {
    Write-Host "Starting $Cores parallel clients to $ServerIP..."
    Write-Host "Test duration: $Duration seconds per client"

    # Measure the total time taken for the test
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # --- Start iperf3 processes in the background ---
    for ($i = 0; $i -lt $Cores; $i++) {
        $Port = $BasePort + $i
        $OutputFile = Join-Path $TempDir.FullName "result-$Port.json"
        
        $ProcessArgs = @{
            FilePath = "iperf3.exe"
            ArgumentList = @(
                "-c", $ServerIP,
                "-p", $Port,
                "-t", $Duration,
                "-w", $WindowSize,
                "-l", $PacketSize,
                "--affinity", $i,
                "--json"
            )
            NoNewWindow = $true
            PassThru = $true
            RedirectStandardOutput = $OutputFile
        }
        $Processes += Start-Process @ProcessArgs
    }

    # --- Progress Bar ---
    for ($elapsed = 1; $elapsed -le $Duration; $elapsed++) {
        $progress = ($elapsed / $Duration) * 100
        Write-Progress -Activity "Running iperf3 Tests" -Status "$elapsed / $Duration seconds" -PercentComplete $progress
        Start-Sleep -Seconds 1
    }
    Write-Progress -Activity "Running iperf3 Tests" -Completed

    # --- Wait for all processes to complete ---
    Write-Host "Waiting for all tests to complete..."
    $Processes | Wait-Process -Timeout (10) # Add a small grace period
    $Stopwatch.Stop()

    # --- Process Results ---
    $TotalBandwidthGbps = 0.0

    Get-ChildItem -Path $TempDir.FullName -Filter "*.json" | ForEach-Object {
        $port = $_.BaseName -replace 'result-'
        try {
            $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $bitsPerSecond = $json.end.sum_received.bits_per_second
            if ($null -ne $bitsPerSecond) {
                $gbps = [math]::Round($bitsPerSecond / 1e9, 2)
                $Results += "Port $port`: $gbps Gbps"
                $TotalBandwidthGbps += $gbps
            } else {
                $Results += "Port $port`: ERROR - No data received"
            }
        } catch {
            $Results += "Port $port`: ERROR - Could not parse result file."
        }
    }

    # --- Display Summary ---
    Write-Host "`n=== Individual Results ===" -ForegroundColor Yellow
    $Results | ForEach-Object { Write-Host $_ }

    Write-Host "`n=== Summary ===" -ForegroundColor Yellow
    Write-Host ("Cores used:      {0}" -f $Cores)
    Write-Host ("Target time:     {0} seconds" -f $Duration)
    Write-Host ("Actual time:     {0:N2} seconds" -f $Stopwatch.Elapsed.TotalSeconds)
    Write-Host ("Total Bandwidth: {0:N2} Gbps" -f $TotalBandwidthGbps)

} finally {
    # --- Cleanup ---
    if (Test-Path $TempDir.FullName) {
        Remove-Item -Recurse -Force $TempDir.FullName
        Write-Host "`nCleaned up temporary directory."
    }
}
