#!/usr/bin/env bash
# Two-process network check: a headless host and a headless client on localhost.
# Usage: tests/net/run_net_check.sh   (set GODOT if godot isn't on PATH)
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PORT="${PORT:-7790}"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 40 "$GODOT" --headless --path . tests/net/net_probe.tscn -- host "$PORT" > /tmp/netcheck_host.log 2>&1 &
HOST_PID=$!
sleep 1
timeout 40 "$GODOT" --headless --path . tests/net/net_probe.tscn -- join "$PORT" > /tmp/netcheck_join.log 2>&1
JOIN_RC=$?
wait $HOST_PID
HOST_RC=$?
grep -h "NETCHECK\|SCRIPT ERROR\|ERROR:" /tmp/netcheck_host.log /tmp/netcheck_join.log
if [[ $HOST_RC -eq 0 && $JOIN_RC -eq 0 ]]; then
	echo "Network check passed."
	exit 0
fi
echo "Network check FAILED (host=$HOST_RC join=$JOIN_RC). Logs: /tmp/netcheck_host.log /tmp/netcheck_join.log"
exit 1
