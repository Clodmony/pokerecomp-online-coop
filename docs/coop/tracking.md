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
| 20 | Reconnection tokens and mobile suspend/resume | partial: a dropped link redials as the remembered player, gives up after ten tries; no device suspend test yet | `coop/launcher` | comment, keep open for #45 |
| 25 | Host-side wild encounters and trainer sight per player | partial: the window's world rolls them, the host fights them | `coop/m1-state-sync` (`15028474`) | comment, keep open for host-side generation with #22 |
| 26 | Drive the battle screen from authoritative session events | partial: the battle field (pictures, panels, HP bars, turn text) is drawn from the host's view (D32); no animations or cries | `coop/launcher` | comment, keep open |
| 34 | Policy: a player joining a campaign late | partial: provisional rule implemented (starter of choice, intro done) | `coop/launcher` (`260ed3b0`) | comment with the rule, keep open for the owner's decision |
| 35 | Captures go to one explicitly chosen player | done | `coop/launcher` (`c01deca6`) | close when the branch merges |
| 36 | Policy: prize money, Pay Day and blackout costs | partial: prize split on the host, blackout paid in each player's world | `coop/launcher` (`edd0a681`) | comment, keep open for the owner's decision |
| 37 | Evolution and move learning for each owner after shared battles | done | `coop/launcher` (`2e204c6d`) | close when the branch merges |
| 38 | Player services: Pokémon Center, Mart, PC and trades between players | done: each window's own Center, Mart and PC on the player's own team, bag, money and PC (D29); trades through the Cable Club (D31) | `coop/launcher` | close when the branch merges |
| 39 | Save migration, autosave and recovery journal | partial: autosave between battles and when the host leaves; no journal or migration | `coop/launcher` | comment, keep open |
| 42 | Host and join screens and the in-game session menu | done (launcher tab; the in-game menu is the SELECT panel) | `coop/launcher` (`65d6c0d6`) | close when the branch merges |
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
| L7 | Upstream: the Gen 1 trade movie names the received Pokémon after its trade evolution (MACHAMP is transferred) before the evolution plays | upstream | cosmetic; file upstream |
