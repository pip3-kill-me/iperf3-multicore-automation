#!/bin/bash

# Install iPerf3 if needed
sudo apt update && sudo apt install -y iperf3

# Configuration
BASE_PORT=5201
CORES=$(nproc)
DURATION=60  # Max test duration (seconds)

echo "Starting $CORES iPerf3 servers on ports $BASE_PORT-$((BASE_PORT+CORES-1))..."

# Start servers
for ((CORE=0; CORE<CORES; CORE++)); do
    PORT=$((BASE_PORT + CORE))
    iperf3 -s -p $PORT -1 -D
done

# Open firewall ports
sudo ufw allow $BASE_PORT:$((BASE_PORT+CORES-1))/tcp

echo "Servers ready for Windows client connections"
echo "Run this on Windows:"
echo "iperf-client.ps1 -ServerIP $(hostname -I | awk '{print $1}')"