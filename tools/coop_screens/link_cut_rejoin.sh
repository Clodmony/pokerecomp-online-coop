# link_cut_minute with a cut of a few seconds (CUT=<seconds>, 8 by default): BLUE's window redials
# while the host may still hold the dead link, and comes back "Back in the session." as the same
# trainer, never a new one (test case S24).
RELAY=p2
DURATION=60
cut p2 16 "${CUT:-8}"
shot p2 12 blue_before_cut
shot p2 22 blue_reconnecting
shot p2 32 blue_back
shot p1 36 red_partner_back
press p2 37 R*4
shot p1 42 red_sees_blue_walk
# shellcheck source=/dev/null
source <(sed -n '/^said()/,$p' "$(dirname "${BASH_SOURCE[0]}")/link_cut_minute.sh")
