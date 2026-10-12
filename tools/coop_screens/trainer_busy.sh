# A trainer fighting one player spots nobody else (SEED=<a tools/coop_seed.gd out dir> with RED on ROUTE 3 (20,6)
# and BLUE at (22,6)): RED walks into the LASS's sight and fights her; BLUE steps into the same sight line
# meanwhile and is not spotted, and once RED has won the LASS is beaten in BLUE's world too. With RED's lead a
# DIGLETT knowing only DIG, each DIG is one command and comes up out of the ground drawn once.
: "${SEED:?trainer_busy needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
DURATION=70
P1_ARGS=auto_battle
shot p1 4 p1_route
shot p2 4 p2_route
press p1 5 U U - - - - A - A - A - A - A
shot p1 14 p1_battle_14
shot p1 16 p1_battle_16
shot p1 18 p1_battle_18
shot p1 20 p1_battle_20
shot p1 22 p1_battle_22
shot p1 24 p1_battle_24
shot p1 26 p1_battle_26
shot p1 28 p1_battle_28
shot p1 30 p1_battle_30
shot p1 32 p1_battle_32
shot p1 34 p1_battle_34
shot p1 36 p1_battle_36
shot p1 38 p1_battle_38
shot p1 40 p1_battle_40
shot p1 42 p1_battle_42
shot p1 44 p1_battle_44
shot p1 46 p1_battle_46
shot p1 48 p1_battle_48
shot p1 50 p1_battle_50
shot p1 52 p1_battle_52
shot p1 54 p1_battle_54
shot p1 56 p1_battle_56
press p2 15 U U
shot p2 18 p2_in_sight
shot p1 60 p1_after
shot p2 62 p2_after
press p2 63 D U
shot p2 66 p2_back_in_sight
check() {
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log \
		&& rg -q '"kind":"battle_start"' "$user/coop_logs" \
		&& ! rg -q '"name":"P2".*"kind":"takeover_start"' "$user/coop_logs"
}
