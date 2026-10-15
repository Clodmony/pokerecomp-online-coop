# local_split_stacked, but BLUE leaves from the CO-OP menu of the bottom half: BLUE's window closes by itself,
# RED's gets back its size and the controller Settings picked, and RED plays on alone (test case K18).
# Seconds count from each window's launch; BLUE's window starts once RED presses Split screen.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=split
P1_ARGS="host name=RED starter=0 split=stacked round=60:SPLIT"
P2_ARGS="name=BLUE starter=2"
DURATION=48
shot p1 16 red_world_top
shot p2 12 blue_world_bottom
press p2 14 SELECT @LEAVE.SESSION A   # LEAVE SESSION, YES
shot p2 15.5 blue_leaving
shot p1 32 red_alone
press p1 33 D*6 R*6
shot p1 38 red_walks_alone

size() { file "$out/$1.png" | grep -oE "[0-9]+ x [0-9]+"; }

check() {
	grep -q "coop launcher: p2 quits" "$out/p1.log" || { echo "split_partner_leaves: BLUE's window did not close by itself" >&2; return 1; }
	grep -q "coop split: the window has the whole screen again, controller device -1" "$out/p1.log" \
		|| { echo "split_partner_leaves: RED's window did not get the whole screen and every controller back" >&2; return 1; }
	! grep -q "coop launcher: p1 back at the launcher" "$out/p1.log" || { echo "split_partner_leaves: RED was sent back to the launcher" >&2; return 1; }
	[[ "$(size red_alone)" != "$(size red_world_top)" ]] || { echo "split_partner_leaves: RED's window kept its half" >&2; return 1; }
	echo "split_partner_leaves: $(grep -o "coop launcher: p2 quits at frame [0-9]*" "$out/p1.log"), RED's window $(size red_world_top), then $(size red_alone)"
}
