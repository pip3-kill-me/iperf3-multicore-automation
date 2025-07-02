#!/bin/bash

# --- Check for required commands ---
for cmd in bc jq iperf3; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please run:"
        echo "sudo apt update && sudo apt install -y bc jq iperf3"
        exit 1
    fi
done

# --- Default values ---
SERVER_IP=""
DURATION=30
WINDOW_SIZE="256k"
PACKET_SIZE="64K"
BASE_PORT=5201
CORES=$(nproc)
TIMEFORMAT="%R"

# --- Function to display usage ---
usage() {
    echo "Usage: $0 -s <server_ip> [-t duration] [-w window_size] [-l packet_size]"
    echo "  -s, --server  The IP address of the iperf3 server (required)."
    echo "  -t, --time    The duration of the test in seconds (default: $DURATION)."
    echo "  -w, --window  The window size (e.g., 256k) (default: $WINDOW_SIZE)."
    echo "  -l, --length  The packet size (e.g., 64K) (default: $PACKET_SIZE)."
    exit 1
}

# --- Parse Command-Line Arguments ---
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -s|--server)
        SERVER_IP="$2"
        shift 2
        ;;
        -t|--time)
        DURATION="$2"
        shift 2
        ;;
        -w|--window)
        WINDOW_SIZE="$2"
        shift 2
        ;;
        -l|--length)
        PACKET_SIZE="$2"
        shift 2
        ;;
        *)
        echo "Unknown parameter: $1"
        usage
        ;;
    esac
done

# --- Validate required arguments ---
if [ -z "$SERVER_IP" ]; then
    echo "Error: Server IP is a required argument."
    usage
fi

echo "Starting $CORES parallel clients to $SERVER_IP..."
echo "Test duration: $DURATION seconds per client"

# --- Create temp directory for results ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Function to display progress bar ---
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

# --- Run tests in parallel ---
START_TIME=$(date +%s.%N)

for ((CORE=0; CORE<$CORES; CORE++)); do
    PORT=$((BASE_PORT + CORE))
    # Pin each iperf3 instance to a specific CPU core
    taskset -c $CORE iperf3 \
        -c "$SERVER_IP" \
        -p $PORT \
        -t $DURATION \
        -w "$WINDOW_SIZE" \
        -l "$PACKET_SIZE" \
        --json > "$TMPDIR/result-$PORT.json" &
done

# Show progress bar while waiting for tests to complete
progress_bar $DURATION &
PROGRESS_PID=$!
wait
kill $PROGRESS_PID 2>/dev/null

END_TIME=$(date +%s.%N)
ACTUAL_DURATION=$(printf "%.2f" $(echo "$END_TIME - $START_TIME" | bc))

# --- Process results ---
TOTAL_BW=0
RESULTS=()

for FILE in "$TMPDIR"/result-*.json; do
    # Check if the file contains valid JSON and results
    if jq -e '.end.sum_received.bits_per_second' "$FILE" >/dev/null 2>&1; then
        PORT=$(basename "$FILE" | cut -d'-' -f2 | cut -d'.' -f1)
        BW=$(jq -r '.end.sum_received.bits_per_second/1e9' "$FILE" | xargs printf "%.2f")
        RESULTS+=("Port $PORT: $BW Gbps")
        TOTAL_BW=$(echo "$TOTAL_BW + $BW" | bc)
    else
        PORT=$(basename "$FILE" | cut -d'-' -f2 | cut -d'.' -f1)
        RESULTS+=("Port $PORT: ERROR - No data received")
    fi
done

# --- Display summary ---
echo -e "\n=== Individual Results ==="
printf "%s\n" "${RESULTS[@]}"

echo -e "\n=== Summary ==="
echo "Cores used:      $CORES"
echo "Target time:     $DURATION seconds"
echo "Actual time:     $ACTUAL_DURATION seconds"
echo "Total Bandwidth: $(printf "%.2f" $TOTAL_BW) Gbps"

