# The Bug-Catching Contest for two (#179, D140, test cases J82 to J86): a seed stands GOLD (CHIKORITA and SENTRET) and
# SILVER (CYNDAQUIL) by the officer in the Route 35 gate on a TUESDAY morning, a contest day. Both enter the same
# contest: the officer keeps GOLD's SENTRET and asks SILVER nothing about a party of one. In the park each sees the other;
# GOLD walks out first and is judged against GOLD's own contestants while SILVER's contest runs on, then SILVER is judged
# against SILVER's. Neither caught a bug, so each gets a BERRY, and GOLD gets SENTRET back under its own uid. B stands in
# for A once the questions are answered, so a press never opens the partner's co-op menu in the park.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=10:15:2,2:3,1 mon=p1:SENTRET:4 clock=10:00:2"
HOST_ARGS=bare
DURATION=190
k() { local out="" n; for (( n = 0; n < $2; n++ )); do out+=" $1 -"; done; echo $out; }
press p1 4 U $(k A 40) $(k B 30)
press p1 70 D
press p1 71.5 $(k A 12) $(k B 75)
press p2 4 L $(k A 28) $(k B 30)
press p2 44 L
press p2 45 U U U
press p2 90 D D D D D D
press p2 93 R
press p2 94 D
press p2 95.5 $(k A 12) $(k B 75)
shot p1 3 gold_gate                   # the contest-day officer behind his counter, SILVER beside GOLD
shot p1 14 gold_more_than_one         # "You have more than one POKéMON."
shot p1 24 gold_party_left            # "GOLD's POKéMON were left with the CONTEST HELPER."
shot p1 56 gold_park_silver           # the park's gate: GOLD, and SILVER up the path in the same contest
shot p1 72 gold_minutes_left          # GOLD walks out: "You still have 20 minute(s) left."
shot p1 86 gold_judged                # GOLD's own third place and score
shot p1 102 gold_consolation          # "Everyone else gets a BERRY as a consolation prize!"
shot p1 118 gold_party_back           # "We'll return the POKéMON we kept for you."
shot p1 124 gold_route_36_gate        # done, in the Route 36 gate
shot p2 3 silver_gate                 # SILVER by the officer, GOLD below him
shot p2 12 silver_asks                # "Would you like to give it a try?" and no party question for one POKéMON
shot p2 50 silver_park_gold           # SILVER up the path, GOLD at the park's gate
shot p2 80 silver_contest_runs_on     # GOLD has left (the partner arrow), SILVER's contest goes on
shot p2 110 silver_judged             # SILVER's own third place, another POKéMON and score than GOLD's
shot p2 126 silver_winner             # the winner of SILVER's contest
shot p2 142 silver_better_next_time   # SILVER's BERRY given: "We hope you do better next time."
shot p2 148 silver_route_36_gate
# A text capture can land a box early or late on a loaded machine. The check reads the seed's TUESDAY on the first
# capture, then the host's last autosave: both judged and done for the day (ENGINE_DAILY_BUG_CONTEST, no timer), a
# BERRY each, GOLD's SENTRET back in GOLD's team under its own uid, nothing left with the officer, and no contest flag
# in the campaign.
check() {
	grep -q 'reloaded campaign .*players \["p1", "p2"\]' "$out/host.log" && grep -q "gold_gate.png OK at TUESDAY 10:0" "$out/p1.log" \
		&& python3 -I - "$out/xdg/godot/app_userdata/pokerecomp/coop_campaigns/gold/gold.json" <<'PY'
import json, sys
saved = json.load(open(sys.argv[1]))
players = {player["player_id"]: player for player in saved["players"]}
contest = {722, 776, 787, 788, 789, 790, 1844, 1861, 1862, 1863, 1864, *range(1814, 1834)}
for pid, team in (("p1", [["p1:1", 152], ["p1:2", 161]]), ("p2", [["p2:1", 155]])):
    player = players[pid]
    assert [[row["uid"], row["mon"]["species"]] for row in player["team"]] == team and not player.get("contest_kept"), (pid, player["team"])
    assert [173, 1] in player["items"], (pid, player["items"])
    engine = {int(flag) for flag in player["world"].get("engine_flags", {})}
    assert 80 in engine and 16 not in engine, (pid, sorted(engine))
assert not {int(flag) for flag in saved["campaign"].get("flags", [])} & contest, saved["campaign"].get("flags")
PY
}
