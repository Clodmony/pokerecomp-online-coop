# RED saves from the START menu and both windows hear it; then BLUE starts a
# battle and RED's next SAVE fails in the game's own box (test case S07).
# Generation 1's START menu keeps its last row, so the second SAVE is START, A.
DURATION=45
press p1 3 START D D D A              # SAVE: POKéMON, ITEM, RED, SAVE
press p1 5 A                          # YES
shot p1 7 red_saving
for at in 8 9.5 11; do press p1 "$at" A; done
shot p2 2 blue_hears_1
shot p2 4 blue_hears_2
shot p2 6 blue_hears_3
press p2 12 SELECT @FIGHT.+PIDGEY
press p1 22 START A
press p1 24 A
shot p1 26.5 red_save_question
press p1 28 A                         # YES, while BLUE fights
shot p1 29.5 red_save_failed_1
shot p1 31 red_save_failed_2
press p1 33 A
