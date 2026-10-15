# Johto's world shared (#174, D132, test cases G20 to G22): GOLD hosts in New Bark Town (the tool host's RED), SILVER joins
# (BLUE). SILVER walks west and the teacher stops it ("Wait, BLUE!"): New Bark Town's scene is still TEACHER_STOPS_YOU.
# GOLD walks into ELM's lab, hears him out and takes CHIKORITA, whose script sets New Bark Town's scene to NOOP; at its
# next rest point SILVER's window pulls that scene, walks west again and leaves for Route 29 with nobody stopping it.
GAME=gold
P2_GAME=silver
DURATION=175
press p1 3 L L L L U U U L L L L L L L L L L R R R R U U   # along the lab's front wall to its door
press p1 14 B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B
press p1 76 D D D R R R U A                       # the third POKé BALL on the table
press p1 80 B
press p1 86 A A A A A A                           # YES, CHIKORITA, and on through its lines
press p1 93 B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B B
press p2 4 L L L L L D D D L L L L L L D D L L    # west along the town's south road
press p2 12 B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B - B -
press p2 130 L L L L L L L L L L
shot p2 10 silver_teacher_stops                   # "Wait, BLUE!": the gate is shut
shot p1 12 gold_meets_elm
shot p1 85 gold_takes_chikorita                   # "CHIKORITA, the grass POKéMON?"
shot p1 128 gold_lab_done                         # the ball is gone, ELM's lines are over
shot p2 128 silver_before_walking
shot p2 136 silver_on_route_29                    # map 24/3: the teacher let SILVER go
check() {
	local log=("$user"/coop_logs/*_join_P2.jsonl)
	jq -s -e '[.[] | select(.kind == "world_pull") | .data.changes.map_scenes // {} | (.set // .value // {})["24:4"]] | index(1) != null' \
		"${log[@]}" > /dev/null || return 1
	jq -s -e '[.[] | select(.kind == "map" and .player == "p2" and .data.map == [24, 3])] | length > 0' "${log[@]}" > /dev/null
}
