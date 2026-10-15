# BROCK's own trainer AI in co-op (test case B43, D126): RED's BULBASAUR poisons BROCK's Pokémon with POISONPOWDER
# and tackles on; BROCK spends his FULL HEAL on the status ("BROCK used FULL HEAL!"), as he does fighting alone.
# Seed built from SEED_ARGS; the host's rolls are fixed.
SEED_ARGS="red viridian_forest mon=BULBASAUR:22:moves=POISONPOWDER/TACKLE"
HOST_ARGS="bare seed=${ROLLS:-7}"
DURATION=100
press p1 1.8 SELECT @FIGHT.+BROCK
for at in 9 14 19; do press p1 "$at" "@^FIGHT.+POISON" "@^FIGHT.+POISON"; done
for at in $(seq 24 4 80); do press p1 "$at" "@^FIGHT.+TACKLE" "@^FIGHT.+TACKLE"; done
for at in $(seq 6 2 90); do shot p1 "$at" "red_$at"; done
for at in $(seq 10.5 0.5 17.5); do shot p1 "$at" "red_$at"; done   # the poisoning and the FULL HEAL

events() { rg -o "\"type\":\"$1\"" "$user/coop_logs" | wc -l; }

check() {
	echo "brock_full_heal: status_inflicted $(events status_inflicted), trainer_used_item $(events trainer_used_item)"
	rg -q '"type":"trainer_used_item","side":1,"item":52,[^}]*"cured":true' "$user/coop_logs" \
		|| { echo "brock_full_heal: BROCK cured nothing with a FULL HEAL (item 52)" >&2; return 1; }
}
