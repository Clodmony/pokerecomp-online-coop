# The run on from BLAINE's badge on Cinnabar Island: SURF up Route 21 to Pallet Town, Viridian Gym's
# spinners and GIOVANNI's EARTHBADGE (met in the gym), Route 22's second rival, Route 23's badge
# guards, Victory Road's STRENGTH boulders (one player pushes, the other waits for the switch the
# campaign shares) and the Indigo Plateau lobby (#88).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_koga.sh"
P1_ARGS="${P1_ARGS/route=koga/route=victory}"
P2_ARGS="${P2_ARGS/route=koga/route=victory}"
DURATION=21600
