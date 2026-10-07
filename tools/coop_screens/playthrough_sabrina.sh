# The run on from KOGA's badge: back north to Lavender Town and through the Underground Path to Celadon,
# each player's own FRESH WATER from the department store's roof for Saffron's gate guards, Silph Co.
# (the CARD KEY, its doors and pads, the rival on 7F, each player's own LAPRAS, GIOVANNI joined on 11F,
# the president's MASTER BALL once each) and SABRINA's badge, joined past her gym's pads (#88).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_koga.sh"
P1_ARGS="${P1_ARGS/route=koga/route=sabrina}"
P2_ARGS="${P2_ARGS/route=koga/route=sabrina}"
DURATION=15600
