# German Red and Blue (#50) on a seed at Pewter's south gate (SEED=<coop_seed.gd out dir, leg viridian_forest>,
# GAME=red_de P2_GAME=blue_de): RED opens every START entry, BLUE walks to the POKéMON CENTER's PC and opens
# SOMEONE's PC and its own; every capture German (test cases G07 to G10).
: "${SEED:?german_screens needs SEED=<an out dir of tools/coop_seed.gd>}"
[[ "$GAME" == *_de ]] || GAME=red_de
HOST_ARGS=bare
DURATION=90
press p1 3 START                      # the menu keeps its last row: each entry is START, D, A from the one before
shot p1 4.5 start_menu
press p1 5 A
shot p1 7.5 dex_list
press p1 8 D D D A                    # #004, the seed's starter
shot p1 10.5 dex_menu
press p1 11 A
shot p1 14 dex_data
press p1 14.5 B B B B
press p1 17 START D A
shot p1 19.5 party
press p1 20 A
shot p1 21.5 party_menu
press p1 22 A
shot p1 24.5 stats_1
press p1 25 A
shot p1 26.5 stats_2
press p1 27 B B B B
press p1 30 START D A
shot p1 32.5 bag
press p1 33 A
shot p1 34.5 bag_item_menu
press p1 35 B B B B
press p1 38 START D A
shot p1 40.5 trainer_card
press p1 41 B B B
press p1 44 START D A
shot p1 47 save_question
press p1 48 B B B
press p1 51 START D A
shot p1 53.5 options
press p1 54 B B
press p1 57 START D A
shot p1 59.5 coop_menu
press p1 60 B B
press p1 63 START D D
shot p1 65.5 start_menu_end
press p1 66 B
press p2 4 U - U - U - U - U - U - U - U       # up the road to the sign at (19,29)
press p2 9 L - L - L - L - L - L               # along row 30 to column 13
press p2 13 U - U - U - U - U - U              # up column 13 into the POKéMON CENTER
shot p2 17.5 center_inside
press p2 18 U - U - U - U - U - R - R - R - R - R - R - R - R - R - R - R - R - D - R - U
shot p2 32 center_pc_front
press p2 33 A
shot p2 35 pc_boot
press p2 36 A
shot p2 38 pc_menu
press p2 39 A                         # SOMEONE's PC, then its lines
shot p2 41 pc_text_1
press p2 42 A
shot p2 44 pc_text_2
press p2 45 A
shot p2 47 pc_text_3
press p2 48 A
shot p2 50 bills_pc
press p2 51 A
shot p2 53 bills_pc_withdraw
press p2 54 B
shot p2 56 bills_pc_back
press p2 57 D D D D A
shot p2 60 pc_menu_again
press p2 61 D A
shot p2 63 players_pc_text
press p2 64 A
shot p2 67.5 players_pc
press p2 68 B B B B B
