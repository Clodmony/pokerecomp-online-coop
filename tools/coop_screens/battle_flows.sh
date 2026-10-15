# The battle screen's own flows on the co-op field (#26, test cases B38-B40): RED's CHARMANDER at L14 with 2030 EXP,
# 6 HP and SCRATCH, GROWL, EMBER, TACKLE, three POTIONs in RED's bag (SEED_ARGS, or a SEED made that way by hand).
# RED fights the session menu's wild PIDGEY on a red bar (the alarm), uses a POTION
# (the party screen fills the bar, "recovered by 20!"), then EMBERs it down: L15 with the stats box beside the line,
# and LEER's "Delete an older move?": NO asks "Abandon learning LEER?", NO asks again, and RED keeps the old moves.
SEED_ARGS="red viridian_forest mon=CHARMANDER:14:moves=SCRATCH/GROWL/EMBER/TACKLE:hp=6:exp=2030 item=POTION:3"
HOST_ARGS=bare
DURATION=75
press p1 1.8 SELECT @FIGHT.+PIDGEY
shot p1 9 red_low_hp
press p1 12 @USE.+POTION
for at in $(seq 13 1 18); do shot p1 "$at" "red_potion_$at"; done
for at in 22 25 28 31; do press p1 "$at" @^FIGHT.+EMBER; done
for at in $(seq 23 1 50); do shot p1 "$at" "red_$at"; done
press p1 52 B                         # NO
shot p1 54 red_abandon                # "Abandon learning LEER?"
press p1 56 B                         # NO again
shot p1 58 red_asked_again
press p1 60 @KEEP.OLD
shot p1 66 red_kept
