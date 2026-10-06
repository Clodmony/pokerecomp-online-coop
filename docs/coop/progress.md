# Co-op progress

What is implemented, what has been verified and how, what is incomplete and
what is blocked. Verification levels are kept apart on purpose:

- **static**: written and read, not executed;
- **tests**: GUT suites passing on Godot 4.8-dev4 (CI or local);
- **socket**: the ENet demo or separate processes over localhost;
- **screens (scripted)**: two real game windows on the owner's imported Red
  cartridge, driven by scripted button presses and checked from screenshots;
- **played**: people played it by hand.

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

Not on GitHub yet; see `tracking.md`.

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
- Real screens: other players as world actors, the co-op battle panel and the
  session menu, `tools/coop_play.gd`, and a Red host mode in
  `tools/coop_session.gd` (#13).

## Incomplete

- The host does not check collision and trusts reported warps, world patches
  and the enemies a window's world prepared (#22, #25).
- A world SAVE the host refuses (a battle is running) prints the game's own
  "saved" line, with the refusal shown over it as a notice (L2).
- The battle is a text panel, not the battle screen (#26): no animations,
  battle text or cries in a shared battle.
- Gen 2 enemy AI in sessions is a random usable move (#27).
- Upstream's `tools/dump_tables.gd -- red trainers` stops on a missing
  `palette` key for Generation 1 trainers (#59).

## Blocked

- Nothing.

## Next concrete step

Play a session by hand from the launcher's Co-op tab on two devices or two
windows and note what feels wrong in `tracking.md`. Then the battle screen in
place of the text panel (#26).
