#!/usr/bin/env bash
# Two co-op windows on a locally imported cartridge, driven by a scenario and
# captured to PNGs, with a private user folder: the owner's campaigns, identity
# and logs are never touched, and runs side by side do not meet.
#
#   GODOT=<4.8-dev7 binary> tools/coop_screens.sh <scenario> [out dir]
#
# A scenario (tools/coop_screens/<name>.sh) is sourced and calls, with seconds
# counted from the moment that window's world opens (60 frames a second):
#   press <p1|p2> <second> KEY...   KEYs one per 0.3 s from that second (U D L R A B START SELECT, - waits, D*6 holds D six);
#                                   in a battle an @ key walks one menu level, is dropped while a turn's lines play, and
#                                   the party list and bag take about 1.5 s to open
#   shot  <p1|p2> <second> <name>   writes <out>/<name>.png
#   close <p1|p2> <second> [signal] closes that window (TERM, or KILL for no goodbye), in seconds after it was launched
#   cut   p2 <second> <seconds> [hold]  with RELAY=p2, p2 dials the host through tools/coop_relay.gd, which drops every
#                                   packet both ways for <seconds> from <second> after p2's first packet (relay.log);
#                                   hold drops only the host's packets to p2's sockets of the cut's start and answers
#                                   the host's reliable ones in p2's place: the host keeps a link p2 has given up
# and may set GAME (red), P2_GAME (GAME: Blue joins a Red host), DURATION, P2_DELAY, HOST_ARGS (bare), P1_ARGS, P2_ARGS (opening),
# P1_TOOL and P2_TOOL (coop_play, or coop_autoplay, whose run ends the scenario
# early once both windows print "autoplay: ... finished" or "FAILED"; P2_TOOL=split
# has p1's Split screen start p2, whose lines land in p1.log).
# HOST_TOOL=none starts no tool host, for windows that host from the launcher
# (coop_launcher_play, whose seconds count from launch); SEED=<dir> starts from the
# coop_campaigns and coop_identity.json a past run left there (or SEED_ARGS="<game> <last leg> [options]" of
# tools/coop_seed.gd builds one into <out>/seed when SEED is unset); a scenario may define
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
command -v "$godot" > /dev/null || { echo "coop_screens: GODOT=$godot is no program (a ~ in it isn't expanded)" >&2; exit 2; }
real_user="${REAL_USER_DIR:-$HOME/.local/share/godot/app_userdata/pokerecomp}"
case "$out/" in "$root"/*) echo "coop_screens: $out is inside the repository" >&2; exit 2 ;; esac

GAME="${GAME:-red}" DURATION=60 P2_DELAY=4 HOST_ARGS="" P1_ARGS="" P2_ARGS="" P1_TOOL=coop_play P2_TOOL=coop_play HOST_TOOL=coop_session
declare -A keys=([p1]="" [p2]="") shots=([p1]="" [p2]="") closes=() signals=()
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
close() { closes[$1]="$2"; signals[$1]="${3:-TERM}"; }
cuts=""
cut() { [[ "$1" == p2 && "${RELAY:-}" == p2 ]] || { echo "coop_screens: cut needs RELAY=p2 and p2" >&2; exit 2; }; cuts+="${cuts:+,}$2:$3${4:+:$4}"; }

# shellcheck source=/dev/null
source "$scenario"
P1_FROM="${P1_FROM:-${FROM:-}}" P2_FROM="${P2_FROM:-${FROM:-}}"
[[ "$P1_TOOL" != coop_autoplay || -z "$P1_FROM" ]] || P1_ARGS+=" from=$P1_FROM"
[[ "$P2_TOOL" != coop_autoplay || -z "$P2_FROM" ]] || P2_ARGS+=" from=$P2_FROM"
[[ "$P1_TOOL$P2_TOOL" != *coop_autoplay* || "${SNAPSHOTS:-1}" == 0 ]] || HOST_ARGS+=" snapshots=$out/snapshots"

rm -rf "$out" && mkdir -p "$out"
[[ "$scenario" != "$root/tools/coop_screens/$name.sh" ]] || scenario="$name"
printf '%s\n' "SCENARIO=$scenario" "P1_FROM=$P1_FROM" "P2_FROM=$P2_FROM" "WHITEOUT=${WHITEOUT:-}" "KILL=${KILL:-}" "SEED=${SEED:-}" > "$out/run.env"
xdg="$out/xdg"
user="$xdg/godot/app_userdata/pokerecomp"
mkdir -p "$user/rom_cache"
P2_GAME="${P2_GAME:-$GAME}"
for game in $(printf '%s\n' "$GAME" "$P2_GAME" | sort -u); do
	cache="$(find "$real_user/rom_cache" -maxdepth 1 -name "${game}_????????" -print -quit)"
	[[ -n "$cache" ]] || { echo "coop_screens: no imported $game under $real_user/rom_cache" >&2; exit 2; }
	ln -s "$(realpath "$cache")" "$user/rom_cache/"
done
if [[ -z "${SEED:-}" && -n "${SEED_ARGS:-}" ]]; then
	read -r -a seed_args <<< "$SEED_ARGS"
	(cd "$root" && XDG_DATA_HOME="$xdg" "$godot" --headless --path . -s res://tools/coop_seed.gd -- "${seed_args[@]:0:2}" "$out/seed" "${seed_args[@]:2}") > "$out/seed.log" 2>&1 \
		|| { echo "coop_screens: $name: the seed was not built (seed.log)" >&2; exit 1; }
	SEED="$out/seed"
	echo "SEED_ARGS=$SEED_ARGS" >> "$out/run.env"
fi
[[ -z "${SEED:-}" ]] || cp -r "$SEED/coop_campaigns" "$SEED/coop_identity.json" "$user/"
port="${PORT:-$(( 24800 + RANDOM % 900 ))}"
pids=()
finish() { kill "${pids[@]}" 2>/dev/null || true; pkill -f "coop_launcher_play.gd -- 127.0.0.1 $port p2 " 2>/dev/null || true; }
trap finish EXIT

cd "$root"
if [[ "$HOST_TOOL" == none ]]; then
	echo "coop_screens: no tool host" > "$out/host.log"
else
	XDG_DATA_HOME="$xdg" "$godot" --headless --path . -s "res://tools/$HOST_TOOL.gd" -- host "$port" "$GAME" $HOST_ARGS > "$out/host.log" 2>&1 &
	pids+=($!)
	for _ in $(seq 60); do grep -q "host on port" "$out/host.log" && break; sleep 0.5; done
	grep -q "host on port" "$out/host.log" || { echo "coop_screens: $name: the host never listened (host.log)" >&2; exit 1; }
fi

launch() {
	local who="$1" extra="$2" tool="$3" game="$GAME" dial="$port"
	[[ "$who" != p2 ]] || game="$P2_GAME"
	[[ "$who" != "${RELAY:-}" ]] || dial="$relay_port"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$xdg" "$godot" --max-fps "$fps" --path . -s "res://tools/$tool.gd" -- 127.0.0.1 "$dial" "$who" "$game" \
		$extra ${keys[$who]:+keys=${keys[$who]}} ${shots[$who]} > "$out/$who.log" 2>&1 &
	local pid=$!
	pids+=("$pid")
	if [[ -n "${closes[$who]:-}" ]]; then
		(sleep "${closes[$who]}"; kill -s "${signals[$who]}" "$pid" 2>/dev/null || true) &
	fi
}
close_split() {
	local pid=""
	for _ in $(seq 240); do pid="$(pgrep -f "coop_launcher_play.gd -- 127.0.0.1 $port p2 " | head -1)" && break; sleep 0.25; done
	[[ -z "$pid" ]] || { sleep "${closes[p2]}"; kill -s "${signals[p2]}" "$pid" 2>/dev/null || true; }
}
relay_port=$(( port + 1000 ))
if [[ -n "${RELAY:-}" ]]; then
	XDG_DATA_HOME="$xdg" "$godot" --headless --path . -s res://tools/coop_relay.gd -- "$relay_port" "$port" "cuts=$cuts" > "$out/relay.log" 2>&1 &
	pids+=($!)
	for _ in $(seq 60); do grep -q "coop relay: $relay_port to" "$out/relay.log" && break; sleep 0.25; done
fi
[[ "$P2_TOOL" != split ]] || export COOP_SPLIT_ARGS="127.0.0.1 $port p2 $P2_GAME partner $P2_ARGS ${keys[p2]:+keys=${keys[p2]}} ${shots[p2]}"
launch p1 "$P1_ARGS" "$P1_TOOL"
sleep "$P2_DELAY"
if [[ "$P2_TOOL" == split ]]; then
	echo "coop_screens: p2 is p1's split screen; its lines are in p1.log" > "$out/p2.log"
	[[ -z "${closes[p2]:-}" ]] || close_split &
else
	launch p2 "$P2_ARGS" "$P2_TOOL"
fi
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
if grep -h "SCRIPT ERROR" "$out"/*.log; then
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
