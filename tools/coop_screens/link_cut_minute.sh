# BLUE's link to the host goes through tools/coop_relay.gd, which drops every packet both ways for a
# minute: BLUE's window says "Lost the host: reconnecting..." and keeps redialling, RED's sees BLUE
# gone, and once the link is back BLUE is "Back in the session." as the same trainer (test case S09).
RELAY=p2
DURATION=115
cut p2 16 60
shot p2 12 blue_before_cut
shot p1 12 red_before_cut
shot p2 30 blue_reconnecting
shot p1 45 red_partner_gone
shot p2 79 blue_back
shot p1 90 red_partner_back
press p2 92 R*4
shot p1 97 red_sees_blue_walk

said() { grep -h '"say"' "$out"/xdg/godot/app_userdata/pokerecomp/coop_logs/*.jsonl | grep -c "$1"; }

check() {
	grep -q "coop relay: link back" "$out/relay.log" || { echo "${name:-link_cut}: the relay never cut and restored the link" >&2; return 1; }
	(( $(said "Lost the host: reconnecting") > 0 )) || { echo "${name:-link_cut}: BLUE was never told the host was lost" >&2; return 1; }
	(( $(said "Back in the session.") > 0 )) || { echo "${name:-link_cut}: BLUE never came back" >&2; return 1; }
	! grep -q '"new_player"' "$out"/xdg/godot/app_userdata/pokerecomp/coop_logs/*host*.jsonl || { echo "${name:-link_cut}: the host made a new player" >&2; return 1; }
	echo "${name:-link_cut}: $(grep -h "coop relay: link" "$out/relay.log" | paste -sd';'), $(grep -ho '"refused[^"]*"\|already_connected' "$out"/xdg/godot/app_userdata/pokerecomp/coop_logs/*.jsonl | sort | uniq -c | paste -sd' ')"
}
