# SHIFT's question in a co-op battle (#28, test case B34): RED, on the windows' default SHIFT, fights BROCK, and when
# GEODUDE faints is asked "BROCK is about to use ONIX! Will RED change POKéMON?" before ONIX is out; the autoplay
# answers NO. Seed it first:
#   godot --headless --path . -s res://tools/coop_seed.gd -- red viridian_forest <dir> level=25 party=3
: "${SEED:?switch_offer needs SEED=<a coop_seed.gd out dir at viridian_forest>}"
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P1_ARGS="route=brock from=pewter_gym shots=$out"
DURATION=300
check() {
	ls "$out"/p1_offer_*.png > /dev/null && grep -q "about to use" "$out/p1_texts.tsv" \
		&& grep -q "autoplay: p1 finished" "$out/p1.log"
}
