# Gold and Silver's Mystery Gift between the two players (#181, test cases J68 to J70; D137): a seed stands GOLD and
# SILVER by the girl on Goldenrod Dept. Store 5F. Both hear her explain MYSTERY GIFT, which unlocks it on the host;
# GOLD picks GIFT SILVER in the co-op menu, SILVER says YES, and both windows open the MYSTERY GIFT screen on the box
# naming what the other sent.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=11:16:9,2:10,2 event=31"
HOST_ARGS=bare
DURATION=60
press p1 4 U - A
shot p1 6 gold_explained              # "MYSTERY GIFT."
press p1 7 A
press p1 10 A
press p1 13 A
press p2 4 U - L - A
press p2 8 A
press p2 11 A
press p2 14 A
press p1 18 SELECT
press p1 20 @GIFT.SILVER
shot p2 24 silver_invited             # "GOLD / MYSTERY GIFT?" YES
press p2 25 A
shot p1 27 gold_screen                # the MYSTERY GIFT screen
shot p1 31 gold_box                   # "SILVER sent <item>." (or a decoration home)
shot p2 31 silver_box
press p1 33 A
press p2 33 A
shot p1 35 gold_box_more
shot p2 35 silver_box_more
press p1 37 A
press p2 37 A
press p1 41 A
press p2 41 A
shot p1 43 gold_after                 # back on 5F
# The host's autosave: each counted the other once today and holds the gift the other's block rolled.
check() {
	python3 -I - "$user/coop_campaigns/gold/gold.json" <<'PY'
import json, sys
players = {player["player_id"]: player for player in json.load(open(sys.argv[1]))["players"]}
gifts = {member: players[member]["mystery_gift"] for member in players}
for member, partner in (("p1", "p2"), ("p2", "p1")):
	gift = gifts[member]
	assert gift["partner_ids"] == [players[partner]["trainer_id"]] and gift["daily_partners"] == 1, gift
	assert gift["backup_item"] > 0 or gift["decorations_received"], gift
PY
}
