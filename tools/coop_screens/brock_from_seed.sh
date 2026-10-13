# RED plays BROCK's leg on its own from a seed at PEWTER CITY (#133; SEED from
# `tools/coop_seed.gd -- red viridian_forest <dir> level=25 party=3`): partner=none meets nobody in the gym,
# BLUE stands by in a plain window, and RED walks to BROCK, beats him and takes the BOULDERBADGE.
: "${SEED:?brock_from_seed needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P1_ARGS="route=brock from=pewter_gym partner=none speed=4 shots=$out"
DURATION=240
check() { grep -q "autoplay: p1 finished, brock reached" "$out/p1.log"; }
