# RED hosts REMEMBER from the Co-op tab; BLUE joins by typing the address, leaves, and on the second
# round presses JOIN and Join without touching the address field: the field shows the address BLUE
# joined before and Join dials it, BLUE back in the world as the same trainer (test case K16).
# Seconds count from each window's launch.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=coop_launcher_play
P1_ARGS="host name=RED starter=1 round=60:REMEMBER"
P2_ARGS="join by_address untouched name=BLUE starter=2 round=60 round=1500"
DURATION=50
shot p2 12 blue_world_first
press p2 14 SELECT @LEAVE.SESSION A   # LEAVE SESSION, YES
shot p2 20 blue_left
shot p2 34 blue_world_again

check() {
	local shown trainers
	shown="$(grep -o 'joins with the address field untouched, showing "[^"]*"' "$out/p2.log" | grep -o '"[^"]*"')"
	[[ -n "$shown" ]] || { echo "join_remembered: BLUE's second round never reached Join" >&2; return 1; }
	[[ "$shown" == '"127.0.0.1:'* ]] || { echo "join_remembered: the field showed $shown, not the address BLUE joined" >&2; return 1; }
	trainers="$(grep -o "p2 round [12] in REMEMBER .*trainer [0-9]*" "$out/p2.log" | grep -oE "trainer [0-9]+$" | sort -u | wc -l)"
	(( $(grep -c "p2 round [12] in REMEMBER" "$out/p2.log") == 2 && trainers == 1 )) \
		|| { echo "join_remembered: BLUE did not come back to REMEMBER as the same trainer" >&2; return 1; }
	echo "join_remembered: the field showed $shown; $(grep -o "p2 round 2 in REMEMBER .*trainer [0-9]*" "$out/p2.log")"
}
