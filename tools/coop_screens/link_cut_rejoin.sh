# A link that dies on BLUE's side first (test case S24): from second 16, for CUT seconds (8 by default), the relay
# drops the host's packets to BLUE's window and answers the host's reliable ones in BLUE's place, so the host holds
# the dead link after BLUE's window has given it up. BLUE redials, is refused as already connected until the host
# lets the old link go, and comes back "Back in the session." as the same trainer, never a new one.
RELAY=p2
DURATION=64
cut p2 16 "${CUT:-8}" hold
shot p2 12 blue_before_cut
shot p2 22 blue_reconnecting
shot p2 38 blue_back
shot p1 40 red_partner_back
press p2 41 R*4
shot p1 46 red_sees_blue_walk
# shellcheck source=/dev/null
source <(sed -n '/^said()/,$p' "$(dirname "${BASH_SOURCE[0]}")/link_cut_minute.sh")
eval "minute_$(declare -f check)"
check() {
	minute_check || return 1
	grep -q 'already_connected' "$out"/xdg/godot/app_userdata/pokerecomp/coop_logs/*.jsonl \
		|| { echo "link_cut_rejoin: the host never refused a redial as already connected" >&2; return 1; }
}
