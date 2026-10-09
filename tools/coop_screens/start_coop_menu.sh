# RED opens START > CO-OP, asks to LEAVE SESSION and says NO, then fights a wild PIDGEY from it;
# BLUE opens START > CO-OP, sees RED in a battle and joins it (#99, test cases S20, S21, S22).
DURATION=40
press p1 1.8 START D D D D D           # POKéMON, ITEM, RED, SAVE, OPTION, CO-OP
shot p1 3.9 red_start_menu
press p1 4.2 A
shot p1 5.0 red_coop_menu             # the campaign, BLUE and where, the last save; FIGHT rows
press p1 5.4 @LEAVE.SESSION
shot p1 6.2 red_leave_question
press p1 6.6 B                        # NO: back to the rows
shot p1 7.2 red_coop_menu_again
press p1 7.6 @FIGHT.+PIDGEY
shot p1 10 red_battle
press p2 6.6 START D D D D D A
shot p2 9.2 blue_coop_menu            # JOIN RED, VS PIDGEY; RED IN A BATTLE
press p2 9.6 @JOIN
shot p2 12.5 blue_joined
press p2 16 SELECT                    # in a battle SELECT opens nothing
shot p2 16.6 blue_select_in_battle
