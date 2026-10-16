# A phone trainer's rematch for each Gold and Silver player (#177, test case J79): a seed stands GOLD and
# SILVER either side of JOEY on Route 30, JOEY beaten by the team and his rematch call taken by each player (own
# EVENT_JOEY_READY_FOR_REMATCH). GOLD talks first and fights JOEY's RATTATA with RAZOR LEAF; once that is over SILVER talks to him
# and fights a rematch of SILVER's own with EMBER, where the host used to count JOEY as beaten and skip SILVER's battle.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=26:1:5,29:7,29 level=20 event=1449 event=p1:628 event=p2:628"
HOST_ARGS=bare
DURATION=100
shot p1 4 gold_route_30
shot p2 4 silver_route_30
press p1 5 R A
for at in 7 9 11 13; do shot p1 "$at" "gold_joey_$at"; press p1 "$((at + 1))" A; done
for at in $(seq 15 2 39); do press p1 "$at" "@^FIGHT.+RAZOR.LEAF"; done
for at in $(seq 16 3 43); do shot p1 "$at" "gold_battle_$at"; done
press p2 50 L A
for at in 52 54 56 58; do shot p2 "$at" "silver_joey_$at"; press p2 "$((at + 1))" A; done
for at in $(seq 60 2 84); do press p2 "$at" "@^FIGHT.+EMBER"; done
for at in $(seq 61 3 91); do shot p2 "$at" "silver_battle_$at"; done
# The host's log: two battles with JOEY won, GOLD's as the team's and SILVER's as a rematch of SILVER's own.
check() {
	local won own
	won="$(rg -c '"kind":"battle_end".*"outcome":"won"' "$user"/coop_logs/*host*.jsonl | head -1)"
	own="$(rg -c '"kind":"battle_start".*"id":"window:[^"]*","kind":"trainer","unique":false,"trainer_class":22,' "$user"/coop_logs/*host*.jsonl | head -1)"
	echo "johto_rematch: battles won: ${won:-0}; rematches of a player's own: ${own:-0}"
	[[ "${won:-0}" -ge 2 && "${own:-0}" -ge 1 ]]
}
