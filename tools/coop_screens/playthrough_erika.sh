# The run to LT. SURGE, then back north to CUT Route 9's tree, through Rock
# Tunnel and Lavender Town, the Underground Path to Celadon City and ERIKA's
# badge, met in her gym; then the Game Corner's poster, the Rocket Hideout's
# spinners, LIFT KEY and elevator, and GIOVANNI's SILPH SCOPE (#88).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_surge.sh"
P1_ARGS="${P1_ARGS/route=surge/route=erika}"
P2_ARGS="${P2_ARGS/route=surge/route=erika}"
DURATION=7200
