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
| Local x86_64, whole suite after the session lifecycle | 4865/4865; co-op suites 54/54; ENet demo 16/16; boot smoke and release gates pass |
| Local x86_64, `test_coop_device` | a device whose link drops dials again and is the same player; a host that leaves saves both players and the joiner hears `host_shutdown` |
| Screens (scripted), Red: PC | BLUE deposits RATTATA in Viridian's Pokémon Center PC; the host's campaign file has it in box 1 under its own uid; a new window session's WITHDRAW lists RATTATA L9 |
| Screens (scripted), Red: story gift | RED talks to Daisy in Blue's house and gets the TOWN MAP; BLUE, out in Pallet Town, opens the bag and finds a TOWN MAP too |
| Screens (scripted), Red: trade | RED and BLUE talk to Viridian's Cable Club receptionist, enter the Trade Center, see each other's real parties, and trade RATTATA for BLUE's MACHOKE; RED's window plays the trade movie and MACHOKE evolves into MACHAMP; the host's saved campaign has MACHAMP with RED (uid `p2:1`, OT BLUE) and RATTATA with BLUE (uid `p1:2`) |
| Screens (scripted), Red: battle field | RED fights BROCK from the session menu and BLUE joins: both windows draw GEODUDE and then ONIX against whoever is out, with HP bars and "CHARMANDER used SCRATCH!", "It's not very effective...", "Enemy GEODUDE used DEFENSE CURL!" in the text box; the turn passes to BLUE when SQUIRTLE is out; recorded as a side-by-side video |
| Screens (scripted), Red: move animations | In the BROCK fight, "CHARMANDER used SCRATCH!" is followed by the cartridge's claw marks over GEODUDE before "It's not very effective..."; recorded as a clip |
| Screens (scripted), Red: draining bars | After "Enemy GEODUDE used TACKLE!" CHARMANDER's bar goes 34, 32, 29, 27 frame by frame, and a turn's lines, animations and bars play in order before the next choice is taken |
| Screens (scripted), Red: move sounds | In the BROCK fight the field asked the world's audio player for four move sounds (SCRATCH, TACKLE, DEFENSE CURL rows), seen in a temporary log line; a Movie Maker recording has the audio track, which the overworld music dominates, so the sounds were checked by the calls rather than by ear |
| Screens (scripted), Red: battle music | Both windows start the battle music the cache has for the fight when the battle opens, and a window's map music comes back when the battle closes (temporary log lines) |
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
| Local x86_64, whole suite after the battle field | 4881/4881 twice; co-op suites 69/69; ENet demo 16/16; boot smoke and release gates pass. One earlier run passed every test and then did not exit (busy for minutes after GUT's summary); the rerun exited normally, and the cause is not known yet |
| Local x86_64, whole suite after trades | 4879/4879; co-op suites 67/67; ENet demo 16/16; boot smoke and release gates pass |
| Local x86_64, whole suite after story gifts | 4876/4876; co-op suites 64/64; ENet demo 16/16; release gates pass |
| Local x86_64, whole suite after the PC sync | 4873/4873; co-op suites 61/61; ENet demo 16/16; release gates pass |
| Screens (scripted), Red: leaving | RED picks LEAVE SESSION from the SELECT menu: RED's window returns to the launcher, the campaign file holds both players, BLUE's world shows "The session ended: host shutdown." and returns to the launcher three seconds later |

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
- Lifecycle: leave from the session menu, end notices, return to the
  launcher, reconnection, autosave between battles, on leaving and when a
  hosting app is paused (D28); a stand-in for a controller who stays away
  (D33).
- Protocol hardening backed by a seeded fuzz test (D35).

## Incomplete

- The host does not check collision and trusts reported warps, world patches
  and the enemies a window's world prepared (#22, #25).
- A world SAVE the host refuses (a battle is running) prints the game's own
  "saved" line, with the refusal shown over it as a notice (L2).
- A shared battle is drawn on the cartridge's battle field (pictures, status
  panels, HP bars and the turn's messages in the game's text box), but it is
  not the battle screen itself (#26): move animations play with their sounds
  and bars drain over the battle's music with cries and the victory fanfare,
  but there are no scroll effects, battler slides or sliding intro.
- Gen 2 enemy AI in sessions is a random usable move (#27).
- Reconnection is automatic on a dropped link (ten tries, two seconds apart),
  but an Android or iOS suspend has not been tried on a device (#20, #45).
- The campaign is saved after battles, every thirty seconds of changes, when
  the host leaves and when a hosting app is paused; there is no recovery
  journal or save migration yet (#39).
- No private desktop or mobile builds yet: this machine has no Godot export
  templates for 4.8-dev4 (#44, #45).
- Shared NPCs, scripts and cutscenes are not locked while one player uses them;
  two windows talking to the same gift giver at the same moment could both be
  given it (#24).
- Upstream's `tools/dump_tables.gd -- red trainers` stops on a missing
  `palette` key for Generation 1 trainers (#59); see also L6 and L7.

## Blocked

- Nothing.

## Next concrete step

Play a session by hand from the launcher's Co-op tab on two devices and note
what feels wrong in `tracking.md`. Then builds once export templates are
installed (#44), and the remaining battle-screen effects (#26).
