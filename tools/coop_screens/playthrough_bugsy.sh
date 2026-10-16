# From a seed after FALKNER's badge both players walk on: each takes their own TOGEPI egg from Elm's aide, through
# Union Cave to Azalea Town and KURT, the first one into the Slowpoke Well fights its Rockets (the other finds them
# gone), and they meet in BUGSY's gym for the HIVEBADGE (#183; test cases J89, J90).
GAME=gold
P2_GAME=silver
SEED_ARGS="gold zephyr_badge"
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P2_TOOL=coop_autoplay
P1_ARGS="route=bugsy speed=4 shots=$out"
P2_ARGS="route=bugsy speed=4 shots=$out"
FROM=gym_out
P2_DELAY=25
DURATION=3600
check() {
	grep -q "autoplay: p1 finished, bugsy reached" "$out/p1.log" && grep -q "autoplay: p2 finished, bugsy reached" "$out/p2.log" \
		&& grep -q "leg togepi_egg" "$out/p1.log" && grep -q "leg togepi_egg" "$out/p2.log" \
		&& grep -q "leg meet_in_azalea_gym" "$out/p1.log" && grep -q "leg meet_in_azalea_gym" "$out/p2.log"
}
