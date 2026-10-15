# Gold's opening for both players (#173, D131, test cases J10 to J12): a Gold window picks CYNDAQUIL and a Silver window
# TOTODILE, each plays its own errand to Mr. Pokémon, its own rival theft and fight in Cherrygrove and the officer, hands
# the egg to Elm, leaves the lab and meets the other in New Bark Town. Only the first window is asked the rival's name.
GAME=gold
P2_GAME=silver
HOST_ARGS=bare
P1_TOOL=coop_autoplay
P2_TOOL=coop_autoplay
P1_ARGS="opening speed=4 ball=0 shots=$out"
P2_ARGS="opening speed=4 ball=1 shots=$out"
P2_DELAY=25
DURATION=3000
check() {
	grep -q "autoplay: p1 finished" "$out/p1.log" && grep -q "autoplay: p2 finished" "$out/p2.log" \
		&& grep -q "leg opening_over" "$out/p1.log" && grep -q "leg opening_over" "$out/p2.log" \
		&& grep -q "out TOTODILE" "$out/p1_texts.tsv" && grep -q "out CHIKORITA" "$out/p2_texts.tsv" \
		&& grep -qh '"kind":"officer"' "$out"/xdg/godot/app_userdata/pokerecomp/coop_logs/*_join_P2.jsonl
}
