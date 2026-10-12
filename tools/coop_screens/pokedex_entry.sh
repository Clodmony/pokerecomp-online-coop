# Two windows on a seed past Oak's POKéDEX (SEED=<coop_seed.gd out dir, leg pokedex or later>): each opens an entry's DATA page,
# #004 in both (the seed's starter); on a German cartridge height and weight read in m and kg (test case G04).
: "${SEED:?pokedex_entry needs SEED=<an out dir of tools/coop_seed.gd>}"
HOST_ARGS=bare
DURATION=30
press p1 4 START A
press p2 4 START A
shot p1 7 p1_dex_list
shot p2 7 p2_dex_list
press p1 8 D D D A
press p2 8 D D D A
shot p1 11.5 p1_dex_menu
shot p2 12.5 p2_dex_menu
press p1 13 A
press p2 14 A
shot p1 17 p1_dex_data
shot p2 18 p2_dex_data
