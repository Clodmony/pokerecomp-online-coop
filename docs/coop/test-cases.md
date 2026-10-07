# Co-op test cases

What to try by hand on real devices, one case per row, and what already
covers it automatically. Every new feature adds its cases here in the same
pull request, and a scenario under `tools/coop_screens/` when it shows on
screen (`GODOT=<4.8-dev4> tools/coop_screens.sh <scenario>`, captures outside
the repository). The **Hand** column stays empty until the owner has played
the case; record the date and devices there.

Two players unless a case says otherwise; each device has its own imported
Red (or Blue) cartridge, the same one.

## Sessions

| ID | Case | Expected | Automated | Two windows | Hand |
|---|---|---|---|---|---|
| S01 | Host a new campaign on the Co-op tab; join from the other device by the listed address | Both worlds open, each with the chosen starter, in Pallet Town; the host hears "<NAME> joined the session." | `test_coop_device`: hosts and joins with their own starters | every scenario (tool host), launcher_host_join, launcher_leave_rehost | |
| S02 | Join with a different cartridge | Refused with a reason the Co-op tab explains | `test_a_client_with_another_cartridge_is_told_why_and_let_go` | | |
| S03 | Start a second campaign on the host device, then pick the first again | Each keeps its own trainers; the device is remembered per campaign | `test_each_campaign_keeps_its_own_trainers...` | launcher_leave_rehost | |
| S04 | A new player brings a single-player save; the first player of a new campaign brings one | Their team, PC, bag and money come along; the first player's story becomes the campaign's | `test_a_campaign_hosted_from_a_save_takes_its_story_and_its_trainer` | | |
| S05 | A new player plays the opening (Oak's speech, bedroom, lab, rival) | Hidden from the others until the lab is left with a starter; the rival's name and starter are kept for the campaign | `test_a_player_who_plays_the_opening_has_a_story_of_their_own...` | playthrough_brock, launcher_host_join | |
| S06 | A new player skips the opening | A level 5 starter of their choice, 3000 money, Pallet Town | `test_a_player_who_skips_the_opening_is_given_their_starter_in_pallet_town` | launcher_leave_rehost | |
| S07 | SAVE from START on either device | "Saved" in both; refused with "Save failed" while any battle runs | `test_a_save_from_either_menu_is_confirmed_to_everyone`, `test_coop_save_refusal` | save_from_start_menu | |
| S08 | Close both apps and host the campaign again | Every player, the story and the PC come back as saved | `test_a_save_waits_for_a_safe_checkpoint_and_reloads_everyone` | | |
| S09 | Pull the joiner's network for a minute | "Lost the host: reconnecting...", then "Back in the session." | `test_a_device_whose_link_drops_comes_back_on_its_own` | | |
| S10 | Send a phone app to the background and back | A host saves first; a joiner redials at once | `test_a_hosting_device_sent_to_the_background_keeps_the_campaign` | | |
| S11 | LEAVE SESSION on the joiner, then on the host | The joiner returns to the launcher's Co-op tab saying "You left the session."; the host ending sends everyone back there saying "The host closed the session." | `test_a_host_that_leaves_saves_the_campaign_and_tells_the_others` | launcher_leave_rehost | |
| S12 | Close the hosting window with the window's close button | The joiner hears "ended" at once instead of redialling | `test_closing_a_hosting_window_tells_the_joiner_before_the_app_quits` | | |
| S13 | Kill the hosting app (no goodbye) right after a trainer win while the partner is in another battle, then host again | The win, its badge, its prize and anything handed out with it are still there | `test_a_win_and_a_gift_while_another_battle_runs_survive_a_crash_of_the_host`, `test_story_journaled_after_the_last_checkpoint_survives...` | | |
| S14 | Open the Co-op tab with a pad or keyboard | Host is focused and in view; the name and address are the ones last used | `test_a_pad_entering_the_co_op_tab_sees_the_button_it_lands_on`, `test_the_co_op_tab_offers_the_name_and_address_this_device_last_joined_with` | launcher_host_join | |
| S15 | Host a campaign again while a player stands inside a building | That window opens inside it on the campaign's story and leaves by the building's own door; a coord script already done (the Cerulean thief) does not run again | `test_a_window_opened_again_inside_a_building_leaves_by_its_own_door`, `test_a_window_opens_its_world_on_the_campaigns_story_and_its_own_place` | | |
| S16 | Host a campaign `tools/coop_seed.gd` wrote at a later point of the story | Both players open where the story left them, side by side, each with the story's party, bag and money; the story's badges and flags apply | `test_a_story_seed_is_a_campaign_where_p1_and_p2_each_hold_their_own_copy_of_the_save` | story_seed (`SEED=<seed dir>`) | |

## Exploration and story

| ID | Case | Expected | Automated | Two windows | Hand |
|---|---|---|---|---|---|
| W01 | Walk together, then onto different maps | Each sees the other in their colour on a shared map only | `test_two_clients_each_move_their_own_player...` | every scenario | |
| W02 | Try to walk through the partner | Blocked like a person | `test_a_partner_on_the_map_blocks_the_way_like_a_person_does` | | |
| W03 | One player beats a gym leader | The badge and the leader's flags show in both worlds | `test_a_badge_won_in_a_battle_reaches_both_windows` | playthrough_brock | |
| W04 | One player picks up an item ball, is given an item, or loses a key item to the story | Every player gets the same item; a key item the story takes goes from all; bought items stay the buyer's | `test_an_item_found_along_the_story_reaches_every_player...`, `test_a_key_item_the_story_takes...` | playthrough_brock | |
| W05 | Both take EEVEE, LAPRAS, a HITMON and the MAGIKARP for sale | Each player can take each once | `test_each_player_is_given_their_own_eevee_and_dojo_pokemon` | | |
| W06 | Both pick up the same item ball at the same moment | Each player has it once | `test_a_gift_two_windows_hand_out_at_once_is_kept_once` | | |
| W07 | Use a Pokémon Center, a Mart and Bill's PC in each world | Each works on that player's own team, bag, money and PC | `test_a_heal_and_a_deposit...`, `test_a_window_opened_later_finds_its_pc_as_it_left_it` | | |
| W08 | The partner arrives, leaves or starts a battle | A line over the world says so, with "SELECT to join" | `test_a_player_hears_when_the_partner_arrives_leaves_or_starts_a_battle` | launcher_host_join | |
| W09 | Both walk into the same trainer | One battle both fight; once beaten the trainer stays beaten | `test_one_trainer_opened_in_two_windows_is_one_battle_both_fight` | playthrough_brock | |
| W10 | Both reach SNORLAX or a legendary | One battle; caught or beaten, it is gone for both | `test_red_and_blues_one_off_wild_pokemon_are_one_encounter_each` | | |
| W11 | A player who skipped the opening delivers OAK'S PARCEL | Oak is in the lab and takes it | `test_coop_session` (D58) | | |
| W12 | Both enter Vermilion Gym; one finds the first switch | Both windows search the same trash cans; each player's SURF score and slot machine stay their own | `test_vermilion_gyms_locks_are_shared_and_a_surf_score_is_its_players_own` | | |
| W13 | One player takes the DOME (or HELIX) FOSSIL in Mt. Moon | Both players hold one; each revives their own | `test_a_gift_given_before_its_scripts_flag_still_reaches_every_player` | playthrough_misty | |
| W14 | Walk Pokémon Tower without the SILPH SCOPE, then with it | Without it a GHOST appears in the window's own battle and can only be run from; with it MAROWAK is a normal fight the partner can join | `test_a_ghost_nobody_can_see_is_left_to_the_windows_own_battle` | | |
| W15 | One player is given the S.S. TICKET by Bill, TM28 by the Cerulean thief and HM01 by the S.S. Anne's CAPTAIN | Every player holds each one once | `test_an_item_found_along_the_story_reaches_every_player...` | playthrough_surge | |
| W16 | Both in Vermilion City; one stands on the dock's ticket check while the other walks the city (the same in Cerulean City) | Each window's city script follows its own player: the check shows once, the partner's walk does not reset it | `test_a_map_script_that_follows_one_players_walk_stays_in_their_window` | playthrough_surge | |
| W17 | Both in Vermilion Gym; one finds the second switch | The door to LT. SURGE opens in both windows at once | `test_a_partners_second_switch_opens_vermilion_gyms_door_in_this_window_too` | playthrough_surge | |
| W18 | Teach CUT, then use it from START > POKéMON on the tree outside Vermilion Gym | The tree is cut in that window and grows back at the next map load, as on the cartridge | | playthrough_surge | |
| W19 | One player searches Vermilion Gym's trash cans while the partner walks into Vermilion City (or out of the gym) | The switches stay in their cans: the searcher finds the first switch where it was; a wrong second can hides it anew for both; with nobody in the city or gym, the next arrival hides it afresh | `test_a_partner_entering_vermilion_city_leaves_the_switches_where_someone_searches`, `test_vermilion_city_rolls_a_new_first_lock_while_nobody_else_is_in_the_city_or_gym` | vermilion_locks | |
| W20 | One player beats a gym leader while the other stands in the gym | Each player holds one copy of the leader's TM; the bystander's window never plays the leader's lines | `test_brock_beaten_in_one_window_hands_each_player_one_tm34` | rest_points | |
| W21 | A scene with a trainer battle in it (the lab rival, BROCK) while the partner plays on | The partner's world changes only when the scene ends; the battle can still be joined live | `test_a_long_scene_with_a_battle_in_it_reaches_the_partner_only_when_it_ends`, `test_a_window_is_at_a_rest_point_only_where_the_cartridge_could_save` | rest_points, playthrough_misty | |
| W22 | LEAVE (or pull the network) in the middle of a scene that gives something, then come back | The scene plays again from its start and nothing is held twice | `test_a_scene_cut_off_by_leaving_leaves_the_host_on_the_last_resting_state`, `test_a_scenes_gift_pokemon_waits_for_its_end_unless_a_fight_in_it_needs_the_party` | | |
| W23 | Both players in Vermilion City; one shows the S.S. TICKET | Each passes the sailor once and nobody is sent back | `test_both_players_in_vermilion_city_each_pass_the_ticket_check_once` | playthrough_surge | |
| W24 | A partner moves the story of the map you stand on | It applies when you next enter that map, never under your feet | `test_a_partners_step_for_the_map_a_window_stands_on_lands_at_its_next_map_load` | | |
| W25 | The partner takes Mt. Moon's fossil while you are elsewhere on that floor | The fossils vanish from your map at once and the way out is open | `test_an_object_a_partner_hides_leaves_the_map_a_window_stands_on_at_once` | playthrough_misty | |
| W26 | Heal, buy or receive a gift in the middle of a scene; SAVE from START | A checkpoint is asked for; the gift sends nothing of the scene, the SAVE sends the scene so far | `test_the_worlds_save_in_a_scene_sends_the_scene_so_far_and_a_gifts_snapshot_does_not` | | |

## Battles

| ID | Case | Expected | Automated | Two windows | Hand |
|---|---|---|---|---|---|
| B01 | Meet a wild Pokémon in the grass; the partner joins with SELECT from another map | The battle is fought on the host; the joiner comes back where they were afterwards | `test_a_battle_the_world_opens_is_fought_on_the_host...` | leave_rejoin_takeover, playthrough_brock, catch_for_partner | |
| B02 | Switch to the partner's Pokémon | The turn passes to its owner | `test_a_free_player_joins_and_the_turn_follows_the_pokemon_that_is_out` | switch_and_suggest | |
| B03 | Move the cursor as the one not deciding | The partner sees "◀ NAME" and nothing happens | `test_a_suggestion_never_acts...` | switch_and_suggest | |
| B04 | LEAVE BATTLE as the joiner | Back in your world; your Pokémon fight on under the partner; you start no other battle until it ends, and one your world starts waits | `test_a_joiner_who_leaves_walks_on...`, `test_a_fight_the_world_opens_waits...` | leave_rejoin_takeover | |
| B05 | REJOIN from the panel or the SELECT menu | Back in the battle at once | `test_a_player_who_left_rejoins_from_the_session_menu` | leave_rejoin_takeover | |
| B06 | Try to leave a battle your own world started | Not offered | `test_a_joiner_who_leaves_hands_their_pokemon_to_whoever_is_left` | | |
| B07 | Close the deciding player's app | The battle waits; after 30 s the other is asked TAKE OVER or KEEP WAITING; the owner takes over again on return | `test_a_partner_stands_in_for_a_controller_who_stays_away` | leave_rejoin_takeover | |
| B08 | Close the only player's app in a battle | Kept about 2 minutes, then ended as fled; saving works again | `test_a_battle_everyone_left_ends_and_stops_holding_up_saves` | | |
| B09 | Throw a ball and name the partner | The catch is theirs (team, or PC when full) | `test_a_caught_pokemon_is_filed_once...` | catch_for_partner | |
| B10 | Use a Potion | It comes from the user's bag only | `test_an_item_comes_out_of_the_acting_players_bag_only` | catch_for_partner | |
| B11 | Win a trainer battle together | Each player gets the whole prize | `test_every_participant_is_paid_the_whole_prize` | playthrough_brock | |
| B12 | Win with EXP.ALL in one bag | Fighters split as usual; each team's others share as they would alone | `test_one_exp_all_pays_every_team...` | | |
| B13 | Level up into a new move or an evolution | The owner is asked; evolution plays in the owner's world | `test_a_level_up_shows_on_the_panel...` | | |
| B14 | Lose a shared battle | Each player whites out in their own world and pays half their own money | `test_the_world_whites_out_its_own_player...` | lose_and_white_out | |
| B15 | A trainer battle from start to end | Sliding intro, the trainer's lines, the defeat line, the prize | `test_a_trainer_win_closes_with_the_defeat...` | playthrough_brock | |

## Trades

| ID | Case | Expected | Automated | Two windows | Hand |
|---|---|---|---|---|---|
| T01 | Trade at a Cable Club | Each Pokémon arrives with its owner's new trainer; nothing is duplicated | `test_two_players_trade_at_the_cable_club...` | cable_club_trade | |
| T02 | Trade a MACHOKE, KADABRA, HAUNTER or GRAVELER | The trade movie shows it as sent (MACHOKE), then it evolves and arrives evolved | `test_a_pokemon_that_evolves_by_trade_arrives_evolved`, `test_a_trade_evolver_is_shown_as_sent_and_arrives_evolved` | cable_club_trade | |
| T03 | Cancel the trade on either side | Nobody's party changes | `test_a_trade_either_side_cancels_moves_nobody` | cable_club_trade | |
| T04 | Fight in the Colosseum | The cartridge's link battle against the partner's team (not yet tried) | | | |

## Platforms and input

| ID | Case | Expected | Automated | Two windows | Hand |
|---|---|---|---|---|---|
| P01 | Windows build joins a Linux host | Plays as on Linux | Wine run only (#44) | | |
| P02 | Tap or click panel rows | First tap moves the cursor, the second chooses | `test_a_tap_on_a_row_moves_the_cursor...` | | |
| P03 | A tall (portrait) window in a battle | The panel sits under the battle field | | | |
| P04 | Android: touch pad, pause and resume | Blocked: no Android build yet (#45) | | | |

## Logs

| ID | Case | Expected | Automated | Two windows | Hand |
|---|---|---|---|---|---|
| L01 | Play a session with log sharing on, then merge the logs | Each device's file holds every player's lines; `tools/coop_log.gd merge` gives one timeline | `test_coop_logs_session` | runner writes `summary.txt` | |
