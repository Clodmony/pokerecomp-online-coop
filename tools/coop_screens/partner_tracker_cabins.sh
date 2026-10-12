# Two windows on the S.S. Anne's first deck (SEED=<a tools/coop_seed.gd out dir>, both moved to SS_ANNE_1F (20,7) and (24,7)): RED
# goes into the third cabin from the stern; BLUE's arrow stands over that cabin's door, not the first one in the
# map's list, and RED's points at the cabin's own door out.
: "${SEED:?partner_tracker_cabins needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
DURATION=24
shot p1 4 p1_hall
shot p2 4 p2_hall
press p1 5 L D
shot p2 8 p2_cabin_door
shot p2 8.6 p2_cabin_door2
press p1 9 D D D
shot p1 11 p1_cabin
shot p1 11.6 p1_cabin2
check() { ! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log; }
