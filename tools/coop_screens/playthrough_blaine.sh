# The run on from SABRINA's badge: out of Saffron's gym by its pads, Route 8 to Fuchsia City, SURF over
# Route 19 to the Seafoam Islands, whose STRENGTH boulders one player drops while the other waits for the
# calm water, Cinnabar Island's lab and the fossil each player revives, the Pokémon Mansion's switches and
# the SECRET KEY, the gym's quiz gates in both windows, and BLAINE's badge (#88).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_koga.sh"
P1_ARGS="${P1_ARGS/route=koga/route=blaine}"
P2_ARGS="${P2_ARGS/route=koga/route=blaine}"
DURATION=21600
