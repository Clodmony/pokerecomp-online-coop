# Both windows start from the launcher, skipping the opening with a starter. RED hosts FIRST and
# BLUE joins; BLUE leaves from the CO-OP menu (SELECT), then RED. RED hosts a new SECOND, BLUE joins, RED
# leaves under BLUE, who is told and sent back. RED picks FIRST again from the campaign list and
# BLUE joins as the same trainer, then saves. Each campaign file holds RED and BLUE once (test
# cases S01, S03, S06, S11). Seconds count from each window's launch; a round presses Host or
# Join 4.5 s after it begins.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=coop_launcher_play
P1_ARGS="host name=RED starter=0 round=60:FIRST round=1140:SECOND round=2220:FIRST"
P2_ARGS="join name=BLUE starter=2 round=60 round=1320 round=2340"
DURATION=56
shot p1 5.3 red_first_filled          # BULBASAUR, a new campaign named FIRST
shot p1 12 red_with_blue              # BLUE stands by the house beside RED's
press p1 16 SELECT @LEAVE.SESSION A   # LEAVE SESSION, YES
shot p1 17.5 red_left                 # back on the Co-op tab: "You left the session."
shot p1 19.4 red_second_tab           # the campaign list starts on FIRST, the latest
shot p1 23.2 red_second_filled        # a new campaign named SECOND
press p1 34 SELECT @LEAVE.SESSION A   # RED leaves while BLUE plays
shot p1 37.4 red_third_tab            # SECOND is the latest now
shot p1 40.3 red_campaign_list        # FIRST picked from the list
shot p1 41.3 red_third_filled
shot p1 50 red_back_in_first
shot p2 5.3 blue_filled               # SQUIRTLE, address 127.0.0.1
shot p2 7 blue_first
press p2 9 SELECT @LEAVE.SESSION A    # LEAVE SESSION, YES
shot p2 9.4 blue_menu
shot p2 11 blue_left                  # "You left the session."
shot p2 22.4 blue_second_tab
shot p2 29 blue_second
shot p2 31 blue_host_left             # "The session ended: host shutdown."
shot p2 35 blue_sent_back             # "The host closed the session."
shot p2 39.4 blue_third_tab
shot p2 43.5 blue_back_in_first       # where BLUE left FIRST, with SQUIRTLE
press p2 44 START D D D A             # START > SAVE
press p2 49 A                         # YES, once the question is printed
shot p2 52 blue_saved                 # "Campaign saved."

check() {
	local file names ok=0 first third
	for file in "$out"/xdg/godot/app_userdata/pokerecomp/coop_campaigns/red/*.json; do
		names="$(jq -r '.campaign.title + ": " + ([.players[].name] | join(","))' "$file")"
		echo "coop_screens: $names"
		[[ "$names" == "FIRST: RED,BLUE" || "$names" == "SECOND: RED,BLUE" ]] && ok=$((ok + 1))
	done
	first="$(grep -o "round 1 in FIRST .*, trainer [0-9]*" "$out/p2.log" | sed 's/round 1 //')"
	third="$(grep -o "round 3 in FIRST .*, trainer [0-9]*" "$out/p2.log" | sed 's/round 3 //')"
	echo "coop_screens: BLUE ${first:-never in FIRST}; back as ${third:-nobody}"
	[[ "$ok" == 2 && -n "$first" && "$first" == "$third" ]]
}
