![Network Speed Test](https://img.shields.io/badge/network-testing-blue?style=for-the-badge)
![Multi-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=for-the-badge)

```markdown
# iPerf3 Network Performance Testing Suite

A complete solution for testing network throughput between Windows and Linux systems with LACP bonding support.

This iPerf3 network testing suite provides automated, cross-platform scripts for measuring network throughput between Windows and Linux systems. The Windows client scripts (install.ps1 and iperf-client.ps1) automatically download and configure iPerf3, then launch parallel test streams across all CPU cores with customizable duration, window size, and packet size parameters. On the Linux server side (install.sh and iperf-server.sh), the scripts handle dependency installation, firewall configuration, and start multiple iPerf3 server instances - one per available core - listening on consecutive ports from 5201 upward. Both sets of scripts feature automatic PATH configuration and are designed for zero-touch deployment, enabling users to go from a fresh system clone to running comprehensive network benchmarks in under a minute. The solution intelligently scales based on available hardware resources while maintaining precise per-connection metrics collection.

## ✨ Features

- 🚀 **Parallel testing** across all CPU cores  
- 📊 **Detailed metrics** 
- ⏱️ **Actual vs target time** comparison  
- 🔗 **Port-specific results** for **bond** analysis  
```
## Quick Start

### 1. On Linux Server (Debian/Ubuntu)
```bash
# Clone repository
git clone https://github.com/yourrepo/iperf3-network-test.git
cd iperf3-network-test/debian

# Install and start server (as root)
sudo bash install.sh
iperf-server.sh
```

### 2. On Windows Client (PowerShell as Admin)
```powershell
# Clone repository
git clone https://github.com/yourrepo/iperf3-network-test.git
cd iperf3-network-test\windows

# Install and run client
.\install.ps1
iperf-client.ps1 -ServerIP 192.168.1.100 -Duration 60
```

## Detailed Usage

### Windows Client Options
```powershell
.\iperf-client.ps1 -ServerIP <IP> `
    [-Duration <seconds>] `
    [-WindowSize <size>] `
    [-PacketSize <size>]
```

| Parameter       | Default | Description                  |
|-----------------|---------|------------------------------|
| `-ServerIP`     | Required| Linux server IP address       |
| `-Duration`     | 30      | Test duration in seconds      |
| `-WindowSize`   | 2M      | TCP window size (e.g., 1M, 8M)|
| `-PacketSize`   | 64K     | Packet size (e.g., 128K)      |

### Linux Server Management
```bash
# Start server (default uses all cores)
iperf-server.sh

# Stop all iPerf3 servers
sudo pkill iperf3
```

## Technical Details

**Windows Components:**
- Automatically downloads iPerf3 v3.19
- Installs to `Program Files\iperf3`
- Adds to system PATH
- Client script stored in `%USERPROFILE%\Scripts`

**Linux Components:**
- Installs via package manager (apt)
- Opens firewall ports 5201-5300
- Server script installed to `/usr/local/bin`

## Troubleshooting

**Common Issues:**
1. **Connection refused**:
   - Verify firewall rules on Linux: `sudo ufw status`
   - Test basic connectivity: `Test-NetConnection -ComputerName <IP> -Port 5201`

2. **Low throughput**:
   ```bash
   # On Linux:
   ethtool <interface>
   # On Windows:
   Get-NetAdapter | Where Status -eq "Up" | Disable-NetAdapterPowerManagement
   ```

3. **Permission errors**:
   - Always run install scripts as Administrator/root
   - On Windows: Right-click PowerShell → "Run as Administrator"

## License

MIT License - Free for personal and commercial use


