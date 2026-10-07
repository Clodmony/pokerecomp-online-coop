# RED fights a wild RATTATA, BLUE joins and suggests, RED switches to BLUE's
# SQUIRTLE and the turn is BLUE's, BLUE switches back (test cases B02 and B03).
# Each window counts from its own world opening; BLUE's opens about four seconds later.
DURATION=55
press p1 1.8 SELECT @FIGHT.+RATTATA
press p2 6.6 SELECT @JOIN
press p2 9.5 @SWITCH.+SQUIRTLE        # a suggestion: RED sees "◀ BLUE" on that row
press p2 11 @SWITCH.+SQUIRTLE
shot p1 17 red_sees_suggestion
for at in 19 22 25; do press p1 "$at" @SWITCH.+SQUIRTLE; done
shot p2 26 blue_decides
for at in 28 31 34; do press p2 "$at" @SWITCH.+CHARMANDER; done
shot p1 45 red_decides_again
