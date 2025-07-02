#!/bin/bash
# Filename: iperf-multicore-client.sh

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
UDP_MODE=false
UDP_BANDWIDTH="1G" # Default UDP bandwidth per stream
REVERSE_MODE=false
BIDIRECTIONAL_MODE=false

# --- Function to display usage ---
usage() {
    echo "Usage: $0 -s <server_ip> [options]"
    echo "Options:"
    echo "  -s, --server <ip>      The IP address of the iperf3 server (required)."
    echo "  -t, --time <secs>      The duration of the test in seconds (default: $DURATION)."
    echo "  -w, --window <size>    The window size (e.g., 256k) (default: $WINDOW_SIZE)."
    echo "  -l, --length <size>    The packet size (e.g., 64K) (default: $PACKET_SIZE)."
    echo "  -U, --udp              Use UDP instead of TCP."
    echo "  -b, --bandwidth <rate> Target bandwidth for UDP tests (e.g., 100M, 1G) (default: $UDP_BANDWIDTH)."
    echo "  -R, --reverse          Run in reverse mode (server sends, client receives)."
    echo "  -d, --bidirectional    Run a bidirectional test simultaneously."
    exit 1
}

# --- Parse Command-Line Arguments ---
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -s|--server) SERVER_IP="$2"; shift 2 ;;
        -t|--time) DURATION="$2"; shift 2 ;;
        -w|--window) WINDOW_SIZE="$2"; shift 2 ;;
        -l|--length) PACKET_SIZE="$2"; shift 2 ;;
        -b|--bandwidth) UDP_BANDWIDTH="$2"; shift 2 ;;
        -U|--udp) UDP_MODE=true; shift ;;
        -R|--reverse) REVERSE_MODE=true; shift ;;
        -d|--bidirectional) BIDIRECTIONAL_MODE=true; shift ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
done

# --- Validate required arguments ---
if [ -z "$SERVER_IP" ]; then
    echo "Error: Server IP is a required argument."
    usage
fi

# --- Announce test type ---
TEST_TYPE="TCP"
if [ "$UDP_MODE" = true ]; then
    TEST_TYPE="UDP"
fi
if [ "$REVERSE_MODE" = true ]; then
    TEST_TYPE="$TEST_TYPE (Reverse)"
elif [ "$BIDIRECTIONAL_MODE" = true ]; then
    TEST_TYPE="$TEST_TYPE (Bidirectional)"
fi

echo "Starting $CORES parallel $TEST_TYPE clients to $SERVER_IP..."
echo "Test duration: $DURATION seconds per client"

# --- Create temp directory for results ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Function to display progress bar ---
progress_bar() {
    local duration=$1
    local elapsed=0
    local bar_length=50

    while [ "$elapsed" -le "$duration" ]; do
        # Calculate progress
        local progress=$((elapsed * bar_length / duration))
        local remaining=$((bar_length - progress))

        # Build the bar string components
        local bar_filled
        bar_filled=$(printf "%${progress}s" | tr ' ' '=')
        local bar_empty
        bar_empty=$(printf "%${remaining}s" | tr ' ' ' ')

        # Print the bar in one go to be safe
        printf "\r[%s%s] %ds/%ds" "$bar_filled" "$bar_empty" "$elapsed" "$duration"

        sleep 1
        elapsed=$((elapsed + 1))
    done
    printf "\n"
}

# --- Run tests in parallel ---
IPERF_ARGS=("-c" "$SERVER_IP" "-t" "$DURATION" "--json")
if [ "$UDP_MODE" = true ]; then
    IPERF_ARGS+=("-u" "-b" "$UDP_BANDWIDTH")
else
    IPERF_ARGS+=("-w" "$WINDOW_SIZE" "-l" "$PACKET_SIZE")
fi
if [ "$REVERSE_MODE" = true ]; then
    IPERF_ARGS+=("-R")
fi
if [ "$BIDIRECTIONAL_MODE" = true ]; then
    IPERF_ARGS+=("-d")
fi

START_TIME=$(date +%s.%N)
for ((CORE=0; CORE<$CORES; CORE++)); do
    PORT=$((BASE_PORT + CORE))
    taskset -c $CORE iperf3 "${IPERF_ARGS[@]}" -p "$PORT" > "$TMPDIR/result-$PORT.json" &
done

progress_bar $DURATION &
PROGRESS_PID=$!
wait
kill $PROGRESS_PID 2>/dev/null
END_TIME=$(date +%s.%N)
ACTUAL_DURATION=$(printf "%.2f" "$(echo "$END_TIME - $START_TIME" | bc)")

# --- Process results ---
TOTAL_BW=0; RESULTS=()
for FILE in "$TMPDIR"/result-*.json; do
    PORT=$(basename "$FILE" | cut -d'-' -f2 | cut -d'.' -f1)
    if ! jq -e . "$FILE" >/dev/null 2>&1; then
        RESULTS+=("Port $PORT: ERROR - Invalid JSON output")
        continue
    fi

    if [ "$UDP_MODE" = true ]; then
        # UDP results parsing
        SUM_BLOCK=$(jq '.end.sum' "$FILE")
        if [ -z "$SUM_BLOCK" ] || [ "$SUM_BLOCK" = "null" ]; then
            RESULTS+=("Port $PORT: ERROR - No UDP summary")
            continue
        fi
        BW=$(echo "$SUM_BLOCK" | jq -r '.bits_per_second/1e9' | xargs printf "%.2f")
        JITTER=$(echo "$SUM_BLOCK" | jq -r '.jitter_ms' | xargs printf "%.3f")
        LOST_PERCENT=$(echo "$SUM_BLOCK" | jq -r '.lost_percent' | xargs printf "%.2f")
        RESULTS+=("Port $PORT: $BW Gbps | Jitter: $JITTER ms | Loss: $LOST_PERCENT%")
        TOTAL_BW=$(echo "$TOTAL_BW + $BW" | bc)
    else
        # TCP results parsing
        SUM_BLOCK_PATH='.end.sum_received'
        if [ "$REVERSE_MODE" = true ]; then
            SUM_BLOCK_PATH='.end.sum_sent'
        fi
        SUM_BLOCK=$(jq "$SUM_BLOCK_PATH" "$FILE")
        if [ -z "$SUM_BLOCK" ] || [ "$SUM_BLOCK" = "null" ]; then
            RESULTS+=("Port $PORT: ERROR - No TCP summary")
            continue
        fi
        BW=$(echo "$SUM_BLOCK" | jq -r '.bits_per_second/1e9' | xargs printf "%.2f")
        RESULTS+=("Port $PORT: $BW Gbps")
        TOTAL_BW=$(echo "$TOTAL_BW + $BW" | bc)
    fi
done

# --- Display summary ---
echo -e "\n=== Individual Results ==="
printf "%s\n" "${RESULTS[@]}"
echo -e "\n=== Summary ==="
echo "Cores used:      $CORES"
echo "Test type:       $TEST_TYPE"
echo "Target time:     $DURATION seconds"
echo "Actual time:     $ACTUAL_DURATION seconds"
echo "Total Bandwidth: $(printf "%.2f" "$TOTAL_BW") Gbps"