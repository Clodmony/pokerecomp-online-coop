# Wild Pokémon from both versions (D104, test cases W01 to W03): RED plays Rote, BLUE Blaue, in a Rote campaign
# with the switch on. RED takes the Underground Path to Route 6 and walks its grass until a wild only Blaue has
# there (KNOFENSA or MAUZI) appears; BLUE stays in Cerulean and is the device that sends Blaue's slots. Seed it first:
#   godot --headless --path . -s res://tools/coop_seed.gd -- red_de cerulean_thief <dir> both
# then run with GAME=red_de P2_GAME=blue_de SEED=<dir>.
: "${SEED:?both_versions needs SEED=<a coop_seed.gd out dir written with both>}"
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P1_ARGS="route=both_versions from=cerulean_to_route_5 shots=$out"
P2_DELAY=1
DURATION=480
shot p2 12 blue_beside
shot p2 200 blue_later
check() {
	grep -q "met a wild .*, which only ${P2_GAME:-blue_de} has" "$out/p1.log" && ls "$out"/p1_other_version_*.png > /dev/null
}
