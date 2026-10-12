# Party balls (SEED: RED on ROUTE 3 (20,6), BLUE at (22,6), RED's three at level 25, the lead knowing only EMBER): under
# "LASS wants to fight!" both parties' balls; under "LASS sent out" her two again, the first fainted.
: "${SEED:?party_balls needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
DURATION=60
P1_ARGS=auto_battle
press p1 5 U U - - - - A - A - A - A - A
shot p1 9 p1_battle_009.0
shot p1 9.5 p1_battle_009.5
shot p1 10 p1_battle_010.0
shot p1 10.5 p1_battle_010.5
shot p1 11 p1_battle_011.0
shot p1 11.5 p1_battle_011.5
shot p1 12 p1_battle_012.0
shot p1 12.5 p1_battle_012.5
shot p1 13 p1_battle_013.0
shot p1 13.5 p1_battle_013.5
shot p1 14 p1_battle_014.0
shot p1 14.5 p1_battle_014.5
shot p1 15 p1_battle_015.0
shot p1 15.5 p1_battle_015.5
shot p1 16 p1_battle_016.0
shot p1 16.5 p1_battle_016.5
shot p1 17 p1_battle_017.0
shot p1 17.5 p1_battle_017.5
shot p1 18 p1_battle_018.0
shot p1 18.5 p1_battle_018.5
shot p1 19 p1_battle_019.0
shot p1 19.5 p1_battle_019.5
shot p1 20 p1_battle_020.0
shot p1 20.5 p1_battle_020.5
shot p1 21 p1_battle_021.0
shot p1 21.5 p1_battle_021.5
shot p1 22 p1_battle_022.0
shot p1 22.5 p1_battle_022.5
shot p1 23 p1_battle_023.0
shot p1 23.5 p1_battle_023.5
shot p1 24 p1_battle_024.0
shot p1 24.5 p1_battle_024.5
shot p1 25 p1_battle_025.0
shot p1 25.5 p1_battle_025.5
shot p1 26 p1_battle_026.0
shot p1 26.5 p1_battle_026.5
shot p1 27 p1_battle_027.0
shot p1 27.5 p1_battle_027.5
shot p1 28 p1_battle_028.0
shot p1 28.5 p1_battle_028.5
shot p1 29 p1_battle_029.0
shot p1 29.5 p1_battle_029.5
shot p1 30 p1_battle_030.0
shot p1 30.5 p1_battle_030.5
shot p1 31 p1_battle_031.0
shot p1 31.5 p1_battle_031.5
shot p1 32 p1_battle_032.0
shot p1 32.5 p1_battle_032.5
shot p1 33 p1_battle_033.0
shot p1 33.5 p1_battle_033.5
shot p1 34 p1_battle_034.0
shot p1 34.5 p1_battle_034.5
shot p1 35 p1_battle_035.0
shot p1 35.5 p1_battle_035.5
shot p1 36 p1_battle_036.0
shot p1 36.5 p1_battle_036.5
shot p1 37 p1_battle_037.0
shot p1 37.5 p1_battle_037.5
shot p1 38 p1_battle_038.0
shot p1 38.5 p1_battle_038.5
shot p1 39 p1_battle_039.0
shot p1 39.5 p1_battle_039.5
shot p1 40 p1_battle_040.0
shot p1 40.5 p1_battle_040.5
shot p1 41 p1_battle_041.0
shot p1 41.5 p1_battle_041.5
shot p1 42 p1_battle_042.0
shot p1 42.5 p1_battle_042.5
shot p1 43 p1_battle_043.0
shot p1 43.5 p1_battle_043.5
shot p1 44 p1_battle_044.0
shot p1 44.5 p1_battle_044.5
shot p1 45 p1_battle_045.0
shot p1 45.5 p1_battle_045.5
shot p1 46 p1_battle_046.0
shot p1 46.5 p1_battle_046.5
shot p1 47 p1_battle_047.0
shot p1 47.5 p1_battle_047.5
shot p1 48 p1_battle_048.0
shot p1 48.5 p1_battle_048.5
shot p1 49 p1_battle_049.0
shot p1 49.5 p1_battle_049.5
shot p1 50 p1_battle_050.0
check() {
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log && rg -q '"kind":"battle_start"' "$user/coop_logs"
}
