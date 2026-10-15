# local_split, then RED's window (the host) is killed with no goodbye: BLUE's half gives up at once
# ("host unreachable") and quits, instead of redialling for two minutes (test case K20).
# Seconds count from each window's launch; BLUE's window starts once RED presses Split screen.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=split
P1_ARGS="host name=RED starter=0 split round=60:SPLIT"
P2_ARGS="name=BLUE starter=2"
DURATION=46
shot p1 16 red_world_left
shot p2 12 blue_world_right
close p1 24 KILL
shot p2 15 blue_host_gone             # just after the kill, still in the world

check() {
	local quit
	quit="$(grep -o "coop launcher: p2 quits at frame [0-9]*" "$out/p1.log" | grep -oE "[0-9]+$")"
	[[ -n "$quit" ]] || { echo "split_host_killed: BLUE's half did not quit by itself within $(( DURATION - 24 )) s of the kill" >&2; return 1; }
	grep -q '"unreachable"' "$out"/xdg/godot/app_userdata/pokerecomp/coop_logs/*.jsonl 2>/dev/null \
		|| echo "split_host_killed: (no \"unreachable\" entry in the session logs)"
	echo "split_host_killed: BLUE's half quit at its frame $quit"
}
