# Both players play to BROCK's badge, then trade at Pewter's Cable Club: p1 is given a MACHOKE
# and offers it, p2 offers its first Pokémon (#38; test cases T01, T02; D31, D64).
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P2_TOOL=coop_autoplay
P1_ARGS="opening speed=4 ball=0 route=trade shots=$out"
P2_ARGS="opening speed=4 ball=1 route=trade shots=$out"
P2_DELAY=25
DURATION=3600

# Each window printed what it gave and took ("<who> traded <uid> <species> for <uid> <species>");
# the saved campaign agrees: both kept their uids, the MACHOKE is p2's MACHAMP, no uid is held twice.
verify() {
	local campaign="$user/coop_campaigns/$GAME/$GAME.json"
	local -a p1 p2
	read -r -a p1 <<< "$(grep -o 'p1 traded .*' "$out/p1.log" | head -1)"
	read -r -a p2 <<< "$(grep -o 'p2 traded .*' "$out/p2.log" | head -1)"
	jq -c '.players[] | {player_id, team: [.team[] | [.uid, .mon.species]], box: [.box[] | .uid]}' "$campaign"
	[[ ${#p1[@]} -eq 7 && ${#p2[@]} -eq 7 && "${p1[2]}" == "${p2[5]}" && "${p1[5]}" == "${p2[2]}" ]] || return 1
	jq -e --arg given "${p1[2]}" --arg taken "${p1[5]}" --argjson kept "${p1[6]}" '
		def team($id): [.players[] | select(.player_id == $id) | .team[]];
		def species($rows; $uid): [$rows[] | select(.uid == $uid) | .mon.species] | first // 0;
		[.players[] | (.team + .box)[] | .uid] as $held
		| species(team("p2"); $given) == 68 and species(team("p1"); $taken) == $kept
		and species(team("p1"); $given) == 0 and species(team("p2"); $taken) == 0
		and ($held | length) == ($held | unique | length)
	' "$campaign" > /dev/null
}
