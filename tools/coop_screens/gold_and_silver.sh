# Gold and Silver on the Co-op tab (#172, test cases G01 to G03): GOLD hosts a new Gold campaign from the launcher
# with CYNDAQUIL, SILVER finds it nearby on a Silver cartridge and joins with TOTODILE; both stand in New Bark Town
# by the house and see each other, and the CO-OP menu says where the partner is. Seconds count from each launch.
GAME=gold
P2_GAME=silver
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=coop_launcher_play
P1_ARGS="host name=GOLD starter=1 round=60:JOHTO"
P2_ARGS="join name=SILVER starter=2 round=60"
DURATION=30
shot p1 1.2 gold_coop_tab             # the Co-op tab lists Gold among the cartridges
shot p1 2.8 gold_filled               # New campaign: no rival; Start in New Bark Town with CYNDAQUIL
shot p2 1.2 silver_coop_tab           # "1 game found nearby"
shot p2 2.6 silver_filled             # New in JOHTO: SILVER, starting in New Bark Town with TOTODILE
shot p1 12 gold_world                 # New Bark Town, SILVER beside GOLD at the house's door
shot p2 12 silver_world               # the same from SILVER's window
press p1 14 SELECT
shot p1 14.6 gold_menu                # "SILVER" in NEW BARK TOWN
press p1 16 B
press p2 13 D D D                     # on SILVER's clock, about four seconds behind GOLD's
shot p1 20 gold_sees_silver_walk      # SILVER walks south (the neighbour may stop it)
check() {
	grep -q "in JOHTO .* GOLD, .*team CYNDAQUIL:5, .* on WorldScreen" "$out/p1.log" \
		&& grep -q "in JOHTO .* SILVER, .*team TOTODILE:5, .* on WorldScreen" "$out/p2.log"
}
