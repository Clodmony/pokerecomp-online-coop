# The run on from BLAINE's badge on Cinnabar Island: SURF up Route 21 to Pallet Town, Viridian Gym's
# spinners and GIOVANNI's EARTHBADGE (met in the gym), Route 22's second rival, Route 23's badge
# guards, Victory Road's STRENGTH boulders (one player pushes, the other waits for the switch the
# campaign shares) and the Indigo Plateau lobby (#88).
# FROM=<leg> starts both windows at that leg, for a SEED= after BLAINE (FROM=cinnabar_gym_out).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_blaine.sh"
P1_ARGS="${P1_ARGS/route=blaine/route=victory}${FROM:+ from=$FROM}"
P2_ARGS="${P2_ARGS/route=blaine/route=victory}${FROM:+ from=$FROM}"
DURATION=28800
