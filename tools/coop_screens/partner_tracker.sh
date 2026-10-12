# Two windows in Pallet Town: RED steps into their house, out again and north towards Route 1 while BLUE walks east;
# each window's arrow points at the other (over a door, or on the screen's edge), and START > CO-OP's TOWN MAP
# shows the partner's icon in their colour. BLUE follows to Pallet Town's north edge and sees RED on Route 1.
DURATION=40
P2_DELAY=2
press p1 4 U
shot p1 7 p1_inside_door_mark
shot p2 7 p2_door_mark
press p2 8 R R R R R R
shot p2 10.5 p2_edge_mark
shot p2 11.2 p2_edge_mark2
shot p2 12 p2_edge_mark3
press p1 11 D
press p1 13 R R R R R U U U U U U U U U
shot p1 18.5 p1_on_the_way
shot p2 18.5 p2_partner_north
press p2 13 L L L L L L L L U U U U U
shot p2 17 p2_partner_across_the_edge
shot p2 17.6 p2_partner_across_the_edge2
press p1 20 SELECT @TOWN.MAP
press p2 20 SELECT @TOWN.MAP
shot p1 23 p1_town_map
shot p2 23 p2_town_map
press p1 25 B
press p2 25 B
check() { ! grep -q "SCRIPT ERROR" "$out"/p1.log "$out"/p2.log; }
