# The host's clock for every window (#175, D133, test cases G30 to G32): GOLD hosts a new Gold campaign from the launcher
# with its clock set to FRIDAY 9:30 PM (`clock=21:30:5`, whatever the machine's own time), SILVER joins on a Silver
# cartridge; both windows draw New Bark Town at night, and each capture line names the window's own weekday and time.
GAME=gold
P2_GAME=silver
HOST_TOOL=none
P1_TOOL=coop_launcher_play
P2_TOOL=coop_launcher_play
P1_ARGS="host name=GOLD starter=1 round=60:NIGHT clock=21:30:5"
P2_ARGS="join name=SILVER starter=2 round=60"
DURATION=34
shot p1 12 gold_night                 # New Bark Town in the night palette, SILVER beside GOLD at the house's door
shot p2 12 silver_night               # the same night from SILVER's window
press p2 13 D D D                     # on SILVER's clock, about four seconds behind GOLD's
shot p1 22 gold_night_later           # still night ten seconds on, SILVER a few steps south
shot p2 22 silver_night_later
check() {
	local night="at FRIDAY 9:3[0-9] PM NITE"
	grep -q "gold_night.png OK $night" "$out/p1.log" && grep -q "silver_night.png OK $night" "$out/p2.log" \
		&& grep -q "gold_night_later.png OK $night" "$out/p1.log" && grep -q "silver_night_later.png OK $night" "$out/p2.log"
}
