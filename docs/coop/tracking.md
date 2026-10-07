# Local issue tracking

Issue status for the co-op work. GitHub was paused from 2026-10-06 to
2026-10-07; work found then got an `L` number, and each was filed as an issue
when GitHub use resumed (the table of found items gives its number).

Statuses: **done** (acceptance criteria met and verified locally),
**partial**, **in progress**, **open**.

## Branches

| Branch | Base | State | GitHub |
|---|---|---|---|
| `coop/slice-1` | `main` | pushed | draft PR #58 |
| `coop/m1-state-sync` | `coop/slice-1` | pushed: ownership, world and party sync, battle takeover, unique window trainers | draft PR #79 (stacked on #58) |
| `coop/launcher` | `coop/m1-state-sync` | pushed: everything from the Co-op tab to private builds, opening, campaigns, story items, logs | draft PR #80 (stacked on #79) |
| `coop/owner-rules` | `coop/launcher` | pushed: the owner's rules (D61) built (D62) | draft PR #81 (stacked on #80) |
| `coop/playthrough` | `coop/owner-rules` | pushed: test cases, two-window runner, autoplayed runs to MISTY and a Cable Club trade, the launcher check, #39, #66, #82, D67 to D71 | draft PR #83 (stacked on #81) |
| `coop/autoplay-surge` | `coop/playthrough` at `72a724fb` | merged into `coop/playthrough` (`91e8c1c6`, #87) | none |

## Issues

| # | Title | Local status | Where | On GitHub |
|---|---|---|---|---|
| 1 to 13 | Slice 1 | done | `coop/slice-1` | closed by PR #58 when merged |
| 14 | Upstream sync procedure and conflict hotspots | partial: every upstream file the fork changes is listed in `architecture.md`; no written merge procedure, no upstream merge tried yet | | keep open; merge 0.1.74 after #58, #79, #80 (D61) |
| 15 | Private CI: cost, caching and required checks | partial: `ci.yml` runs import, suite, boot and the ENet demo; paused with GitHub, the same steps run locally | | keep open |
| 16 | Classify every world, save and runtime field | done | `coop/m1-state-sync` (`9efac512`) | close when the branch merges |
| 17 | Run the world logic against a campaign plus player projection | done (each window runs its own world, synced by patches) | `coop/m1-state-sync` (`a151f505`) | close when the branch merges |
| 18 | GameRuntime co-op mode | done | `coop/launcher` (`65d6c0d6`) | close when the branch merges |
| 19 | Session handshake: protocol version, cartridge identity, no content transfer | done: the hello carries the protocol and the cartridge id and SHA-1, and a mismatch is refused with a reason the Co-op tab explains; nothing from the cartridge is sent | `coop/slice-1`, `coop/launcher` | close when the branch merges |
| 20 | Reconnection tokens and mobile suspend/resume | partial: a dropped link redials as the remembered player for about two minutes with a notice; a hosting app sent to the background saves the campaign; a joiner back from a pause redials at once (D46); no device suspend test yet | `coop/launcher` | comment, keep open for #45 |
| 21 | Protocol hardening: limits, schema validation and fuzzing | done: seeded fuzz test over every message type, boundary readers and shape checks, 2 MiB packet cap (D35) | `coop/launcher` | close when the branch merges |
| 22 | Per-player actors in the world simulation | done as the owner reads it (D72): the host keeps the campaign and battles, each window simulates its maps, NPCs and movement and shares at rest points | | closed 2026-10-07 |
| 23 | Remote players on the same map with interpolation | done | `coop/slice-1` (`PokeCoopRemoteActor`), screenshots in `progress.md` | close when the branch merges |
| 24 | Lock shared NPCs, scripts and cutscenes while one player uses them | open, approved (D72): the first player in drives every rival scene after the opening; gifts settled on the host (D62) | | keep open until built |
| 25 | Host-side wild encounters and trainer sight per player | won't do (D72): windows roll them, the host fights them | `coop/m1-state-sync` (`15028474`) | closed as not planned 2026-10-07 |
| 26 | Drive the battle screen from authoritative session events | partial: the battle field (pictures, panels, draining HP bars, turn text, move animations) is drawn from the host's view (D32), with move and hit sounds, blinks, screen shakes, palette effects, thrown balls, faints, recalls and send-outs (D39), battle music, cries and the victory fanfare (audible since D38); a trainer win closes with the defeat line, the trainer sliding back in, their line and the prize share (D41), and battles open with the sliding intro (D42); what is left is the field being a separate screen from `Gen2BattleScreen` | `coop/launcher` | comment, keep open |
| 27 | Share the battle screen's enemy AI with host sessions | open for Generation 2 (a random usable move); Generation 1 sessions use the cartridge's trainer AI | | keep open; Generation 2 is out of scope for now (D61) |
| 28 | Route switch offers, Baton Pass and Mimic to the right owner | partial: Mimic's choice goes to the Pokémon's owner in the panel; Red and Blue have no switch offer or Baton Pass; Generation 2 not checked | `coop/launcher` | keep open; Generation 2 is out of scope for now (D61) |
| 29 | Session menu: join a battle from another map and return afterwards | done (JOIN in the SELECT panel from any map; the return point is kept) | `coop/slice-1`, `coop/launcher` | close when the branch merges |
| 30 | Controller loss: pause, timeout and resume | done: paused; after 30 s the others are asked TAKE OVER or KEEP WAITING; the owner takes it back (D33, D61, D62) | `coop/launcher`, `coop/owner-rules` | close when the branches merge |
| 31 | Policy: withdrawing from a shared battle | done: LEAVE BATTLE and a dropped link are one rule; Pokémon fight on and stay the owner's; REJOIN; a battle nobody is in ends after about two minutes (D61, D62) | `coop/owner-rules` | close when the branch merges |
| 32 | Route map-script event flags and badges through campaign commits | done: flags and badges travel as campaign world patches (D23), trainer victories as commits | `coop/m1-state-sync` | close when the branch merges |
| 33 | Catalogue unique Red/Blue encounters | done: trainers and one-off wild Pokémon are one encounter each (D36); gift Pokémon are each player's own (D61, D62) | `coop/launcher`, `coop/owner-rules` | close when the branches merge |
| 34 | Policy: a player joining a campaign late | done, the owner kept the rules (D61): play the opening on a story of their own, skip it with a starter of choice, or bring a save (D34, D50) | `coop/launcher` (`260ed3b0`) | close when the branch merges: the owner keeps the rules (D61) |
| 35 | Captures go to one explicitly chosen player | done | `coop/launcher` (`c01deca6`) | close when the branch merges |
| 36 | Policy: prize money, Pay Day and blackout costs | done: every participant is paid the whole prize with Pay Day's; a loss halves each loser's own money (D61) | `coop/owner-rules` | close when the branch merges |
| 37 | Evolution and move learning for each owner after shared battles | done, with EXP.ALL per team (D61, D62) | `coop/launcher`, `coop/owner-rules` | close when the branches merge |
| 38 | Player services: Pokémon Center, Mart, PC and trades between players | done: each window's own Center, Mart and PC on the player's own team, bag, money and PC (D29); trades through the Cable Club (D31) | `coop/launcher` | close when the branch merges |
| 39 | Save migration, autosave and recovery journal | done: autosave, `.bak` and a failed write changing nothing (D40); a journal of the state after each story change between checkpoints, and format 2 settling format 1 files once (D66) | `coop/playthrough` | close when the branch merges |
| 40 | Import a single-player save as a co-op player | done: a new player brings a save slot; a new campaign's first player brings its story too (D34) | `coop/launcher` | close when the branch merges |
| 41 | Co-op battle HUD: controller, owner tags and advisory cursor | done: the panel names who decides, tags each ally with its owner's colour, shows the partner's suggestion and fades refusals (D45) | `coop/launcher` | close when the branch merges |
| 42 | Host and join screens and the in-game session menu | done (launcher tab; the in-game menu is the SELECT panel) | `coop/launcher` (`65d6c0d6`) | close when the branch merges |
| 43 | Touch and pad input for co-op menus | partial: the on-screen pad's presses reach the panel by the same path as keys; panel rows take a tap or a click (cursor, then choose); a tall window puts the panel under the battle; not tried on a device | `coop/launcher` | comment, keep open |
| 44 | Private Windows and Linux builds | partial: the stock 4.8-dev4 export templates are installed locally; `Windows Desktop` and `Linux` export from the existing presets (release, one file each, no cartridge data); a Windows engine under Wine joined a Linux host; not yet run on a real Windows PC | `coop/launcher` | comment, keep open until the first session on Windows |
| 45 | Android client: lifecycle and reconnect | open, deferred by the owner until after #88 and #44 (D72): pause and resume handling exists (D46), no Android build | | keep open |
| 46 | iOS client build without executable mods | open: no iOS build; needs a Mac and the owner's account | | keep open |
| 47 | Two-process ENet integration check in CI | done: `tools/coop_two_process.sh` runs the host and both players as three processes (`coop_session.gd -- check host\|p1\|p2`), 30/30 local passes, and the CI step passed on #80 | `coop/launcher` (`d5e65c2f`), #80 | closes when #80 merges |
| 48 | Scripted co-op playthrough to the first gym (local cartridge only) | done: `tools/coop_autoplay.gd` plays two windows from Oak's speech to BROCK's badge (`playthrough_brock`, about five minutes, three clean runs); MISTY and beyond in progress | `coop/playthrough` | close when the branch merges |
| 49 | Readiness checklist for private builds | done: `readiness.md`, with a player guide in `playing.md` | `coop/launcher` | close when the branch merges |
| 50 | German Red/Blue support | open, waits for the owner's own dump (D72) | | keep open |
| 51 | Internet relay option | open (later milestone); WireGuard or a forwarded port work today | | keep open |
| 52 | Dedicated server mode | open (later milestone); `tools/coop_session.gd host` runs a headless host already | | keep open |
| 53 | Local split-screen | open (later milestone) | | keep open |
| 54 | Host migration | open (later milestone) | | keep open |
| 55 | Provenance audit of upstream-tracked files and co-op asset rules | open | | keep open |
| 56 | Investigate iOS App Store feasibility | open | | keep open |
| 57 | Decide when and how to publish the fork | open: the owner's decision; the repository stays private until a stable release | | keep open; private, no plan yet (D61) |
| 59 | Upstream: dump_tables.gd trainers stops on Generation 1 data | open | | |
| 82 | The host drops every gen1_bytes change, so those bytes are not kept between sessions | done: owned byte by byte, the Vermilion locks the campaign's (D63) | `coop/playthrough` (`eb387271`) | close when the branch merges |
| 84 | World sharing: share the campaign at rest points, never mid-scene | in progress: adopted (D72), steps 1 and 2 on `coop/rest-points` | | |
| 85 | Vermilion Gym's trash-can locks stay put while someone is in the city or gym | in progress on `coop/vermilion-locks` | | |
| 86 | Upstream: the Cerulean thief's TM28 box stays on screen after its scene | in progress on `coop/tm28-box` | | |
| 87 | Review and merge coop/autoplay-surge | done: merged (`91e8c1c6`), D73 to D75 | `coop/playthrough` | close with the scenario runs |
| 88 | Autoplayed two-window run to the Hall of Fame | in progress: done to LT. SURGE; Celadon and ERIKA on `coop/autoplay-erika`; campaign seeds for parallel stretches on `coop/campaign-seed` | | |

## Found while GitHub was paused

| L | Issue | Title | Milestone | Notes |
|---|---|---|---|---|
| L1 | #60 | Claim trainers fought from a window as unique encounters | M6 | done on `coop/m1-state-sync`: a second window joins the running fight, a beaten trainer stays beaten |
| L2 | #61 | Tell a window when its SAVE was refused | M8 | done: a notice over the world says why; since D56 the game's own box says "Save failed: battle in progress" before anything is written, the notice remaining for a battle that starts on the way |
| L3 | #62 | Leave a session from the game and return to the launcher | M9 | done on `coop/launcher`: LEAVE SESSION, the end notice and the window closing all leave through one path |
| L4 | #63 | Window saves failed the game's own checks (slot -1), refusing PC and other validated services | M7 | done on `coop/launcher`: slot 0 under a scratch save root |
| L5 | #64 | Story gifts (key items, HMs, gift TMs) reach every player | M6 | done on `coop/launcher`: policy in `PokeCoopPolicy.share_gifts` (D30) |
| L6 | #65 | Upstream: a Gen 1 link trade from a save slot puts the catch rate in the item byte, so a Pokémon whose catch rate is not an item (RATTATA, 255) fails the arriving save's check | upstream | seen in co-op before the co-op cable sent host rows; file upstream with a repro |
| L8 | #67 | Upstream: the Gen 1 battle intro draws the player's back-picture head as Crystal's six-column OAM, scrambling it | upstream | fixed in the fork's `battle_intro.gd` (D42); file upstream with the fix |
| L7 | #66 | Upstream: the Gen 1 trade movie names the received Pokémon after its trade evolution (MACHAMP is transferred) before the evolution plays | upstream | cosmetic; file upstream Fixed on `coop/playthrough` (`4dd8cba6`, D64): the movie is built before the evolution |
| L9 | #68 | Several campaigns per host device, so a run with another group does not overwrite the first | M8 | done on `coop/launcher`: one file per campaign, a picker and a name on the Co-op tab, identity per campaign (D49) |
| L10 | #69 | Upstream: the rival's challenge in Oak's lab can be walked past: the player can move while the rival walks to his POKé BALL (`wJoyIgnore` not modelled), and walking down at once leaves the lab without the fight | upstream | fixed in the fork's `world_screen.gd` (D54): no player step while a Gen 1 script walks someone; checked in single player. File upstream with the fix |
| L11 | #70 | Upstream: a direction pressed on the frame the player stops never turns them, and a press that does not turn leaves the facing alone, so after the Viridian Mart's parcel scene DOWN does not leave the shop | upstream | fixed in the fork's `world_api.gd` (D57): a Gen 1 press faces its direction as `wPlayerDirection` does; file upstream with the fix |
| L12 | #71 | A new player plays the opening on a story of their own | M9 | done on `coop/launcher` (D50) |
| L13 | #72 | A window's stale echo of its own world change rewound map scripts | M7 | fixed on `coop/launcher` (D51) |
| L14 | #73 | Every item found or given along the story reaches every player; key items the story takes are taken from all | M7 | done on `coop/launcher` (D52) |
| L15 | #74 | Partners are solid, so players do not stand on one cell | M3 | done on `coop/launcher` (D53) |
| L16 | #75 | Three or more players: every partner's suggestion shown, Cable Club partner by room, a third team joins with what fits | M3 | done on `coop/launcher` (D55); tests only, not played with three |
| L17 | #76 | A campaign of players who skipped the opening had Oak's lab before the intro: no Oak, so the parcel could not be delivered | M6 | fixed on `coop/launcher` (D58) |
| L18 | #77 | Session logs for host and clients, and a debug stream that copies each player's lines to the others | tooling | done on `coop/launcher` (D59) |
| L19 | #78 | Closing a hosting window ended the session with no grace: the joiner got no "ended" and kept redialling, and the host's last log lines missed it | M2 | fixed on `coop/launcher` (D60): the window waits for the goodbye, at most 2.5 s for a host and 0.6 s for a joiner |
