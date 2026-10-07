# The run on from SABRINA's badge to the Hall of Fame: the Indigo Plateau's nurse, LORELEI, BRUNO, AGATHA
# and LANCE met room by room (one player talks to each, the other joins from the menu), the rival as
# Champion driven by the window that fought AGATHA and joined by the other, and each player's own Hall of
# Fame and credits (#88).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_sabrina.sh"
P1_ARGS="${P1_ARGS/route=sabrina/route=elite}"
P2_ARGS="${P2_ARGS/route=sabrina/route=elite}"
DURATION=18000
