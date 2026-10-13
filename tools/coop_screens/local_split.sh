# RED hosts a new campaign SPLIT from the Co-op tab with BULBASAUR and presses Split screen: RED's
# window takes the left half of the screen, and a second window it starts takes the right half and
# joins at 127.0.0.1 as BLUE with SQUIRTLE. RED leaves from the CO-OP menu: BLUE's window closes
# itself and RED's gets the whole screen back (test cases K17, K18). Seconds count from each
# window's launch; BLUE's window starts once RED presses Split screen.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=split
P1_ARGS="host name=RED starter=0 split round=60:SPLIT"
P2_ARGS="name=BLUE starter=2"
DURATION=40
shot p1 4.8 red_split_hosting         # Hosting SPLIT on the left half, "A second player joins on the right."
shot p1 16 red_world_left             # Pallet Town, BLUE by the house beside RED's
shot p2 1.6 blue_joining              # the right half on the Co-op tab, joining SPLIT
shot p2 12 blue_world_right
press p1 24 SELECT @LEAVE.SESSION A   # LEAVE SESSION, YES
shot p1 30 red_whole_screen           # the Co-op tab on the whole screen again

window() { grep -o "$1.*window at .*" "$out/p1.log" | head -1 | grep -oE "[0-9]+" | tail -4 | paste -sd' '; }
size() { file "$out/$1.png" | grep -oE "[0-9]+ x [0-9]+"; }

check() {
	local line left right
	for line in "coop split: left half" "coop split: right half" "coop split: the window has the whole screen again"; do
		grep -q "$line" "$out/p1.log" || { echo "local_split: no \"$line\" in p1.log" >&2; return 1; }
	done
	read -r -a left <<< "$(window "p1 round 1 in SPLIT")"
	read -r -a right <<< "$(window "p2 round 1 in SPLIT")"
	echo "local_split: RED's window ${left[*]}, BLUE's ${right[*]}; RED's tab $(size red_split_hosting), then $(size red_whole_screen)"
	(( ${#left[@]} == 4 && ${#right[@]} == 4 )) || { echo "local_split: a window was not reported" >&2; return 1; }
	(( right[0] == left[0] + left[2] && right[1] == left[1] && right[3] == left[3] )) || { echo "local_split: the halves are not side by side" >&2; return 1; }
	[[ "$(size red_split_hosting)" == "$(size red_world_left)" && "$(size red_whole_screen)" != "$(size red_world_left)" ]] \
		|| { echo "local_split: RED's window did not take its half and give it back" >&2; return 1; }
}
