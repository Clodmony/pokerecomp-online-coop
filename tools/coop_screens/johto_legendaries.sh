# Johto's one-off Pokémon are each player's (#180, D138, test cases J72 to J76): a seed stands GOLD below Route 36's
# weird tree and SILVER at Violet City's west edge, both with a SQUIRTBOTTLE and a level 60 starter. GOLD waters the
# tree and beats SUDOWOODO in a battle on the host; the tree is gone from GOLD's Route 36. SILVER then walks into
# Route 36, which loads its objects from SILVER's world: the tree still stands there, drawn as SUDOWOODO, and asks
# SILVER for the SQUIRTBOTTLE.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=10:3:35,10 at2=10:5:2,9 level=60 item=SQUIRTBOTTLE:1"
HOST_ARGS="bare seed=26"             # the host's rolls fixed, so the battle ends at the same moment every run
DURATION=94
shot p1 3 gold_tree                   # the weird tree above GOLD
press p1 4 U A - - A - - A - - A - - A - - A - - A - - A - - A - - A - - A - - A   # face the tree, YES to the SQUIRTBOTTLE, its lines
shot p1 6 gold_squirtbottle
for at in $(seq 20 2 56); do press p1 "$at" "@^FIGHT.+BODY"; done   # a press walks one menu level
shot p1 24 gold_battle
shot p1 62 gold_tree_gone             # GOLD's path north is open
press p2 63 L L L L L L L L L L L L L L L L L L L L L U L L L L L L L L D L L L L L L L   # each leg pressed past its wall: up to the fisher, round him, to the tree
shot p2 77 silver_tree_stands         # SUDOWOODO blocks SILVER's Route 36
shot p1 77 gold_sees_silver
press p2 78 A
shot p2 81 silver_squirtbottle        # SILVER's own tree asks for the SQUIRTBOTTLE
press p2 83 B B
check() {
	local campaign="$user/coop_campaigns/$GAME/$GAME.json"
	jq -e '.campaign.flags | map(tostring) | index("1784") == null' "$campaign" > /dev/null || return 1
	jq -e '[.players[] | .world.event_flags // {} | has("1784")] == [true, false]' "$campaign" > /dev/null
}
