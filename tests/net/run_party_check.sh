#!/usr/bin/env bash
# Multi-process check of loot, boss rolls, binding, trading and duels: a headless
# host and two headless clients on localhost play one scenario.
# Usage: tests/net/run_party_check.sh SCENARIO   (loot | roll | trade | duel)
# env: GODOT, PORT, PLAYERS (3)
set -uo pipefail
cd "$(dirname "$0")/../.."
SCENARIO="${1:-loot}"
GODOT="${GODOT:-godot}"
PORT="${PORT:-7795}"
PLAYERS="${PLAYERS:-3}"
LOGS="${TMPDIR:-/tmp}/partycheck"
mkdir -p "$LOGS"
rm -f "$LOGS"/*.log

timeout 90 "$GODOT" --headless --path . tests/net/party_probe.tscn -- host "$PORT" "$PLAYERS" "$SCENARIO" > "$LOGS/host.log" 2>&1 &
HOST_PID=$!
sleep 1.5
PIDS=()
for i in $(seq 1 $((PLAYERS - 1))); do
	timeout 90 "$GODOT" --headless --path . tests/net/party_probe.tscn -- join "$PORT" "$PLAYERS" "$SCENARIO" "$i" > "$LOGS/join$i.log" 2>&1 &
	PIDS+=($!)
	sleep 0.3
done
FAIL=0
for pid in "${PIDS[@]}"; do
	wait "$pid" || FAIL=1
done
wait $HOST_PID || FAIL=1
grep -h "PARTYCHECK\|SCRIPT ERROR" "$LOGS"/*.log
if [[ $FAIL -eq 0 ]]; then
	echo "Party check '$SCENARIO' passed ($PLAYERS players)."
	exit 0
fi
echo "Party check '$SCENARIO' FAILED. Logs: $LOGS/"
exit 1
