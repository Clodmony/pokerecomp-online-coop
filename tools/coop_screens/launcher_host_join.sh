# RED hosts a new campaign from the launcher's Co-op tab with CHARMANDER; BLUE joins it by
# address and plays the opening (Oak's speech with the tab's name, the rival named GARY, the
# bedroom) while RED hears BLUE arrive and the session menu says where BLUE is (test cases S01,
# S05, W08). Seconds count from each window's launch: a round takes a step every 0.5 s and
# presses Host or Join 4.5 s in.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=coop_launcher_play
P1_ARGS="host name=RED starter=1 round=60:WITH_BLUE"
P2_ARGS="join name=BLUE rival=2 round=60"
DURATION=56
shot p1 0.9 red_shelf                 # the launcher as it opens, on the Play tab
shot p1 1.4 red_coop_tab              # the Co-op tab as a pad reaches it, Host in view
shot p1 5.3 red_filled                # RED, opening skipped with CHARMANDER, new campaign WITH BLUE
shot p1 7 red_world                   # Pallet Town
shot p1 10.5 red_blue_joined          # "BLUE joined the session."
press p1 14 SELECT
shot p1 14.6 red_menu                 # "With BLUE (in the opening)"
press p1 16 B
shot p2 1.4 blue_coop_tab
shot p2 5.3 blue_filled               # BLUE, the opening played (the default), address 127.0.0.1
shot p2 7 blue_copyright
shot p2 14 blue_speech
shot p2 30 blue_speech_later
shot p2 52 blue_bedroom               # the opening's bedroom, nobody else drawn
press p1 55 SELECT
shot p1 55.6 red_menu_later           # BLUE still in the opening, nowhere on RED's map
