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

The owner settled the open questions (D72); the work follows `tasks.md`.

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
| #85 (D77), Vermilion Gym's first lock kept while a partner is near | two GUT tests; two windows, `vermilion_locks` from an edited after-Surge seed: BLUE walks from the Pokémon Center into the city twice while RED searches, BLUE's window rolls 6 (10 in another run) and keeps 4, RED finds the first switch in can 4 and opens the first lock; three passing runs. Control run with the change off: BLUE's entry sends lock 10 and RED finds only trash in can 4 |
| Campaign seeds (D78) | `tools/coop_seed.gd` writes a two-player campaign at any of upstream's 30 Gen 1 story legs in 5 to 7 s, byte for byte the same each time; ten seeds, one per later stretch start, each opened in two windows (`story_seed`): both players where the story left them, side by side, the party right, 0 script errors; the autopilot finished `from=lt_surge` at once on the Vermilion seed. Against the real run's campaign after LT. SURGE the story seed has the same badges and 62 of its 66 story flags (three trainers the story's path skipped, and `EVENT_WALKED_OUT_OF_DOCK`), and no host `defeated` encounters or gift commits |

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
- Private Windows and Linux builds are exported, but the Windows build has only
  run under Wine; there is no Android or iOS build (#44, #45, #46).
- Per-walk event flags such as `EVENT_IN_SAFARI_ZONE` are still the
  campaign's (D79). A gift two windows hand out at once is kept once (D62), but a race
  that also moves new story, or one that gives coins, is not caught.
- Upstream's `tools/dump_tables.gd -- red trainers` stops on a missing
  `palette` key for Generation 1 trainers (#59); see also L6.
- The autoplayed runs heal and cure their party between steps and grind with
  the save editor, as upstream's own check does, so they prove the co-op flow,
  not the difficulty; a whiteout ends a run rather than being retried.

## Blocked

- Nothing.

## Next concrete step

See [tasks.md](tasks.md) (the next tasks in order) and
[playbook.md](playbook.md) (the plan to a fully playable run). In short: share
the campaign at rest points (#84, #85, adopted in D72), let the first player in
drive a rival scene (#24), then play on to the Hall of Fame (#88) before the
owner's hand-played session (#44).
