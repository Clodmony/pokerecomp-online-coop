# A joined trainer battle on Gold and Silver (#176, test cases G40 to G44): RED (Gold) fights FALKNER from the session
# menu and BLUE (Silver) joins; RED's party list shows BLUE's SQUIRTLE holding a BERRY and switches to it; BLUE opens
# the PACK, turns through ITEMS, BALLS, KEY ITEMS and TM/HM, uses a POTION from ITEMS, and WATER GUNs FALKNER's team down
# (NO to "Will BLUE change POKéMON?").
GAME=gold
P2_GAME=silver
DURATION=150
press p1 1.8 SELECT @FIGHT.+FALKNER
press p2 6.6 SELECT @JOIN
press p1 18 R A                        # FIGHT to <PKMN>, the party list
shot p1 20.5 gold_party_held_item      # SQUIRTLE's BERRY beside its icon, "BLUE's POKéMON"
press p1 22 "@SWITCH.+SQUIRTLE"
press p1 23.5 "@SWITCH.+SQUIRTLE"
press p1 25 "@SWITCH.+SQUIRTLE"
shot p1 29 gold_squirtle_out
press p2 32 D A                        # PACK
shot p2 34.5 silver_pack_items         # POTION x2 and its description
press p2 35 R
shot p2 36.5 silver_pack_balls
press p2 37 R
shot p2 38.5 silver_pack_key_items     # the BICYCLE, which a battle cannot use
press p2 39 R
shot p2 40.5 silver_pack_tm_hm
press p2 41 R A                        # round to ITEMS, then POTION's USE and QUIT
shot p2 43 silver_pack_use
press p2 44 A
for at in 46 47 48 49 50 51; do shot p2 "$at" "silver_potion_$at"; done
for at in $(seq 56 2 140); do press p2 "$at" "@^FIGHT.+WATER" "@^STAY" "@^SEND.OUT"; done   # NO to SHIFT's question
for at in $(seq 57 2 139); do press p1 "$at" "@^FIGHT.+EMBER" "@^STAY" "@^SEND.OUT"; done
for at in $(seq 54 3 147); do shot p1 "$at" "gold_$at"; shot p2 "$at" "silver_$at"; done
check() {
	local used won
	used="$(rg -o '"command":\{"type":"item","item":[0-9]+' "$user"/coop_logs/*host*.jsonl | grep -oE '[0-9]+$' | uniq | paste -sd' ')"
	won="$(rg -c '"kind":"battle_end".*"outcome":"won"' "$user"/coop_logs/*host*.jsonl | head -1)"
	echo "johto_battle: items used: $used; won: ${won:-0}"
	[[ "$used" == "18" && "${won:-0}" -ge 1 ]]
}
