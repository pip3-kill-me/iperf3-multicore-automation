#!/bin/bash

# Check for required commands
for cmd in bc jq iperf3; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please run:"
        echo "sudo apt install -y bc jq iperf3"
        exit 1
    fi
done

# Required parameter: server IP
SERVER_IP=$1
[ -z "$SERVER_IP" ] && { echo "Usage: $0 <server_ip> [-t duration] [-w window_size] [-l packet_size]"; exit 1; }
shift

# Default values
DURATION=30
WINDOW_SIZE="10M"
PACKET_SIZE="64K"
BASE_PORT=5201
CORES=$(nproc)
TIMEFORMAT="%R"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--time) DURATION=$2; shift 2 ;;
        -w|--window) WINDOW_SIZE=$2; shift 2 ;;
        -l|--length) PACKET_SIZE=$2; shift 2 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

echo "Starting $CORES parallel clients to $SERVER_IP..."
echo "Test duration: $DURATION seconds per client"

# Create temp directory
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Function to display progress bar
progress_bar() {
    local duration=$1
    local elapsed=0
    local bar_length=50
    
    while [ $elapsed -le $duration ]; do
        local progress=$((elapsed * bar_length / duration))
        local remaining=$((bar_length - progress))
        printf "\r["
        printf "%${progress}s" | tr ' ' '='
        printf "%${remaining}s" | tr ' ' ' '
        printf "] %ds/%ds" $elapsed $duration
        sleep 1
        elapsed=$((elapsed + 1))
    done
    printf "\n"
}

# Run tests
START_TIME=$(date +%s.%N)

for ((CORE=0; CORE<$CORES; CORE++)); do
    PORT=$((BASE_PORT + CORE))
    taskset -c $CORE iperf3 \
        -c "$SERVER_IP" \
        -p $PORT \
        -t $DURATION \
        -w "$WINDOW_SIZE" \
        -l "$PACKET_SIZE" \
        --json > "$TMPDIR/result-$PORT.json" &
done

# Show progress bar while waiting
progress_bar $DURATION &
PROGRESS_PID=$!
wait
kill $PROGRESS_PID 2>/dev/null

END_TIME=$(date +%s.%N)
ACTUAL_DURATION=$(printf "%.2f" $(echo "$END_TIME - $START_TIME" | bc))

# Process results
TOTAL_BW=0
RESULTS=()

for FILE in "$TMPDIR"/result-*.json; do
    PORT=$(basename "$FILE" | cut -d'-' -f2 | cut -d'.' -f1)
    BW=$(jq -r '.end.sum_received.bits_per_second/1e9' "$FILE" | xargs printf "%.2f")
    RESULTS+=("Port $PORT: $BW Gbps")
    TOTAL_BW=$(echo "$TOTAL_BW + $BW" | bc)
done

# Display summary
echo -e "\n=== Individual Results ==="
printf "%s\n" "${RESULTS[@]}"

echo -e "\n=== Summary ==="
echo "Cores used:    $CORES"
echo "Target time:   $DURATION seconds"
echo "Actual time:   $ACTUAL_DURATION seconds"
echo "Total speed:   $(printf "%.2f" $TOTAL_BW) Gbps"