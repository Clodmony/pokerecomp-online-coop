#!/bin/sh
# The co-op slice as three processes over localhost ENet: the host and both
# players of `tools/coop_session.gd -- check`, on the synthetic cache. Each runs
# under tools/ci_godot.sh, so a hang is killed with its stacks after the
# timeout. Exits non-zero unless all three passed.
#
# Usage: GODOT=godot tools/coop_two_process.sh [port] [timeout_seconds]
# The defaults are port 24690 and 120 seconds a process; GODOT defaults to godot.
set -u

cd "$(dirname "$0")/.." || exit 1
godot="${GODOT:-godot}"
port="${1:-24690}"
cap="${2:-120}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

start() {
	(
		GODOT_CAP="$cap" GODOT_DONE="coop check $1: all" tools/ci_godot.sh "$godot" \
			--headless --path . -s res://tools/coop_session.gd -- check "$1" "$port" \
			>"$work/$1.log" 2>&1
		echo $? >"$work/$1.exit"
	) &
}

# The players dial once the host listens; a host that never does ends with its cap.
start host
until grep -qF "coop: host on port $port" "$work/host.log" 2>/dev/null || [ -f "$work/host.exit" ]; do
	sleep 1
done
if [ ! -f "$work/host.exit" ]; then
	start p1
	start p2
fi
wait

failed=0
for role in host p1 p2; do
	status="$(cat "$work/$role.exit" 2>/dev/null || echo "not started")"
	echo "----- $role: exit $status -----"
	cat "$work/$role.log" 2>/dev/null
	[ "$status" = 0 ] || failed=1
done
if [ "$failed" -ne 0 ]; then
	echo "::error::the two-process co-op check failed on port $port"
fi
exit "$failed"
