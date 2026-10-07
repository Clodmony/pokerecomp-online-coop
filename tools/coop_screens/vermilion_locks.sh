# BLUE walks out into Vermilion City while RED searches the gym's trash cans, and the first switch
# stays in its can: RED finds it where it was before BLUE arrived (#85; test case W15).
# SEED is a campaign saved after LT. SURGE's badge (playthrough_surge's end). The scenario edits a
# copy beside the out dir into the search: no THUNDERBADGE, locks, TM24 or LT. SURGE win, the first
# switch in can 4 (column 2, middle row), RED below the closed door facing can 5 under it, BLUE in
# Vermilion's POKéMON CENTER above the mat.
: "${SEED:?vermilion_locks needs SEED=<a campaign saved after LT. SURGE>}"
mkdir -p "$out.seed/coop_campaigns/red"
cp "$SEED/coop_identity.json" "$out.seed/"
jq '.campaign.badges -= (if (.campaign.badges / 4 | floor) % 2 == 1 then 4 else 0 end)
	| .campaign.flags -= [352, 353, 358, 359] | .campaign.defeated -= ["trainer:36:0"]
	| .campaign.world.gen1_bytes = {"first_lock_trash_can": 4}
	| .players |= map(if .player_id == "p1" then .map = [0, 92] | .cell = [3, 10] | .facing = 0
		else .map = [0, 89] | .cell = [3, 6] | .facing = 0 end)' \
	"$SEED/coop_campaigns/red/red.json" > "$out.seed/coop_campaigns/red/red.json"
SEED="$out.seed"
DURATION=30
press p1 1.8 A                        # can 5: only trash
shot p1 2.6 red_only_trash
press p1 3.6 A
press p2 1.8 D D D                    # out of the POKéMON CENTER: the city rolls its first lock
shot p2 5 blue_in_vermilion
press p1 14 U A                       # can 4, where the switch was before BLUE came
shot p1 16 red_first_switch
for at in 17.4 19 20.6 23.2 24.8; do press p1 "$at" B; done   # B reads on and never searches again
shot p1 20.2 red_turn_it_on
shot p1 22.8 red_first_lock_open
shot p2 22 blue_still_in_vermilion

check() {
	local user="$out/xdg/godot/app_userdata/pokerecomp" saved last lock opened blue entered sent kept
	saved="$user/coop_campaigns/red/red.json"
	last="$(tail -n 1 "$saved.journal" 2>/dev/null || cat "$saved")"   # a checkpoint removes the journal
	lock="$(jq '.campaign.world.gen1_bytes.first_lock_trash_can' <<< "${last:-null}")"
	opened="$(jq '.campaign.flags | index(353) != null' <<< "${last:-null}")"
	blue="$(grep -h '"player":"p2","kind":"in"' "$user"/coop_logs/*_host_HOST.jsonl | grep -v '"relay"')"
	entered="$(grep -c '"type":"move","map":\[0,5\]' <<< "$blue")"
	sent="$(grep -c 'first_lock_trash_can' <<< "$blue")"
	kept="$(grep -h '"kind":"locks_kept"' "$user"/coop_logs/*_join_P2.jsonl | grep -o '"data":{[^}]*}' | cut -d: -f2- | head -n 1)"
	echo "coop_screens: BLUE's steps in Vermilion City ${entered}, first locks BLUE sent ${sent}; kept over a roll: ${kept:-none}"
	echo "coop_screens: the campaign's first lock ${lock}; RED opened the first lock: ${opened}"
	[[ "$entered" -gt 0 && "$sent" == 0 && "$lock" == 4 && "$opened" == true ]]
}
