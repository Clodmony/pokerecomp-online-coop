# RED fights a wild ONIX L60 alone and loses: the battle closes by itself, RED's own world
# whites out, party healed, half RED's money, back at the last spawn (test case B14).
DURATION=112
press p1 1.8 SELECT @FIGHT.+ONIX
for at in 6 10 14 18 22 26 30 34 38 42 46 50 54 58 62 66 70; do press p1 "$at" @FIGHT @SEND.OUT; done
shot p1 20 red_fighting
shot p1 86 red_white_out              # the world's own "out of useable POKéMON!", no A spent on the battle
press p1 87 A
press p1 89 A
press p1 93 START A
shot p1 97 red_party
