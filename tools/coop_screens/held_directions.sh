# RED holds DOWN in START > CO-OP, then in a wild PIDGEY's move list: the cursor walks on
# at the cartridge's repeat rate rather than stopping after one row (#43, test cases P08).
DURATION=30
press p1 1.8 START D D D D D           # POKéMON, ITEM, RED, SAVE, OPTION, CO-OP
press p1 4.2 A
shot p1 5.0 red_coop_menu
press p1 5.4 D*8                       # held 2.4 s
shot p1 5.6 red_held_0
shot p1 6.4 red_held_1
shot p1 6.6 red_held_2
shot p1 6.9 red_held_3
shot p1 7.3 red_held_4
press p1 8.1 @FIGHT.+PIDGEY
shot p1 17 red_battle
press p1 18 A                          # FIGHT, once the intro's lines are done
shot p1 18.6 red_moves
press p1 19.2 D*8
shot p1 19.4 red_moves_held_0
shot p1 20.2 red_moves_held_1
shot p1 20.4 red_moves_held_2
shot p1 20.7 red_moves_held_3
shot p1 21.1 red_moves_held_4
press p1 22.2 B
shot p1 23 red_back_to_main
