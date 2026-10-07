# Both players play the opening and walk to Pewter Gym; p1 fights BROCK while p2 stands by inside
# the gym and stays 20 s after the badge (#84, D72). The story crosses at rest points only and
# the gym's script step is each player's, so p2's gym never replays BROCK's after-battle lines.
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P2_TOOL=coop_autoplay
P1_ARGS="opening speed=4 ball=0 shots=$out"
P2_ARGS="opening speed=4 ball=1 route=watch_brock shots=$out"
P2_DELAY=25
DURATION=3600

# Each player holds one TM34 (bag and PC), and p2's window never took a Pewter Gym step
# (wPewterGymCurScript, byte 12); the windows' longest holds are printed for the record.
check() {
	local campaign="$user/coop_campaigns/$GAME/$GAME.json"
	local tm34='([.items[] | select(.[0] == 234) | .[1]] | add // 0) + ((.world.pc_items // {})["234"] // 0)'
	jq -c ".players[] | {player_id, tm34: $tm34}" "$campaign" || return 1
	jq -c '.campaign | {badges, beat_brock: (.flags | tostring | test("\\b119\\b"))}' "$campaign"
	jq -e "[.players[] | $tm34] == [1, 1]" "$campaign" > /dev/null || return 1
	jq -s -c '[.[] | select(.kind == "world_pull" and .relay == null and .data.held > 0)] | sort_by(.data.held) | .[-3:][]
		| {player, held: .data.held, by: .data.held_by}' "$user"/coop_logs/*_join_*.jsonl
	jq -s -e '[.[] | select(.kind == "world_pull" and .relay == null) | (.data.changes.gen1_map_scripts // {}) as $c
		| (($c.set // {}) | has("12")) or (($c.value // {}) | has("12")) or (($c.erase // []) | index(12) != null)]
		| any | not' "$user"/coop_logs/*_join_P2.jsonl > /dev/null
}
