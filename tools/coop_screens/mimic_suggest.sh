# Mimic's question in a co-op battle (#28, test case B35; seed as switch_offer's, RED's lead knowing MIMIC and EMBER).
# RED talks to the LASS, BLUE joins; RED's MIMIC asks RED's window which move to copy and shows BLUE's window the
# same list, where BLUE points at TAIL WHIP: RED's list wears BLUE's mark. auto_battle leaves it up three seconds,
# then copies the first move.
SEED_ARGS="red pewter_gym mon=CHARMANDER:25:moves=MIMIC/EMBER mon=CHARMANDER:25 mon=CHARMANDER:25 at=0:14:20,6:22,6"
HOST_ARGS=bare
DURATION=60
P1_ARGS=auto_battle
press p1 5 U U - - - - A - A - A - A - A
press p2 9 SELECT @JOIN
press p2 12 $(for _ in $(seq 100); do printf '@MIMIC.TAIL '; done)
for at in $(seq 10 45); do
	shot p1 "$at" "p1_battle_$at"
	shot p2 "$at" "p2_battle_$at"
done
check() {
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log && rg -q '"suggestion":\{"type":"mimic","value":1' "$user/coop_logs" \
		&& rg -q '"type":"mimic","choice":0' "$user/coop_logs"
}
