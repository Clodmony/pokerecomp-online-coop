# A co-op bag holds forty rows (D109), on a seed at Pewter's south gate (BLUE's bag twenty different items, the PC
# its POTION): BLUE withdraws the POTION, which the cartridge would refuse, then scrolls the bag to its twenty-first row.
SEED_ARGS="red viridian_forest $(printf 'item=%s ' POKEBALL GREATBALL ULTRABALL ANTIDOTE BURNHEAL ICEHEAL AWAKENING \
	PARLYZHEAL FULLRESTORE MAXPOTION HYPERPOTION SUPERPOTION ESCAPEROPE REPEL FIRESTONE THUNDERSTONE WATERSTONE HPUP PROTEIN IRON)"
HOST_ARGS=bare
DURATION=100
press p2 4 U - U - U - U - U - U - U - U       # german_screens' walk to the POKéMON CENTER's PC
press p2 9 L - L - L - L - L - L
press p2 13 U - U - U - U - U - U
press p2 18 U - U - U - U - U - R - R - R - R - R - R - R - R - R - R - R - R - D - R - U
shot p2 32 pc_front
press p2 33 A
press p2 36 A
shot p2 38 pc_menu
press p2 39 D A                       # RED's own PC
shot p2 41.5 players_pc_text
press p2 42 A
shot p2 45 players_pc
press p2 46 A                         # WITHDRAW ITEM
shot p2 48.5 withdraw_list
press p2 49 A
shot p2 51.5 how_many
press p2 52 A
press p2 55 A                         # the count box takes the second press
shot p2 57.5 withdrew
press p2 58.5 B                       # out: the line, the list, the item menu, the PC menu
press p2 60.5 B
press p2 62.5 B
press p2 64.5 B
press p2 67 START D D A
shot p2 69.5 bag_top
press p2 70 D D D D D D D D D D D D D D D D D D D D
shot p2 78 bag_bottom
press p2 78.5 D
shot p2 80 bag_cancel
press p2 80.5 B B B
press p2 83 START D D A               # SAVE, two rows below ITEM: the host writes the campaign
shot p2 86 save_question
press p2 86.5 A
shot p2 92 saved
check() {
	! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log \
		&& [[ "$(tr -d ' \n\t' < "$user/coop_campaigns/red/red.json" | grep -o '\[20,1\]' | wc -l)" -ge 1 ]] \
		&& tr -d ' \n\t' < "$user/coop_campaigns/red/red.json" | grep -q '"pc_items":{}'
}
