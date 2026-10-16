# Gold and Silver's Colosseum between the two players (#181, test case J71; D137): a seed stands GOLD (ONIX L20)
# and SILVER (SENTRET L2) at Goldenrod's Cable Club. Each talks to the COLOSSEUM receptionist, saves and sits on their
# own side of the table; the host pits them in one battle on the co-op field, both choosing TACKLE (auto_battle), until
# SENTRET faints: YOU WIN and YOU LOSE, then each window's link record, then back at the table.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=20:1:9,3:9,4 mon=p1:ONIX:20 mon=p2:SENTRET:2 event=31"
HOST_ARGS=bare
P1_ARGS=auto_battle
P2_ARGS=auto_battle
DURATION=175
press p1 4 U A
press p1 7 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
press p1 25 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
press p1 85 U - U - L - U - R - A
press p2 50 U - A
press p2 53 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
press p2 71 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
press p2 92 U - U - R - R - U - L - A
shot p2 52 silver_talks                # "Welcome to CABLE CLUB COLOSSEUM."
shot p2 98 silver_seat                # on the right of the table, the friend on the left
shot p1 103 gold_battle               # GOLD's ONIX against SILVER's SENTRET, then the turns,
shot p2 103 silver_battle             # YOU WIN and YOU LOSE and each window's link record as they come
shot p1 107 gold_fight_1
shot p2 107 silver_fight_1
shot p1 111 gold_fight_2
shot p2 111 silver_fight_2
shot p1 115 gold_fight_3
shot p2 115 silver_fight_3
shot p1 119 gold_fight_4
shot p2 119 silver_fight_4
press p1 128 B - - - - - - - - - - - - B - - - - - - - - - - - - B - - - - - - - - - - - - B
press p2 128 B - - - - - - - - - - - - B - - - - - - - - - - - - B - - - - - - - - - - - - B
shot p1 123 gold_fight_5
shot p2 123 silver_fight_5
shot p1 150 gold_back                 # back at the table
shot p2 150 silver_back
# The battle finished on the host, and its autosave holds both parties as the seed saved them (`LoadPokemonData`).
check() {
	python3 -I - "$out/seed/coop_campaigns/gold/gold.json" "$user/coop_campaigns/gold/gold.json" <<'PY'
import json, sys
def teams(path): return {p["player_id"]: [(r["uid"], r["mon"]["species"], r["mon"]["hp"], r["mon"]["exp"]) for r in p["team"]] for p in json.load(open(path))["players"]}
seeded, saved = teams(sys.argv[1]), teams(sys.argv[2])
assert saved == seeded, (seeded, saved)
PY
	grep -q 'versus:b1 by p[12]: versus' "$out/summary.txt"
}
