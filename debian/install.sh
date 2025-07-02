#!/bin/bash
# Install iPerf3 with error handling

echo "Setting up iPerf3 server..."

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo)" >&2
    exit 1
fi

# Install dependencies
if ! command -v iperf3 &> /dev/null; then
    echo "Installing iPerf3..."
    apt-get update && apt-get install -y iperf3 jq bc || {
        echo "Failed to install packages" >&2
        exit 1
    }
fi

# Configure firewall
echo "Configuring firewall..."
ufw allow 5201:5300/tcp || echo "Warning: Failed to configure firewall" >&2

# Install server script
echo "Installing server control script..."
cp iperf-server.sh /usr/local/bin/ && \
chmod +x /usr/local/bin/iperf-server.sh || {
    echo "Failed to install server script" >&2
    exit 1
}

# Install client script
echo "Installing client control script..."
cp iperf-client.sh /usr/local/bin/ && \
chmod +x /usr/local/bin/iperf-client.sh || {
    echo "Failed to install client script" >&2
    exit 1
}

echo -e "\nDebian server setup complete!"
echo "To start server: iperf-server.sh"
echo "To start client: iperf-client.sh"
