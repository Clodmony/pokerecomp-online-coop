# local_split with Top and bottom picked under How to split the screen?: RED's window takes the top half
# of the screen and BLUE's the bottom half, both the screen's full width; RED leaves and gets its size back (K17, K18).
# Seconds count from each window's launch; BLUE's window starts once RED presses Split screen.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=split
P1_ARGS="host name=RED starter=0 split=stacked round=60:SPLIT"
P2_ARGS="name=BLUE starter=2"
DURATION=40
shot p1 6.5 red_split_hosting         # Hosting SPLIT on the top half, "A second player joins in the bottom half."
shot p1 16 red_world_top
shot p2 1.6 blue_joining
shot p2 12 blue_world_bottom
press p1 24 SELECT @LEAVE.SESSION A
shot p1 30 red_whole_screen

window() { grep -o "$1.*window at .*" "$out/p1.log" | head -1 | grep -oE "[0-9]+" | tail -4 | paste -sd' '; }
size() { file "$out/$1.png" | grep -oE "[0-9]+ x [0-9]+"; }

check() {
	local line top bottom screen
	for line in "coop split: top half" "coop split: bottom half" "coop split: the window has the whole screen again"; do
		grep -q "$line" "$out/p1.log" || { echo "local_split_stacked: no \"$line\" in p1.log" >&2; return 1; }
	done
	read -r -a top <<< "$(window "p1 round 1 in SPLIT")"
	read -r -a bottom <<< "$(window "p2 round 1 in SPLIT")"
	read -r -a screen <<< "$(grep -o "top half at .* of screen [^,]*, [^,]*,[^,]*,[^]]*" "$out/p1.log" | head -1 | grep -oE "[0-9]+" | tail -4 | paste -sd' ')"
	echo "local_split_stacked: screen ${screen[*]}, RED's window ${top[*]}, BLUE's ${bottom[*]}; RED's tab $(size red_split_hosting), then $(size red_whole_screen)"
	(( ${#top[@]} == 4 && ${#bottom[@]} == 4 && ${#screen[@]} == 4 )) || { echo "local_split_stacked: a window was not reported" >&2; return 1; }
	(( top[0] == screen[0] && top[1] == screen[1] && bottom[0] == screen[0] && top[2] == bottom[2] )) \
		|| { echo "local_split_stacked: the halves do not start at the screen's left and top" >&2; return 1; }
	(( bottom[1] == top[1] + top[3] && top[2] > top[3] )) || { echo "local_split_stacked: the halves are not one above the other and wide" >&2; return 1; }
	[[ "$(size red_split_hosting)" == "$(size red_world_top)" && "$(size red_whole_screen)" != "$(size red_world_top)" ]] \
		|| { echo "local_split_stacked: RED's window did not take its half and give it back" >&2; return 1; }
}
