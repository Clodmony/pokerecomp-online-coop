# The run on from Mr. Fuji's POKé FLUTE: SNORLAX on Route 12 woken by one player and joined by the other
# (one encounter for the campaign), Routes 13 to 15 to Fuchsia City, a catch in the Safari Zone that must
# reach the host, HM03 and the GOLD TEETH, the warden's HM04, and KOGA's badge (#88).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_surge.sh"
P1_ARGS="${P1_ARGS/route=surge/route=koga}"
P2_ARGS="${P2_ARGS/route=surge/route=koga}"
