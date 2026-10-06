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
| 16 | Classify every world, save and runtime field | done | `coop/m1-state-sync` (`9efac512`) | close when the branch merges |
| 17 | Run the world logic against a campaign plus player projection | done (each window runs its own world, synced by patches) | `coop/m1-state-sync` (`a151f505`) | close when the branch merges |
| 18 | GameRuntime co-op mode | done | `coop/launcher` (`65d6c0d6`) | close when the branch merges |
| 20 | Reconnection tokens and mobile suspend/resume | partial: a dropped link redials as the remembered player for about two minutes with a notice; a hosting app sent to the background saves the campaign; a joiner back from a pause redials at once (D46); no device suspend test yet | `coop/launcher` | comment, keep open for #45 |
| 21 | Protocol hardening: limits, schema validation and fuzzing | done: seeded fuzz test over every message type, boundary readers and shape checks, 2 MiB packet cap (D35) | `coop/launcher` | close when the branch merges |
| 23 | Remote players on the same map with interpolation | done | `coop/slice-1` (`PokeCoopRemoteActor`), screenshots in `progress.md` | close when the branch merges |
| 25 | Host-side wild encounters and trainer sight per player | partial: the window's world rolls them, the host fights them | `coop/m1-state-sync` (`15028474`) | comment, keep open for host-side generation with #22 |
| 26 | Drive the battle screen from authoritative session events | partial: the battle field (pictures, panels, draining HP bars, turn text, move animations) is drawn from the host's view (D32), with move and hit sounds, blinks, screen shakes, palette effects, thrown balls, faints, recalls and send-outs (D39), battle music, cries and the victory fanfare (audible since D38); a trainer win closes with the defeat line, the trainer sliding back in, their line and the prize share (D41), and battles open with the sliding intro (D42); what is left is the field being a separate screen from `Gen2BattleScreen` | `coop/launcher` | comment, keep open |
| 29 | Session menu: join a battle from another map and return afterwards | done (JOIN in the SELECT panel from any map; the return point is kept) | `coop/slice-1`, `coop/launcher` | close when the branch merges |
| 30 | Controller loss: pause, timeout and resume | done: paused, a participant stands in after 30 s, the owner takes it back (D33) | `coop/launcher` | close when the branch merges |
| 32 | Route map-script event flags and badges through campaign commits | done: flags and badges travel as campaign world patches (D23), trainer victories as commits | `coop/m1-state-sync` | close when the branch merges |
| 33 | Catalogue unique Red/Blue encounters | done for battles: every trainer by class and index, and SNORLAX, the birds and MEWTWO by species and map (D36); gift Pokémon are first come | `coop/launcher` | close when the branch merges, or keep open for gift Pokémon |
| 34 | Policy: a player joining a campaign late | partial: provisional rule implemented (starter of choice, intro done) | `coop/launcher` (`260ed3b0`) | comment with the rule, keep open for the owner's decision |
| 35 | Captures go to one explicitly chosen player | done | `coop/launcher` (`c01deca6`) | close when the branch merges |
| 36 | Policy: prize money, Pay Day and blackout costs | partial: prize split on the host, blackout paid in each player's world | `coop/launcher` (`edd0a681`) | comment, keep open for the owner's decision |
| 37 | Evolution and move learning for each owner after shared battles | done | `coop/launcher` (`2e204c6d`) | close when the branch merges |
| 38 | Player services: Pokémon Center, Mart, PC and trades between players | done: each window's own Center, Mart and PC on the player's own team, bag, money and PC (D29); trades through the Cable Club (D31) | `coop/launcher` | close when the branch merges |
| 39 | Save migration, autosave and recovery journal | partial: autosave after battles, every 30 s of changes, on leaving and on pause; the checkpoint before is kept as `.bak` and a failed write changes nothing (D40); no journal or migration | `coop/launcher` | comment, keep open |
| 40 | Import a single-player save as a co-op player | done: a new player brings a save slot; a new campaign's first player brings its story too (D34) | `coop/launcher` | close when the branch merges |
| 42 | Host and join screens and the in-game session menu | done (launcher tab; the in-game menu is the SELECT panel) | `coop/launcher` (`65d6c0d6`) | close when the branch merges |
| 43 | Touch and pad input for co-op menus | partial: the on-screen pad's presses reach the panel by the same path as keys; panel rows take a tap or a click (cursor, then choose); a tall window puts the panel under the battle; not tried on a device | `coop/launcher` | comment, keep open |
| 44 | Private Windows and Linux builds | partial: the stock 4.8-dev4 export templates are installed locally; `Windows Desktop` and `Linux` export from the existing presets (release, one file each, no cartridge data); a Windows engine under Wine joined a Linux host; not yet run on a real Windows PC | `coop/launcher` | comment, keep open until the first session on Windows |
| 49 | Readiness checklist for private builds | done: `readiness.md`, with a player guide in `playing.md` | `coop/launcher` | close when the branch merges |
| 59 | Upstream: dump_tables.gd trainers stops on Generation 1 data | open | | |

## Found while GitHub is paused

| L | Title | Milestone | Notes |
|---|---|---|---|
| L1 | Claim trainers fought from a window as unique encounters | M6 | done on `coop/m1-state-sync`: a second window joins the running fight, a beaten trainer stays beaten |
| L2 | Tell a window when its SAVE was refused | M8 | done on `coop/launcher`: a notice over the world says why |
| L3 | Leave a session from the game and return to the launcher | M9 | done on `coop/launcher`: LEAVE SESSION, the end notice and the window closing all leave through one path |
| L4 | Window saves failed the game's own checks (slot -1), refusing PC and other validated services | M7 | done on `coop/launcher`: slot 0 under a scratch save root |
| L5 | Story gifts (key items, HMs, gift TMs) reach every player | M6 | done on `coop/launcher`: policy in `PokeCoopPolicy.share_gifts` (D30) |
| L6 | Upstream: a Gen 1 link trade from a save slot puts the catch rate in the item byte, so a Pokémon whose catch rate is not an item (RATTATA, 255) fails the arriving save's check | upstream | seen in co-op before the co-op cable sent host rows; file upstream with a repro |
| L8 | Upstream: the Gen 1 battle intro draws the player's back-picture head as Crystal's six-column OAM, scrambling it | upstream | fixed in the fork's `battle_intro.gd` (D42); file upstream with the fix |
| L7 | Upstream: the Gen 1 trade movie names the received Pokémon after its trade evolution (MACHAMP is transferred) before the evolution plays | upstream | cosmetic; file upstream |
| L9 | Several campaigns per host device, so a run with another group does not overwrite the first | M8 | done on `coop/launcher`: one file per campaign, a picker and a name on the Co-op tab, identity per campaign (D49) |
| L10 | Upstream: the rival's challenge in Oak's lab can be walked past: after "BLUE received a SQUIRTLE!" the player can move while the lab script is still on its previous step, and walking down at once leaves the lab without the fight | upstream | seen in a plain single-player world with the same driver (no co-op); `joy_ignore` is not modelled. File upstream |
| L11 | Upstream: a direction pressed on the frame the player stops is recorded as the last stop direction without turning, so further presses of it bump without turning until another direction is pressed | upstream | seen while driving the lab; not checked against hardware. File upstream |
| L12 | A new player plays the opening on a story of their own | M9 | done on `coop/launcher` (D50) |
| L13 | A window's stale echo of its own world change rewound map scripts | M7 | fixed on `coop/launcher` (D51) |
