param (
    [int]$BasePort = 5201,
    [int]$Cores = (Get-CimInstance Win32_Processor).NumberOfCores
)

# Start persistent iPerf3 servers (remove -1 flag)
1..$Cores | ForEach-Object {
    $Port = $BasePort + $_ - 1
    Start-Process -NoNewWindow -FilePath "iperf3.exe" -ArgumentList @(
        "-s",
        "-p", $Port
    )
}

# Keep script running to monitor processes
Write-Host "Servers running on ports $BasePort to $($BasePort+$Cores-1)" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow

# Get the first non-loopback IPv4 address
$localIP = (Get-NetIPAddress -AddressFamily IPv4 `
            | Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } `
            | Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host "`nServers ready for client connections"
Write-Host "Run this on Windows:"
Write-Host "iperf-client.ps1 -ServerIP $localIP"
Write-Host "Run this on Debian:"
Write-Host "iperf-client.sh -s $localIP"

try {
    while ($true) { Start-Sleep -Seconds 1 }  # Infinite loop
}
finally {
    Get-Process iperf3 | Stop-Process -Force
}