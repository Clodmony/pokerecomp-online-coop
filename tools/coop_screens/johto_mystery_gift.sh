# Gold and Silver's Mystery Gift between the two players (#181, test cases J68 to J70; D137): a seed stands GOLD and
# SILVER by the girl on Goldenrod Dept. Store 5F. Both hear her explain MYSTERY GIFT, which unlocks it on the host;
# SILVER picks GIFT GOLD in the co-op menu, GOLD says YES, and both windows open the MYSTERY GIFT screen on the box
# naming what the other sent. Both turn away from her first, so no A after a menu talks to her again.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=11:16:9,2:10,2 event=31"
HOST_ARGS=bare
DURATION=75
press p1 4 U - A
shot p1 6 gold_explained              # "MYSTERY GIFT."
press p1 7 A - - - - - - - - - A - - - - - - - - - A - - - - - - B - - - - - B - - - - - B - - - - - B
press p2 4 U - L - A
press p2 8 A - - - - - - - - - A - - - - - - - - - A - - - - - - B - - - - - B - - - - - B - - - - - B
press p1 24 D                          # away from her
press p2 26 R
press p2 34 SELECT                     # once both unlocks reached the host
press p2 36 @GIFT.GOLD
shot p1 42 gold_invited               # "SILVER / MYSTERY GIFT?" YES
press p1 44 A - - - - - - - - - A
shot p1 50 gold_screen                # the MYSTERY GIFT screen
shot p1 54 gold_box                   # "SILVER sent <item>." (or a decoration home)
shot p2 50 silver_box
press p1 57 A - - - - - - - - - A - - - - - - - - - A
press p2 50 A - - - - - - - - - A - - - - - - - - - A - - - - - - - - - A
shot p1 60 gold_box_more
shot p2 56 silver_box_more
shot p1 68 gold_after                 # back on 5F
shot p2 64 silver_after
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
