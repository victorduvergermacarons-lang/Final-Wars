#!/usr/bin/env bash
# Multi-process network check: a headless host and PLAYERS-1 headless clients on
# localhost. Usage: tests/net/run_net_check.sh   (env: GODOT, PORT, PLAYERS=4)
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PORT="${PORT:-7790}"
PLAYERS="${PLAYERS:-4}"
LOGS="${TMPDIR:-/tmp}/netcheck"
mkdir -p "$LOGS"
rm -f "$LOGS"/*.log

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 60 "$GODOT" --headless --path . tests/net/net_probe.tscn -- host "$PORT" "$PLAYERS" > "$LOGS/host.log" 2>&1 &
HOST_PID=$!
sleep 1
PIDS=()
for i in $(seq 1 $((PLAYERS - 1))); do
	timeout 60 "$GODOT" --headless --path . tests/net/net_probe.tscn -- join "$PORT" "$PLAYERS" "$i" > "$LOGS/join$i.log" 2>&1 &
	PIDS+=($!)
	sleep 0.3
done
FAIL=0
for pid in "${PIDS[@]}"; do
	wait "$pid" || FAIL=1
done
wait $HOST_PID || FAIL=1
grep -h "NETCHECK\|SCRIPT ERROR\|ERROR:" "$LOGS"/*.log
if [[ $FAIL -eq 0 ]]; then
	echo "Network check passed ($PLAYERS players)."
	exit 0
fi
echo "Network check FAILED. Logs: $LOGS/"
exit 1
