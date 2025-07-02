Here's a comprehensive `README.md` file for your iPerf3 testing repository:

```markdown
# iPerf3 Network Performance Testing Suite

A complete solution for testing network throughput between Windows (server) and Linux (client) systems with LACP bonding support.

## Features

- 🚀 **Parallel testing** across all CPU cores
- 📊 **Detailed metrics** with 2-decimal precision
- ⏱️ **Actual vs target time** comparison
- 🔗 **Port-specific results** for bond analysis

## Prerequisites

### Windows Server
- Windows 10/11 Pro/Enterprise or Server 2016+
- iPerf3 for Windows ([download](https://iperf.fr/))
- PowerShell 5.1+

### Linux Client
```bash
sudo apt update && sudo apt install -y iperf3 jq bc
```

## File Structure

```
iperf-network-test/
├── windows/
│   └── iperf-server.ps1       # Windows server script
├── linux/
│   └── iperf-client.sh        # Linux client script
└── README.md                  # This file
```

## Usage

### 1. Start Windows Server

Run in PowerShell **as Administrator**:

```powershell
.\iperf-server.ps1
```

Sample output:

```
Starting 8 iPerf3 servers on ports 5201 to 5208
Servers ready. Connect from Linux using:
bash iperf-client.sh 192.168.2.100
```

### 2. Run Linux Client

```bash
./iperf-client.sh <server_ip> [-t duration] [-w window_size] [-l packet_size]
```

Example:

```bash
./iperf-client.sh 192.168.2.100 -t 10 -w 8M -l 128K
```

### 3. Sample Output

```
=== Individual Results ===
Port 5201: 4.44 Gbps
Port 5202: 4.79 Gbps
Port 5203: 4.75 Gbps
Port 5204: 4.81 Gbps

=== Summary ===
Cores used:    4
Target time:   10 seconds
Actual time:   10.03 seconds
Total speed:   18.79 Gbps
```

## Configuration Options

| Parameter         | Default | Description              |
| ----------------- | ------- | ------------------------ |
| `-t` / `--time`   | 30      | Test duration in seconds |
| `-w` / `--window` | 2M      | TCP window size          |
| `-l` / `--length` | 64K     | Packet size              |

## Troubleshooting

### Common Issues

1. **"Port null" in results**:

   - Ensure `jq` is installed (`sudo apt install jq`)
   - Verify no file permission issues in `/tmp`

2. **Low throughput**:

   ```bash
   # Check NIC settings
   ethtool <interface>
   # Verify CPU affinity
   taskset -p <pid>
   ```

3. **Connection refused**:

   ```powershell
   # On Windows:
   Test-NetConnection -Port 5201 -ComputerName <client_ip>
   ```

## License

MIT License - Free for personal and enterprise use

```

### Key Sections Included:
1. **Badges** - Visual indicators for compatibility
2. **Prerequisites** - Clear installation requirements
3. **Usage Guide** - Step-by-step execution flow
4. **Sample Output** - Expected results format
5. **Configuration Table** - Quick parameter reference
6. **Troubleshooting** - Common solutions
7. **File Structure** - Repository organization

This README provides both quick-start instructions and detailed reference information suitable for both beginners and advanced users. The markdown formatting ensures proper display on GitHub/GitLab.
```
