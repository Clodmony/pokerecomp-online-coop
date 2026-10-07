# Two windows on a campaign tools/coop_seed.gd wrote at a point of the story (SEED=<its out dir>):
# both where the story left them side by side, each party on START, then RED walks and BLUE sees it.
: "${SEED:?story_seed needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
DURATION=36
shot p1 4 p1_world
shot p2 4 p2_world
press p1 6 START D A                  # POKéMON, under the POKéDEX
press p2 6 START D A
shot p1 9 p1_party
shot p2 9 p2_party
press p1 11 B B B
press p2 11 B B B
press p1 15 D D
shot p1 17.5 p1_walked
shot p2 19 p2_sees_walk
check() { grep -q 'reloaded campaign .*players \["p1", "p2"\]' "$out/host.log"; }
