# A story gate one player opens is open for the team (#174, D91, D132, test cases J20 to J22): a seed stands GOLD
# below LANCE at the Lake of Rage and SILVER at the door of Mahogany Town's mart. SILVER walks in first and finds a
# plain shop, no stairs; GOLD tells LANCE YES, which sets the mart's scene to LANCE_UNCOVERS_STAIRS. SILVER walks
# out and in again and plays that scene in its own window: LANCE's DRAGONITE knocks the guard aside and the
# staircase to the Rocket hideout opens. The campaign holds no story but the flags set here.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=9:6:21,29 at2=2:7:11,8 event=-1748 event=1749"
HOST_ARGS=bare
DURATION=110
press p1 3 U A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A - A -                                    # face LANCE, then YES and through his lines
press p2 3 U U                                    # into the mart
shot p2 6 silver_mart_before                      # the shop as it is: no LANCE, no stairs
press p2 8 D                                      # back out to Mahogany Town
shot p1 8 gold_meets_lance
shot p1 30 gold_lance_asks
shot p1 60 gold_lance_gone                        # LANCE flew off to Mahogany
press p2 62 U U B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B -                               # into the mart again
shot p2 66 silver_lance_in_the_mart
shot p2 100 silver_stairs_open                    # the staircase LANCE uncovered, in SILVER's own window
check() {
	local log=("$user"/coop_logs/*_join_P2.jsonl)
	jq -s -e '[.[] | select(.kind == "world_pull") | .data.changes.map_scenes // {} | (.set // .value // {})["3:40"]] | index(1) != null' \
		"${log[@]}" > /dev/null || return 1
	jq -e '.campaign.flags | map(tostring) | index("738") != null' "$user/coop_campaigns/$GAME/$GAME.json" > /dev/null
}
