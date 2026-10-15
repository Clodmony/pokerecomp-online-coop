# JUMP KICK's crash on the co-op field (test case B38, the half battle_effects cannot show: its PIDGEY falls to the
# first JUMP KICK). RED's HITMONLEE MEDITATEs while the wild PIDGEY's SAND-ATTACK lowers its accuracy, then spams
# JUMP KICK until one misses: "HITMONLEE kept going and crashed!" and the screen shakes. Seed built from SEED_ARGS;
# the host's rolls are fixed (ROLLS=<seed>) so the misses fall on the same turns every run.
SEED_ARGS="red viridian_forest mon=HITMONLEE:30:moves=MEDITATE/JUMP_KICK"
HOST_ARGS="bare seed=${ROLLS:-3}"
DURATION=140
press p1 1.8 SELECT @FIGHT.+PIDGEY
for at in $(seq 8 1.5 80); do press p1 "$at" "@^FIGHT.+MEDITATE" "@^FIGHT.+MEDITATE"; done
for at in $(seq 84 1.5 128); do press p1 "$at" "@^FIGHT.+JUMP" "@^FIGHT.+JUMP"; done
for at in $(seq 6 1 132); do shot p1 "$at" "red_$at"; done

events() { rg -o "\"type\":\"$1\"" "$user/coop_logs" | wc -l; }

check() {
	echo "battle_crash: accuracy_lowered $(rg -o '"stat":"accuracy"' "$user/coop_logs" | wc -l), crashed $(events crashed), screen_shake $(events screen_shake)"
	(( $(events crashed) > 0 )) || { echo "battle_crash: no crashed in the host's battle views" >&2; return 1; }
}
