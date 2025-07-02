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
        $ErrorFile = Join-Path $TempDir.FullName "error-$Port.log"
        $finalArgs = $baseArgs + @("-p", $Port, "--affinity", $i)
        
        $ProcessArgs = @{
            FilePath = "iperf3.exe"
            ArgumentList = $finalArgs
            NoNewWindow = $true
            PassThru = $true
            RedirectStandardOutput = $OutputFile
            RedirectStandardError = $ErrorFile
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
    # Wait for processes, but catch the timeout exception so the script can continue
    $Processes | Wait-Process -Timeout ($Duration + 5) -ErrorAction SilentlyContinue
    $Stopwatch.Stop()

    # --- Process Results ---
    $TotalBandwidthGbps = 0.0
    Get-ChildItem -Path $TempDir.FullName -Filter "*.json" | ForEach-Object {
        $port = $_.BaseName -replace 'result-'
        $errorFile = Join-Path $_.DirectoryName "error-$port.log"
        try {
            # Check for iperf3 errors first
            if ((Test-Path $errorFile) -and ((Get-Item $errorFile).Length -gt 0)) {
                $errorMsg = Get-Content $errorFile -Raw
                throw $errorMsg.Trim()
            }

            $jsonContent = Get-Content $_.FullName -Raw
            if ([string]::IsNullOrWhiteSpace($jsonContent)) {
                # Provide a more helpful error message for this specific case
                throw "Result file is empty. (The iperf3 server may be overloaded or unable to handle the request)." 
            }

            $json = $jsonContent | ConvertFrom-Json
            
            # Check for the top-level error property in iperf3's JSON output
            if ($null -ne $json.error) {
                throw $json.error
            }

            if ($Udp.IsPresent) {
                if ($null -eq $json.end.sum) { throw "No UDP summary block found." }
                $sum = $json.end.sum
                
                $bps_raw = if ($null -ne $sum.bits_per_second) { $sum.bits_per_second } else { 0 }
                $jitter_raw = if ($null -ne $sum.jitter_ms) { $sum.jitter_ms } else { 0 }
                $loss_raw = if ($null -ne $sum.lost_percent) { $sum.lost_percent } else { 0 }

                $gbps = [math]::Round($bps_raw / 1e9, 2)
                $jitter = [math]::Round($jitter_raw, 3)
                $loss = [math]::Round($loss_raw, 2)

                if ($gbps -eq 0 -and $jitter -eq 0 -and $loss -eq 0) {
                    $Results += "Port $port`: ERROR - No traffic received (possible bandwidth overload)"
                } else {
                    $Results += "Port $port`: $gbps Gbps | Jitter: $jitter ms | Loss: $loss`%"
                    $TotalBandwidthGbps += $gbps
                }
            } else { # TCP Mode
                $sumBlock = if ($Reverse.IsPresent) { $json.end.sum_sent } else { $json.end.sum_received }
                if ($null -eq $sumBlock) { throw "No TCP summary block found." }

                $bps_raw = if ($null -ne $sumBlock.bits_per_second) { $sumBlock.bits_per_second } else { 0 }
                $gbps = [math]::Round($bps_raw / 1e9, 2)
                $Results += "Port $port`: $gbps Gbps"
                $TotalBandwidthGbps += $gbps
            }
        } catch {
            $Results += "Port $port`: ERROR - $($_.Exception.Message)"
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
    # Forcefully stop any lingering iperf3 processes that were started by this script
    Write-Host "Stopping any lingering iperf3 processes..."
    foreach ($p in $Processes) {
        try {
            Stop-Process -Id $p.Id -Force -ErrorAction Stop
        } catch {
            # Ignore errors if the process already stopped
        }
    }
    # Now that processes are stopped, cleanup should succeed
    if (Test-Path $TempDir.FullName) {
        Write-Host "Cleaning up temporary directory..."
        Remove-Item -Recurse -Force $TempDir.FullName
    }
}