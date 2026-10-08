# The run on to the Hall of Fame: the Indigo Plateau's nurse, then LORELEI, BRUNO, AGATHA and LANCE room by room
# (each player's own run: one window talks to the member, the other joins from the menu and then meets the member
# for its own run), the Champion taken by one window and joined by the other from LANCE's room, and each player's
# own Hall of Fame, credits and CONTINUE in Pallet Town while the partner is still in the League (#88).
# FROM=<leg> starts both windows at that leg, for a SEED= at the Indigo Plateau lobby (FROM=lobby_nurse).
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_victory.sh"
P1_ARGS="${P1_ARGS/route=victory/route=elite}"
P2_ARGS="${P2_ARGS/route=victory/route=elite}"
DURATION=25200
