# Gold's opening for both players, then each walks, fights and talks their own way through Route 29, Cherrygrove,
# Routes 30 and 31 and Violet City to FALKNER's gym, where they meet before the ZEPHYRBADGE (#183; test cases J87, J88).
source "$(dirname "${BASH_SOURCE[0]}")/gold_opening.sh"
P1_ARGS="$P1_ARGS route=falkner"
P2_ARGS="$P2_ARGS route=falkner"
DURATION=3600
check() {
	grep -q "autoplay: p1 finished, falkner reached" "$out/p1.log" && grep -q "autoplay: p2 finished, falkner reached" "$out/p2.log" \
		&& grep -q "leg meet_in_violet_gym" "$out/p1.log" && grep -q "leg meet_in_violet_gym" "$out/p2.log"
}
