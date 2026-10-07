# The first Route 22 rival scene (#24, D72): RED walks into it, BLUE arrives from Viridian City
# during it and waits under a line naming RED, joins the rival battle with SELECT, and walks on
# once RED's scene is over, the rival gone. rival_scene_killed.sh (KILL=1) closes RED's window
# in the scene instead: BLUE walks on at once, the campaign keeps the rival waiting, and RED's
# window opened again meets him from the start.
# The seed is tools/coop_seed.gd's campaign after the POKéDEX with level 20 parties, edited to put
# RED two steps east of the trigger and BLUE on Viridian City's west edge, both facing west.
seed_xdg="$out.seed/xdg"
mkdir -p "$seed_xdg/godot/app_userdata/pokerecomp/rom_cache"
ln -sfn "$(find "$real_user/rom_cache" -maxdepth 1 -name "${GAME}_????????" -print -quit)" \
	"$seed_xdg/godot/app_userdata/pokerecomp/rom_cache/"
XDG_DATA_HOME="$seed_xdg" "$godot" --headless --path "$root" -s res://tools/coop_seed.gd -- \
	"$GAME" pokedex "$out.seed/story" level=20 > "$out.seed.log" 2>&1
mkdir -p "$out.seed/coop_campaigns/$GAME"
cp "$out.seed/story/coop_identity.json" "$out.seed/"
jq '.players |= map(if .player_id == "p1" then .map = [0, 33] | .cell = [31, 5] | .facing = 2
	else .map = [0, 1] | .cell = [1, 15] | .facing = 2 end)' \
	"$out.seed/story/coop_campaigns/$GAME/$GAME.json" > "$out.seed/coop_campaigns/$GAME/$GAME.json"
SEED="$out.seed"
HOST_ARGS=bare
P2_DELAY=4
DURATION=150

press p1 1.8 L L                      # onto (29, 5): the rival sees RED
shot p1 4 red_rival_comes
press p2 1.8 L L                      # into Route 22 while RED's scene runs
shot p2 4.5 blue_waits
press p2 5.4 L L D                    # held: BLUE does not move
shot p2 7 blue_still_waits
if [[ "${KILL:-0}" == 1 ]]; then
	DURATION=50                       # the host's autosave keeps where RED stood
	close p1 12
	shot p2 16 blue_let_go
	press p2 17 L L L L
	shot p2 20 blue_walks_on
else
	for at in $(LC_ALL=C seq 6 0.6 120); do press p1 "$at" A; done
	shot p1 9 red_rival_talks
	for at in 9 13 17; do press p2 "$at" SELECT @JOIN B; done
	shot p2 20 blue_in_battle
	shot p1 30 red_battle
	for at in $(LC_ALL=C seq 22 1.2 95); do press p2 "$at" A; done
	shot p2 60 blue_battle_won
	shot p1 70 red_after_battle
	shot p2 75 blue_after_battle
	shot p1 90 red_rival_gone
	shot p2 92 blue_free
	press p2 100 L L L L
	shot p2 104 blue_walks_on
	shot p1 110 red_end
fi

# The host's scene claims and BLUE's waits; BLUE's window took the result and never stepped Route 22's
# script (wRoute22CurScript, byte 26) itself; the campaign's rival flags (1317 beaten, 1319 waiting).
check() {
	local saved="$user/coop_campaigns/$GAME/$GAME.json" last claims waits blue_pulls blue_sent
	last="$(tail -n 1 "$saved.journal" 2>/dev/null || cat "$saved")"
	claims="$(grep -h '"kind":"in"' "$user"/coop_logs/*_host_HOST.jsonl | grep -v '"relay"' | grep '"type":"scene"' \
		| jq -c '{player, on: .data.message.on, map: .data.message.map, result: .data.result}' || true)"
	waits="$(grep -h '"kind":"scene_wait"' "$user"/coop_logs/*_join_P2.jsonl | jq -c '.data' || true)"
	blue_pulls="$(grep -h '"kind":"world_pull"' "$user"/coop_logs/*_join_P2.jsonl | grep -c '"1317":true' || true)"
	blue_sent="$(grep -h '"player":"p2","kind":"in"' "$user"/coop_logs/*_host_HOST.jsonl | grep '"type":"world"' \
		| grep -c '"gen1_map_scripts":{[^}]*"26"' || true)"
	echo "coop_screens: scene claims: ${claims//$'\n'/ }"
	echo "coop_screens: BLUE's waits: ${waits//$'\n'/ }; pulls with the rival beaten ${blue_pulls}; script steps sent ${blue_sent}"
	jq -c '{beat_rival: (.campaign.flags | index(1317) != null), rival_waits: (.campaign.flags | index(1319) != null),
		rival_shown: (.campaign.world.toggled_objects["34"] // false), p1: (.players[] | select(.player_id == "p1") | {map, cell})}' <<< "$last"
	[[ "$claims" == *'"on":true'* && "$waits" == *'"driver":"p1"'* && "$waits" == *'"driver":""'* && "$blue_sent" == 0 ]] || return 1
	if [[ "${KILL:-0}" != 1 ]]; then
		[[ "$claims" == *'"on":false'* && "$blue_pulls" -gt 0 ]] || return 1
		jq -e '(.campaign.flags | index(1317) != null) and (.campaign.flags | index(1319) == null)' <<< "$last" > /dev/null
		return
	fi
	jq -e '(.campaign.flags | index(1319) != null) and (.campaign.flags | index(1317) == null)
		and ([.players[] | select(.player_id == "p1") | .cell] == [[29, 5]])' <<< "$last" > /dev/null || return 1
	# RED's window opened again on the trigger: the rival comes for RED from the start.
	local again=$(( port + 1 )) pids=() hosts
	XDG_DATA_HOME="$xdg" "$godot" --headless --path . -s "res://tools/$HOST_TOOL.gd" -- host "$again" "$GAME" $HOST_ARGS \
		> "$out/host_again.log" 2>&1 &
	pids+=($!)
	for _ in $(seq 60); do grep -q "host on port" "$out/host_again.log" && break; sleep 0.5; done
	XDG_DATA_HOME="$xdg" "$godot" --max-fps "$fps" --path . -s res://tools/coop_play.gd -- 127.0.0.1 "$again" p1 "$GAME" \
		capture="$out/red_again.png@360" capture="$out/red_again_talks.png@600" > "$out/p1_again.log" 2>&1 &
	pids+=($!)
	sleep 25
	kill "${pids[@]}" 2> /dev/null || true
	sleep 1
	hosts="$(ls -t "$user"/coop_logs/*_host_HOST.jsonl | head -n 1)"
	claims="$(grep '"kind":"in"' "$hosts" | grep -v '"relay"' | grep -c '"type":"scene","map":\[0,33\],"on":true' || true)"
	echo "coop_screens: RED's window opened again claimed the scene ${claims} time(s)"
	[[ "$claims" -gt 0 ]]
}
