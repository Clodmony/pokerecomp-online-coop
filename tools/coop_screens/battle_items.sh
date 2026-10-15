# Items in a co-op battle (test case B40): RED's poisoned, hurt CHARMANDER fights the wild PIDGEY; RED uses an
# ANTIDOTE, a POTION (the party screen fills the bar) and the POKé FLUTE (its own boxes, the tune between them),
# then EMBERs the PIDGEY down. Seed built from SEED_ARGS.
SEED_ARGS="red viridian_forest mon=CHARMANDER:14:moves=SCRATCH/EMBER:status=PSN:hp=15 item=ANTIDOTE:1 item=POTION:1 item=POKE_FLUTE:1"
HOST_ARGS="bare seed=${ROLLS:-7}"
DURATION=85
press p1 1.8 SELECT @FIGHT.+PIDGEY
for at in 10 11.5 13; do press p1 "$at" "@USE.+ANTIDOTE"; done   # one level of the menus a press, the bag slower
for at in 20 21.5 23; do press p1 "$at" "@USE.+POTION"; done
for at in 30 31.5; do press p1 "$at" "@USE.+FLUTE"; done
for at in $(seq 40 4 64); do press p1 "$at" "@^FIGHT.+EMBER" "@^FIGHT.+EMBER"; done
for at in $(seq 6 1 70); do shot p1 "$at" "red_$at"; done

check() {
	local used
	used="$(rg -o '"command":\{"type":"item","item":[0-9]+' "$user"/coop_logs/*host*.jsonl | grep -oE '[0-9]+$' | uniq | paste -sd' ')"
	echo "battle_items: items used in order: $used"
	[[ "$used" == "11 20 73" ]] || { echo "battle_items: not ANTIDOTE (11), POTION (20) and POKé FLUTE (73) in that order" >&2; return 1; }
}
