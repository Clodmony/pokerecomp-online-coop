# BLUE plays Blue (Blaue Edition with GAME=red_de) in RED's Red campaign: the friend menu's battle and trade between the two cartridges.
case "$GAME" in red) P2_GAME="${P2_GAME:-blue}" ;; red_de) P2_GAME="${P2_GAME:-blue_de}" ;; esac
# shellcheck source=/dev/null
source "$root/tools/coop_screens/friend_menu.sh"
