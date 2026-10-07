#!/usr/bin/env bash
# Two co-op windows on a locally imported cartridge, driven by a scenario and
# captured to PNGs, with a private user folder: the owner's campaigns, identity
# and logs are never touched, and runs side by side do not meet.
#
#   GODOT=<4.8-dev4 binary> tools/coop_screens.sh <scenario> [out dir]
#
# A scenario (tools/coop_screens/<name>.sh) is sourced and calls, with seconds
# counted from the moment that window's world opens (60 frames a second):
#   press <p1|p2> <second> KEY...   KEYs one per 0.3 s from that second (U D L R A B START SELECT, - waits)
#   shot  <p1|p2> <second> <name>   writes <out>/<name>.png
#   close <p1|p2> <second>          closes that window, in seconds after it was launched
# and may set GAME (red), DURATION, P2_DELAY, HOST_ARGS (bare), P1_ARGS, P2_ARGS (opening),
# P1_TOOL and P2_TOOL (coop_play, or coop_autoplay, whose run ends the scenario
# early once both windows print "autoplay: ... finished" or "FAILED"), and may
# define verify, run once the windows are closed: non-zero fails the scenario.
# The out dir defaults to /tmp/coop_screens/<scenario>; it must be outside the
# repository, since captures show cartridge graphics. Exits non-zero when a
# process logged a script error.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
scenario="${1:?usage: GODOT=<binary> tools/coop_screens.sh <scenario> [out dir]}"
[[ -f "$scenario" ]] || scenario="$root/tools/coop_screens/$scenario.sh"
name="$(basename "$scenario" .sh)"
out="$(realpath -m "${2:-/tmp/coop_screens/$name}")"
godot="${GODOT:?set GODOT to the Godot 4.8-dev4 binary}"
real_user="${REAL_USER_DIR:-$HOME/.local/share/godot/app_userdata/pokerecomp}"
case "$out/" in "$root"/*) echo "coop_screens: $out is inside the repository" >&2; exit 2 ;; esac

GAME=red DURATION=60 P2_DELAY=4 HOST_ARGS="" P1_ARGS="" P2_ARGS="" P1_TOOL=coop_play P2_TOOL=coop_play
declare -A keys=([p1]="" [p2]="") shots=([p1]="" [p2]="") closes=()
start_frames=90 slot_frames=18 fps=60

press() {
	local who="$1" at="$2"; shift 2
	local slot list
	slot=$(awk -v t="$at" -v s="$start_frames" -v f="$slot_frames" -v r="$fps" 'BEGIN { printf "%d", (t * r - s) / f + 0.5 }')
	IFS=, read -r -a list <<< "${keys[$who]}"
	while (( ${#list[@]} < slot )); do list+=("-"); done
	(( ${#list[@]} == slot )) || { echo "coop_screens: $who press at ${at}s overlaps earlier keys" >&2; exit 2; }
	list+=("$@")
	keys[$who]="$(IFS=,; echo "${list[*]}")"
}
shot() { shots[$1]+=" capture=$out/$3.png@$(awk -v t="$2" -v r="$fps" 'BEGIN { printf "%d", t * r }')"; }
close() { closes[$1]="$2"; }

# shellcheck source=/dev/null
source "$scenario"

rm -rf "$out" && mkdir -p "$out"
xdg="$out/xdg"
user="$xdg/godot/app_userdata/pokerecomp"
mkdir -p "$user/rom_cache"
cache="$(find "$real_user/rom_cache" -maxdepth 1 -name "${GAME}_????????" -print -quit)"
[[ -n "$cache" ]] || { echo "coop_screens: no imported $GAME under $real_user/rom_cache" >&2; exit 2; }
ln -s "$cache" "$user/rom_cache/"
port="${PORT:-$(( 24800 + RANDOM % 900 ))}"
pids=()
finish() { kill "${pids[@]}" 2>/dev/null || true; }
trap finish EXIT

cd "$root"
XDG_DATA_HOME="$xdg" "$godot" --headless --path . -s res://tools/coop_session.gd -- host "$port" "$GAME" $HOST_ARGS > "$out/host.log" 2>&1 &
pids+=($!)
for _ in $(seq 60); do grep -q "host on port" "$out/host.log" && break; sleep 0.5; done

launch() {
	local who="$1" extra="$2" tool="$3"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$xdg" "$godot" --max-fps "$fps" --path . -s "res://tools/$tool.gd" -- 127.0.0.1 "$port" "$who" "$GAME" \
		$extra ${keys[$who]:+keys=${keys[$who]}} ${shots[$who]} > "$out/$who.log" 2>&1 &
	local pid=$!
	pids+=("$pid")
	if [[ -n "${closes[$who]:-}" ]]; then
		(sleep "${closes[$who]}"; kill "$pid" 2>/dev/null || true) &
	fi
}
launch p1 "$P1_ARGS" "$P1_TOOL"
sleep "$P2_DELAY"
launch p2 "$P2_ARGS" "$P2_TOOL"
ended() { grep -qE "autoplay: [a-z0-9]+ (finished|FAILED)" "$out/$1.log" || [[ "$2" != coop_autoplay ]]; }
for (( waited = 0; waited < DURATION; waited += 2 )); do
	sleep 2
	if [[ "$P1_TOOL$P2_TOOL" == *coop_autoplay* ]] && ended p1 "$P1_TOOL" && ended p2 "$P2_TOOL"; then break; fi
done
sleep 3
grep -h "autoplay:" "$out/p1.log" "$out/p2.log" || true
finish
sleep 1
XDG_DATA_HOME="$xdg" "$godot" --headless --path . -s res://tools/coop_log.gd -- summary user://coop_logs > "$out/summary.txt" 2>&1 || true

ls "$out"/*.png 2>/dev/null || echo "coop_screens: no captures"
if grep -h "SCRIPT ERROR" "$out"/host.log "$out"/p1.log "$out"/p2.log; then
	echo "coop_screens: $name logged script errors" >&2
	exit 1
fi
if grep -q "autoplay: .*FAILED" "$out"/p1.log "$out"/p2.log; then
	echo "coop_screens: $name: an autoplayed window failed" >&2
	exit 1
fi
if declare -F verify > /dev/null && ! verify; then
	echo "coop_screens: $name: verify found the result wrong" >&2
	exit 1
fi
echo "coop_screens: $name done, captures in $out"
