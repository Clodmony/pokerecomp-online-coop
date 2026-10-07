# The run on from the Rocket Hideout's SILPH SCOPE: the car up, the Game Corner, Route 7, the
# Underground Path and Lavender Town, Pokémon Tower floor by floor (the rival on 2F, the MAROWAK
# ghost one player walks into and the other joins from the menu, the Rockets on 7F), Mr. Fuji and
# the POKé FLUTE both players hold (#88).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_surge.sh"
P1_ARGS="${P1_ARGS/route=surge/route=tower}"
P2_ARGS="${P2_ARGS/route=surge/route=tower}"
