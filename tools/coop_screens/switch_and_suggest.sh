# RED fights a wild RATTATA, BLUE joins and suggests, RED switches to BLUE's
# SQUIRTLE and the turn is BLUE's, BLUE switches back (test cases B02, B03 and B21).
# Each window counts from its own world opening; BLUE's opens about four seconds later.
DURATION=55
press p1 1.8 SELECT @FIGHT.+RATTATA
press p2 6.6 SELECT @JOIN
shot p2 8.5 blue_main_red_decides     # BLUE's FIGHT/PKMN/ITEM/RUN, "RED decides" beside it
press p2 9.5 @SWITCH.+SQUIRTLE        # a suggestion: the party list walked to SQUIRTLE
shot p2 10.6 blue_party_suggesting    # "RED decides." under BLUE's own list
press p2 11 @SWITCH.+SQUIRTLE         # A from BLUE suggests again
press p1 16 D                         # RED's cursor to ITEM: the hollow mark stands on <PKMN>
shot p1 16.5 red_main_marked
press p1 16.9 U R A                   # into <PKMN>: the mark on SQUIRTLE's row
shot p1 18.3 red_party_marked
press p1 18.6 B
shot p1 21.2 red_sees_suggestion      # left idle, the box spells out "BLUE suggests SQUIRTLE"
for at in 23 26 29; do press p1 "$at" @SWITCH.+SQUIRTLE; done
shot p2 27 blue_decides
for at in 29 32 35; do press p2 "$at" @SWITCH.+CHARMANDER; done
shot p1 45 red_decides_again
