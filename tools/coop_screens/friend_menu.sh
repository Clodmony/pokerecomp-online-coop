DURATION=340
P2_DELAY=2
P1_ARGS=auto_battle
P2_ARGS=auto_battle
press p1 2 START A
press p2 2 START A
shot p1 3 red_party_before
shot p2 3 blue_party_before
press p1 4 B
press p1 6 B
press p2 4 B
press p2 6 B
press p1 9 SELECT
shot p1 10 red_coop_menu
press p1 11 @BATTLE.BLUE
shot p2 10 blue_battle_question
press p2 11 A
shot p1 15 red_battle
shot p2 15 blue_battle
shot p1 45 red_battle_turn
shot p2 45 blue_battle_turn
shot p1 155 red_after
shot p2 155 blue_after
press p1 156 START A
press p2 156 START A
shot p1 158 red_party_after
shot p2 158 blue_party_after
press p1 160 B
press p1 162 B
press p2 160 B
press p2 162 B
press p1 165 SELECT @TRADE.BLUE
shot p2 165 blue_trade_question
press p2 166 A
shot p1 174 red_trade
shot p2 174 blue_trade
press p1 176 A R A
press p2 176 A R A
shot p1 181 red_trade_offer
shot p2 181 blue_trade_offer
press p1 183 A
press p2 183 A
press p1 188 A
press p2 188 A
press p1 193 A
press p2 193 A
shot p1 285 red_trade_after
shot p2 285 blue_trade_after
press p1 305 D D D D D D A
shot p1 330 red_trade_closed
shot p2 330 blue_trade_closed
check() {
	local campaign="$user/coop_campaigns/$GAME/$GAME.json"
	jq -e '.players | length == 2' "$campaign" > /dev/null || return 1
	rg -q '"outcome":"versus"' "$user/coop_logs" || return 1
	rg -q '"trade_swap"' "$user/coop_logs" || return 1
	rg -q '"end":1' "$user/coop_logs" || return 1
	jq -e '.players | all(.map == [0,0] and .money == 3000)' "$campaign" > /dev/null || return 1
	jq -e '[.players[] | .team[-1].uid] == ["p2:1","p1:1"]' "$campaign" > /dev/null || return 1
	jq -e '[.players[].team[].uid] | length == (unique | length)' "$campaign" > /dev/null
}
