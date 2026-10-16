# Johto's one-off Pokémon are each player's (#180, D138, test cases J72 to J76): a seed stands GOLD below Route 36's
# weird tree and SILVER at Violet City's west edge, both with a SQUIRTBOTTLE and a level 60 starter. GOLD waters the
# tree and beats SUDOWOODO in a battle on the host; the tree is gone from GOLD's Route 36. SILVER then walks into
# Route 36, which loads its objects from SILVER's world: the tree still stands there, drawn as SUDOWOODO, and asks
# SILVER for the SQUIRTBOTTLE.
GAME=gold
P2_GAME=silver
SEED_ARGS="gold new at=10:3:35,10 at2=10:5:2,9 level=60 item=SQUIRTBOTTLE:1"
HOST_ARGS=bare
DURATION=75
shot p1 3 gold_tree                   # the weird tree above GOLD
press p1 4 U A - - A - - A - - A - - A - - A - - A - - A - - A - - A - - A - - A   # face the tree, YES to the SQUIRTBOTTLE, its lines
shot p1 6 gold_squirtbottle
for at in $(seq 20 3 41); do press p1 "$at" "@^FIGHT.+BODY"; done
shot p1 24 gold_battle
shot p1 46 gold_tree_gone             # GOLD's path north is open
press p2 48 L L L L L L L L L L L L L L L L L U L L D L L L L L L L   # west into Route 36, round the fisher, to the tree
shot p2 59 silver_tree_stands         # SUDOWOODO blocks SILVER's Route 36
shot p1 59 gold_sees_silver
press p2 60 A
shot p2 63 silver_squirtbottle        # SILVER's own tree asks for the SQUIRTBOTTLE
press p2 65 B B
check() {
	local campaign="$user/coop_campaigns/$GAME/$GAME.json"
	jq -e '.campaign.flags | map(tostring) | index("1784") == null' "$campaign" > /dev/null || return 1
	jq -e '[.players[] | .world.event_flags // {} | has("1784")] == [true, false]' "$campaign" > /dev/null
}
