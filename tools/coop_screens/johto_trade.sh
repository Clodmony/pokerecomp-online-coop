# Gold and Silver's Trade Center between the two players (#181, test cases J65 to J67; D137): a seed stands GOLD
# (ONIX holding a METAL COAT) and SILVER (SENTRET holding a BERRY) at Goldenrod's Cable Club. Each talks to the TRADE
# receptionist and saves (no "can't link to the past"), sits on their own side of the table; SILVER offers and waits
# under WAITING..! for GOLD's offer, then both TRADE: SILVER's window plays the movie and ONIX evolves into STEELIX.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=20:1:5,3:5,4 mon=p1:ONIX:20:METAL_COAT mon=p2:SENTRET:10:BERRY event=31"
HOST_ARGS=bare
DURATION=235
press p1 4 U A
shot p1 6 gold_receptionist           # "Welcome to CABLE CLUB TRADE CENTER."
press p1 7 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
press p1 25 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
shot p1 40 gold_comes_in
press p1 46 U - U - L - U - R - A
shot p1 122 gold_trade_screen         # GOLD's ONIX over SILVER's SENTRET
press p1 137 A
press p1 140 R
press p1 143 A                         # SILVER offered first: no wait
shot p1 148 gold_asked                # "Trade ONIX for SENTRET?"
press p1 152 A - - - - A
shot p1 158 gold_movie                # ONIX, OT/GOLD, leaves
shot p1 174 gold_sent                 # "ONIX was sent to SILVER."
press p2 62 U
press p2 66 U                          # again, in case GOLD still stood at the counter
press p2 70 U - A
press p2 75 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
press p2 93 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
press p2 114 U - U - R - R - U - L - A
shot p2 120 silver_seat                # on the right of the table, the friend on the left
press p2 127 A
press p2 130 R
press p2 133 A
shot p2 136 silver_waiting            # WAITING..! for GOLD's offer
shot p2 148 silver_asked
press p2 152 A - - - - A
shot p2 174 silver_received           # "SENTRET was sent to GOLD."
shot p2 190 silver_take_care          # "Take good care of ONIX."
shot p2 204 silver_evolved            # "Congratulations! Your ONIX evolved into STEELIX!"
# The host's autosave: SILVER holds GOLD's ONIX as STEELIX under GOLD's uid, the METAL COAT spent; GOLD holds
# SILVER's SENTRET with its BERRY under SILVER's uid.
check() {
	python3 -I - "$user/coop_campaigns/gold/gold.json" <<'PY'
import json, sys
players = {player["player_id"]: player for player in json.load(open(sys.argv[1]))["players"]}
def team(member): return [(row["uid"], row["mon"]["species"], row["mon"].get("item", 0)) for row in players[member]["team"]]
assert team("p1") == [("p2:2", 161, 173)] and team("p2") == [("p1:2", 208, 0)], (team("p1"), team("p2"))
PY
}
