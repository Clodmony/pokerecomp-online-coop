# Split screen: RED stays at their door while BLUE leaves theirs, walks west and north onto Route 1. Each half's arrow
# stays on the part of its buffer the half shows: on the side edges first, then RED's on the top and BLUE's on the bottom (#142).
# BLUE's seconds count from the right half's launch, some ten seconds after RED's.
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=split
P1_ARGS="host name=RED starter=0 split round=60:SPLIT"
P2_ARGS="name=BLUE starter=2"
DURATION=60
shot p1 20 red_partner_east
shot p1 20.6 red_partner_east2
shot p2 12 blue_partner_west
shot p2 12.6 blue_partner_west2
press p2 24 L L L U U U U U U U U U
shot p2 30 blue_partner_south
shot p2 30.6 blue_partner_south2
shot p1 46 red_partner_north
shot p1 46.6 red_partner_north2
check() { ! grep -q "SCRIPT ERROR" "$out"/p1.log; }
