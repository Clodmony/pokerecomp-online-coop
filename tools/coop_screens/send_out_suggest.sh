# "Use next POKéMON?" with the partner in a wild battle (#151, test case B36; SEED: tools/coop_seed.gd red viridian_forest
# level=25 party=3, then RED's lead at 1 HP knowing only SELFDESTRUCT). RED fights the session menu's wild ONIX,
# BLUE joins; the first turn faints RED's CHARMANDER either way: RED's window asks "Use next POKéMON?", BLUE's asks
# the same and BLUE points at NO (a suggestion to run), so RED's box wears BLUE's mark there; RED answers YES.
: "${SEED:?send_out_suggest needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
DURATION=55
press p1 2 SELECT @FIGHT.+ONIX
press p2 6 SELECT @JOIN
press p1 12 $(for _ in $(seq 12); do printf '@SELFDESTRUCT '; done)
for at in 24 27 30 33; do press p2 "$at" @RUN; done
for at in $(seq 8 45); do
	shot p1 "$at" "p1_battle_$at"
	shot p2 "$at" "p2_battle_$at"
done
press p1 36 A
press p1 39 @CHARMANDER
check() {
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log && rg -q '"suggestion":\{"type":"run","value":0' "$user/coop_logs" \
		&& rg -q '"type":"send_out"' "$user/coop_logs"
}
