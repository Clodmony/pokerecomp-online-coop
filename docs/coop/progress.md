# Co-op progress

What is implemented, what has been verified and how, what is incomplete and
what is blocked. Verification levels are kept apart on purpose:

- **static**: written and read, not executed;
- **tests**: GUT suites passing on the pinned Godot (4.8-dev4 until the
  0.1.75 merge, 4.8-dev7 since; CI or local);
- **socket**: the ENet demo or separate processes over localhost;
- **screens (scripted)**: two real game windows on the owner's imported Red
  cartridge, driven by scripted button presses and checked from screenshots;
- **played**: people played it by hand.

## A Generation 1 trade keeps the catch rate out of the item (#65, D120, 2026-10-14)

Outside co-op, a Red or Blue Cable Club trade with the other save slot refused
a RATTATA: upstream's `peer_from_save` sends a Generation 1 Pokémon's catch rate
in the item byte (for the Time Capsule), and the receiving Generation 1 save held
item 255 and failed its own check. Upstream's `commit_link_trade` now clears the
item of a Pokémon arriving in a Generation 1 game; the catch rate travels in its
own field. Co-op trades send the host's rows and never took this path. Branch
`coop/65-link-trade-catch-rate`.

| Verification | Result |
|---|---|
| GUT, before | `test_a_generation_1_trade_keeps_the_catch_rate_out_of_the_item` failed: `candidate_save_invalid`, catch rate 0 where 255 was sent |
| GUT, after | `test_link` 36/36 |
| `tools/verify.sh cable_club_trade`, twice on 3d9a5f16 | whole suite 5184/5184, gates, boot, ENet demo and three processes ok; `cable_club_trade` failed both times before any trade, stalled in the opening (Oak's parcel; a menu opened in the bedroom) while another program held a CPU core (load average about 2) |
| `tools/verify.sh cable_club_trade` on 706a0263, load average 0.4 | all passed: whole suite 5184/5184, ENet ok, `cable_club_trade` in 278 s: P1's MACHOKE arrives in P2's party and evolves into MACHAMP, P2's MANKEY joins P1, each uid once; captures looked at. The windows showed 15 frames a second in this run too, so the frame rate alone does not explain the two failures |
| Real cartridge, single-player save-slot trade | not run |

## Verify's ENet stages on free ports (#146, 2026-10-14)

`tools/verify.sh` ran the ENet demo on the default port 24680, the port a game
hosted from the Co-op tab listens on, and the three-process check on 24690.
With either held by another program the stage failed although the branch was
fine (the last three runs before this one). Each stage now picks a UDP port
nothing listens on (`ss`), from 25700-29699, above the game's ports and the
scenarios' (24800-25699), and the summary names both. CI keeps its fixed
ports. Branch `coop/146-verify-port`.

| Verification | Result |
|---|---|
| Probe, before | with 24680 and 24690 held by a UDP socket: the ENet demo ("coop: cannot listen on port 24680") and the three-process check ("cannot listen on port 24690") both exit 1 |
| `tools/verify.sh` with 24680 held by a UDP socket (24690 was not held in this run), on f238d34f plus this change | all passed: whole suite 5183/5183, gates, boot, ENet demo 16/16 on 26419, three processes (host 4, p1 7, p2 8 steps) on 26442 |

## Split screen top and bottom (#144, D119, 2026-10-14)

Asked by the owner: split screen was side by side only. Split screen on the
Hosting screen now asks **How to split the screen?**: Side by side (first and
focused) or Top and bottom. Top and bottom gives the host's window the top
half and the second window the bottom half, both the screen's full width;
Who plays where? and the toast name the halves for the layout. The layout
reaches the second window in its argument (`stacked`). Branch
`coop/144-split-layout`.

| Verification | Result |
|---|---|
| GUT, before | `test_a_split_screen_stacks_its_halves_top_and_bottom_when_asked` failed ("Invalid call to function 'half' in base 'GDScript'. Expected 2 argument(s)"), and the second window's request had no layout (`read` returned no `stacked`) |
| GUT, after | `test_coop_lobby` 11/11; source budget at the comment ceiling (41583, net zero) |
| Screens (scripted), Red | `local_split_stacked`: How to split the screen? with Side by side focused; Top and bottom picked; Who plays where? asks for the top half, then the bottom; RED's window 1920,0 2560x720 and BLUE's 1920,720 2560x720 on the owner's 2560x1440 monitor; both in Pallet Town, each seeing the other in the wider view; RED leaves, BLUE's window quits and RED's tab is 1152x648 again. `local_split` (Side by side): halves 1280x1440, as before. All captures looked at |
| Probe, partner arrow in a wide half | `partner_tracker_split` with Top and bottom: RED's arrow at the top while BLUE walks onto Route 1 (22 px from the window's top), BLUE's at the bottom (23 px from its bottom), both inside the window. In these runs the developer's debug line (shown only with debug keys on) is drawn over part of each arrow |
| `tools/verify.sh local_split local_split_stacked split_quit partner_tracker_split`, commit 306b53bd | whole suite 5183/5183, gates, boot, three processes and all four scenarios ok. The ENet demo failed because another program on this machine held UDP 24680; rerun on 24690: 16/16 |
| Not run | split screen on Windows; a portrait monitor; played by hand |

## The partner arrow inside the window, split screen included (#142, 2026-10-14)

Found by the owner in split screen, everywhere: player 2 never saw the arrow,
player 1 lost it at the top. A screen centres a buffer a little larger than
itself (`Gen2Screen._fit` rounds it up to 32 hardware pixels past 160x144), so
its edges are cut off: about 14 hardware pixels left and right and 11 at the
top and bottom in a split half (buffer 192x208 at 7x in a 1152x1296 screen), 7
at the top and bottom in a 1152x648 window. The arrow sat 4 pixels in from the
buffer's edge, so in a half it was drawn where nobody saw it, and a partner in
the cut-off strip counted as on the screen and got none. Now
`PokeCoopRemoteActor.shown_on` works out the shown part from the screen's own
size, `view_size()` and `native_size()`, for any window shape (a top-and-bottom
split too), and the arrow, the arrow over a door and the on-screen test all use
it. Branch `coop/142-partner-arrow`.

