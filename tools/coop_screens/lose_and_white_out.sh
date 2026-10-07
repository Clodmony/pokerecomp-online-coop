# RED fights a wild ONIX L60 alone and loses: RED's own world whites out,
# party healed, half RED's money, back at the last spawn (test case B14).
DURATION=105
press p1 1.8 SELECT @FIGHT.+ONIX
for at in 6 10 14 18 22 26 30 34 38 42 46 50 54 58 62 66 70; do press p1 "$at" @FIGHT @SEND.OUT; done
shot p1 20 red_fighting
for at in 74 77 80; do press p1 "$at" A; done
shot p1 88 red_white_out
press p1 90 START A
shot p1 94 red_party
