#!/usr/bin/env bash
# Two co-op windows on a locally imported cartridge, driven by a scenario and
# captured to PNGs, with a private user folder: the owner's campaigns, identity
# and logs are never touched, and runs side by side do not meet.
#
#   GODOT=<4.8-dev7 binary> tools/coop_screens.sh <scenario> [out dir]
#
# A scenario (tools/coop_screens/<name>.sh) is sourced and calls, with seconds
# counted from the moment that window's world opens (60 frames a second):
#   press <p1|p2> <second> KEY...   KEYs one per 0.3 s from that second (U D L R A B START SELECT, - waits, D*6 holds D six)
#   shot  <p1|p2> <second> <name>   writes <out>/<name>.png
#   close <p1|p2> <second>          closes that window, in seconds after it was launched
# and may set GAME (red), P2_GAME (GAME: Blue joins a Red host), DURATION, P2_DELAY, HOST_ARGS (bare), P1_ARGS, P2_ARGS (opening),
# P1_TOOL and P2_TOOL (coop_play, or coop_autoplay, whose run ends the scenario
# early once both windows print "autoplay: ... finished" or "FAILED").
# HOST_TOOL=none starts no tool host, for windows that host from the launcher
# (coop_launcher_play, whose seconds count from launch); SEED=<dir> starts from the
# coop_campaigns and coop_identity.json a past run left there; a scenario may define
# check(), run last, that fails the scenario by returning non-zero.
# An autoplayed window starts at leg P1_FROM / P2_FROM (each defaults to FROM), and an
# autoplayed run has the host snapshot the campaign and each window's leg every 10 s
# into <out>/snapshots/<n>/ (SNAPSHOTS=0 turns it off): tools/coop_resume.sh reruns
# the scenario from one. <out>/run.env records the scenario and what shaped it.
# The out dir defaults to ~/dev-scratch/pokerecomp-online-coop/coop_screens/<scenario> (COOP_SCREENS_OUT
# moves it); it must be outside the
# repository, since captures show cartridge graphics. Exits non-zero when a
# process logged a script error.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
scenario="${1:?usage: GODOT=<binary> tools/coop_screens.sh <scenario> [out dir]}"
[[ -f "$scenario" ]] || scenario="$root/tools/coop_screens/$scenario.sh"
name="$(basename "$scenario" .sh)"
out="$(realpath -m "${2:-${COOP_SCREENS_OUT:-$HOME/dev-scratch/pokerecomp-online-coop/coop_screens}/$name}")"
godot="${GODOT:?set GODOT to the Godot 4.8-dev7 binary}"
real_user="${REAL_USER_DIR:-$HOME/.local/share/godot/app_userdata/pokerecomp}"
case "$out/" in "$root"/*) echo "coop_screens: $out is inside the repository" >&2; exit 2 ;; esac

GAME="${GAME:-red}" DURATION=60 P2_DELAY=4 HOST_ARGS="" P1_ARGS="" P2_ARGS="" P1_TOOL=coop_play P2_TOOL=coop_play HOST_TOOL=coop_session
declare -A keys=([p1]="" [p2]="") shots=([p1]="" [p2]="") closes=()
start_frames=90 slot_frames=18 fps=${FPS:-60}

press() {
	local who="$1" at="$2"; shift 2
	local slot list
	slot=$(awk -v t="$at" -v s="$start_frames" -v f="$slot_frames" -v r="$fps" 'BEGIN { printf "%d", (t * r - s) / f + 0.5 }')
	IFS=, read -r -a list <<< "${keys[$who]}"
	while (( ${#list[@]} < slot )); do list+=("-"); done
	(( ${#list[@]} == slot )) || { echo "coop_screens: $who press at ${at}s overlaps earlier keys" >&2; exit 2; }
	local key
	for key in "$@"; do
		if [[ "$key" == *"*"* ]]; then
			list+=("${key%%\**}")
			for (( n = 1; n < ${key##*\*}; n++ )); do list+=("~"); done
		else
			list+=("$key")
		fi
	done
	keys[$who]="$(IFS=,; echo "${list[*]}")"
}
shot() { shots[$1]+=" capture=$out/$3.png@$(awk -v t="$2" -v r="$fps" 'BEGIN { printf "%d", t * r }')"; }
close() { closes[$1]="$2"; }

# shellcheck source=/dev/null
source "$scenario"
P1_FROM="${P1_FROM:-${FROM:-}}" P2_FROM="${P2_FROM:-${FROM:-}}"
[[ "$P1_TOOL" != coop_autoplay || -z "$P1_FROM" ]] || P1_ARGS+=" from=$P1_FROM"
[[ "$P2_TOOL" != coop_autoplay || -z "$P2_FROM" ]] || P2_ARGS+=" from=$P2_FROM"
[[ "$P1_TOOL$P2_TOOL" != *coop_autoplay* || "${SNAPSHOTS:-1}" == 0 ]] || HOST_ARGS+=" snapshots=$out/snapshots"

rm -rf "$out" && mkdir -p "$out"
[[ "$scenario" != "$root/tools/coop_screens/$name.sh" ]] || scenario="$name"
printf '%s\n' "SCENARIO=$scenario" "P1_FROM=$P1_FROM" "P2_FROM=$P2_FROM" "WHITEOUT=${WHITEOUT:-}" "KILL=${KILL:-}" > "$out/run.env"
xdg="$out/xdg"
user="$xdg/godot/app_userdata/pokerecomp"
mkdir -p "$user/rom_cache"
[[ -z "${SEED:-}" ]] || cp -r "$SEED/coop_campaigns" "$SEED/coop_identity.json" "$user/"
P2_GAME="${P2_GAME:-$GAME}"
for game in $(printf '%s\n' "$GAME" "$P2_GAME" | sort -u); do
	cache="$(find "$real_user/rom_cache" -maxdepth 1 -name "${game}_????????" -print -quit)"
	[[ -n "$cache" ]] || { echo "coop_screens: no imported $game under $real_user/rom_cache" >&2; exit 2; }
	ln -s "$(realpath "$cache")" "$user/rom_cache/"
done
port="${PORT:-$(( 24800 + RANDOM % 900 ))}"
pids=()
finish() { kill "${pids[@]}" 2>/dev/null || true; }
trap finish EXIT

cd "$root"
if [[ "$HOST_TOOL" == none ]]; then
	echo "coop_screens: no tool host" > "$out/host.log"
else
	XDG_DATA_HOME="$xdg" "$godot" --headless --path . -s "res://tools/$HOST_TOOL.gd" -- host "$port" "$GAME" $HOST_ARGS > "$out/host.log" 2>&1 &
	pids+=($!)
	for _ in $(seq 60); do grep -q "host on port" "$out/host.log" && break; sleep 0.5; done
fi

launch() {
	local who="$1" extra="$2" tool="$3" game="$GAME"
	[[ "$who" != p2 ]] || game="$P2_GAME"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$xdg" "$godot" --max-fps "$fps" --path . -s "res://tools/$tool.gd" -- 127.0.0.1 "$port" "$who" "$game" \
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
if declare -F check > /dev/null && ! check; then
	echo "coop_screens: $name: the scenario's check failed" >&2
	exit 1
fi
echo "coop_screens: $name done, captures in $out"