| Verification | Result |
|---|---|
| Probe, before | `partner_tracker` in two normal windows: both see arrows (so the bug needs split screen). A split probe printed each half's marks (RED's at (180, 96) on the right, BLUE's at (4, 96) on the left, buffer 192x208): the arrows were in each half's SubViewport texture but outside the window's crop (screen 1152x1296, buffer drawn 1344x1456 at (-96, -80)) |
| GUT, before | `test_the_arrow_stays_on_the_part_of_the_buffer_the_window_shows` failed for all nine directions, e.g. "towards (0, -15) at (84, 4), inside [P: (13.71429, 11.42857), S: (164.5714, 185.1429)]", and "an arrow towards (0, -6)": a partner six cells up, in the hidden top strip, got none |
| GUT, after | `test_coop_session` 167/167; source budget 4/4 at the comment ceiling (net zero) |
| Screens (scripted), Red | `partner_tracker_split`, before: no arrow in any of the 8 captures. After: RED's arrow on the right edge while BLUE stands at their door, at the top when BLUE walks onto Route 1; BLUE's on the left edge, then at the bottom left from Route 1; 6 of 8 captures show it, the other two fall in the blink. All captures looked at |
| `partner_tracker_cabins`, from an `ss_anne` seed moved onto SS_ANNE_1F | BLUE's arrow over the cabin door RED took; RED's, inside the cabin, over its door in the top row, now fully inside the 1152x648 window (it was 4 pixels from the buffer's top, 7 of which the window cuts off) |
| `tools/verify.sh partner_tracker partner_tracker_split partner_tracker_cabins local_split`, commit 7e883375 | whole suite 5182/5182, gates, boot, three processes, `partner_tracker`, `partner_tracker_split`, `local_split` ok. The ENet demo failed because another program on this machine held UDP 24680; rerun on 24690: 16/16. `partner_tracker_cabins` failed for want of its seed; rerun with one (above): ok |
| Not run | a top-and-bottom split (split screen was side by side only; see #144 above); split screen on Windows; a phone in portrait |

## Split screen's controllers and quitting; the Co-op tab after a re-import (#140, #139, #138, D117, D118, 2026-10-13)

Found by the owner in the #137 build. **#140:** the halves took the first two
connected controllers, not the one Settings picked, so a virtual pad another
program pressed could move a player. Now Who plays where? asks each half to
press A (or Enter for the keyboard), and Settings' pick plays on the left
without asking. **#139:** SELECT > QUIT BOTH on either half saves and closes
both windows; the right half no longer redials a host that is gone. **#138:**
the Co-op tab reads the cartridges again whenever it is shown, so a cartridge
imported again on the Play tab is Ready without a restart. Branch
`coop/140-138-139-pads-tab-quit`.

| Verification | Result |
|---|---|
| Probe, normal window, Red | the owner's DualSense Edge picked (same GUID and serial as their `options.json`), two virtual "Microsoft X-Box pad" devices made through uinput pressing A, the d-pad and the stick, one unplugged and plugged back in: Godot's raw joypad state saw each press, `PokePadChoice.heard` was false for each, no `gen2_` or `ui_` action went down; the pick stayed on device 0 throughout. The normal-window report was not reproduced |
| Split screen, before | `SplitScreen.pads` gave the halves `connected[0]` and `connected[1]`; the probe's device order (DualSense 0, the virtual pads 1 and 2) puts a virtual pad on the right half |
| GUT, before | `test_a_cartridge_imported_while_the_tab_is_away_is_ready_when_the_tab_is_shown_again` failed: "the tab reads the cartridges again when it comes back". The split-screen and quit tests call the new `halves`, `pressed`, `quit_both` and `QUIT_BOTH` |
| GUT, after | `test_coop_lobby` 10/10, `test_coop_device` 38/38, `test_coop_session` 166/166: halves by press with twin virtual pads and a picked DualSense, each half hearing only its pad; QUIT BOTH asked like LEAVE SESSION; the right half quits with code 3 and a host whose child exited with 3 quits after its goodbye; a dropped link ends the right half at once |
| Screens (scripted), Red | `local_split`: Who plays where? gets Enter (left: keyboard) and A on the first pad (right: the DualSense); halves 1280x1440 side by side; the toast names both and how to quit. `split_quit`: BLUE picks QUIT BOTH, "Close both windows?", YES: BLUE's window quits (frame 1262), RED's follows about 5 s later (frame 1992) and the campaign file holds BLUE |
| `tools/verify.sh local_split split_quit`, commit 2ad81874 | all passed: whole suite 5181/5181, gates, boot, ENet demo, three processes, both scenarios |
| Not run | killing the host's process by hand (K20 is covered by GUT only); the halves on Windows; the owner's other program pressing its own virtual pads during a split |

## Split screen on one PC (#53, D116, 2026-10-13)

Two players on one computer: Split screen on the Hosting screen (Linux and
Windows) moves the window to the left half of its screen, borderless, and
starts a second game process on the right half, which opens on the Co-op tab
and joins 127.0.0.1. Each half has its own controller (one controller: the
keyboard on the left, the controller on the right), and the right window
quits when its session ends, giving the left its window back. Branch
`coop/53-local-split-screen`, on top of #136's branch.

| Verification | Result |
|---|---|
| GUT, before | `test_a_split_screen_gives_each_half_its_own_controller_over_the_one_settings_picked`: parse error, no `PokeCoopLobby.SplitScreen` or `PokePadChoice.held` |
| GUT, after | passes: controllers per half for none, one and two pads, the halves of a screen, the second window's argument read back, a held pad over "Every controller" and the keyboard's half hearing no pad |
| Screens (scripted), Red | `local_split`: RED hosts SPLIT and presses Split screen; RED's window at 1920,0 1280x1400 and BLUE's at 3200,0 1280x1400 (the owner's second monitor, halves side by side), with the two connected controllers split between them by name; BLUE names themself on the right half and both play in Pallet Town; RED leaves, BLUE's window quits by itself and RED's tab is 1152x648 again. One of four runs failed before the split: an A press from a real controller opened Red's save screen in the focused window |
| `tools/verify.sh local_split launcher_host_join coop_tab_tour`, commit f009f001 | all passed: whole suite 5176/5176, gates, boot, ENet demo, three processes, three scenarios; the tour's Hosting shots show Split screen wide and upright |
| Played by the owner, KDE | it worked, but the taskbar showed below the halves: they asked for the work area |
| After: whole monitor, kept on top | `local_split` asks for 1920,0 2560x1440 and gets 1280x1400 halves: KWin caps a window at the work area, so the always-visible panel stays (it needs Auto hide). X11 state read while playing: `_NET_WM_STATE_ABOVE` on both; after the split, RED's window without it |
| `tools/verify.sh local_split`, commit 13de787f | all passed: whole suite 5176/5176, gates, boot, ENet demo, three processes, local_split |
| Not run | a button pressed on a real controller in the half without the focus (the setting is Godot's `Input.ignore_joypad_on_unfocused_application`, off in both halves); an exported build; Windows, so whether the halves cover its taskbar; Wayland's own driver (the project runs on X11, where a game may place its window) |

## A controller types on the Co-op tab (#128, D115, 2026-10-13)

A controller reached every field on the Co-op tab but could not type in one.
A on a field (pad or touch pad) now opens the tab's own keys: letters, digits,
`-` and `.` for names and the title; digits, `.` and `:` for the address; each
key types at once, B or Done goes back to the field. Found with it in a played
session: a remembered address showed in the field, and Join asked to type it
until a digit was deleted and typed again. Branch `coop/128-controller-typing`.

| Verification | Result |
|---|---|
| GUT, before the fix | `test_join_dials_the_remembered_address_the_field_shows`: no dial ("Join dials what the field shows without a keystroke"); `test_a_pad_types_an_address_and_a_name_on_the_tabs_own_keys`: no sheet after A on the address field |
| GUT, after | both pass: the pad lands on a key, the d-pad reaches every key, keys type the address (one Delete), B returns to the field, Join dials it; on New player the letter keys rename the trainer and Done closes them |
| Screens (scripted), Red | `coop_tab_tour` with two new shots, `keys_address` and `keys_name`, light and dark, wide and upright: every key on the card (a first run clipped the tenth and seventh column; now 8 wide, 5 upright, 3 for the address) |
| `tools/verify.sh coop_tab_tour launcher_host_join`, commit 98ceb52f | all passed: whole suite 5175/5175, gates, boot, ENet demo, three processes, both scenarios |
| Not run | a real controller by hand, a phone, Windows; the keys on Edit campaign's fields (same code path, not shot) |

## BROCK's leg autoplayed from a seed next to a plain window (#133, 2026-10-13)

From a seed, `route=brock from=pewter_gym` did walk to BROCK, but only after
`meet_in_pewter_gym`, which waits for the partner in the gym. A plain
`coop_play` partner never comes, so the window stood still until the watchdog
failed it with "nothing moved". The autopilot's `partner=none` ends its meet legs
at once, and a failure names its leg. New scenario `brock_from_seed`. Branch
`coop/133-autoplay-brock-seed`.

| Verification | Result |
|---|---|
| Before: a `viridian_forest` seed (`level=25 party=3`), RED autoplayed `route=brock from=pewter_gym`, BLUE a plain window | `p1 leg pewter_gym 5 s ... cell (4, 13)`, then `p1 FAILED at leg 1: nothing moved for 150 s` |
| Before: the same seed with both windows autoplayed | both reached BROCK and the BOULDERBADGE (p2 in 53 s, p1 in 57 s): the walk to BROCK was never the problem |
| After: `brock_from_seed` on that seed | `meet_in_pewter_gym 0 s`, beat the JR. TRAINER♂ and BROCK, `p1 finished, brock reached in 49 s`; captures looked at |
| `tools/verify.sh brock_from_seed=<seed> playthrough_brock`, on 48739ad8 plus this change | all passed: whole suite 5173/5173, gates, boot, ENet demo, three processes; `brock_from_seed` finished from the seed; `playthrough_brock` from Oak's speech, where BLUE's `meet_in_pewter_gym` still waited 22 s for RED; both took the BOULDERBADGE; captures looked at |

## A seed per scenario, and a runner that fails without Godot (#132, D114, 2026-10-13)

`tools/verify.sh` takes `<scenario>=<seed dir>` and refuses an exported `SEED`;
`tools/coop_screens.sh` fails when `GODOT` is no program or its host never
listens. Branch `coop/132-scenario-runner`.

| Verification | Result |
|---|---|
| Before (probes with a stand-in Godot that records the host's user folder) | `GODOT='~/nonexistent' tools/coop_screens.sh switch_and_suggest` exited 0, "no captures", "done"; `SEED=<dir> tools/verify.sh switch_and_suggest story_seed` gave the seed to both: `switch_and_suggest seeded=yes` |
| After, same probes | the missing binary exits 2 naming it; an exported `SEED` makes verify exit 2 before any stage; `switch_and_suggest story_seed=<dir>`: `seeded=no`, then `seeded=yes`; a host that never listens fails the scenario (exit 1) |
| `tools/verify.sh switch_and_suggest story_seed=~/…` (a `viridian_forest` seed, the `~` left to verify), on 60d76fdb plus this change | all passed: whole suite 5173/5173, gates, boot, ENet demo, three processes; `story_seed` reloaded the seed (map 0/2, cell 18,35, `SEED=` in its `run.env`), `switch_and_suggest` started fresh (map 0/0, empty `SEED=`); captures looked at |

## SHIFT's switch offer in co-op battles (#28, D113, 2026-10-13)

Co-op battles used SET style, so a trainer's next Pokémon came out unasked. Now
the player whose Pokémon is out is asked "Will RED change POKéMON?" if their own
BATTLE STYLE is SHIFT; the partner may suggest an answer. Mimic already asked
the Pokémon's owner; Baton Pass is not in Red and Blue. Branch
`coop/28-battle-offers`.

| Verification | Result |
|---|---|
| GUT, before the fix | the four new tests failed: after a trainer's Pokémon fainted the phase was `action`, not `offer`, for the owner on SHIFT; the view had no `offer`; the field had no line for the question; the host never learned the window's style and the menu stayed shut |
| GUT, after | the new tests pass (five session, one window end to end, one field); whole suite 5173/5173 in `tools/verify.sh` on 6965b198. The first verify run (8fcd2433) had one failure outside co-op, `test_a_turn_on_the_spot_in_grass_rolls_a_wild_encounter`; it passed alone (76/76) and in the final run |
| Screens (scripted), Red | `switch_offer` (new; a `viridian_forest` seed with `level=25 party=3` moved onto ROUTE 3 as `party_balls`', RED's lead knowing only EMBER): both windows on SHIFT, BLUE joins RED's fight with the LASS; when RATTATA faints both say "LASS is about to use NIDORAN♂!" over her ball row (one crossed out), RED's window asks "Will P1 change POKéMON?" with YES/NO over CHARMANDER where the battle screen puts it, BLUE's shows the same question; after NO the row goes and "LASS sent out NIDORAN♂!". `party_balls` now passes through the same question; `switch_and_suggest` and `catch_for_partner` unchanged. All passed in `tools/verify.sh`; every capture looked at. A first try from the same seed with the autoplay's BROCK leg (`route=brock from=pewter_gym`) never moved: it found no walk to BROCK, before any battle |
| Not run | a hand-played session; YES in two windows (switching to the partner's Pokémon is covered by GUT only); German, Blue, Windows |

## Private builds by script (#44, D112, 2026-10-13)

`tools/verify.sh --builds[=<dir>]` makes the private Windows and Linux builds
of HEAD as the last stage of a branch's check: both from a `git archive` of one
commit, booted, and zipped with `BUILD.txt` and `PLAYING.md`. Branch
`coop/44-private-builds`.

| Verification | Result |
|---|---|
| Before | builds were exported by hand from the working tree; the newest (2026-10-12, old checkout) predate 0.1.78, the bag and the party balls |
| `tools/verify.sh --coop --builds`, commit ed2866ac | import, co-op suites 286/286, gates, boot, ENet demo, three processes, then the builds: `Linux` (88 MB) and `Windows Desktop` (121 MB) exported in seconds from the archive, the Linux build boots headless and the Windows build under Wine 11.19 in a fresh prefix, both in the run's private user folder; the zips (40 MB, 49 MB) hold the binary, `BUILD.txt` (0.1.78, protocol 8, the commit) and `PLAYING.md` |
| `tools/verify.sh --builds=builds`, commit 0f58e0f8 | all passed: whole suite 5167/5167, gates, boot, ENet demo, three processes; both builds boot (Linux headless, Windows under Wine) and sit zipped in the checkout's `builds/` for the owner's session |
| The same with uncommitted doc edits | every other stage passes, builds: FAILED (uncommitted changes at the start), exit 1 |
| Not run | a build on a real Windows PC or a second Linux machine, a hand-played session (the issue stays open for it) |

## Keyboard, controller and touch pad in co-op menus (#43, D111, 2026-10-13)

An audit of every co-op menu on the three inputs. The CO-OP menu and the
battle menus read raw events before the input runtime's filter: one stick push
walked seven rows; a held key or touch-pad button moved one row, or three where the OS repeated the key, where the
cartridge's menus walk on. Both now read after the filter. Branch
`coop/43-touch-pad-input`.

| Verification | Result |
|---|---|
| GUT, before the fix | the new menu and battle tests failed: the co-op menu moved 7 / 3 / 1 rows (stick / held key / held touch pad) while the cartridge's path heard none of it |
| GUT, after | menu and battle move exactly as often as a reader on the cartridge's path, for all three; whole suite 5167/5167 (three new tests) |
| Co-op tab | `test_a_pad_reaches_every_button_and_field_on_the_co_op_tabs_screens`: on Start, Host, New campaign, Join and New player the focus lands on the screen and the d-pad reaches every button and field. Typing with a pad came with #128. Hosting and the sheets not walked |
| Screens (scripted), Red | `held_directions` (new; scripted windows can hold a button, `D*8`): START > CO-OP walks its rows while DOWN is held; in a battle's move list a press log showed the first repeat 29 frames after the press, then one every 5 frames, round SCRATCH, GROWL, EMBER |
| Two windows, existing scenarios | `start_coop_menu`, `switch_and_suggest`, `catch_for_partner`, `versus_from_menus`, `leave_rejoin_takeover`, `lose_and_white_out` passed; captures looked at. `friend_menu` failed once in `tools/verify.sh`: BLUE's window answered the trade invitation NO at the moment of its scripted A, with YES under the cursor a second before. Not reproduced: three runs alone on the branch and one on the base branch passed. Cause unknown; the owner's controllers reach scripted windows on this machine |
| Not run | a real stick or touch pad by hand, a phone, Windows; Cable Club, the TOWN MAP and taken-over battles are the cartridge's own screens and were not changed |

## Upstream 0.1.78 (#126, D110, 2026-10-13)

Upstream `v0.1.78` merged into the co-op line; three releases of Generation 3
field work, Godot still 4.8-dev7. Branch `coop/126-upstream-0.1.78`.

| Run | Result |
|---|---|
| `tools/verify.sh`, local x86_64, dev7 | import, gates, boot, ENet demo 16/16 and three processes passed; whole suite 5164/5164 (152555 asserts, 237 s) |
| Engine-free gates | version 0.1.78 everywhere; comment ceiling 41583, both sides' raises |
| Screens (scripted), Red | `playthrough_brock`: both windows reached BROCK, 18 battles won, 0 script errors; `cable_club_trade`: MACHOKE traded to P2 and evolved, 0 script errors; captures looked at. Run on a scratch copy of the owner's Red cache stamped with the new format 174 (no Generation 1 import code changed); the owner's caches show "Update needed" until imported again |
| Not run | German games, Blue, a phone, Windows |

## A co-op bag holds forty rows (#124, D109, 2026-10-13)

The owner asked for a bag that fits more items. Each player's bag in a co-op
run now holds forty rows instead of the cartridge's twenty. A solo game keeps
twenty. Branch `coop/bag-size`, stacked on `coop/opponent-balls` (#122).

| Verification | Result |
|---|---|
| Synthetic tests | Three new: `test_a_raised_generation_1_bag_takes_more_rows` (unit), `test_a_window_takes_a_twenty_first_item_out_of_its_pc_and_the_host_keeps_it`, `test_closing_a_session_gives_a_solo_game_back_the_cartridges_bag` (integration); the gift-spill test now fills forty rows |
| Whole suite | 5148/5148 on 4.8-dev7 under bwrap, 152121 asserts |
| Gates, sockets | `tools/release.sh --gates` pass, comments 41354/41354; ENet demo 16/16 on port 24657 |
| Screens | `bag_forty` on the Red import (a `viridian_forest` seed, BLUE's bag twenty different items, the PC its POTION): in the Pewter POKéMON CENTER BLUE withdraws the POTION ("Withdrew POTION.", where the cartridge says it can't carry more); the bag lists it as row twenty-one before CANCEL; after SAVE the host's campaign holds 21 rows and an empty PC (the scenario's check). All captures looked at, no script errors. A control run with nineteen items behaves as before |
| Not run | A Mart purchase or a pickup past twenty on screen (the same `receive_check`); a bag of forty-one; no hand-played session |

## Party balls in co-op battles (D108, 2026-10-13)

The owner asked whether the opponent's remaining Pokémon used to show as
balls. They did, and still do in a solo game, but the co-op field never drew
them. It now shows both rows under "X wants to fight!" (yours alone under
"Wild X appeared!"), and the trainer's row again after each faint, under "X
sent out", until the next Pokémon comes out. The host's battle views carry
`enemy_states` (HP and status per member). Branch `coop/opponent-balls`, built
on the local merge of #109, #111, #112, #116, #117 and #121.

| Verification | Result |
|---|---|
| Synthetic tests | Two new: `test_a_trainer_battle_opens_on_both_parties_balls_and_this_player_sees_their_own` (integration), `test_the_view_carries_each_enemy_members_hp_and_status_for_its_balls`; `test_a_trainers_next_pokemon_comes_out_after_the_last_one_has_fainted` now also checks the balls |
| Suites | Co-op 281/281, battle screen, renderer and HUD suites pass; the whole suite ran 5144/5145 before the comment trim, the one failure the comment total; after trimming comments only, `test_source_budget` passes at 41354/41354 |
| Gates, sockets | `tools/release.sh --gates` pass; ENet demo 16/16 on port 24653 |
| Screens | `party_balls` on the Red import (a `pewter_gym` seed with `party=3 level=25` moved onto ROUTE 3, RED's lead knowing only EMBER): under "LASS wants to fight!" her two balls top left, RED's three bottom right; after RATTATA faints her row shows it crossed out and NIDORAN♂'s whole under "LASS sent out NIDORAN♂!", gone once it is out. All captures looked at, no script errors, battle won |
| Not run | A friend battle's balls on screen; the whole suite again after the comment trim; no hand-played session |

## Owner's play-test fixes: a busy trainer, DIG, battle menus (#118, #119, #120, D107, 2026-10-12)

The owner's German session on the S.S. Anne turned up three faults, each
traced in the host log (`2026-10-12_22-44-51_host_CLOEDL.jsonl`):

- A trainer fighting one player spotted the partner who walked past (GÖRE,
  `trainer:3:10`). Sight is each window's own and only the host knew of the
  fight. A trainer the host names as running in a battle or beaten for the
  campaign now spots nobody else (D107); talking to it still joins.
- DIG needed a second press: the session never took a locked-in turn on its
  own (`advance()` was empty), so every charged, recharging, rampaging or
  raging turn waited for a command the cartridge never asks for. The host now
  takes it with the last chosen slot, as `CheckPlayerLockedIn` does.
- DIG drew the Pokémon twice: upstream's `SE_SLIDE_MON_UP` slid the picture
  from home up by 56 pixels instead of up into its box from below, leaving a
  copy on the screen's top rows when the field stamped it back home. The
  slide now rises into the box and ends home, and Gen 1 slides keep to their
  box's rows, as the cartridge's `CopyPicTiles` does (the slide down had
  written over the text box's rows too).
- A battle menu fell back to FIGHT/PKMN/ITEM/RUN when the partner locked in
  their choice in a friend battle: the menu asked again on every new revision,
  and a lock-in moves the revision on with no events. It now asks again only
  on a turn that carries events, or when the phase, controller, pause or the
  session's own rows change (a bag growing by one row no longer counts).

| Verification | Result |
|---|---|
| Synthetic tests | Five new: `test_a_trainer_the_partner_is_fighting_or_beat_spots_nobody_else`, `test_a_partners_lock_in_leaves_the_other_players_open_list_open` (integration), `test_a_locked_in_turn_is_taken_with_no_second_command`, `test_a_sight_gate_skips_the_trainers_it_refuses`, `test_a_generation_1_slide_up_rises_into_its_box_and_ends_home` (unit) |
| Whole suite | 5143/5143 on 4.8-dev7 under bwrap, 152107 asserts |
| Gates, sockets | `tools/release.sh --gates` pass, comments 41354/41354 (ceiling raised by four, D107); ENet demo 16/16 on port 24641 |
| Every Gen 1 animation | Headless on the German Rot import, both sides: DIG (91) ends with one picture at home and no animation writes below a picture's box; the others that end shifted are the hiding slides (151, 192), as before |
| Screens | `trainer_busy` on the Red import (a `pewter_gym` seed moved onto ROUTE 3, RED's lead a DIGLETT knowing only DIG): RED walks into the LASS's sight and fights her; BLUE steps next to her meanwhile and is not spotted (no takeover in the host log); DIG digs, comes up and hits with one command for the two turns (host log: two commands, two `battle_advance`), DIGLETT drawn once at home. `versus_lock_in` (the `pewter_gym` seed): RED locks in while BLUE's move list is open on GROWL; it stays open on GROWL until BLUE chooses, then the turn plays. All captures looked at, no script errors |
| Not run | A partner spotted during the other player's walk-up (left open, D107); FLY, SOLARBEAM, THRASH and HYPER BEAM on screen (the unit test covers recharge); no hand-played session |

## Finding the partner, and a friend battle under a menu's white (D106, 2026-10-12)

The owner found the partner easy to lose and asked for an arrow or a map
(D106). A partner off the screen is a blinking arrow in their colour on the
screen's edge; past a door, stairs or a route's edge it stands over, or
points at, the way they went; START > CO-OP > TOWN MAP and the TOWN MAP item
show their icon. The owner also got a white screen when a friend accepted
their invitation while they were in START > OPTION. Cause: a Gen 1 menu
opens and closes behind `GBPalWhiteOut`, the screen's white cover, held for
the screen's load frames by the world; a battle that begins inside those
frames freezes the world with the cover up, over the battle field, until the
battle ends. The field now takes the cover down while it is up. An invitation
also waits until its player is back on the map, out of every menu, Mart, PC
and the TOWN MAP (the check missed the start menu and the service screens).

| Verification | Result |
|---|---|
| Synthetic tests | Seven new in `test_coop_session` (edge arrow and a widened screen's edge, a door on a connected map, the way out of a building, the TOWN MAP direction and icons, arrow images, the session menu's TOWN MAP, the white taken down under a battle; the last fails without the fix) |
| Whole suite | 5135/5135 on 4.8-dev7 under bwrap, 152061 asserts |
| Gates, sockets | `tools/release.sh --gates` pass, comments 41350/41350 (ceiling raised by three, D106); ENet demo 16/16 on port 24633 |
| Screens | `partner_tracker` on the Red import: the arrow over RED's front door in BLUE's window, on the left edge as BLUE walks east (it follows RED's steps), at the top while RED is on Route 1, none over the TOWN MAP; RED's window has none while standing on the doormat; BLUE's TOWN MAP shows RED's icon on Route 1, half under BLUE's own in Pallet Town. `versus_from_menus`: BLUE in the START menu gets the question only after closing it; RED in OPTION sees the battle at once. All captures looked at, no script errors |
| Not reproduced | The white screen itself: four scripted timings (OPTION open before the answer, party screen, German Rot, the launcher's Co-op tab) all drew the battle; the cover is up only for the menu's load frames, which a script did not hit. The fix rests on the test |
| Not run | A partner across the sea or after FLY on screen (the test covers the direction); no hand-played session |
| Owner's first session with the build | The partner vanished when he walked north out of Vermilion City: on Route 6 he was not drawn (only partners on the same map were) and, being on the screen, got no arrow either. A partner on a map connections reach (the next route or town) is now drawn there, eased and never solid, and the arrow takes over out of sight; arrows sit two pixels further in. `partner_tracker` now has BLUE at Pallet Town's north edge seeing RED walk on Route 1, and RED seeing BLUE across it. The joiner (Blaue) was reported to get no arrow at all; a launcher run with a Rote host and a Blaue joiner showed the joiner's arrow over the host's door, so the joiner's build was likely the earlier one (not confirmed) |
| On the S.S. Anne | The owner saw the arrow over the wrong cabin door: the six cabins of a deck are one map, and the search kept the first door in the map's list into it. Of the doors on the way into one map it now takes, on this player's own map, one they can walk to (the camera-reach test the draw list uses, which keeps another cabin's door out), and into the partner's map the one that lands nearest them; an arrow over a door in the screen's top row stays on the screen. Checked headless on the Red import for all six cabins both ways, and `partner_tracker_cabins` (from an `ss_anne` seed moved onto SS_ANNE_1F): BLUE's arrow over the third cabin's door RED took, RED's over that cabin's door. Co-op suites 275/275, whole suite 5137/5137 before the last clamp, gates, ENet demo 16/16 |

## Battle music to the end, and a run button (D105, 2026-10-12)

The owner reported that the map's music came back on the final strike or a
successful throw in a battle the world opened. Cause: the world's battle
bridge told the world the fight was over the moment the host's outcome came
in, and the world's battle exit (`_finish_battle_exit`) put the map's track
back while the field still played the faint, the experience and the fanfare.
The bridge now waits for the field's last line (`PokeCoopBattleTakeover.busy`).
A wild win's fanfare now starts when the Pokémon falls, ahead of its line and
the experience, as `FaintEnemyPokemon` does; a trainer's still follows the
experience. Hold B to run (D105): the session registers upstream's RUN BUTTON
policy, and a partner's steps are eased at the pace they report them.

| Verification | Result |
|---|---|
| Synthetic tests | Co-op suites 247/247 (three new: the world waits for the field's last line, a wild fanfare on the fall and only once, running and a running partner's pace) |
| Whole suite | 5106 tests on 4.8-dev7 under bwrap; the only failure was the comment ceiling, fixed by trimming the new comments (`test_source_budget` 4/4 after) |
| Gates, sockets | `tools/release.sh --gates` pass, comments 41343/41343; ENet demo 16/16 on port 24611 |
| Screens | `playthrough_brock` on the Red import, both windows finished (BROCK in 295 s), 47 captures inspected, no script errors. A local probe (not committed) logged each window's music: in all 22 battles the fanfare (wild, trainer, gym leader) started while the field was up and the map's track came back only after the field had closed. No catch happened in that run; a catch takes the same bridge path |
| Owner's campaign deleted by a test run | The whole suite shares the player's user folder, and `test_coop_device` (from #109/#111) deletes every file in `user://coop_campaigns/red_de` and `blue_de`. This session's run at 21:14 deleted the owner's German campaigns; earlier runs had done the same. Both were restored from the `host_end` lines of the owner's host logs (CAMPAIGN 2: 3 badges, two teams of six), read back identical, with copies kept outside the repository. Every test run now keeps campaigns and session logs in `user://coop_campaigns_test` and `user://coop_logs_test` (a GUT pre-run hook, and the suite sets it itself); test logs also no longer push the owner's logs out of the thirty kept. A full run afterwards left the real campaigns and logs unchanged |
| Not run | Running was not driven in a window (the scripted keys press one button at a time); no hand-played session |

## Friend menu continuation (#104, D100, 2026-10-11–12)

Claude left an uncommitted `coop/pvp-battle` worktree on the native menus and
Cable Club continue branch. `coop/friend-menu` keeps that worktree intact and
completes its friend battles, invitations and trades; dependencies are draft
#101 and #103. BATTLE / TRADE / CANCEL is available by talking to the partner,
and named BATTLE / TRADE rows are in START > CO-OP (also SELECT).

| Verification | Result |
|---|---|
| Synthetic tests | Co-op suites 243/243, 1217 assertions. Friend invitations, both choices/replacements, mirrored views, full unsplit EXP for winner/loser, healing without money/warp/whiteout, simultaneous learning, forced turns, timeout/busy/disconnect, direct trade swap/cancellation and log replay. The existing gesture test now releases held actions and clears a previous menu's input stall before counting presses. |
| Editor | Godot 4.8-dev7 import/class scan; analyser: 0 warnings across all 18 changed scripts; Debugger dump: 0 entries |
| Whole suite and boot | 5098/5098 tests, 151074 assertions, 214.4 s through the bounded CI runner on 2026-10-12; editor import and boot smoke pass |
| Source gates | `test_source_budget` 4/4; engine-free gates pass, comments 41343/41343 |
| Localhost sockets | ENet demo 16/16 on port 24581; three-process host/p1/p2 check passes on 24582 |
| Screens | `friend_menu`: English Red and German Rote Edition, 21 captures each, all inspected: own teams on both battle fields, natural finish, healed parties (Blue's RATTATA level 9 to 10), trade invitations, the complete native trade movie, swapped parties and CANCEL back at both original cells. The saved campaign keeps 3000 money each and every UID once. A short German invitation run also checks the widened JA/NEIN box. Captures and imports stay under `/tmp`, outside commits |
| Platforms | Linux game windows exercised. Local Linux and Windows exports both boot: Linux directly, Windows under Wine in a fresh temporary prefix. No hand-played Windows or phone session for this continuation. |

## Baseline

| Check | Result | Where |
|---|---|---|
| Upstream commit | `696d1c9a1d345ae08fd7febac8aa320aed6608b5` (0.1.72) | `upstream/main` on 2026-10-05 |
| Import, GUT, boot smoke on `main` | Passed: 184 scripts, 4812 tests, 135416 asserts, 381.6 s; boot smoke passed | fork CI run 37376496611 (`main` = baseline plus workflow guard and README notice) |
| Engine-free gates | Passed | `tools/release.sh --gates`, local |

## Verification runs (2026-10-06)

| Run | Result |
|---|---|
| CI run 37380076818 (first slice push) | Import, GUT 4837/4837, boot smoke passed; ENet demo 15/16, shutdown step failed (fixed, D18) |
| CI run 37381224660 (slice before the real screens) | All four steps passed: GUT 4837/4837, demo 16/16 |
| Local x86_64, after the real-screen work | Co-op suites 27/27 (`test_coop_state` 6, `test_coop_battle` 10, `test_coop_session` 11); `test_smoke` 2/2; `test_source_budget` 4/4; ENet demo 16/16 |
| Local ENet demo | 16/16, repeated: 3 runs on x86_64, 5 on the x86_32 build |
| Separate processes, synthetic | `host` plus two `client` processes on 127.0.0.1: both welcomed, each lists the other once both are connected |
| Separate processes, Red | `host red` refuses a client with another cartridge and tells it why (`refused: content_mismatch`); a Red client joins |
| Screens (scripted), Red | Host `red` plus two `coop_play.gd` windows, see below |
| CI on the final commit | see the pull request's checks |

### What the scripted Red windows showed

Screenshots were taken locally and are not committed (they show cartridge
graphics).

1. RED's and BLUE's windows open on Pallet Town at their own doorsteps; each
   draws the other player in that player's colour.
2. BLUE walks left; RED's window shows the move and the new facing; BLUE's own
   window agrees on the cell (13,6 to 11,6).
3. RED starts a wild Pidgey battle from the session menu; BLUE's window shows
   RED with the "!" emote at the encounter spot.
4. BLUE joins from its session menu: both panels list Charmander and Pidgey
   [RED] and Squirtle and Rattata [BLUE]; RED's panel says YOUR TURN.
5. BLUE moves its cursor: RED's panel marks FIGHT EMBER `<- BLUE` with the
   revision unchanged.
6. RED switches to BLUE's Squirtle: RED's panel says BLUE DECIDES, BLUE's says
   YOUR TURN at revision 2 with Squirtle's moves. BLUE's world did not move
   while its panel was open.
7. Both players fight separate wild battles at once and win; RED saves from the
   session menu. The file holds RED's Charmander at 1012 exp, 24/34 HP and 7
   SCRATCH PP spent, BLUE's Squirtle at 1005 exp and 2 TACKLE PP spent, both
   benches untouched. A restarted `host red` reloads it and a client rejoins.

## M1 state sync (local branch `coop/m1-state-sync`, 2026-10-06)

Not on GitHub at the time (GitHub was paused); its items were filed as issues on 2026-10-07.

| Run | Result |
|---|---|
| Local x86_64, whole suite | 4855/4855 (188 scripts, 135696 asserts, 193 s); boot smoke passed |
| Local x86_64, co-op suites | 43/43 (`test_coop_session` 21, `test_coop_battle` 10, `test_coop_ownership` 6, `test_coop_state` 6); ENet demo 16/16 |
| Screens (scripted), Red: joint Brock fight | RED starts Brock from the menu, BLUE joins, RED hands over to BLUE's Squirtle, Bubble wins. Both windows' own trainer cards then show the Boulder Badge and 3693 money each (3000 plus half of 1386); BLUE's own party menu shows Squirtle at L13 with its battle damage |
| Screens (scripted), Red: Route 1 grass | RED's world rolls a wild Pidgey in Route 1's tall grass; the takeover makes it a host battle; BLUE joins from its menu; RED wins and the world resumes with "Battle finished: won" |

What the tests add beyond the screens: a story flag set in one window reaches
the other; flags set in both windows at once both survive; a window opened
late takes the campaign without erasing it; a bag change stays with its
player; a badge won in battle reaches both windows; battle results come back
into a window's party; a heal and a deposit made in a window reach the host
(the deposited Pokémon keeps its uid in the box); a battle the world opens is
fought on the host with the world's prize zeroed; a lost window battle is not
charged twice; the world's SAVE writes the campaign.

## Launcher, captures, evolution, whiteout (local branch `coop/launcher`, 2026-10-06)

| Run | Result |
|---|---|
| Local x86_64, co-op suites | 52/52, including `test_coop_device` over real localhost sockets (host, join, come back as the same player) |
| Real launcher, two instances | Co-op tab: one hosts, one joins `127.0.0.1`; both worlds open with the starters they chose; a recorded video shows the partner joining and walking over |
| Screens (scripted), Red: capture | A wild Rattata from Route 1's grass, Master Ball thrown by RED for BLUE: BLUE's panel says caught for BLUE and BLUE's own party menu lists it |
| Screens (scripted), Red: evolution | BLUE's Squirtle reaches 16 in RED's battle; BLUE's window plays the evolution into Wartortle; BLUE's party menu shows Wartortle L16 |
| Screens (scripted), Red: loss | Both lose to a level 40 Onix from the session menu; both windows show the blackout and wake up in Pallet Town |
| Local x86_64, whole suite after the session lifecycle | 4865/4865; co-op suites 54/54; ENet demo 16/16; boot smoke and release gates pass |
| Local x86_64, `test_coop_device` | a device whose link drops dials again and is the same player; a host that leaves saves both players and the joiner hears `host_shutdown` |
| Screens (scripted), Red: PC | BLUE deposits RATTATA in Viridian's Pokémon Center PC; the host's campaign file has it in box 1 under its own uid; a new window session's WITHDRAW lists RATTATA L9 |
| Screens (scripted), Red: story gift | RED talks to Daisy in Blue's house and gets the TOWN MAP; BLUE, out in Pallet Town, opens the bag and finds a TOWN MAP too |
| Screens (scripted), Red: trade | RED and BLUE talk to Viridian's Cable Club receptionist, enter the Trade Center, see each other's real parties, and trade RATTATA for BLUE's MACHOKE; RED's window plays the trade movie and MACHOKE evolves into MACHAMP; the host's saved campaign has MACHAMP with RED (uid `p2:1`, OT BLUE) and RATTATA with BLUE (uid `p1:2`) |
| Screens (scripted), Red: battle field | RED fights BROCK from the session menu and BLUE joins: both windows draw GEODUDE and then ONIX against whoever is out, with HP bars and "CHARMANDER used SCRATCH!", "It's not very effective...", "Enemy GEODUDE used DEFENSE CURL!" in the text box; the turn passes to BLUE when SQUIRTLE is out; recorded as a side-by-side video |
| Screens (scripted), Red: move animations | In the BROCK fight, "CHARMANDER used SCRATCH!" is followed by the cartridge's claw marks over GEODUDE before "It's not very effective..."; recorded as a clip |
| Screens (scripted), Red: draining bars | After "Enemy GEODUDE used TACKLE!" CHARMANDER's bar goes 34, 32, 29, 27 frame by frame, and a turn's lines, animations and bars play in order before the next choice is taken |
| Screens (scripted), Red: move sounds | In the BROCK fight the field asked the world's audio player for four move sounds (SCRATCH, TACKLE, DEFENSE CURL rows), seen in a temporary log line; a Movie Maker recording has the audio track, which the overworld music dominates, so the sounds were checked by the calls rather than by ear |
| Screens (scripted), Red: hit effects | In the BROCK fight, after SCRATCH lands GEODUDE's picture blinks off and on five times; "Enemy GEODUDE used DEFENSE CURL!" flashes the field's palettes; after "Enemy GEODUDE used TACKLE!" the whole field jolts down and back (the cartridge's vertical shake through the scroll registers); frames captured every ten frames and a Movie Maker recording (whose battle part turned out silent, see battle audio) |
| Screens (scripted), Red: send-outs and faints | RED (a level 30 SQUIRTLE) fights BROCK from the session menu with BLUE joined: "BROCK wants to fight!", GEODUDE growing out of the ball on "BROCK sent out GEODUDE!", the poof and SQUIRTLE growing on "Go! SQUIRTLE!"; GEODUDE sinks out of its square and its panel goes before "Enemy GEODUDE fainted!", ONIX's panel and picture come with "BROCK sent out ONIX!", and ONIX sinks the same way before the window returns to the world; frames every eight frames |
| Local x86_64, whole suite after the learning fixes | 4910/4910 twice, ENet demo 16/16, release gates pass. The first run passed every test and then did not exit: one non-worker thread, started a fifth of a second after launch, had spun at full CPU the whole run while the main thread waited on it; a sampled normal run has no such thread. `ptrace` is not permitted on this machine, so there is no stack; it looks like an engine thread of 4.8-dev4 rather than test code |
| Screens (scripted), Red: saving | BLUE saves with START > SAVE: BLUE's window shows "Campaign saved." beside the game's "BLUE saved the game!", RED's shows "BLUE saved the campaign.", and RED's session menu then reads "Saved 8 seconds ago. It also saves itself after battles and every thirty seconds of changes." (D48) |
| Local x86_64, returning by name | a device test drops a joiner's remembered id and joins again under the same name: the host hands back the same trainer and keeps two players |
| Local x86_64, several campaigns | Whole suite 4921/4921, co-op suites 108/108, ENet demo 16/16. A device test hosts campaign A (RED, BLUE), then campaign B on the same port where GREEN, on another device, gets the same player id BLUE had in A; BLUE's device joining B is a new trainer rather than GREEN's, and back in A, under another name, is BLUE again. A second test moves an earlier build's single campaign file into the folder and hosts it (D49) |
| Screens (scripted), Red: campaign picker | The Co-op tab lists "WITH ALEX: RED, ALEX, 3 badges, saved 2026-10-06 19:37" above the earlier build's file as "FIRST CAMPAIGN: RED, 0 badges, ..."; picking "A new campaign" shows a name field. Hosting a new campaign named "with alex" from the tab wrote `coop_campaigns/red/red-<unix>-<tag>.json` titled WITH ALEX, the session menu read "CO-OP SESSION  WITH ALEX", and the identity file recorded the host's player under that campaign id |
| Screens (scripted), Red: the opening | Two windows (RED, GREEN) join a fresh campaign with "Play the opening" against a host on localhost: each shows the copyright screen and Oak's speech (the player's name taken from the tab, the rival named BLUE from the presets), wakes in its own bedroom, is stopped by Oak at the grass and walked to the lab, takes CHARMANDER or BULBASAUR while that window's rival takes the counter, fights him on the host (two private fights at once, not joinable), and leaves the lab. Neither window drew the other at any point of its opening (checked every frame; Pallet Town and the lab included); RED, out first, saw nobody until GREEN left the lab, then both saw each other in front of it. The host then dropped each private story, the windows took the campaign's, and the campaign kept the rival's name and the first finisher's rival starter. CHARMANDER is healed after the lab fight as on the cartridge. Recorded side by side with RED's audio (local only, cartridge graphics). The same lab, driven in a plain single-player world, also lets the player walk past the rival's challenge (L10) |
| Local x86_64, opening and echo | Session tests: a player in the opening gets no starter, stands in the bedroom, sees nobody and is seen by nobody until the lab is left, keeps story changes off the campaign until then, and their rival fight is private and claims no campaign encounter; a window's stale echo no longer rewinds a map script it moved on twice (the test fails without the fix); a player part-way through the opening survives a save |
| Local x86_64, story items and partners | Session tests: potions picked up with a story change reach the partner in the same number while an item bought stays the buyer's; OAK's PARCEL delivered is taken from both players while a fossil stays with each; a partner on the map is a solid actor |
| Single player, Red: the lab's challenge (L10) | Driving the lab in a plain world, walking down at once after naming the starter: the player now stands still while the rival walks to his POKé BALL (D54), and walking down then meets "BLUE: Wait RED!" and the fight, where before the player left the lab without it |
| Local x86_64, three players (in-memory loopback, synthetic cache) | `test_coop_three_players` 9/9: every partner's suggestion on the controller's panel in their colour, two-player mark unchanged; Trade Center pairing (pair kept when a third enters, re-paired when one leaves, id order on simultaneous arrival, a waiting player cabled from outside) and a trade between two of three; a third team trimmed to the two fit Pokémon left, refused with no room, queued joins sharing the room. Not played with three windows (D55) |
| Local x86_64, refused save | `test_coop_save_refusal` 4/4: the host's state carries why a checkpoint would be refused; Red's Gen 1 save menu reaches its FAILED step during a battle, sends no checkpoint and saves after it; a real world screen's START > SAVE ends SAVE_FAILED and leaves the save untouched (D56). Not yet seen on a real cartridge |
| Local x86_64, two-process ENet check (#47) | `tools/coop_two_process.sh <port>` runs the host, p1 and p2 as three processes on the synthetic cache: p1 starts a battle, p2 joins, the turn goes to p2's Pokémon and back, the battle is won, the host shuts down and both players end on `host_shutdown`. 30/30 passes (16 sequential, 5 pinned to one CPU, 9 as three concurrent runs); a busy port, a missing player, an unknown role and a 2 s cap all exit non-zero, and a demo that cannot listen now fails instead of passing 0 steps. The CI step is written but not run (GitHub paused) |
| Local x86_64, whole suite after merging | 4942/4942 with the three branches above, the story items and the Gen 1 facing fix |
| Screens (scripted), Red: OAK'S PARCEL with two players | A fresh campaign, both players skipping the opening: RED walks Route 1 to the Viridian Mart, the clerk gives OAK'S PARCEL, and GREEN, waiting in Pallet Town, has one in its bag at once (D52); RED walks back and gives it to Oak, and the parcel leaves both bags. Before D58 the skip-mode lab had no Oak to give it to (L17), and before D57 the Mart's exit mat would not let RED out after the clerk's scene (L11) |
| Local x86_64, session logs | `test_coop_log` 10/10, `test_coop_logs_session` 12/12 (one over real localhost sockets), whole suite on the logs branch 4964/4964; ENet demo 16/16 with and without logs; three `check ... logs` processes: each file holds the other devices' lines (all but their closing lines); the demo's host log replays to the same campaign and players, and a changed logged message makes the replay report the difference |
| Local x86_64, logging cost | ENet demo mean 3.35 s off, 3.37 s on; in memory, 2000 steps with battles across three logged devices, 0.29 ms a step off, 0.32 ms on |
| Screens (scripted), Red: session logs | a headless hosting session on a throwaway Red campaign plus one `coop_play.gd` window: the window logged world_open, map changes, world pulls and every move, and the two files hold each other's lines |
| Socket, Red: closing a hosting window | A headless hosting session with a `coop_play.gd` joiner gets the window's close request: the host quits 2.0 s later on its own and the joiner ends on "session ended (host_shutdown)" instead of redialling; `test_coop_device` covers the same over sockets (D60) |
| Local x86_64, whole suite after the logs | 4966/4966; ENet demo 16/16; the three-process check passes; release gates and boot pass |
| Builds, commit 2cacdc6e (then c86e20b4) | Stock 4.8-dev4 export templates installed (SHA-512 checked); `Windows Desktop` (119 MB) and `Linux` (85 MB) release builds exported, one file each, no cartridge data; the Linux build and the Windows build under Wine boot headless; the official Windows engine under Wine imported Red (same SHA-1 as the Linux side) and joined a host run by the Linux engine over a socket: given its starter, its world opened, each side saw the other. Not yet run on a real Windows PC |
| Builds, commit c0a14aed | `Windows Desktop` and `Linux` release builds exported again with several campaigns and the opening (players meet after Oak's lab); the Linux build boots headless and the Windows build boots under Wine; zipped for the Windows player with an updated guide (the opening, hosting a named campaign). Not yet run on a real Windows PC |
| Builds, commit 49865aa1 | `Windows Desktop` and `Linux` release builds exported with everything above (story items, three-player readiness, the refused save, session logs and the goodbye on close); the Linux build boots headless and the Windows build boots under Wine; zipped for the Windows player with the guide updated (items, saving during a battle, logs). Not yet run on a real Windows PC |
| Local x86_64, joining a host that never answers | a device test dials a port nobody hosts: after fifteen seconds the session reports `host_unreachable` and the Co-op tab explains the address, the Host button and UDP 24680; a cartridge mismatch now says both players need the same game file |
| Screens (scripted), Red: Pokédex seen | After the two-window run (a wild PIDGEY caught for BLUE, then BROCK) the saved campaign lists PIDGEY, GEODUDE and ONIX as seen for both RED and BLUE, and PIDGEY as caught for BLUE; before D47 battles added nothing to "seen"; whole suite 4916/4916, ENet demo 16/16, release gates pass |
| Screens (scripted), Red: where the partner is | BLUE opens SELECT in Pallet Town while RED walks Route 1: "With RED (ROUTE 1)", and a second later, as RED's world starts a battle, "With RED (in a battle)" and "Join RED against wild RATTATA" |
| Screens (scripted), Red: host restart | Both windows walking, the host is killed: each says "Lost the host: reconnecting..."; the host is started again twelve seconds later on the same campaign and both say "Back in the session." as the same players; a device test drops and redials a joiner back from a long pause; whole suite 4915/4915, ENet demo 16/16, release gates pass |
| Screens (scripted), Red: partner notices | RED's window says "BLUE joined the session." when BLUE connects; BLUE, in Pallet Town, reads "RED is in a battle against wild RATTATA. SELECT to join." as RED's world starts a battle on Route 1; whole suite 4914/4914, ENet demo 16/16, release gates pass |
| Screens (scripted), Red: the panel | In the two-window run the panel names the opponent ("Wild PIDGEY L3", "BROCK's ONIX L14"), lists RED's and BLUE's Pokémon under their names in their colours, says "Your turn" or "RED is choosing. Your cursor is a suggestion.", groups FIGHT, POKéMON and BAG, marks BLUE's suggestion "◀ BLUE", and ends on "Caught for BLUE!" or "You won!"; a test taps a row twice and the move is chosen (D45); whole suite 4913/4913 |
| Screens (scripted), Red: feature tour | One two-window run, recorded side by side with sound (2:38): RED and BLUE walk together to Pallet Town's north edge; RED's world starts a wild battle on Route 1 and BLUE joins it from Pallet Town; BLUE's cursor shows on RED's panel as "<- BLUE" on GROWL and RED takes it; RED switches to BLUE's SQUIRTLE and the turn passes to BLUE; BLUE's GREAT BALL catches the wild PIDGEY for BLUE and BLUE's party lists it; both beat BROCK, each window naming its own player and share; RED saves the campaign. The Brock fight opens on an empty box (D44) |
| Local x86_64, review of the battle field work | a read-only review since D38 found eight issues, all fixed with tests or a probe (D44); whole suite 4912/4912, ENet demo 16/16, release gates pass |
| Launcher (scripted), Red: a world battle joined | RED hosts from the launcher's Co-op tab and BLUE joins by address; RED walks out of Pallet Town into Route 1's grass and the world starts a wild battle (transition, sliding intro, "Wild RATTATA appeared!") fought on the host; BLUE, still in Pallet Town, joins it from SELECT and sees "BLUE joined the battle!" and "RED is deciding...". Two windows on one machine: a window that loses focus has its held buttons released by the engine, so the driver presses again |
| Screens (scripted), Red: the screen's own words | In the BROCK fight "Enemy GEODUDE used DEFENSE CURL!" is now followed by "Enemy GEODUDE's DEFENSE rose!"; a scratch battle on the Red data words paralysis, poison damage, stat drops, "Hit the enemy 2 times!" and draining through the same path |
| Local x86_64, whole suite after the screen's words | 4911/4911; ENet demo 16/16; release gates pass |
| Screens (scripted), Red: learning a move | RED's CHARMANDER (four moves, five EXP short of level 15) beats a wild PIDGEY: the panel shows L15 and 41 maximum HP as "CHARMANDER grew to level 15!" comes up (it used to show 41/39 until the turn ended), "CHARMANDER is / trying to learn / LEER!" in full (its first row used to overflow the box and lose the rest), "Which move should be forgotten?" while RED chooses, then "1, 2 and... Poof!", "CHARMANDER forgot SCRATCH!", "And... CHARMANDER learned LEER!" (the battle used to close on the press that chose, before the field had read the final view) |
| Screens (scripted), Red: a lost battle | RED and BLUE, a level 2 PIDGEY each, lose to BROCK: each PIDGEY sinks before "PIDGEY fainted!", a replacement is asked for as "Bring out which POKéMON?" rather than "What will PIDGEY do?", the last line stands its full hold (an A press during it used to close the battle mid-line), and RED's world then blacks out with its own "RED is out of useable POKéMON!" |
| Screens (scripted), Red: sliding intro | BROCK and RED's back picture slide in from either side, RED's head whole (it was scrambled before L8), "BROCK wants to fight!", BROCK slides out and GEODUDE grows out of the ball, RED slides out before "Go! SQUIRTLE!"; after the win "RED defeated BROCK!", BROCK slides back in, "RED got ¥693 for winning!"; frames every eight frames |
| Screens (scripted), Red: trainer closing | RED (SQUIRTLE L30) and BLUE beat BROCK from the session menu: "RED defeated BROCK!" and "RED got ¥693 for winning!", RED's half of the prize, in RED's window, recorded with sound |
| Screens (scripted), Red: switches and a player faint | RED (PIDGEY L2, SQUIRTLE L30) fights BROCK with BLUE joined: "PIDGEY enough! Come back!" shrinks PIDGEY away, "Go! SQUIRTLE!" plays the poof and SQUIRTLE grows with its panel, and the same back; GEODUDE's TACKLE shakes the screen, PIDGEY's bar drains to 0, PIDGEY sinks and its panel goes before "PIDGEY fainted!", and RED sends out BLUE's CHARMANDER behind the poof; frames every eight frames |
| Screens (scripted), Red: player picture | Every co-op battle before D39 drew the player's Pokémon scrambled (Crystal's tilemap read with Generation 1's layout); side by side, the same frame now shows CHARMANDER's real back picture |
| Screens (scripted), Red: battle audio | Every earlier recording was silent from the battle's first frame (-91 dB): the session held the world screen, and the audio player inside it, under the panel (D38). With the audio player kept running, a Movie Maker recording of RED's throws at a wild PIDGEY peaks between -3 and -6 dB through the whole battle |
| Screens (scripted), Red: thrown balls | RED throws seven balls at a wild PIDGEY from the session menu: each plays the toss (GREAT BALL's own), the poof, PIDGEY hidden in a shaking ball, then the poof and PIDGEY back with "Shoot! It was so close too!" or "Aww! It appeared to be caught!"; the seventh catches it and "All right! PIDGEY was caught!" shows with PIDGEY still in the ball; frames every four frames and a recording with sound |
| Screens (scripted), Red: battle music | Both windows start the battle music the cache has for the fight when the battle opens, and a window's map music comes back when the battle closes (temporary log lines; inaudible until D38) |
| Screens (scripted), Red: opening and fanfare | A wild PIDGEY from the session menu opens with "Wild PIDGEY appeared!"; the win queued and played the wild fanfare (temporary log line) |
| Screens (scripted), Red: ZAPDOS | RED and BLUE stand beside ZAPDOS in the Power Plant; RED talks to it, then BLUE does, and BLUE is joined into RED's battle rather than given a second ZAPDOS ("BLUE joined the battle!"); "RED used MASTER BALL!" and "All right! ZAPDOS was caught!"; RED's team gains ZAPDOS once, and EVENT_BEAT_ZAPDOS reaches BLUE's world, so it is gone in both |
| Local x86_64, exit hang, co-op only | the co-op suites ran fifteen times in a row under the watcher and always exited, so the rare hang is not narrowed to them |
| Local x86_64, review fixes | twelve findings of a read-only review confirmed and fixed (D37), each with a test; co-op suites 87/87 |
| Screens (scripted), Red: after the review | the PC deposit and a reopened window's WITHDRAW, BLUE's SAVE during RED's battle ("The campaign was not saved: battle in progress."), and RED's handed-over ZAPDOS battle sending no save request |
| Local x86_64, exit hang | twice today a whole-suite run passed every test and then did not exit; four further runs under a watcher that would have dumped the stacks all exited cleanly, so the cause is still unknown |
| Local x86_64, fuzz | the fuzz test passes for seeds 2026, 7 and 99 in the suite and was also run once over twenty other seeds; every crash it found is fixed (D35); a 200-Pokémon PC crosses real sockets in one message |
| Launcher (scripted), Red: bring a save | A mid-game Red save in a scratch save root (two badges, VENUSAUR, PIDGEOTTO, PIKACHU, ¥9876) is chosen on the Co-op tab and hosted: the new campaign has both badges and Brock beaten, the party menu lists the three, and the trainer card shows ¥9876 with the BOULDER and CASCADE badges |
| Screens (scripted), Red: stand-in | RED starts the BROCK fight, BLUE joins, and RED's window is closed on RED's turn: within five seconds BLUE's window shows "PAUSED: waiting for RED to reconnect" and "RED is away. Waiting..."; thirty seconds later "YOUR TURN for RED's POKéMON" and BLUE moves RED's CHARMANDER until the battle ends |
| Screens (scripted), Red: Mart | BLUE buys a POKé BALL at the Pewter Mart: the window shows ¥3000 then ¥2800, and the host's record of BLUE (echoed in BLUE's own view) reads money 2800 and one POKé BALL |
| Screens (scripted), Red: portrait | RED's window at 540x960 in the Brock fight: the battle field fills the width at the top and the co-op panel sits under it |
| Local x86_64, whole suite after the loss fixes | 4908/4908; co-op suites 95/95; ENet demo 16/16; release gates pass |
| Local x86_64, whole suite after the sliding intro | 4907/4907; ENet demo 16/16; release gates pass |
| Local x86_64, whole suite after the trainer closing | 4906/4906; co-op suites 94/94; ENet demo 16/16; release gates pass |
| Local x86_64, save safety | a second write keeps the first checkpoint as `.bak`, a damaged campaign file is neither read with an engine error nor kept as the backup (unit test); whole suite 4905/4905, ENet demo 16/16, release gates pass |
| Local x86_64, whole suite after faint sounds | 4904/4904; ENet demo 16/16; release gates pass |
| Local x86_64, whole suite after the battle stage | 4904/4904; co-op suites 92/92; ENet demo 16/16; boot smoke and release gates pass |
| Local x86_64, whole suite after thrown balls and battle audio | 4902/4902; co-op suites 90/90; ENet demo 16/16; boot smoke and release gates pass |
| Local x86_64, whole suite after the hit effects | 4900/4900; co-op suites 88/88; ENet demo 16/16; boot smoke and release gates pass |
| Local x86_64, whole suite after the battle field | 4881/4881 twice; co-op suites 69/69; ENet demo 16/16; boot smoke and release gates pass. One earlier run passed every test and then did not exit (busy for minutes after GUT's summary); the rerun exited normally, and the cause is not known yet |
| Local x86_64, whole suite after trades | 4879/4879; co-op suites 67/67; ENet demo 16/16; boot smoke and release gates pass |
| Local x86_64, whole suite after story gifts | 4876/4876; co-op suites 64/64; ENet demo 16/16; release gates pass |
| Local x86_64, whole suite after the PC sync | 4873/4873; co-op suites 61/61; ENet demo 16/16; release gates pass |
| Screens (scripted), Red: leaving | RED picks LEAVE SESSION from the SELECT menu: RED's window returns to the launcher, the campaign file holds both players, BLUE's world shows "The session ended: host shutdown." and returns to the launcher three seconds later |

## Owner's rules (branch `coop/owner-rules`, 2026-10-07)

The rules the owner settled in D61, built as D62.

| Check | Result |
|---|---|
| Local x86_64, whole suite | 4977/4977, exit 0; co-op suites 164/164 |
| Local x86_64, sockets | ENet demo 16/16; three-process check: host 4/4, p1 7/7, p2 8/8; boot smoke and release gates pass |
| Tests: leaving | a joiner leaves, walks, is seen again and starts nothing; the partner decides for the Pokémon left behind; it keeps the experience it earned; the initiator cannot leave; REJOIN from the session menu; a queued join is called off |
| Tests: stand-in | paused with no stand-in for 30 s, then `stand_in_due`; only TAKE OVER hands the turn over; the owner takes it back and is waited for again the next time; a battle nobody is in is kept 2 minutes, not 30 s |
| Tests: rewards | each participant gets the whole trainer prize; one EXP.ALL pays each team what it would pay that team alone, whoever carries it |
| Tests: gifts | the EEVEE ball, a Dojo gift and their flags stay with the player who took them and are saved with them, the Dojo's beaten flag reaches everyone; a found item two windows hand out at once is kept once, a purchase in the same change is not taken back |
| Tests: world fight while busy | a fight the window's world opens after leaving waits until the old battle ends, then starts on the host and is won |
| Screens (scripted), Red, 60 fps | a fresh campaign: RED fights a wild PIDGEY from the session menu, BLUE joins ("BLUE joined the battle!") and sees LEAVE BATTLE; BLUE leaves and is back in Pallet Town with RED marked "!" where the battle is; BLUE's SELECT menu offers "Rejoin the battle against wild PIDGEY" and rejoins; RED's window is closed, and 30 s later BLUE is asked "RED is still away. Take over their POKéMON, or keep waiting?"; TAKE OVER gives "RED is away: you choose for their POKéMON." and "What will CHARMANDER do?". The local campaign file was set aside for the run and put back unchanged |
| Not run on screens | EXP.ALL, the full prize, gift Pokémon and the race, and a world fight waiting after leaving: tests only |

## Playable round (branch `coop/playthrough`, 2026-10-07)

The owner parked the hand-played session and asked for everything as close to
playable as possible, a hand-test list kept per feature (`test-cases.md`), and
a two-window check of each feature (D65).

| Check | Result |
|---|---|
| Local x86_64, whole suite on the merged branch | 4983/4983, exit 0; 4989/4989 after the launcher check merged |
| Two windows, `leave_rejoin_takeover` | as on `coop/owner-rules`, now run by `tools/coop_screens.sh` in a private user folder; the owner's campaign file unchanged (checked by hash) |
| Two windows, `playthrough_brock` (autoplay, 4x speed) | three clean runs, about five minutes each: both players play Oak's speech and the lab, the rival fight, OAK'S PARCEL (fetched by one, delivered by the other, taken from both), Route 1, Viridian Forest and its BUG CATCHER, the Pewter Gym; the second window walked into BROCK mid-fight and joined (one battle, participants P2 and P1, each paid ₽1386), the BOULDERBADGE and TM34 reached both players; 0 errors in every process |
| Two windows, `playthrough_misty` | first run: both through Mt. Moon (SUPER NERD, the fossil), Cerulean and MISTY's CASCADEBADGE, 45 battles, 0 errors; it showed the fossil reaching only the player who took it (fixed, D67). Two runs then whited out from poison on the walk (cartridge behaviour; the autopilot now heals and cures when hurt). Fourth run, with D67: both players hold the DOME FOSSIL, both badges, TM11 and TM34, 47 battles, 0 errors |
| Two windows, `catch_for_partner` | RED fights a wild PIDGEY, BLUE joins, RED throws a POKé BALL naming BLUE: "Caught for BLUE!", the PIDGEY is in BLUE's party with BLUE as its trainer, the ball came out of RED's bag (5 to 4), BLUE's untouched; scenarios can now pick a panel row by name (`@THROW.+BLUE`) |
| Two windows, `switch_and_suggest` | BLUE joins and moves the cursor: RED's panel shows "SQUIRTLE L12 BLUE ◀ BLUE"; RED switches to BLUE's SQUIRTLE and the turn is BLUE's ("What will SQUIRTLE do?"); BLUE switches back and it is RED's again |
| Two windows, `lose_and_white_out` | RED alone loses to a wild ONIX L60: RED's window halves RED's money (3000 to 1500), heals the party and wakes in Pallet Town; BLUE untouched. A level 60 GEODUDE was tried first and blew itself up, which the cartridge counts as a win |
| Two windows, `save_from_start_menu` | RED saves from START: "Campaign saved." in RED's window and "RED saved the campaign." in BLUE's; with BLUE in a battle RED's next SAVE ends in the game's box with "Save failed: battle in progress" (after D70 with no YES/NO left behind it) |
| Two windows, launcher (D69) | `launcher_host_join`: RED hosts WITH BLUE from the Co-op tab with CHARMANDER, BLUE joins by address and plays the opening (rival named from the offered list), RED hears "BLUE joined the session." and the session menu says "With BLUE (in the opening)". `launcher_leave_rehost`: BLUE leaves, RED leaves, RED hosts SECOND, RED leaves while BLUE is in and BLUE lands on the Co-op tab with "The host closed the session.", RED picks FIRST from the list and BLUE rejoins as the same player; each campaign file holds RED and BLUE once (the scenario's `check()`). Both rerun on the merged branch, captures looked at. Five fixes from these runs (D69), each with a test |
| Two windows, `cable_club_trade` (autoplay) | After BROCK both go to Pewter's Pokémon Center, P1 is given a level 20 MACHOKE by the save editor (the host files it as `p1:3`), both talk to the Cable Club receptionist, save, pick TRADE CENTER, meet and sit at the table. Round 1: P1 offers MACHOKE, P2 MANKEY, P2 picks CANCEL; neither team changes on the host. Round 2: both TRADE; the host swaps once and saves. P2's movie shows "No.067 MACHOKE OT/P1" and "Take good care of MACHOKE.", then "MACHOKE evolved into MACHAMP!" (D64). Saved: P1 [p1:2 MANKEY, p1:1 CHARMANDER, p2:2 MANKEY], P2 [p2:1 SQUIRTLE, p1:3 MACHAMP]; five Pokémon before and after, each uid held once. Four runs in a row passed (about six minutes each) and two more on the merged branch, the second with D71 (the Trade Center shows no leftover wait box); the scenario's `check` reads the saved file |
| Tests: D63, D64, D66, D67 | `test_vermilion_gyms_locks_are_shared_and_a_surf_score_is_its_players_own`; `test_a_trade_evolver_is_shown_as_sent_and_arrives_evolved`; the journal and format 2 tests in `test_coop_state` and `test_a_win_and_a_gift_while_another_battle_runs_survive_a_crash_of_the_host`; `test_a_gift_given_before_its_scripts_flag_still_reaches_every_player` and `test_a_window_in_a_script_takes_the_partners_story_once_the_script_ends` |

## To the Hall of Fame (branch `coop/playthrough`, second session, 2026-10-07)

The owner settled the open questions (D72); the work follows the issues.

| Check | Result |
|---|---|
| Merge of `coop/autoplay-surge` (#87, D73 to D75) | co-op suites 179/179; whole suite 4993/4994, the one failure `tasks.md` naming a folder only this machine has (docs fixed); 4995/4995 after the #86 merge; release gates pass |
| Two windows, `playthrough_misty` on the merge | both players to MISTY's badge in 600 and 624 s, 51 battles, 0 errors; the last capture shows both in Cerulean Gym |
| Two windows, `cable_club_trade` on the merge | passes in 367 and 385 s: MACHOKE arrives in P2's party and evolves into MACHAMP, five Pokémon before and after, each uid once |
| Seeded runs | `SEED=<dir>` and the autopilot's `from=<leg>`: two windows opened on a campaign saved after LT. SURGE, both on their saved cells in Vermilion Gym, and finished `from=lt_surge` at once |
| #86 (D76), upstream: a no-press box held up by its row's own fade | `CloseTextDisplay` now takes it down at the row's end (`_gen1_close_text_display`); test `test_a_gen1_rows_end_takes_down_a_no_press_box_its_fade_held_up`; on the Red import the thief's leg passes and the player walks on, and upstream's `played` check passes from the intro to the Cerulean Gym exit (30 battles). Cosmetic, not fixed: the receipt's `text_waitbutton` shows an arrow and an empty last page where the cartridge keeps "Bye!" through the fade |
| Two windows, `playthrough_surge` from a new campaign (#87, #86) | both players from Oak's speech to LT. SURGE's THUNDERBADGE in 1270 and 1244 s, 78 battles, 0 errors, with no workaround: the thief's leg passes with no box left on Route 5 (D76). The first try stalled on Route 25: the autopilot's heal never restored PP, so an ODDISH fought a LASS with ACID spent and only status moves that could not land; the heal now restores PP as a Pokémon Center does. Seen in the passing run, left for #84 step 2: P2's window plays LT. SURGE's TM24 lines though P1 led the fight (the gym bytes are still shared) |
| #84 (D72, D79), share at rest points | eight new GUT tests and two more in the logs and save-refusal suites, each change broken on purpose once to see a test fail; on the agent's branch whole suite 5008/5008, co-op suites 192/192 (192/192 again on the merge). Two windows: `rest_points` (new) twice: P2 stands in Pewter Gym while P1 fights BROCK, BROCK's whole scene leaves P1 as one patch (longest hold 2999 frames), each player holds one TM34 and P2's window never takes the gym's step; `playthrough_misty` (639 and 614 s, 55 battles) and `cable_club_trade` pass. The first Misty run stalled at Mt. Moon B2F: pulled object hides changed the state but not the live objects, so the fossils barred the way out (fixed, `load_object_masks`) |
| D80, a checkpoint only on a real SAVE | `save_written` from `persist_world_snapshot`; the save tests now tell a heal's snapshot from the world's SAVE; whole suite 4992/5008 with the 16 `test_coop_device` tests refused their fixed ENet port by an agent's suite running beside it, then 19/19 alone |
| Two windows, `playthrough_surge` on the rest points (D79) | from a new campaign both players reach the THUNDERBADGE in 1259 and 1242 s, 71 battles, 0 errors; the saved campaign has three badges and each player holds HM01, TM11, TM24, TM28 and TM34 exactly once |
| #88 stretch `koga` (D81), seeded from the story after Pokémon Tower | two passing runs (543 and 507 s), 0 errors: SNORLAX woken with the POKé FLUTE and fought by both (one battle), gone for both; each player catches in the Safari Zone (RHYHORN, NIDORAN♂ on the host team and in the save); HM03 and the GOLD TEETH, then HM04, reach both; KOGA fought by both, SOULBADGE. Found and fixed: the Safari Game flags were the campaign's (the partner was warped to the gate), and every ball asked for a checkpoint. Co-op suites 194/194 on the merge |
| #88 stretch `tower` (D82), seeded from the story after the Rocket Hideout | the car, the Game Corner, Route 7, the underground, Route 8, Lavender, the tower floor by floor, Mr. Fuji: three passing runs on the merged branch (331/361 s on the last), 0 errors, each player with one POKé FLUTE in the window and on the host. MAROWAK fought by one and joined by the other from the menu; the 2F rival one host battle both fought (each window plays the rival's lines, #24); without the SILPH SCOPE a wild battle stays the window's own GHOST (D68). Found and fixed: the purified zone flag looped between the players; a partner's taken item ball stayed solid (D79 fixes it too). Co-op suites 195/195 on the merge |
| #88 stretch `erika` (D83) | Rock Tunnel, Celadon and ERIKA, the Game Corner, the Rocket Hideout's spinners, the LIFT KEY, GIOVANNI and the SILPH SCOPE. Seeded from the run after LT. SURGE: pass in 766/761 s, 0 errors; `playthrough_erika` from a new campaign: pass in 2008/1983 s, 110 battles, 0 errors, BROCK and MISTY joined, ERIKA joined from SELECT, GIOVANNI fought by both; each player holds the RAINBOWBADGE, SILPH SCOPE, LIFT KEY and TM21 once. Found and fixed: a DISABLEd move the panel kept offering. Co-op suites 196/196 on the merge; a seeded window run caught a constant both stretches declared (the GUT suites do not load the autopilot) |
| #24 (D84), the first window into a rival scene drives it | six GUT tests; whole suite 5014/5014 on the agent's branch, co-op suites 202/202 on the merge; the ENet demo and the three-process check pass with protocol 5. Two windows: `rival_scene` (RED meets the Route 22 rival, BLUE crosses into Route 22, is held under the line, cannot walk, JOINs the battle with SELECT, then walks on with the rival gone) and `rival_scene_killed` (RED's window closed inside the rival's text: BLUE let go at once, the campaign keeps the rival waiting, RED reopened meets him from the start). An autoplayed run from Mt. Moon to LT. SURGE held the partner at Cerulean and on S.S. Anne 2F with no replay. Only the first Route 22 fight has its own scenario; Pokémon Tower 2F, Silph Co. 7F and the second Route 22 fight are covered by the tests and the shared code |
| #88 stretch `sabrina` (D85), from the KOGA run's campaign | Fuchsia back to Celadon's roof for FRESH WATER, Saffron's gate, Silph Co. (the CARD KEY, the pads, LAPRAS, the 7F rival, GIOVANNI, the MASTER BALL) and SABRINA: pass in 499 s on the merged branch with D84, 0 errors; MARSHBADGE in both windows, one MASTER BALL each, each player's own LAPRAS; the 7F rival held the second window, which joined; GIOVANNI and SABRINA fought by both. No co-op code change; two autopilot deadlocks of solid partners in one-tile corridors fixed in the legs |
| Two windows, `playthrough_koga` from a new campaign (first chained run) | both players through BROCK, MISTY, LT. SURGE and the ERIKA stretch to GIOVANNI's SILPH SCOPE (112 battles, 0 script errors), then both stalled at the tower stretch's first leg in the Rocket Hideout's elevator: one window's elevator shake wait never ended while it stood on the panel cell. Under investigation |
| #88 stretch `blaine` (D86), seeded in front of SABRINA | Saffron Gym's pads out, SURF to the Seafoam Islands (one player drops the STRENGTH boulders, the partner surfs the calm water), each player's DOME FOSSIL and KABUTO, the Pokémon Mansion's switches and SECRET KEY, Cinnabar Gym's quiz gates (a partner's answer opens the gate in both windows) and BLAINE fought by both: two passing runs (634/630 s and 689/680 s), 0 script errors; VOLCANOBADGE and exactly one TM38 each, in the window and on the host. Three GUT tests; co-op suites 205/205, whole suite 5021/5021. Not run: the chained run from a new campaign. |
| The chained run's Rocket Hideout car stall | the autopilot, not co-op or game code: since the ERIKA stretch its car leg always chose B4F, so the tower stretch rode back to B4F every 300 frames and the watchdog's samples fell inside the shake; with both windows in the car the waiting one also blocked the only path from the panel to the door. Each panel leg now names its floor and a waiting window stands aside. Reproduced before the fix; four seeded two-window runs pass after it, two with both windows in the car at once (one from Celadon through the hideout to the POKé FLUTE, 501/500 s). Seen once, not looked into: a partner who just entered the car was not drawn in the other window while its elevator script ran. |
| Two windows, `playthrough_blaine` from a new campaign (second chained run, after the car fix) | both players through BROCK, MISTY, LT. SURGE, ERIKA, the Rocket Hideout car (both ways) and Pokémon Tower to 6F, 0 script errors; then p2, reaching 7F after p1 had rescued Mr. Fuji, never moved off the stairs (the autopilot's route out), and p1 waited beside SNORLAX until its watchdog fired. Being fixed on `coop/tower-7f-late`. |
| Pokémon Tower 7F for a late partner | upstream's `played.gd` never stepped off a stair warp it stood on to take it back (the route out of 7F was the stairs the late window came up). Fixed there in four lines. Reproduced before the fix; after it, a seeded run with p2 reaching 7F after p1's rescue passes through KOGA (524/520 s, 0 errors: one POKé FLUTE each, one SNORLAX battle, SOULBADGE for both), and a normal tower run passes. Upstream's `validate.gd -- played` on Red still reaches the last badge. Seen in a run from a story-level seed, not looked into: after a whiteout to Pallet the autopilot's way back stuck on Mt. Moon B2F (25,9). |
| #88 stretch `victory` (D89, D90), seeded after BLAINE | SURF to Pallet and Viridian, GIOVANNI fought by both (EARTHBADGE, one TM27 each), Route 22's second rival (one window drives, the other joins), Route 23's guards, Victory Road's boulders and switches to the Indigo Plateau lobby. Three bugs found and fixed: a partner's switch left the wall shut in a window on the floor; the cartridge's switch resets walled in a partner still inside; a Generation 1 wild fight's reload closed a switch's block (upstream). Three GUT tests, each failing without its fix. Passing: three runs from Cinnabar (about 9 to 10 min, 0 script errors), two from SABRINA through BLAINE and victory (about 20 min), one through victory and the Elite Four to both Halls of Fame. Whole suite 5030/5030. Not run: the order of one player leaving Victory Road first, on screen (GUT test only). |
| D92, one drink opens Saffron's gates for the team | three GUT tests; co-op suites 216/216, whole suite 5033/5033. Two windows, the SABRINA stretch seeded in Fuchsia: only p1 bought and gave the FRESH WATER, p2 got the campaign's flag standing in Route 7's gate and walked through, both finished through SABRINA, 0 script errors. Not walked: the gates on Routes 5, 6 and 8 (same flag). |
| D93, the Elite Four as one run for the team (replaces D87) | three GUT tests replace D87's; whole suite 5032/5032 and the ENet demo on the agent's branch. Two windows seeded in the lobby: a team run passes (435/460 s, 0 script errors; five host battles, the partner never talks to a member, its own Champion ends at once as won, both Halls of Fame, then the clear); with `WHITEOUT=1` p2 loses to BRUNO, the host holds the clear while p1 is inside, p2 walks back through LORELEI's open exit and the run goes on to both Halls of Fame. Seen only in GUT tests: a late arrival who never joined, the rematch after the clear, a disconnect inside. |
| Two windows, `playthrough_elite` from a new campaign (third chained run, before D92 and D93) | about 3 h with 0 script errors through BROCK, MISTY, LT. SURGE, ERIKA, the Rocket Hideout car, Pokémon Tower (both fixes held), SNORLAX, the Safari Zone, KOGA and Saffron into Silph Co.; then both windows froze on 7F in a Silph worker's text box drawn with doubled lines, still revealing after 420 s, right after p1 joined a battle from the menu. Being diagnosed on `coop/silph-7f-stall`. |
| The Silph Co. 7F freeze | the autopilot, not the game: a full party sends the gift LAPRAS to the PC box, and the `lapras` leg looked only in the party, so both windows talked to the worker for 420 s (the doubled lines are how scrolling pages are listed). The autopilot now looks in the party and every box (LAPRAS, KABUTO, the host's team). Reproduced from a full-party seed before the fix; after it the same seed passes through SABRINA (320 s, 0 errors), and the failed run's own campaign passes from `lapras` (183 s). Not run: BLAINE with a full party. |
| The third chained run's campaign continued from LAPRAS | Silph Co. 7F, GIOVANNI and SABRINA pass (0 script errors); then the BLAINE stretch failed at its first leg: the autopilot teaches SURF only to party members, and p1's real party had no SURF learner (LAPRAS was in the box). Being fixed on `coop/seed-party` with the full-party audit. |
| Full parties in the autopilot and `party=<n>` seeds | when no party member can learn an HM the autopilot boxes a member without a field move and takes a learner from the PC (LAPRAS for SURF); a catch or gift with six in the party boxes one first. The continued campaign then passes from LAPRAS through BLAINE (1006/980 s, 0 script errors; LAPRAS kept its uid, KABUTO went to BOX 1). One GUT test for the seed option; co-op suites 219/219. Seen once from a `party=6` seed, being looked into: a window on Seafoam B4F never sent the two flags for the first boulders dropped on B1F and B2F, so the current stayed on. Not run: a grind catch or the trade's MACHOKE with six in the party. |
| D94, the Seafoam boulders lost to a partner on Route 20 | a co-op sync loss: `EVENT_IN_SEAFOAM_ISLANDS` was the campaign's, so a partner on Route 20 cleared it and sent Route 20's boulder reset, and a boulder the player inside had dropped vanished. Now each player's; a host drops the cartridge's own walk flags from an older campaign; the autopilot's hole pushes end on the hole's flag. Two GUT tests fail without the fix; whole suite 5038/5038. Two seeded runs from a `party=6` seed pass through BLAINE (one with all six hole flags checked); the race itself is shown by the failing run's logs and the GUT test, not reproduced live. |
| Two windows, `playthrough_elite` from a new campaign (fifth chained run, `bffff782`) | 0 script errors to Pokémon Tower; p1 rescued Mr. Fuji and went on, p2 arrived late, left 7F by the stairs (the earlier fix held), then stood still on 4F at (10,9) on its way down to Mr. Fuji's house until the leg timed out. Being fixed on `coop/tower-late-descent`. |
| The fifth run's tower descent | the autopilot, not routing or co-op: its move choice in co-op battles ignored type, so a GROWLITHE lead used TAKE DOWN on every GASTLY for no effect and each wild battle took about 100 s, pushing the six-floor descent past its limit. Moves are now weighed by type effectiveness. From the fifth run's own campaign: 7F to Mr. Fuji's house in 80 s, both windows through KOGA (563/559 s, 0 script errors); from 4F in 21 s. Seen once, not yet fixed: a Safari Game ending with no catch leaves the autopilot standing at the gate. |
| D96, run snapshots and `tools/coop_resume.sh` | one GUT test (a snapshot copy changes nothing, writes no checkpoint, counts no SAVE, is refused mid-battle); whole suite 5039/5039, ENet demo. A seeded tower run killed after 190 s left 12 snapshots with each window's leg; resumed from #8 with the windows on different legs (Lavender and Tower 2F) and from the last one, both passed with 0 script errors. Not run: thinning in a real long run, a resume from a repeated leg name. |
| #50 German Red and Blue (D95), static | offsets mapped from pokered-de's symbols against English pokered by symbol name (322 moved, 25 pinned facility slots); renamed labels and mid-routine offsets checked by hand; Blaue's shift checked against `pokeblue.sym` |
| #50 German, tested | whole suite 5043/5043 with the German layout, charmap, registry and mixed-join refusal tests; boot smoke, ENet demo, gates |
| #50 German, imported | both owner dumps (sha1 checked) pass `import_rom --verify` and import (151 species, 165 moves, 226 maps) in an isolated user folder; map-script decoding refuses nothing on either. Six import failures found and fixed (listed on #50) |
| #50 German, played | headless: `validate.gd played` takes red_de and blue_de to MISTY's badge. Two windows: red_de through `playthrough_brock` to BROCK, 0 script errors; `german_menus` on red_de (and a scratch run on blue_de). Not played: Blaue in a two-window playthrough. Open: about 400 English literals the engine writes (mostly Gen 2), the save box's label column, fixed-column menus with longer German words, Blaue's opening frame timings |
| The Safari Zone's empty game | the autopilot, not the game: it paced grass cells that, as on the cartridge, never roll a wild (42 of the center's 189), spent all 500 steps, and then had no leg for the gate. It now walks only grass that can meet a wild, and pays again after an empty game. From the fifth run's campaign both windows pass through KOGA (537/532 s, 0 script errors); a seeded KOGA run passes; a forced empty game paid again and caught. Limit: a game that runs out on the way to HM03 or the GOLD TEETH still stalls. |
| The seventh chained run, resumed (D96) | the run (snapshots on, started before the Safari fix) stalled at hour 2.5 on the empty Safari Game; `tools/coop_resume.sh` from snapshot 178 on the fixed code then filled p1's box: a resume at `safari_catch` skipped the step that records the team size a catch counts against, so 21 catches went unnoticed. A resumed leg now keeps the note steps in front of it, and a full current box changes to one with room. Host and window agreed on the box throughout. Snapshot 178 then passes through KOGA as is, and with box 1 filled to 20 (the catch lands in box 2 on the host); one GUT test pins the host's box change. |
| The roof deadlock (resumed seventh run) | both through KOGA, then the partner, second onto the department store roof, waited on the stair cell the drinker had to pass (D92's legs). The partner now waits under the vending machines, and both waits count the partner's movement as progress. Resumed from snapshot 20 of the resumed run: both through SABRINA, 0 script errors; whole suite 5040/5040. |
| **#88: a new campaign to both Halls of Fame in two windows** (seventh chained run, resumed twice from its snapshots, D96) | from Oak's speech in a new campaign through all eight gyms, the Rocket Hideout, Pokémon Tower, Silph Co., Seafoam, Cinnabar, Victory Road, the Elite Four and the Champion to both Halls of Fame, credits and Continue in Pallet Town, and the team's League run cleared for the campaign. Three segments: Oak's speech to the Safari Zone (stopped there by the empty Safari Game), snapshot 178 to the department store roof (stopped by the roof deadlock), snapshot 20 to the end (exit 0, both windows `finished`). 0 script errors in every host and window log. Looked at: LANCE's room with its exit open, the Champion, both Halls of Fame. Not yet: one unbroken run on the final commit. |
| Unbroken run on `main` (`FPS=120`), first try and its resume | a new campaign to the Rocket Hideout car in 37 minutes, where both windows, arriving together, traded the panel cell forever (fixed: only the second player yields). Resumed from snapshot 105 with the fix: the car in 1 s each, then on to both Halls of Fame and the League's clear in 51 minutes (3069/3044 s), 0 script errors in host and windows. A whole run at 120 frames a second takes about 1½ hours. |
| #88 stretch `elite` (D87, D88), seeded in the Indigo Plateau lobby at level 60 | the lobby nurse, LORELEI, BRUNO, AGATHA, LANCE (the lead alternating, the partner joining from SELECT and then winning at once), the Champion joined from LANCE's room, each window's own Hall of Fame, credits and Continue in Pallet Town: six runs, the last three pass, the last with 0 script errors. Found and fixed on the way: a won joined battle blacked out an initiator whose own team fell; the Hall of Fame's reset dropped the window to the saves page. Co-op suites 211/211, whole suite 5027/5027, ENet demo and three-process check pass. Not run: the chained run, an Elite Four rematch, a whiteout inside the League, Windows and the launcher path. |
| #85 (D77), Vermilion Gym's first lock kept while a partner is near | two GUT tests; two windows, `vermilion_locks` from an edited after-Surge seed: BLUE walks from the Pokémon Center into the city twice while RED searches, BLUE's window rolls 6 (10 in another run) and keeps 4, RED finds the first switch in can 4 and opens the first lock; three passing runs. Control run with the change off: BLUE's entry sends lock 10 and RED finds only trash in can 4 |
| Campaign seeds (D78) | `tools/coop_seed.gd` writes a two-player campaign at any of upstream's 30 Gen 1 story legs in 5 to 7 s, byte for byte the same each time; ten seeds, one per later stretch start, each opened in two windows (`story_seed`): both players where the story left them, side by side, the party right, 0 script errors; the autopilot finished `from=lt_surge` at once on the Vermilion seed. Against the real run's campaign after LT. SURGE the story seed has the same badges and 62 of its 66 story flags (three trainers the story's path skipped, and `EVENT_WALKED_OUT_OF_DOCK`), and no host `defeated` encounters or gift commits |
| Phone softlock after a battle (2026-10-09, played on an iPhone) | the panel freezes the world screen, and the on-screen pad with it, so a phone could only tap rows, and a finished battle had none: the result could not be closed. The pad now runs under a held world (the tappable CLOSE and BAG row of that fix were replaced by D98). GUT: co-op suites and the whole suite pass; two windows: `catch_for_partner`, the result shows `> CLOSE`. Not yet played on the phone again |
| Battle menus on the world screen (#99, D98) | co-op battles drawn in the world's own 160x144 screen with FIGHT/PKMN/ITEM/RUN, the move list with TYPE/PP, the party list over both teams, the bag, YES/NO questions and a ball's recipient list; no side panel. Tests: whole suite passes (see the PR); two windows 2026-10-10, captures looked at: `switch_and_suggest`, `catch_for_partner`, `leave_rejoin_takeover`, `lose_and_white_out`, `playthrough_brock` (both windows finished, 0 script errors), `start_coop_menu`; a 540x1170 window with the touch pad forced on (battle at the top, pad visible). Not checked: a German window, the learn and Mimic screens on screen (GUT only), a real phone |
| Suggestions at every menu level (#99, D98) | the partner's hollow ▷ on the main menu and the row, initials with three players, "BLUE suggests / SQUIRTLE" in the idle controller's box, a ball's recipient. GUT (two and three players); seen in `switch_and_suggest` and `catch_for_partner` |
| A battle closes by itself (#98) | the result needs no A: seen in `catch_for_partner` and `lose_and_white_out`; GUT |
| START > CO-OP and gestures (#99, D99) | CO-OP in the START menu of a co-op world only; the session menu on the 160x144 screen (offers, JOIN/REJOIN with the foe, LEAVE asked YES/NO, partners and last save); SELECT still opens it; swipes and taps over the screen while it or a co-op battle is open. GUT; two windows: `start_coop_menu`, `leave_rejoin_takeover`, `catch_for_partner`, `save_from_start_menu`, `playthrough_brock`, `german_menus` (red_de), `launcher_host_join`, `launcher_leave_rehost`. Gestures in GUT only; not played on a phone |

## Upstream 0.1.75 (branch `coop/upstream-sync`, 2026-10-09)

Upstream `v0.1.75` merged into `main` at `d1087a8` (D97, #14); Godot 4.8-dev7.
A cloud session with no cartridge: everything below runs on the synthetic cache.

| Run | Result |
|---|---|
| Local x86_64, dev7: import | passed, no script errors; the import rewrites 26 `.import` files with new default keys, which are not committed (upstream does not either) |
| Local x86_64, dev7: whole suite | 5078/5078 (196 scripts, 150885 asserts, 450 s) |
| Local x86_64, dev7: co-op suites | 223/223; ENet demo 16/16; three processes: host 4/4, p1 7/7, p2 8/8; boot smoke passed |
| Local x86_64, dev4: `main` before the merge, for comparison | whole suite 5030/5047: the 17 failures were all `test_coop_device`, whose fixed port 24791 a parallel run held; its co-op suites alone 223/223 |
| Engine-free gates | version 0.1.75 everywhere, comments 41343 of 41343 |
| Screens (scripted), Red | not run: no cartridge in the merging session; `playthrough_brock` and `cable_club_trade` are the owner's checks before the merge (P05) |
| Stuck in the Trade Center (2026-10-11, played: Linux host, Windows partner) | Generation 1's Cable Club rooms have no exit; the cartridge leaves them by a reset that continues at the receptionist, where the save before the link put the player. A co-op continue used the player's last reported cell, in the room, so a reset and a new host both opened inside it again. The host now keeps the cell the room was entered from (and the last map the center's door leads to) and a continue and the campaign file use it. GUT: co-op suites 232/232; not yet played again |
| Red and Blue together (D101, 2026-10-12) | the host lets in the other game of a language pair when both are verified dumps; `coop_screens.sh` takes `P2_GAME`. GUT: co-op suites pass except three `test_coop_device` launcher tests that fail the same way on the base branch in a full local co-op run (they pass alone; CI green on #105). Two windows, the owner's dumps imported into a scratch folder: `catch_for_partner` red+blue, `red_and_blue` (friend battle and trade) red+blue and red_de+blue_de, `playthrough_brock` with a Red host and a Blue window (both reached BROCK, 0 script errors); captures looked at. Not played by hand |
| German check (#50, 2026-10-12) | every German line of `Gen1LayoutDe.UI` searched for in the owner's Rote Edition dump: 182 of 217 and all 12 `WORDS` are the cartridge's own text, the naming screen's two are its pieces, three too short to tell; the rest is co-op wording, listed in `docs/coop/german-wording.md` for the owner. Two windows: `playthrough_brock` on blue_de (both reached BROCK, 0 script errors; the text dump shows no English line); `pokedex_entry` on red_de and blue_de seeds (GLUMANDA 0.6m, 8.5kg). Found and fixed: a trainer's win line printed `<PLAYER>` (English too) |
| German everywhere (#50, D102, 2026-10-12) | the engine's remaining English lines in German games now use the cartridge's words (267 of 356 table lines found in both dumps, 7 more in the cartridge's pieces, 82 project wording), co-op messages and refusals included, and German column layouts for SAVE, JA/NEIN, battle, Safari, PC and Cable Club. Found by a German two-window playthrough (Rote host + Blaue partner) from Oak's speech to Pokémon Mansion 3F (autopilot stall there; seeded later runs stalled before VIRIDIAN) plus static search. Tests: full suite 5102/5102; two windows on red_de + blue_de: `german_menus`, `friend_menu`, `catch_for_partner`, new `german_screens`, `playthrough_brock`; English `catch_for_partner` unchanged; captures looked at. Not seen on screen: the Safari Zone, a fifth move learned, the mart, GIOVANNI to the Hall of Fame. The launcher stays English |
| Co-op tab redesign and protocol 7 (D103, 2026-10-12) | Start, Host, New campaign (rival's name), Edit campaign, Hosting, Join (Nearby, By address, Recent), Connecting, Failure, New player; light and dark; phone layout. GUT: `test_coop_lobby` plus probe, navigation, compact, rival/rename/delete and dial tests; whole suite 5118/5118; gates, ENet demo, two-process check. Two windows: `coop_tab_tour` (Rote host, Blaue joiner; 72 captures, both themes, wide and upright, looked at), `launcher_host_join`, `launcher_leave_rehost`, `playthrough_brock` (red_de + blue_de). Not run on a phone, on Windows, over a real VPN or between two physical devices; the phone layout was a 390x844 window with simulated insets |
| Both games' campaigns on Host (D103 follow-up, 2026-10-12) | the owner's Rote campaign vanished with Blaue selected: Host now lists the campaigns of both games of the pair, each card labelled with its game, and a Blaue cartridge hosts a Rote campaign from Rote's folder (the host's own window plays Blaue). GUT: `test_a_blaue_cartridge_lists_and_hosts_a_rote_campaign_from_its_own_folder`; co-op device suite 29/29; whole suite 5122/5122 (the machine's controllers hidden from the headless run, see below); gates, ENet demo 16/16, three processes. Two windows: `coop_tab_tour` (red_de + blue_de) passed with the new `host_other_version` captures, looked at. A Co-op tab test left its Joining sheet on the root, where the next test's Cancel could land: the suite now drops leftover sheets |
| Controller pick (owner's request, 2026-10-12) | every connected pad used to play at once. Settings > Controls > Controller picks one, kept in the options file by GUID, name, serial and order among twins; every pad binding in the InputMap (the eight and the launcher's `ui_*`) listens to that device only, found again after a replug; other pads' events are dropped before the launcher sees them; keyboard and mouse untouched. GUT: `test_pad_choice` (3 tests). Seen: the Controller row and its list on this machine's three real pads (scratch capture; the picked Xbox (2) answers `ui_down`, the DualSense does not). Not yet pressed by hand, not run on Windows. Local headless suites run under `bwrap --dev-bind / / --dev /dev`, since the owner's pads otherwise send stick events into timing-sensitive tests |
| Wild Pokémon from both versions (#110, D104, protocol 8, 2026-10-12) | the per-campaign switch in New campaign and Edit campaign; each window of a paired game sends its wild slots to the host, which passes the other version's on; in a slot where the other version has a Pokémon the player's own version never has in the wild, half the wilds there are that one, through `register_wild_substitute` (the owner chose exclusives only; Pokémon both versions have keep the cartridge's odds). GUT: `test_with_both_versions_the_other_versions_exclusives_take_half_their_slots`, `test_wild_pokemon_from_both_versions_is_a_campaign_switch_off_until_turned_on`, the wild substitute's `slot`; whole suite 5124/5124; gates, ENet demo 16/16, three processes. Two windows: `both_versions` on a `both` seed at `cerulean_thief`: Rote window (Blaue partner) met a wild MAUZI L10, then (exclusives only) KNOFENSA, on Route 6, and the other way round a Blaue window (Rote partner) met MYRAPLA, then MENKI; `coop_tab_tour` with the switch on (New campaign, card, Edit sheet, Hosting waiting for Blaue, then on); captures looked at. Not seen: the water tables, a catch of the other version's Pokémon, Red + Blue in English (same code, tables differ only in content) |
## Slice 1 acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Two client instances connect to a host | tests, socket, screens (scripted) |
| 2 | Each controls a separate player and sees the other on the same map | tests, socket, screens (scripted) |
| 3 | One player battles while the other explores | tests, socket, screens (scripted) |
| 4 | The second player starts an independent battle | tests, socket, screens (scripted) |
| 5 | A free player requests to join an ongoing battle | tests, socket, screens (scripted) |
| 6 | Joining happens at the next safe turn boundary | tests |
| 7 | Both owners' Pokémon appear in the shared roster | tests, socket, screens (scripted) |
| 8 | Switching Pokémon transfers turn control to its owner | tests, socket, screens (scripted) |
| 9 | The other player's advisory selection is visible without executing | tests, socket, screens (scripted) |
| 10 | Results update the correct Pokémon and player records | tests, socket, screens (scripted) |
| 11 | A trainer victory updates a shared flag exactly once | tests, socket (synthetic trainer); Brock offered on Red but not fought in a window |
| 12 | Save and reload at a safe checkpoint keeps both players and progress | tests, socket, screens (scripted) |

Every criterion has passed at the test level and in at least one run over
real sockets, and all but 6 and 11 were seen in the real game windows. Nobody
has **played** it by hand yet.

## Implemented

- Campaign and player state, exactly-once commits, versioned save (#2, #11).
- Allied roster up to twelve, per-owner experience, battle sessions with
  ownership-based turns, suggestions, joins, results, story commits (#3 to #8).
- Host, client, loopback and ENet transports; graceful shutdown and refusal (#9, #10, #12).
- Each window runs the real world on its own save, kept in step by world-state
  patches, party and PC copies against a revision (D23, D29); flags and badges
  are the campaign's, bag, money and position the player's.
- A window's own wild and trainer battles are fought on the host and can be
  joined from any map; unique trainers are one encounter for the campaign
  (D24, L1). Shared battles are drawn on the cartridge's battle field (D32).
- Captures for a named player, prize split, evolution, move learning and
  whiteout in each owner's world (D27).
- Player services in each window: Pokémon Center, Mart, Bill's PC (D29), and
  trades between players through the Cable Club with trade evolutions (D31).
- Story gifts (key items, HMs, gift TMs) reach every player (D30).
- Launcher Co-op tab: host or join, a starter or a trainer brought from a
  single-player save, whose story starts a new campaign (D26, D34).
- Several campaigns per host device, each its own named file, picked or
  started on the Co-op tab; a device is remembered per campaign (D49).
- The opening for new players, on a story of their own and hidden from the
  others until Oak's lab is left (D50); the rival's name and starter kept for
  the campaign.
- Every item found or given along the story reaches every player, and a key
  item the story takes is taken from all (D52); partners block the way (D53).
- Battles and trades ready for three or more players (D55); a refused SAVE
  fails in the game's own box (D56).
- Session logs on every device, shared between players by a debug stream, and
  merged, summarised and replayed by `tools/coop_log.gd` (D59).
- Lifecycle: leave from the session menu, end notices, return to the
  launcher, reconnection, autosave between battles, on leaving and when a
  hosting app is paused (D28); a stand-in for a controller who stays away
  (D33).
- Protocol hardening backed by a seeded fuzz test (D35).
- Gen 1 script bytes owned byte by byte (D63), the trade movie as sent (D64),
  a journal between checkpoints and format 2 (D66), and a script's changes sent
  as one patch (D67).
- A two-window scenario runner and a window that plays itself to BROCK's or
  MISTY's badge (D65); the launcher's Co-op tab checked in two windows, with
  five fixes (D69).
- The owner's rules (D61, D62): LEAVE BATTLE and REJOIN, a dropped controller's
  partner asked before standing in, a battle nobody is in kept two minutes,
  the full prize for every participant, EXP.ALL per team, gift Pokémon per
  player, and a gift two windows hand out at once kept once.

## Incomplete

- The host does not check collision and trusts reported warps, world patches
  and the enemies a window's world prepared: accepted by the owner (D72), the
  windows stay trusted.
- A battle that starts between the host's last state and a window's SAVE is
  still refused after the game's "saved" line, with the notice (D56).
- A shared battle is drawn on the cartridge's battle field (pictures, status
  panels, HP bars and the turn's messages in the game's text box), but it is
  not the battle screen itself (#26): move animations play with their sounds,
  hit sounds, blinks and screen shakes, thrown balls toss, shake and break out,
  pictures sink on a faint and grow out of the ball on a send-out, bars drain
  over the battle's music with cries, and a trainer win closes with the
  fanfare, the defeat line, the trainer sliding back in, their own line and the
  player's prize, and a battle seen from its start opens with the sliding
  intro (D39, D41, D42).
- Gen 2 enemy AI in sessions is a random usable move (#27).
- Reconnection is automatic on a dropped link (sixty tries, two seconds apart,
  with a notice), and a joining device back from a pause of more than three
  seconds redials at once (D46), but an Android or iOS suspend has not been
  tried on a device (#20, #45).
- The campaign is saved after battles, every thirty seconds of changes, when
  the host leaves and when a hosting app is paused, the checkpoint before is
  kept as `.bak`, and a failed write leaves the old file alone (D40); between
  checkpoints each story change is journaled with the players' state and read
  back after a crash, and format 1 files are upgraded once on read (D66); a
  real host crash, a power loss and a phone are untried.
- Private Windows and Linux builds come from `tools/verify.sh --builds`, but
  the Windows build has only run under Wine; there is no Android or iOS build
  (#44, #45, #46).
- Per-walk event flags such as `EVENT_IN_SAFARI_ZONE` are still the
  campaign's (D79). A gift two windows hand out at once is kept once (D62), but a race
  that also moves new story, or one that gives coins, is not caught.
- Upstream's `tools/dump_tables.gd -- red trainers` stopped on a missing
  `palette` key for Generation 1 trainers (#59); upstream 0.1.75 prints such a
  row as `monochrome` (static only, not yet run on a cartridge); see also L6.
- The autoplayed runs heal and cure their party between steps and grind with
  the save editor, as upstream's own check does, so they prove the co-op flow,
  not the difficulty; a whiteout ends a run rather than being retried.

## Blocked

- Nothing.

## Next concrete step

See the open issues on GitHub (the work, one issue at a time) and
[playbook.md](playbook.md) (the plan to a fully playable run). In short: share
the campaign at rest points (#84, #85, adopted in D72), let the first player in
drive a rival scene (#24), then play on to the Hall of Fame (#88) before the
owner's hand-played session (#44).
