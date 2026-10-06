# Local issue tracking

GitHub is paused (see `AGENTS.md`), so issue status is kept here until it can be
synced. Each row names the GitHub issue, what is true locally, and what to do
on GitHub once use resumes. New work found while GitHub is paused gets an `L`
number and is filed on GitHub later.

Statuses: **done** (acceptance criteria met and verified locally),
**partial**, **in progress**, **open**.

## When GitHub resumes

1. Restore the push URL: `git remote set-url --push origin git@github.com:Clodmony/pokerecomp-coop.git`.
2. Push `coop/slice-1` (one local commit ahead of PR #58) and each local branch
   below; open a draft PR per branch.
3. File every `L` item as an issue and replace its `L` number in the docs.
4. Close or comment on the issues as the "On GitHub" column says.

## Branches

| Branch | Base | State | GitHub |
|---|---|---|---|
| `coop/slice-1` | `main` | pushed up to `e5bef608`; `4d8cdaf4` (GitHub pause note) local only | draft PR #58 |
| `coop/m1-state-sync` | `coop/slice-1` | local only: ownership, world and party sync, battle takeover, unique window trainers | none yet |
| `coop/launcher` | `coop/m1-state-sync` | local only: launcher Co-op tab, new players, captures, evolution, whiteout, session lifecycle | none yet |

## Issues

| # | Title | Local status | Where | On GitHub |
|---|---|---|---|---|
| 1 to 13 | Slice 1 | done | `coop/slice-1` | closed by PR #58 when merged |
| 14 | Upstream sync procedure and conflict hotspots | partial: every upstream file the fork changes is listed in `architecture.md`; no written merge procedure, no upstream merge tried yet | | keep open |
| 15 | Private CI: cost, caching and required checks | partial: `ci.yml` runs import, suite, boot and the ENet demo; paused with GitHub, the same steps run locally | | keep open |
| 16 | Classify every world, save and runtime field | done | `coop/m1-state-sync` (`9efac512`) | close when the branch merges |
| 17 | Run the world logic against a campaign plus player projection | done (each window runs its own world, synced by patches) | `coop/m1-state-sync` (`a151f505`) | close when the branch merges |
| 18 | GameRuntime co-op mode | done | `coop/launcher` (`65d6c0d6`) | close when the branch merges |
| 19 | Session handshake: protocol version, cartridge identity, no content transfer | done: the hello carries the protocol and the cartridge id and SHA-1, and a mismatch is refused with a reason the Co-op tab explains; nothing from the cartridge is sent | `coop/slice-1`, `coop/launcher` | close when the branch merges |
| 20 | Reconnection tokens and mobile suspend/resume | partial: a dropped link redials as the remembered player for about two minutes with a notice; a hosting app sent to the background saves the campaign; a joiner back from a pause redials at once (D46); no device suspend test yet | `coop/launcher` | comment, keep open for #45 |
| 21 | Protocol hardening: limits, schema validation and fuzzing | done: seeded fuzz test over every message type, boundary readers and shape checks, 2 MiB packet cap (D35) | `coop/launcher` | close when the branch merges |
| 22 | Per-player actors in the world simulation | open: each window runs its own world and the host trusts it; a host-side world needs the owner's go-ahead | | keep open |
| 23 | Remote players on the same map with interpolation | done | `coop/slice-1` (`PokeCoopRemoteActor`), screenshots in `progress.md` | close when the branch merges |
| 24 | Lock shared NPCs, scripts and cutscenes while one player uses them | open: two windows talking to the same gift giver at once can both be given it; with #22 | | keep open |
| 25 | Host-side wild encounters and trainer sight per player | partial: the window's world rolls them, the host fights them | `coop/m1-state-sync` (`15028474`) | comment, keep open for host-side generation with #22 |
| 26 | Drive the battle screen from authoritative session events | partial: the battle field (pictures, panels, draining HP bars, turn text, move animations) is drawn from the host's view (D32), with move and hit sounds, blinks, screen shakes, palette effects, thrown balls, faints, recalls and send-outs (D39), battle music, cries and the victory fanfare (audible since D38); a trainer win closes with the defeat line, the trainer sliding back in, their line and the prize share (D41), and battles open with the sliding intro (D42); what is left is the field being a separate screen from `Gen2BattleScreen` | `coop/launcher` | comment, keep open |
| 27 | Share the battle screen's enemy AI with host sessions | open for Generation 2 (a random usable move); Generation 1 sessions use the cartridge's trainer AI | | keep open |
| 28 | Route switch offers, Baton Pass and Mimic to the right owner | partial: Mimic's choice goes to the Pokémon's owner in the panel; Red and Blue have no switch offer or Baton Pass; Generation 2 not checked | `coop/launcher` | comment, keep open for Generation 2 |
| 29 | Session menu: join a battle from another map and return afterwards | done (JOIN in the SELECT panel from any map; the return point is kept) | `coop/slice-1`, `coop/launcher` | close when the branch merges |
| 30 | Controller loss: pause, timeout and resume | done: paused, a participant stands in after 30 s, the owner takes it back (D33) | `coop/launcher` | close when the branch merges |
| 31 | Policy: withdrawing from a shared battle | partial: provisional rule, no withdrawal (a battle ends for all together) | `design.md` | comment with the rule, keep open for the owner's decision |
| 32 | Route map-script event flags and badges through campaign commits | done: flags and badges travel as campaign world patches (D23), trainer victories as commits | `coop/m1-state-sync` | close when the branch merges |
| 33 | Catalogue unique Red/Blue encounters | done for battles: every trainer by class and index, and SNORLAX, the birds and MEWTWO by species and map (D36); gift Pokémon are first come | `coop/launcher` | close when the branch merges, or keep open for gift Pokémon |
| 34 | Policy: a player joining a campaign late | partial: provisional rules implemented: play the opening on a story of their own, skip it with a starter of choice, or bring a save (D34, D50) | `coop/launcher` (`260ed3b0`) | comment with the rule, keep open for the owner's decision |
| 35 | Captures go to one explicitly chosen player | done | `coop/launcher` (`c01deca6`) | close when the branch merges |
| 36 | Policy: prize money, Pay Day and blackout costs | partial: prize split on the host, blackout paid in each player's world | `coop/launcher` (`edd0a681`) | comment, keep open for the owner's decision |
| 37 | Evolution and move learning for each owner after shared battles | done | `coop/launcher` (`2e204c6d`) | close when the branch merges |
| 38 | Player services: Pokémon Center, Mart, PC and trades between players | done: each window's own Center, Mart and PC on the player's own team, bag, money and PC (D29); trades through the Cable Club (D31) | `coop/launcher` | close when the branch merges |
| 39 | Save migration, autosave and recovery journal | partial: autosave after battles, every 30 s of changes, on leaving and on pause; the checkpoint before is kept as `.bak` and a failed write changes nothing (D40); no journal or migration | `coop/launcher` | comment, keep open |
| 40 | Import a single-player save as a co-op player | done: a new player brings a save slot; a new campaign's first player brings its story too (D34) | `coop/launcher` | close when the branch merges |
| 41 | Co-op battle HUD: controller, owner tags and advisory cursor | done: the panel names who decides, tags each ally with its owner's colour, shows the partner's suggestion and fades refusals (D45) | `coop/launcher` | close when the branch merges |
| 42 | Host and join screens and the in-game session menu | done (launcher tab; the in-game menu is the SELECT panel) | `coop/launcher` (`65d6c0d6`) | close when the branch merges |
| 43 | Touch and pad input for co-op menus | partial: the on-screen pad's presses reach the panel by the same path as keys; panel rows take a tap or a click (cursor, then choose); a tall window puts the panel under the battle; not tried on a device | `coop/launcher` | comment, keep open |
| 44 | Private Windows and Linux builds | partial: the stock 4.8-dev4 export templates are installed locally; `Windows Desktop` and `Linux` export from the existing presets (release, one file each, no cartridge data); a Windows engine under Wine joined a Linux host; not yet run on a real Windows PC | `coop/launcher` | comment, keep open until the first session on Windows |
| 45 | Android client: lifecycle and reconnect | open: pause and resume handling exists (D46), no Android build or device run | | keep open |
| 46 | iOS client build without executable mods | open: no iOS build; needs a Mac and the owner's account | | keep open |
| 47 | Two-process ENet integration check in CI | partial: `tools/coop_two_process.sh` runs the host and both players as three processes (`coop_session.gd -- check host\|p1\|p2`), 30/30 local passes; `ci.yml` runs it after the demo, not yet run while GitHub is paused | `coop/launcher` (`d5e65c2f`) | close once the new CI step passes on a pull request |
| 48 | Scripted co-op playthrough to the first gym (local cartridge only) | partial: scripted two-window runs cover the opening, Route 1, a joined wild battle, BROCK from the session menu, the Cable Club trade and OAK's PARCEL; no single run from the start to BROCK's gym | local scratch drivers | keep open |
| 49 | Readiness checklist for private builds | done: `readiness.md`, with a player guide in `playing.md` | `coop/launcher` | close when the branch merges |
| 50 | German Red/Blue support | open (later milestone) | | keep open |
| 51 | Internet relay option | open (later milestone); WireGuard or a forwarded port work today | | keep open |
| 52 | Dedicated server mode | open (later milestone); `tools/coop_session.gd host` runs a headless host already | | keep open |
| 53 | Local split-screen | open (later milestone) | | keep open |
| 54 | Host migration | open (later milestone) | | keep open |
| 55 | Provenance audit of upstream-tracked files and co-op asset rules | open | | keep open |
| 56 | Investigate iOS App Store feasibility | open | | keep open |
| 57 | Decide when and how to publish the fork | open: the owner's decision; the repository stays private until a stable release | | keep open |
| 59 | Upstream: dump_tables.gd trainers stops on Generation 1 data | open | | |

## Found while GitHub is paused

| L | Title | Milestone | Notes |
|---|---|---|---|
| L1 | Claim trainers fought from a window as unique encounters | M6 | done on `coop/m1-state-sync`: a second window joins the running fight, a beaten trainer stays beaten |
| L2 | Tell a window when its SAVE was refused | M8 | done: a notice over the world says why; since D56 the game's own box says "Save failed: battle in progress" before anything is written, the notice remaining for a battle that starts on the way |
| L3 | Leave a session from the game and return to the launcher | M9 | done on `coop/launcher`: LEAVE SESSION, the end notice and the window closing all leave through one path |
| L4 | Window saves failed the game's own checks (slot -1), refusing PC and other validated services | M7 | done on `coop/launcher`: slot 0 under a scratch save root |
| L5 | Story gifts (key items, HMs, gift TMs) reach every player | M6 | done on `coop/launcher`: policy in `PokeCoopPolicy.share_gifts` (D30) |
| L6 | Upstream: a Gen 1 link trade from a save slot puts the catch rate in the item byte, so a Pokémon whose catch rate is not an item (RATTATA, 255) fails the arriving save's check | upstream | seen in co-op before the co-op cable sent host rows; file upstream with a repro |
| L8 | Upstream: the Gen 1 battle intro draws the player's back-picture head as Crystal's six-column OAM, scrambling it | upstream | fixed in the fork's `battle_intro.gd` (D42); file upstream with the fix |
| L7 | Upstream: the Gen 1 trade movie names the received Pokémon after its trade evolution (MACHAMP is transferred) before the evolution plays | upstream | cosmetic; file upstream |
| L9 | Several campaigns per host device, so a run with another group does not overwrite the first | M8 | done on `coop/launcher`: one file per campaign, a picker and a name on the Co-op tab, identity per campaign (D49) |
| L10 | Upstream: the rival's challenge in Oak's lab can be walked past: the player can move while the rival walks to his POKé BALL (`wJoyIgnore` not modelled), and walking down at once leaves the lab without the fight | upstream | fixed in the fork's `world_screen.gd` (D54): no player step while a Gen 1 script walks someone; checked in single player. File upstream with the fix |
| L11 | Upstream: a direction pressed on the frame the player stops never turns them, and a press that does not turn leaves the facing alone, so after the Viridian Mart's parcel scene DOWN does not leave the shop | upstream | fixed in the fork's `world_api.gd` (D57): a Gen 1 press faces its direction as `wPlayerDirection` does; file upstream with the fix |
| L12 | A new player plays the opening on a story of their own | M9 | done on `coop/launcher` (D50) |
| L13 | A window's stale echo of its own world change rewound map scripts | M7 | fixed on `coop/launcher` (D51) |
| L14 | Every item found or given along the story reaches every player; key items the story takes are taken from all | M7 | done on `coop/launcher` (D52) |
| L15 | Partners are solid, so players do not stand on one cell | M3 | done on `coop/launcher` (D53) |
| L16 | Three or more players: every partner's suggestion shown, Cable Club partner by room, a third team joins with what fits | M3 | done on `coop/launcher` (D55); tests only, not played with three |
