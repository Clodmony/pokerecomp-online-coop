# German Red or Blue (#50, D95): the START menu, SAVE's question and a wild
# battle's lines in the cartridge's own words. Needs red_de or blue_de imported;
# GAME=blue_de picks Blaue Edition.
[[ "$GAME" == *_de ]] || GAME=red_de
DURATION=60
press p1 3 START
shot p1 4.5 start_menu
press p1 6 D D D A
shot p1 8.5 save_question
press p1 10 B B B
press p2 3 SELECT
shot p2 4.5 coop_menu
press p2 6 @FIGHT
shot p2 12 battle_send_out
press p2 18 A
shot p2 20 battle_menu
press p2 22 A
shot p2 24 move_menu
press p2 26 A
shot p2 28 used_move_1
shot p2 31 used_move_2
shot p2 34 used_move_3
