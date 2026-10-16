# Baton Pass in a joined wild battle on Gold and Silver (#149, test cases J60 to J62; SEED_ARGS: GOLD's EEVEE L20
# knowing SWORDS DANCE and BATON PASS, SILVER's GEODUDE L20 knowing TACKLE). GOLD fights the session menu's wild
# PIDGEY and SILVER joins; GOLD's SWORDS DANCE, then BATON PASS: GOLD's window opens the party list at once, with no
# "Use next POKéMON?", and SILVER's shows the same list, where SILVER points at GEODUDE: GOLD's list wears SILVER's
# mark. GOLD passes to SILVER's GEODUDE, which TACKLEs PIDGEY down for SILVER.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=24:4:13,6:12,6 mon=p1:EEVEE:20:moves=SWORDS_DANCE/BATON_PASS mon=p2:GEODUDE:20:moves=TACKLE"
HOST_ARGS=bare
DURATION=80
press p1 2 SELECT @FIGHT.+PIDGEY
press p2 6 SELECT @JOIN
for at in 12 14 16; do press p1 "$at" "@^FIGHT.+SWORDS"; done
for at in $(seq 22 2 30); do press p1 "$at" "@^FIGHT.+BATON"; done
for at in $(seq 23 2 41); do press p2 "$at" "@^SEND.OUT.+GEODUDE"; done
for at in 44 46 48; do press p1 "$at" "@^SEND.OUT.+GEODUDE"; done
for at in $(seq 51 2 73); do press p2 "$at" "@^FIGHT.+TACKLE"; done
for at in $(seq 8 77); do shot p1 "$at" "gold_$at"; shot p2 "$at" "silver_$at"; done
check() {
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log \
		&& rg -q '"suggestion":\{"type":"send_out","value":1' "$user/coop_logs" \
		&& rg -q '"type":"send_out","index":1' "$user/coop_logs" \
		&& ! rg -q 'invalid_send_out' "$user/coop_logs"
}
