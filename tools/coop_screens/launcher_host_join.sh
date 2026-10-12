# RED hosts a new campaign from the launcher's Co-op tab with CHARMANDER; BLUE finds it nearby,
# joins as a new player and plays the opening (Oak's speech with the tab's name, the rival named
# GARY, the bedroom) while RED hears BLUE arrive and the CO-OP menu says where BLUE is and the
# address RED is reached at (test cases S01, S05, W08, K07, K14). Seconds count from each window's
# launch: a round takes a step every third of a second once what it waits for is there.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=coop_launcher_play
P1_ARGS="host name=RED starter=1 round=60:WITH_BLUE"
P2_ARGS="join name=BLUE rival=2 round=60"
DURATION=56
shot p1 0.9 red_shelf                 # the launcher as it opens, on the Play tab
shot p1 1.2 red_coop_tab              # the Co-op tab's start: cartridges, Host and Join
shot p1 2.6 red_filled                # New campaign WITH BLUE, RED starting in Pallet Town with CHARMANDER
shot p1 7 red_world                   # Pallet Town
shot p1 10.5 red_blue_joined          # "BLUE joined the session."
press p1 14 SELECT
shot p1 14.6 red_menu                 # "BLUE IN THE OPENING", "IP <address>"
press p1 16 B
shot p2 1.2 blue_coop_tab             # "1 game found nearby"
shot p2 2.6 blue_filled               # New in WITH BLUE: BLUE, the opening played (the default)
shot p2 7 blue_copyright
shot p2 14 blue_speech
shot p2 30 blue_speech_later
shot p2 52 blue_bedroom               # the opening's bedroom, nobody else drawn
press p1 55 SELECT
shot p1 55.6 red_menu_later           # BLUE still in the opening, nowhere on RED's map
