<#
.SYNOPSIS
Automatically installs iPerf3 on Windows with proper permissions
#>

# Run as Administrator check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    exit 1
}

# Configuration
$iperfUrl = "https://github.com/ar51an/iperf3-win-builds/releases/download/3.19/iperf-3.19-win64.zip"
$installPath = "$env:ProgramFiles\iperf3"
$tempFile = "$env:TEMP\iperf3.zip"

# Download iPerf3
try {
    Write-Host "Downloading iPerf3 from GitHub..."
    Invoke-WebRequest -Uri $iperfUrl -OutFile $tempFile -ErrorAction Stop
}
catch {
    Write-Host "Failed to download iPerf3: $_" -ForegroundColor Red
    exit 1
}

# Install iPerf3
try {
    if (-not (Test-Path $installPath)) {
        New-Item -Path $installPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Host "Installing iPerf3 to Program Files..."
    Expand-Archive -Path $tempFile -DestinationPath $installPath -Force
    
    # Add to system PATH
    $env:PATH += ";$installPath"
    [Environment]::SetEnvironmentVariable(
        "PATH",
        [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";$installPath",
        "Machine"
    )
    
    # Verify installation
    if (Test-Path "$installPath\iperf3.exe") {
        Write-Host "iPerf3 installed successfully!" -ForegroundColor Green
    }
    else {
        throw "Installation failed - iperf3.exe not found"
    }
}
catch {
    Write-Host "Installation error: $_" -ForegroundColor Red
    exit 1
}

# Install client script
$scriptPath = "$env:USERPROFILE\Scripts"
if (-not (Test-Path $scriptPath)) {
    New-Item -Path $scriptPath -ItemType Directory -Force | Out-Null
}

try {
    Copy-Item "iperf-client.ps1" $scriptPath -Force
    Write-Host "Client script installed to $scriptPath" -ForegroundColor Green
}
catch {
    Write-Host "Failed to install client script: $_" -ForegroundColor Yellow
}

Write-Host "`nSetup complete! Please restart your terminal." -ForegroundColor Cyan