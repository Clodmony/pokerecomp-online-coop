# RED fights a wild PIDGEY, BLUE joins, leaves, rejoins from the CO-OP menu (SELECT);
# RED's window closes and BLUE is asked to take over (test cases B01, B04, B05 and B07).
DURATION=72
press p1 1.8 SELECT A                 # FIGHT wild PIDGEY, the CO-OP menu's first row
shot p1 10 red_battle
press p2 6.6 SELECT @JOIN             # JOIN RED's battle
shot p2 10 blue_joined                # FIGHT/PKMN/ITEM/RUN, "RED decides" beside them
press p2 12.3 @LEAVE.BATTLE           # RUN, then YES to "Leave the battle? Your team stays."
shot p2 14 blue_left                  # back in Pallet Town, RED marked where the battle is
press p2 15.0 SELECT
shot p2 15.3 blue_menu                # REJOIN, VS PIDGEY
press p2 15.9 @REJOIN
shot p2 18.3 blue_rejoined
close p1 26                           # RED's window goes; BLUE's battle waits
shot p2 28.3 blue_waiting
shot p2 55 blue_asked                 # "RED is away. Take over?" with YES/NO
press p2 57 @TAKE.OVER
shot p2 60.8 blue_took_over           # the menu, "For RED" beside it
