```markdown
# iPerf3 Network Performance Test Suite

![Network Testing](https://img.shields.io/badge/network-testing-blue)
![Multi-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey)

Automated network throughput testing between Windows (client) and Linux (server) systems with parallel multi-core support.

## Features

- ⚡ **One-command setup** for both Windows and Linux  
- 🔄 **Automatic iPerf3 installation** on both platforms  
- 🖥️ **Multi-core parallel testing** for maximum throughput  
- 📊 **Real-time performance metrics**  
- 🔥 **Self-contained** with no manual configuration  

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
```

