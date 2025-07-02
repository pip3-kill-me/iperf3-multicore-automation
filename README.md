![Network Speed Test](https://img.shields.io/badge/network-testing-blue?style=for-the-badge)
![Multi-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=for-the-badge)


# iPerf3 Network Performance Testing Suite

A complete solution for testing network throughput between Windows and Linux systems with LACP bonding support.

This iPerf3 network testing suite provides automated, cross-platform scripts for measuring network throughput between Windows and Linux systems. The Windows client scripts (install.ps1 and iperf-client.ps1) automatically download and configure iPerf3, then launch parallel test streams across all CPU cores with customizable duration, window size, and packet size parameters. On the Linux server side (install.sh and iperf-server.sh), the scripts handle dependency installation, firewall configuration, and start multiple iPerf3 server instances - one per available core - listening on consecutive ports from 5201 upward. Both sets of scripts feature automatic PATH configuration and are designed for zero-touch deployment, enabling users to go from a fresh system clone to running comprehensive network benchmarks in under a minute. The solution intelligently scales based on available hardware resources while maintaining precise per-connection metrics collection.

## ✨ Features

- 🚀 **Parallel testing** across all CPU cores  
- 📊 **Detailed metrics** 
- ⏱️ **Actual vs target time** comparison  
- 🔗 **Port-specific results** for **bond** analysis  

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


# Tuning

## Overview
This section covers important network tuning considerations when running iperf3 tests with HP NC523SFP adapters in multi-core environments. Proper configuration is essential to achieve maximum throughput and accurate benchmark results.

## Key Tuning Parameters

### 1. Offloading Options
**Why adjust offloading?**
Network interface offloading features can significantly impact performance, especially at high speeds (10Gbps+). While offloading can reduce CPU usage, it may also introduce inconsistencies in benchmarking.

**Recommended settings:**
```bash
# Disable generic segmentation offload
ethtool -K ethX gso off

# Disable TCP segmentation offload
ethtool -K ethX tso off

# Disable UDP fragmentation offload
ethtool -K ethX ufo off

# Disable generic receive offload
ethtool -K ethX gro off

# Disable large receive offload
ethtool -K ethX lro off
```

**Note:** For production environments (non-benchmarking), you may want to re-enable some of these features after testing.

### 2. MTU Configuration
**Why adjust MTU?**
The default 1500-byte MTU may not be optimal for 10Gbps+ networks. Jumbo frames can improve throughput but require end-to-end consistency.

**Recommended settings:**
```bash
# Set jumbo frames (9000 bytes)
ifconfig ethX mtu 9000

# Verify setting
ethtool -g ethX
```

**Requirements:**
- All devices in the path must support the same MTU
- Must be configured on both ends of the connection

### 3. Windows Link Aggregation Limitations
When testing with Windows servers/clients:

- Windows Server Standard edition limits teaming to 1Gbps per connection
- Use Windows Server Datacenter edition for full 10Gbps aggregation
- Consider using SMB Direct (RDMA) instead of traditional teaming for best performance
- Verify NIC teaming mode (LACP vs Static) matches switch configuration

### 4. Interrupt Coalescing
Adjust interrupt coalescing to balance between latency and CPU usage:

```bash
# View current settings
ethtool -c ethX

# Example adjustment (values in microseconds)
ethtool -C ethX rx-usecs 50 tx-usecs 50
```

### 5. CPU Affinity and IRQ Balancing
For multi-core systems:

```bash
# Set IRQ affinity to specific cores
echo "mask" > /proc/irq/XX/smp_affinity

# Disable irqbalance service
systemctl stop irqbalance
```

### 6. TCP Window Size
Adjust for high bandwidth-delay product networks:

```bash
# Increase maximum TCP window size
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
```

### 7. HP NC523SFP-Specific Tuning
For optimal performance with HP NC523SFP adapters:

```bash
# Enable SR-IOV if available (requires BIOS support)
ethtool --set-priv-flags ethX sr-iov on

# Adjust ring parameters
ethtool -G ethX rx 4096 tx 4096

# Verify firmware is up to date
ethtool -i ethX
```

## Verification Commands
After applying settings, verify with:

```bash
# Check offloading settings
ethtool -k ethX

# Check interface statistics
ethtool -S ethX

# Monitor interrupts
cat /proc/interrupts | grep ethX
```

## Important Notes
- All changes should be tested systematically - don't adjust multiple parameters at once
- Consider making changes persistent through /etc/network/interfaces or equivalent
- Reboot may be required for some settings to take effect
- Document all changes made for reproducibility
## License

MIT License - Free for personal and commercial use


