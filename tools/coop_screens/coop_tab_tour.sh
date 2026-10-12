# Every screen of the Co-op tab, photographed by the windows themselves in the light and the dark
# theme, wide (1152x648) and upright (390x844 with a notch and a home indicator): <screen>_<theme>_<shape>.png.
# Rote hosts a new CAMPAIGN 1 with the rival BLAU and wild Pokémon from both versions; Blaue finds it
# nearby, first fails to reach an address nobody hosts, then joins as a new player. Rote stops hosting
# (asked first), shows its campaign card, its edit and delete sheets, then hosts it again; Blaue, sent
# back, shows its Host screen with Rote's campaign on it, then joins again as the trainer the host
# knows. Run with GAME=red_de P2_GAME=blue_de (test cases K01 to K15, V01, V02).
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=coop_launcher_play
P1_ARGS="host name=RED starter=1 rival_name=BLAU both_versions round=60:CAMPAIGN_1 tour=$out"
P2_ARGS="join name=BLUE starter=2 round=60 tour=$out"
DURATION=150

check() {
	local missing=0 screen look
	for screen in start host new_campaign hosting hosting_joined stop_hosting start_last_session troubleshooting \
		host_cards edit_campaign delete_campaign start_nearby join connecting failure new_player sent_back host_other_version connecting_known; do
		for look in light_wide light_upright dark_upright dark_wide; do
			[[ -f "$out/${screen}_${look}.png" ]] || { echo "coop_screens: no ${screen}_${look}.png"; missing=$((missing + 1)); }
		done
	done
	grep -h "round 1 in CAMPAIGN 1" "$out/p1.log" "$out/p2.log"
	[[ "$missing" == 0 && "$(grep -c "p2 round 1 in CAMPAIGN 1 .* as p2 BLUE" "$out/p2.log")" == 2 ]] \
		&& grep -q "p1 round 1 in CAMPAIGN 1 .* as p1 RED" "$out/p1.log"
}
