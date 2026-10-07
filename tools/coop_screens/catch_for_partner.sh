# RED fights a wild PIDGEY, BLUE joins, and RED throws POKé BALLs naming BLUE
# until one holds; the PIDGEY is BLUE's (test cases B01, B09 and B10).
DURATION=70
press p1 1.8 SELECT A                 # FIGHT wild PIDGEY
for at in 12 15 18 21 24 27 30 33 36 39 42 45 48 51; do
	press p1 "$at" @THROW.+BLUE       # taken whenever it is RED's turn and the field is still
done
shot p1 9.5 red_rows
shot p1 54 red_after
press p2 6.6 SELECT D D D A           # JOIN
shot p2 9 blue_joined
shot p2 30 blue_mid
shot p2 56 blue_after
press p2 58 A                         # close the battle
press p2 60 START A                   # the party
shot p2 63 blue_party
