# RED fights a wild PIDGEY, BLUE joins, and RED throws POKé BALLs naming BLUE
# until one holds; the PIDGEY is BLUE's (test cases B01, B09 and B10).
DURATION=100
press p1 1.8 SELECT A                 # FIGHT wild PIDGEY
press p1 14 D A                       # ITEM, once BLUE's arrival has been told: the bag's own list
shot p1 15 red_bag
press p1 15.4 A                       # a ball asks whom the catch is for
shot p1 16.4 red_recipient
for at in $(seq 17 3 80); do
	press p1 "$at" @THROW.+BLUE       # taken whenever it is RED's turn and the field is still
done
shot p1 9.5 red_rows
shot p1 84 red_after
press p2 6.6 SELECT @JOIN
shot p2 9 blue_joined
shot p2 30 blue_mid
shot p2 84 blue_after                 # the battle closed itself once its last line had played
press p2 86 START A                   # the party
shot p2 89 blue_party
