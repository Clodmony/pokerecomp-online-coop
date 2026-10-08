# The run on to the Hall of Fame as a team (D91): the Indigo Plateau's nurse, then LORELEI and AGATHA fought by one
# window with the other joined beside it (the exit opens in both), BRUNO and LANCE fought by one window with the other
# joined from the room behind and walking through afterwards without a fight; the Champion taken by one window and
# joined by the other from LANCE's room, which then meets him beaten for Oak's scene and its own Hall of Fame, credits
# and CONTINUE in Pallet Town; the run is cleared for the campaign once both are out of the League (#88).
# A SEED= at the Indigo Plateau lobby starts with FROM=lobby_nurse.
# WHITEOUT=1 has BRUNO's fighter lose its first fight alone and white out to the Indigo Plateau while the partner
# waits in LORELEI's room: the lobby's reset is held, and the fighter walks back through LORELEI's open exit.
source "$(dirname "${BASH_SOURCE[0]}")/playthrough_victory.sh"
P1_ARGS="${P1_ARGS/route=victory/route=elite}${WHITEOUT:+ whiteout=$WHITEOUT}"
P2_ARGS="${P2_ARGS/route=victory/route=elite}${WHITEOUT:+ whiteout=$WHITEOUT}"
DURATION=36000
