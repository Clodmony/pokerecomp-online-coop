# local_split, but BLUE's window on the right half is closed instead of RED leaving: RED's window
# gets back its size, its frame and the controller Settings picked (every one here), and RED plays on
# alone in Pallet Town (test case K18).
# Seconds count from each window's launch; BLUE's window starts once RED presses Split screen.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=split
P1_ARGS="host name=RED starter=0 split round=60:SPLIT"
P2_ARGS="name=BLUE starter=2"
DURATION=48
shot p1 16 red_world_left
shot p2 12 blue_world_right
close p2 16
shot p1 32 red_alone                  # the whole screen again, still in Pallet Town
press p1 33 D*6 R*6
shot p1 38 red_walks_alone

size() { file "$out/$1.png" | grep -oE "[0-9]+ x [0-9]+"; }

check() {
	grep -q "coop split: the window has the whole screen again, controller device -1" "$out/p1.log" \
		|| { echo "split_partner_closed: RED's window did not get the whole screen and every controller back" >&2; return 1; }
	! grep -q "coop launcher: p1 back at the launcher" "$out/p1.log" || { echo "split_partner_closed: RED was sent back to the launcher" >&2; return 1; }
	[[ "$(size red_alone)" != "$(size red_world_left)" ]] || { echo "split_partner_closed: RED's window kept its half" >&2; return 1; }
	echo "split_partner_closed: RED's window $(size red_world_left), then $(size red_alone)"
}
