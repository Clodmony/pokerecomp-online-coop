# A trainer keeps to its other moves while RED's Pokémon already has a status (test case B43, its second half; the
# first is brock_full_heal). RED stands beside ROUTE 3's LASS whose JIGGLYPUFF knows SING, POUND and DISABLE, RED's
# lead a poisoned ONIX with TACKLE and HARDEN; auto_battle fights it out (HARDEN while TACKLE is disabled). The LASS's
# class discourages status moves (layer 1), so JIGGLYPUFF never SINGs (move 47) at the poisoned ONIX. Seed built
# from SEED_ARGS.
SEED_ARGS="red pewter_gym mon=ONIX:12:moves=TACKLE/HARDEN:status=PSN at=0:14:32,10:31,10"
HOST_ARGS="bare seed=${ROLLS:-7}"
DURATION=100
P1_ARGS=auto_battle
press p1 5 R - A - A - A - A - A
for at in $(seq 6 2 94); do shot p1 "$at" "red_$at"; done

enemy_moves() { rg -o '"type":"used_move","side":1,"move":[0-9]+' "$user/coop_logs" | sed 's/.*"move"://' | sort | uniq -c | tr '\n' ' '; }

check() {
	echo "trainer_status_moves: the enemy's moves (count, number): $(enemy_moves)"
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log || return 1
	(( $(rg -o '"type":"used_move","side":1' "$user/coop_logs" | wc -l) >= 4 )) \
		|| { echo "trainer_status_moves: fewer than four enemy moves" >&2; return 1; }
	! rg -q '"type":"used_move","side":1,"move":47[,}]' "$user/coop_logs" \
		|| { echo "trainer_status_moves: JIGGLYPUFF sang at a poisoned Pokémon" >&2; return 1; }
}
