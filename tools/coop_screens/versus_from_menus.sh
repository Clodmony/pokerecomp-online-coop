# A friend battle asked for while both players are in menus: BLUE is in the START menu when RED's invitation
# comes, so the question waits until BLUE closes it; RED waits in OPTION, and the battle is drawn over it
# (never the white of a menu's fade the frozen world was in).
DURATION=36
P2_DELAY=2
P1_ARGS=auto_battle
press p2 5 START
shot p2 6 p2_start_menu
press p1 7 SELECT @BATTLE
press p1 9 START D D D D A
shot p2 11 p2_start_menu_no_question
shot p1 11 p1_options
press p2 12 B
shot p2 14 p2_question_after_menu
press p2 15 A
shot p1 21 p1_battle_over_options
shot p2 21 p2_battle
check() { ! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log && rg -q '"kind":"versus"' "$user/coop_logs"; }
