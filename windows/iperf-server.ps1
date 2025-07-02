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

try {
    while ($true) { Start-Sleep -Seconds 1 }  # Infinite loop
}
finally {
    Get-Process iperf3 | Stop-Process -Force
}