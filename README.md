
![Network Speed Test](https://img.shields.io/badge/network-testing-blue?style=for-the-badge) 
![Multi-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=for-the-badge)
![PowerShell](https://img.shields.io/badge/powershell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Bash](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)

# iPerf3 Multicore Network Performance Testing scripts

A complete solution for testing network throughput between Windows and Linux systems with LACP bonding support on 10GbE.

This iPerf3 network testing suite provides automated, cross-platform scripts for measuring network throughput between Windows and Linux systems. The Windows client scripts (install.ps1 and iperf-client.ps1) automatically download and configure iPerf3, then launch parallel test streams across all CPU cores with customizable duration, window size, and packet size parameters. On the Linux server side (install.sh and iperf-server.sh), the scripts handle dependency installation, firewall configuration, and start multiple iPerf3 server instances - one per available core - listening on consecutive ports from 5201 upward. Both sets of scripts feature automatic PATH configuration and are designed for zero-touch deployment, enabling users to go from a fresh system clone to running comprehensive network benchmarks in under a minute. The solution intelligently scales based on available hardware resources while maintaining precise per-connection metrics collection.

## ✨ Features

- 🚀 **Parallel testing** across all CPU cores
- 📊 **Detailed metrics**
- ⏱️ **Actual vs target time** comparison
- 🔗 **Port-specific results** for **bond** analysis

## Quick Start

### 1. Server Setup (Debian/Ubuntu)

```bash
# Clone repository
git clone https://github.com/pip3-kill-me/iperf3-multicore-automation
cd iperf3-network-test/debian

# Install and start server (as root)
sudo bash install.sh
iperf-server.sh
```

### 2. Server Setup (Windows)
```powershell
.\iperf-servers.ps1 [-BasePort <port>] [-Cores <number>]
```
| Parameter    | Default               | Description                                  |
|-------------|-----------------------|----------------------------------------------|
| `-BasePort` | `5201`                | Starting port for iPerf3 servers.            |
| `-Cores`    | *(Auto-detected)*     | Number of server instances (one per core).   |

**Example**:  
```powershell
.\iperf-servers.ps1 -BasePort 6000 -Cores 4  # Starts servers on ports 6000-6003
```

> [!NOTE]  
> Press **`Ctrl+C`** to stop all servers and clean up processes.

### 2. On Windows Client (PowerShell as Admin)

```powershell
# Clone repository
git clone https://github.com/pip3-kill-me/iperf3-multicore-automation
cd iperf3-network-test\windows

# Install and run client
.\install.ps1
iperf-client.ps1 -ServerIP 192.168.1.100 -Duration 60
```

## Detailed Usage

### **On Debian Client (iperf-multicore-client.sh)**
```bash
./iperf-multicore-client.sh -s <address> -t <seconds> -w <size> -l <size>
```
| Parameter | Default | Description |
| :---- | :---- | :---- |
| `\-s, \--server` | **Required** | The IP address of the iperf3 server. |
| `\-t, \--time` | 30 | The test duration for each client in seconds. |
| `\-u, \--udp` |  | UDP mode. |
| `\-b, \--bandwidth` | 1G | Bandwidth for UDP mode. |
| `\-w, \--window` | 256k | The TCP window size (e.g., 512k, 1M). |
| `\-l, \--length` | 64K | The size of the packet to send (e.g., 128K). |

### **Windows Client Options**

```powershell
.\iperf-client.ps1 -ServerIP <IP> 
    [-Duration <seconds>] 
    [-WindowSize <size>] 
    [-PacketSize <size>]
```

| Parameter     | Default  | Description                    |
| ------------- | -------- | ------------------------------ |
| `-ServerIP`   | Required | Server IP address              |
| `-Udp     `   |          | UDP mode                       |
| `-Bandwidth`  | 1G       | Bandwidth for UDP mode         |
| `-Duration`   | 30       | Test duration in seconds       |
| `-WindowSize` | 2M       | TCP window size (e.g., 1M, 8M) |
| `-PacketSize` | 64K      | Packet size (e.g., 128K)       |

### Linux Server Management

```bash
# Start server (default uses all cores)
iperf-server.sh

# Stop all iPerf3 servers
sudo pkill iperf3
```
> [!IMPORTANT]  
> If the core count is heterogeneus, open the server on the machine with the greatest amount of cores.

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
> [!CAUTION]
> Disabling large receive offload can cause unexpected behaviour in LACP.
> 
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

# Windows Network Tuning for High-Performance iperf3 Testing with HP NC523SFP

## Windows-Specific Configuration

### 1. Disabling Offloading Features

**PowerShell Commands:**

```powershell
# Disable TCP Chimney Offload (recommended for benchmarking)
Set-NetOffloadGlobalSetting -Chimney Disabled

# Disable RSS (Receive Side Scaling) if experiencing core imbalance
Disable-NetAdapterRss -Name "Ethernet*"

# Disable all offloading features (requires admin)
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "TCP Checksum Offload (IPv4)" -DisplayValue "Disabled"
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "UDP Checksum Offload (IPv4)" -DisplayValue "Disabled"
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Disabled"
```

**Note:** Some features may appear differently depending on NIC driver version.

### 2. Jumbo Frames Configuration

**GUI Method:**

1. Open "Network Connections"
2. Right-click your adapter → Properties → Configure
3. Advanced tab → Find "Jumbo Packet" or "MTU"
4. Set value to 9014 (or highest supported)
5. Click OK and restart the connection

**PowerShell Method:**

```powershell
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "Jumbo Packet" -DisplayValue "9014"
Restart-NetAdapter -Name "Ethernet"
```

### 3. Windows NIC Teaming (LBFO)

**Limitations to be aware of:**

- Windows Server Standard edition has throughput limitations
- Switch-independent mode doesn't require switch configuration but may have lower performance
- Dynamic mode (LACP) requires switch support
- This method no longer works on Windows 10, as Microsoft, in their infinite wisdom, decided to remove LACP configuration options

**PowerShell Configuration:**

```powershell
# Create new team
New-NetLbfoTeam -Name "iperfTeam" -TeamMembers "Ethernet1","Ethernet2" -TeamingMode SwitchIndependent -LoadBalancingAlgorithm Dynamic

# Verify team status
Get-NetLbfoTeam | Select Name, Status, TeamMembers
```

### 4. TCP Window Scaling

**Registry Edits (requires admin):**

```powershell
# Enable Window Scaling
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Tcp1323Opts" -Value 3

# Set auto-tuning level
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPWindowSize" -Value 64240
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpWindowScaling" -Value 1

# Set RWIN size (decimal)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "GlobalMaxTcpWindowSize" -Value 16777216
```

**Note:** Reboot required for these changes to take effect.

### 5. HP NC523SFP-Specific Tuning on Windows

**Driver Settings:**

1. Open Device Manager
2. Expand Network Adapters
3. Right-click HP NC523SFP → Properties
4. Advanced tab recommended settings:
   - Receive Buffers: 4096
   - Transmit Buffers: 4096
   - Interrupt Moderation: Disabled (for benchmarking)
   - SR-IOV: Enabled (if available)
5. Power Management tab → Disable "Allow the computer to turn off this device"

### 6. Disabling Energy Efficient Ethernet

```powershell
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled"
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "Green Ethernet" -DisplayValue "Disabled"
```

### 7. Verifying Settings

**PowerShell Commands:**

```powershell
# Check offloading status
Get-NetOffloadGlobalSetting

# Check adapter advanced properties
Get-NetAdapterAdvancedProperty -Name "Ethernet"

# Check TCP parameters
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

# Check driver information
Get-NetAdapter | Select Name, DriverVersion, NdisVersion
```

### Important Windows-Specific Notes:

1. The "HP Network Configuration Utility" (if installed) may override some PowerShell settings
2. Windows Firewall can significantly impact performance - either disable or create proper rules
3. For consistent benchmarking results:
   - Disable all unnecessary services
   - Set power profile to "High Performance"
   - Consider testing in "Windows Server Core" mode for minimal overhead
4. Some settings may require driver-specific commands - consult HP documentation for your exact driver version

## Important Notes

- All changes should be tested systematically - don't adjust multiple parameters at once
- Consider making changes persistent through /etc/network/interfaces or equivalent
- Reboot may be required for some settings to take effect
- Document all changes made for reproducibility

## License

MIT License - Free for personal and commercial use

---
[pip3-kill-me](https://github.com/pip3-kill-me)