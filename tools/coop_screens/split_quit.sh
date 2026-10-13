# RED hosts SPLIT from the Co-op tab and presses Split screen; BLUE joins on the right half.
# In the world BLUE picks QUIT BOTH from the CO-OP menu: BLUE's window quits with the code
# that asks RED's to follow, and RED's says goodbye, saves the campaign and quits (K19).
# Seconds count from each window's launch; BLUE's window starts once RED presses Split screen.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=split
P1_ARGS="host name=RED starter=0 split round=60:SPLIT"
P2_ARGS="name=BLUE starter=2"
DURATION=45
shot p2 12 blue_world_right
press p2 18 SELECT @QUIT.BOTH         # QUIT BOTH: "Close both windows?"
shot p2 19.5 blue_quit_both
press p2 20.4 A                       # YES

check() {
	local campaign
	for who in p2 p1; do
		grep -q "coop launcher: $who quits" "$out/p1.log" || { echo "split_quit: $who's window did not quit by itself" >&2; return 1; }
	done
	campaign="$(find "$out/xdg/godot/app_userdata/pokerecomp/coop_campaigns" -name '*.json' -newer "$out/blue_world_right.png" -print -quit)"
	[[ -n "$campaign" ]] && grep -q '"BLUE"' "$campaign" || { echo "split_quit: no campaign saved with BLUE after the world opened" >&2; return 1; }
	echo "split_quit: $(grep -o "coop launcher: p. quits at frame [0-9]*" "$out/p1.log" | paste -sd';'), $(basename "$campaign") saved"
}
