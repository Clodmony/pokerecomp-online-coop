# SHIFT's question in a co-op battle (#28, test case B34; seed as party_balls': RED on ROUTE 3 (20,6), BLUE at (22,6), the lead knowing only EMBER).
# Both windows keep the default SHIFT. RED talks to the LASS, BLUE joins; when her first Pokémon faints both windows
# say "LASS is about to use ...!", then RED's asks "Will RED change POKéMON?" and BLUE's shows RED's question to
# suggest on. auto_battle leaves it up three seconds, then answers NO.
SEED_ARGS="red pewter_gym mon=CHARMANDER:25:moves=EMBER mon=CHARMANDER:25 mon=CHARMANDER:25 at=0:14:20,6:22,6"
HOST_ARGS=bare
DURATION=75
P1_ARGS=auto_battle
press p1 5 U U - - - - A - A - A - A - A
press p2 9 SELECT @JOIN
for at in $(seq 10 60); do
	shot p1 "$at" "p1_battle_$at"
	shot p2 "$at" "p2_battle_$at"
done
check() {
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log && rg -q 'switch_offered' "$user/coop_logs" \
		&& rg -q '"type":"stay"' "$user/coop_logs"
}
