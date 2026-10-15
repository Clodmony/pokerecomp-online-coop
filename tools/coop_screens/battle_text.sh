# The battle screen's lines on the co-op field (test case B37): RED's PIKACHU SPARKY spams HORN DRILL at the
# session menu's wild PIDGEY, missing and then landing "One-hit KO!"; EXP.ALL shares the award with the traded
# KADABRA ("a boosted"). Then the wild ONIX L60 faints SPARKY, KADABRA is sent out and, traded at L60 with no badge,
# disobeys before it faints too. The seed is built by the runner from SEED_ARGS; the host's rolls are fixed.
SEED_ARGS="red viridian_forest mon=PIKACHU:20:moves=HORN_DRILL/THUNDERSHOCK:nick=SPARKY mon=KADABRA:60:moves=CONFUSION/PSYBEAM:traded item=EXP.ALL:1"
HOST_ARGS="bare seed=${ROLLS:-7}"
DURATION=125
press p1 1.8 SELECT @FIGHT.+PIDGEY
for at in $(seq 7 3 40); do press p1 "$at" "@^FIGHT.+HORN" "@^FIGHT.+HORN"; done
for at in $(seq 6 2 44); do shot p1 "$at" "red_pidgey_$at"; done
press p1 48 SELECT @FIGHT.+ONIX
for at in $(seq 53 4 105); do press p1 "$at" @^FIGHT @^FIGHT @SEND.OUT @SEND.OUT; done
for at in $(seq 52 3 110); do shot p1 "$at" "red_onix_$at"; done

events() { rg -o "\"type\":\"$1\"" "$user/coop_logs" | wc -l; }

check() {
	local kind missing=""
	for kind in used_move missed ohko exp_gained fainted sent_out; do
		(( $(events "$kind") > 0 )) || missing+=" $kind"
	done
	echo "battle_text: events used_move $(events used_move), missed $(events missed), ohko $(events ohko), exp_gained $(events exp_gained), disobeyed $(rg -o '"instead":true' "$user/coop_logs" | wc -l), sent_out $(events sent_out)"
	rg -q '"type":"used_move","side":0,[^}]*"instead":true' "$user/coop_logs" || missing+=" disobedience"
	rg -q '"type":"exp_gained",[^}]*"name":"KADABRA",[^}]*"boosted":true' "$user/coop_logs" || missing+=" boosted"
	[[ -z "$missing" ]] || { echo "battle_text: no$missing in the host's battle views" >&2; return 1; }
}
