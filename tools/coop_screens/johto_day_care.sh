# Gold and Silver's day care (#178, test cases G50 to G54): a seed stands GOLD and SILVER in Route 34's pen. GOLD's
# day care holds DITTO and CYNDAQUIL with their egg waiting, SILVER's man a SENTRET. GOLD's window shows GOLD's man
# outside and both of GOLD's in the pen, SILVER's only SENTRET; GOLD takes the egg, and one step hatches it in GOLD's
# party, while SILVER goes in by the back door and finds SILVER's man indoors, raising SENTRET.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=11:1:15,17:13,16 care=p1:DITTO:20:CYNDAQUIL:18:egg care=p2:SENTRET:12"
HOST_ARGS=bare
DURATION=78
shot p1 3 gold_pen                    # GOLD's man by the fence, DITTO and CYNDAQUIL in the pen
shot p2 3 silver_pen                  # no man outside, SENTRET alone in the pen, GOLD by the fence
press p1 5 U U A
shot p1 7.5 gold_man_asks             # "Ah, it's you!"
press p1 8 A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A - - - - A
shot p1 14 gold_had_an_egg            # "Your POKéMON had an EGG!"
shot p1 22 gold_wants_it              # "You want it?" YES
shot p1 26 gold_received_egg          # "GOLD received the EGG!"
shot p1 34 gold_man_walks_in          # GOLD's man has gone back indoors, the egg handed over
press p1 35 D - D
shot p1 37 gold_huh                   # one step south: "Huh?"
press p1 38 B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B - - - B
shot p1 43 gold_hatching
shot p1 49 gold_hatched               # CYNDAQUIL came out of its EGG
shot p1 58 gold_no_nickname           # back on Route 34, "CYNDAQUIL hatched"
press p1 66 START
shot p1 67.5 gold_start_menu
press p1 68 A
shot p1 70 gold_party                 # CHIKORITA and the hatched CYNDAQUIL, no EGG left
press p2 5 U U
shot p2 8 silver_day_care             # indoors: SILVER's man and the lady
press p2 9 U U U U A
shot p2 12 silver_man_talks           # "Huh? Back already? Your SENTRET"
press p2 13 A - - - - - A - - - - - A - - - - - - A
shot p2 15 silver_man_more            # "needs a little more time with us."
shot p2 23 silver_asks_back           # SILVER's own price to take SENTRET back, YES or NO
press p2 24 B - - - - A - - - - A - - - - A
shot p2 26 silver_keeps_it            # NO: "Come again."
# The host's last autosave: GOLD's egg handed over to GOLD (still an EGG, or CYNDAQUIL), SILVER's SENTRET still with
# SILVER's man, and none of the pen's four flags in the campaign.
check() {
	grep -q 'reloaded campaign .*players \["p1", "p2"\]' "$out/host.log" \
		&& python3 -I - "$out/xdg/godot/app_userdata/pokerecomp/coop_campaigns/gold/gold.json" <<'PY'
import json, sys
saved = json.load(open(sys.argv[1]))
players = {player["player_id"]: player for player in saved["players"]}
def care(player): return [mon.get("species") for mon in player["world"].get("day_care_mons", [])]
def team(player): return [row["mon"]["species"] for row in player["team"]]
gold, silver = players["p1"], players["p2"]
assert care(gold) == [132, 155] and int(gold["world"]["day_care_man"]) & 0x40 == 0 and team(gold)[1:] == [155], (care(gold), team(gold))
assert care(silver) == [161, None] and len(team(silver)) == 1, (care(silver), team(silver))
assert not {str(flag) for flag in saved["campaign"].get("flags", [])} & {"1765", "1766", "1767", "1768"}, saved["campaign"].get("flags")
PY
}
