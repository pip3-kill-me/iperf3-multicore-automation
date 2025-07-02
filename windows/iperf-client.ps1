param (
    [string]$ServerIP = "",
    [int]$Duration = 30,
    [string]$WindowSize = "2M",
    [string]$PacketSize = "64K"
)

# Verify parameters
if (-not $ServerIP) {
    Write-Host "Usage: .\iperf-client.ps1 -ServerIP <debian_ip> [-Duration 30] [-WindowSize 2M] [-PacketSize 64K]"
    exit 1
}

$Cores = (Get-CimInstance Win32_Processor).NumberOfCores
$BasePort = 5201
$Processes = @()

Write-Host "Starting $Cores parallel clients to $ServerIP..."

# Run tests
for ($i = 0; $i -lt $Cores; $i++) {
    $Port = $BasePort + $i
    $ProcessArgs = @{
        FilePath = "iperf3.exe"
        ArgumentList = @(
            "-c", $ServerIP,
            "-p", $Port,
            "-t", $Duration,
            "-w", $WindowSize,
            "-l", $PacketSize,
            "--affinity", $i
        )
        NoNewWindow = $true
        PassThru = $true
    }
    $Processes += Start-Process @ProcessArgs
}

# Wait for completion
$Processes | Wait-Process
Write-Host "All tests completed" -ForegroundColor Green