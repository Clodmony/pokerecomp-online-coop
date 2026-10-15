# The co-op field's effects (test case B38): RED's MEW makes a SUBSTITUTE (the doll; its bar turns red and
# beeps), MINIMIZEs (the dot), badly poisons the wild PIDGEY with TOXIC and TRANSFORMs into it, then RED sends out HITMONLEE
# (the doll is gone) whose JUMP KICK may miss and crash (the screen shakes). Seed built from SEED_ARGS.
SEED_ARGS="red viridian_forest mon=MEW:30:moves=SUBSTITUTE/MINIMIZE/TOXIC/TRANSFORM:hp=40 mon=HITMONLEE:30:moves=JUMP_KICK"
HOST_ARGS="bare seed=${ROLLS:-7}"
DURATION=120
press p1 1.8 SELECT @FIGHT.+PIDGEY
turn() { local at; for at in $(awk -v t="$1" 'BEGIN { print t, t + 1.5, t + 3 }'); do press p1 "$at" "$2" "$2"; done; }
turn 10 "@^FIGHT.+SUBSTITUTE"         # a press walks one menu level; a press during a turn's lines is dropped
turn 22 "@^FIGHT.+MINIMIZE"
turn 34 "@^FIGHT.+TOXIC"
turn 46 "@^FIGHT.+TRANSFORM"
for at in $(seq 58 1.5 67); do press p1 "$at" "@SWITCH.+HITMONLEE"; done   # the row is gone once HITMONLEE is out
for at in $(seq 70 4 106); do press p1 "$at" "@^FIGHT.+JUMP" "@^FIGHT.+JUMP"; done
for at in $(seq 6 1 112); do shot p1 "$at" "red_$at"; done

events() { rg -o "\"type\":\"$1\"" "$user/coop_logs" | wc -l; }

check() {
	local kind missing=""
	for kind in substitute_made minimized status_inflicted transformed sent_out; do
		(( $(events "$kind") > 0 )) || missing+=" $kind"
	done
	echo "battle_effects: substitute_made $(events substitute_made), minimized $(events minimized), status_inflicted $(events status_inflicted), transformed $(events transformed), sent_out $(events sent_out), crashed $(events crashed)"
	[[ -z "$missing" ]] || { echo "battle_effects: no$missing in the host's battle views" >&2; return 1; }
}
