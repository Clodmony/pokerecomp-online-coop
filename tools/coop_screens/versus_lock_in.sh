# A friend battle where RED locks in first: BLUE's move list stays open, cursor and all, until BLUE chooses
# (SEED=<a tools/coop_seed.gd out dir> with both players on one map).
: "${SEED:?versus_lock_in needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
DURATION=45
press p1 5 SELECT @BATTLE
press p2 9 A
shot p2 17 p2_battle
press p2 22 A D
shot p2 23 p2_move_list
press p1 25 A A
shot p1 28 p1_waiting
shot p2 28 p2_move_list_after_lock_in
press p2 30 A
shot p2 33 p2_turn
shot p1 33 p1_turn
check() { ! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log && rg -q '"kind":"versus"' "$user/coop_logs" \
	&& [[ "$(rg -o '"command":\{"type":"move"' "$user"/coop_logs/*host*.jsonl | wc -l)" -ge 2 ]]; }
