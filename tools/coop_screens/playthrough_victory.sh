# The run on from BLAINE's badge on Cinnabar Island: SURF up Route 21 to Pallet Town, Viridian Gym's
# spinners and GIOVANNI's EARTHBADGE (met in the gym), Route 22's second rival, Route 23's badge
# guards, Victory Road's STRENGTH boulders (one player pushes, the other waits for the switch the
# campaign shares) and the Indigo Plateau lobby (#88).
# A SEED= after BLAINE starts with FROM=cinnabar_gym_out.
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_blaine.sh"
P1_ARGS="${P1_ARGS/route=blaine/route=victory}"
P2_ARGS="${P2_ARGS/route=blaine/route=victory}"
DURATION=28800
