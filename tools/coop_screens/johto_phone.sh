# Each Gold and Silver player's own POKéGEAR (#177, test cases J77 and J81): a seed gives GOLD JOEY's number and
# SILVER none. In New Bark Town GOLD's phone card lists MOM, ELM and JOEY and GOLD calls JOEY; SILVER's lists MOM and
# ELM only, so JOEY can ring GOLD's window and never SILVER's.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new phone=p1:15"
HOST_ARGS=bare
DURATION=40
shot p1 4 gold_town
press p1 5 START
shot p1 6.5 gold_start_menu
press p1 7 D - D - D
shot p1 8.5 gold_on_pokegear
press p1 9 A
shot p1 11 gold_pokegear
press p1 11.5 R
shot p1 13 gold_phone_card             # MOM, ELM and JOEY
press p1 13.5 D
shot p1 15 gold_on_joey
press p1 15.5 A
shot p1 17 gold_call_menu              # CALL, DELETE, CANCEL
press p1 17.5 A
shot p1 19.5 gold_calling              # "Hello. This is JOEY..."
press p1 21 A
shot p1 22.5 gold_call_2               # "How's it going, GOLD?"
press p1 23 A
shot p1 24.5 gold_call_3
press p1 25 A
shot p1 26.5 gold_call_4
press p1 27 A
shot p1 28.5 gold_call_5
press p2 5 START
press p2 7 D - D - D
shot p2 8.5 silver_on_pokegear
press p2 9 A
press p2 11.5 R
shot p2 13 silver_phone_card           # MOM and ELM only
press p2 13.5 D
shot p2 15 silver_no_joey              # past ELM there is nobody to call
# The host's last autosave: JOEY's number in GOLD's POKéGEAR only, and no phone flag in the campaign.
check() {
	grep -q 'reloaded campaign .*players \["p1", "p2"\]' "$out/host.log" \
		&& python3 -I - "$out/xdg/godot/app_userdata/pokerecomp/coop_campaigns/gold/gold.json" <<'PY'
import json, sys
saved = json.load(open(sys.argv[1]))
players = {player["player_id"]: player for player in saved["players"]}
def phone(player): return sorted(int(contact) for contact in player["world"].get("phone_contacts", {}))
assert phone(players["p1"]) == [1, 4, 15] and phone(players["p2"]) == [1, 4], (phone(players["p1"]), phone(players["p2"]))
assert not {int(flag) for flag in saved["campaign"].get("flags", [])} & set(range(607, 671)), saved["campaign"].get("flags")
PY
}
