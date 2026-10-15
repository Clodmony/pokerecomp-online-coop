# Two levels from one award (test case B39): RED's BULBASAUR L5 starts against the wild ONIX L60 and makes way for
# MEWTWO, whose PSYCHIC wins; BULBASAUR's half of the award takes it from L5 to L10 in one line, the stats box beside
# that line only. Generation 1 teaches only the last level's moves (`_raise_levels`), so no LEECH SEED (L7) is offered;
# the fifth move's question is battle_flows'. Seed built from SEED_ARGS.
SEED_ARGS="red viridian_forest mon=BULBASAUR:5:moves=TACKLE/GROWL/SCRATCH/EMBER mon=MEWTWO:70:moves=PSYCHIC"
HOST_ARGS="bare seed=${ROLLS:-7}"
DURATION=100
press p1 1.8 SELECT @FIGHT.+ONIX
for at in $(seq 10 1.5 22); do press p1 "$at" "@SWITCH.+MEWTWO"; done   # one menu level a press; the row is gone once MEWTWO is out
for at in $(seq 24 3 42); do press p1 "$at" "@^FIGHT.+PSYCHIC" "@^FIGHT.+PSYCHIC"; done
for at in $(seq 6 1 90); do shot p1 "$at" "red_$at"; done

shot p1 75 red_after


check() {
	local grew
	grew="$(rg -o '"type":"grew_level","side":0,"index":0,[^}]*"old_level":[0-9]+,"new_level":[0-9]+' "$user/coop_logs" | head -1 | grep -oE '[0-9]+,"new_level":[0-9]+$' | grep -oE '[0-9]+' | paste -sd' ')"
	echo "battle_level_twice: BULBASAUR from L${grew% *} to L${grew#* }"
	[[ -n "$grew" ]] && (( ${grew#* } - ${grew% *} >= 2 )) || { echo "battle_level_twice: no two levels from one award" >&2; return 1; }
}
