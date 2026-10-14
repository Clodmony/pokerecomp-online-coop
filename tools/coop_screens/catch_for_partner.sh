# RED fights a wild PIDGEY, BLUE joins, and RED throws POKé BALLs naming BLUE
# until one holds; the PIDGEY is BLUE's, and BLUE's window alone shows its new
# POKéDEX entry and asks for a nickname (test cases B01, B09, B10 and B42).
HOST_ARGS="seed=26"                   # the host's rolls fixed, so the ball holds at the same moment every run
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
shot p2 39 blue_new_dex               # "New POKéDEX data will be added for PIDGEY!" (the seeded ball holds near 36 s)
shot p2 44 blue_dex_page              # the entry, its height and weight known
press p2 46 B                         # the entry's second page
press p2 48 B                         # and back to the battle
press p2 54 B                         # "Do you want to give a nickname" waits, then "to PIDGEY?"
shot p2 56 blue_nickname              # with YES/NO
press p2 57 B                         # NO
shot p2 84 blue_after                 # the battle closed itself once its last line had played
press p2 86 START A                   # the party
shot p2 89 blue_party
