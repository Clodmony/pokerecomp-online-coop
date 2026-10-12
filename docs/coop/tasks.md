# Tasks: start here

The resume point for the next session. Read [playbook.md](playbook.md) for the
why; this is the what, in order. Tick a box in the same commit as the work, and
keep the snapshot below current.

## Snapshot (2026-10-08, third session, after the merge)

- **Upstream 0.1.75 (2026-10-09, #14, D97):** merged on `coop/upstream-sync`
  (draft pull request). The fork now pins Godot **4.8-dev7**: install the dev7
  editor and its stock export templates before the next local run or build, and
  import every cartridge again (cache format 163 to 170). Before it merges, run
  `playthrough_brock` and `cable_club_trade` on the owner's Red import; the
  merging session had no cartridge.
- **Branches and pull requests:** everything is merged into `main` (#58, #79,
  #80, #81, #83, #89 on 2026-10-08, with the owner's approval). New work
  branches from `main`.
- **Halted at the weekly usage limit (2026-10-08/09):** the first unbroken
  `playthrough_elite` on `main` (`FPS=120`, about 1.3 times faster than 60)
  stopped after 37 minutes in the Rocket Hideout car: both windows arrived
  together, each saw the other on the panel cell and stepped aside, then back,
  forever. Fixed: only the second player yields the panel. Resumed from the
  run's snapshot 105, both rode the car in 1 s each and took the SILPH SCOPE;
  the resumed run then reached both Halls of Fame in 51 minutes, 0 script
  errors (a whole run at `FPS=120` is about 1½ hours). Next: one unbroken run on
  `main` once this merges. Battles, paced in real time on the host, now
  dominate a run's length.
- **Owner decisions:** all six answered (D72); none waiting.
- **This round** (all merged into `coop/playthrough` and pushed; the agents'
  git worktrees can be removed):
  - Merged into `coop/playthrough` and chained in ROUTES: `erika` (D83),
    `tower` (D82), `koga` (D81), `sabrina` (D85); #24 (D84, protocol 5);
    D80 (a checkpoint only on a real SAVE).
  - The chained run's Rocket Hideout car stall was the autopilot choosing the
    wrong floor and blocking the car's door path (`coop/elevator-stall`, merged).
    The chained run then stalled on Pokémon Tower 7F for a partner arriving
    after Mr. Fuji's rescue (`coop/tower-7f-late`, merged). The third chained run froze on Silph Co.
    7F: the autopilot looked for LAPRAS only in a full party
    (`coop/silph-7f-stall`, merged), then could not teach SURF with LAPRAS in
    the box (`coop/seed-party`, merged). The fifth chained run stalled on a late
    partner's way down Pokémon Tower (`coop/tower-late-descent`, merged: the autopilot's moves now respect type).
  - `coop/autoplay-blaine` merged (D86): Cinnabar and BLAINE, chained after
    `sabrina`; two seeded runs pass.
  - `coop/autoplay-victory` merged (D89, D90): GIOVANNI, Route 22's second
    rival and Victory Road, chained between `blaine` and `elite`. Every stretch
    to the Hall of Fame is now in ROUTES; what is left of #88 is one chained
    `playthrough_elite` from a new campaign.
  - `coop/autoplay-elite` merged (D87, replaced by D93; D88): the Elite Four, the
    Champion and each player's Hall of Fame.
  - Owner's answers (D91): Saffron's gate drink and the Elite Four are the
    team's, not each player's: the drink (D92) and the Elite Four (D93)
    are merged.
  - Seeds (lost on reboot) were under `/tmp/claude-1000/lead/seeds/`; rebuild
    with `tools/coop_seed.gd`.
- **Next free decision number:** D102 (D72 to D101 are recorded).
- **Godot 4.8-dev7** since the 0.1.75 merge (D97; dev4 before it):
  `Godot_v4.8-dev7_linux.x86_64.zip` from godot-builds, unzipped into the
  session scratchpad; the system `godot` is 4.7 and cannot open the project.
  The installed export templates are dev4's; dev7's are needed for builds.
- **Cartridge:** the owner's Red import is `rom_cache/red_ea9bcae6` in the user
  folder; the scenario runner links it read-only into a private one.
- **Snapshots (D96):** every autoplayed run writes `<out>/snapshots/`;
  `tools/coop_resume.sh <run dir> [n | -seconds]` resumes a stalled run there.
- **Seeds:** `SEED=<dir>` starts a scenario from a campaign and the autopilot's
  `from=<leg>` skips the legs before it; `tools/coop_seed.gd -- red <leg> <dir>`
  writes one at any leg of upstream's story walk in seconds (D78). Seeds are
  never committed.
- **Not in git (lost on reboot):** run captures, logs, seeds and the agents'
  scratch scripts; the agents' git worktrees can be removed once their
  branches are merged.

## Current continuation (2026-10-11)

`coop/friend-menu` continues Claude's uncommitted PvP work, on the native menu
and Cable Club continue fixes (`coop/link-room-continue`, draft #103, which
follows #101). #104 implements consenting friend battles and direct trades
from START > CO-OP or by talking to the partner (D100). See `progress.md` for
its exact verification; the broader campaign tasks below remain outstanding.

## Next tasks

1. [x] **#86** Fix the Cerulean thief's stuck TM28 box (upstream), with a GUT
   test. Done when a no-press text followed by a fade leaves no box.
2. [x] **#87** Merge `coop/autoplay-surge` into `coop/playthrough`. Conflicts
   expected in `tools/coop_autoplay.gd`. Then: co-op suites, whole suite,
   `playthrough_misty`, `cable_club_trade`, `playthrough_surge` (should pass
   after task 1), D72 onward for its three fixes, test-case rows (re-host inside
   a building; ticket, TM28 and HM01 for everyone; per-player city scripts;
   Vermilion Gym's door for both; CUT), progress rows, PR #83's description.
3. [x] **Owner decisions** (playbook, "Decisions waiting on the owner"):
   answered 2026-10-07, recorded as D72.
4. [x] **#84 step 1** Hold a window's world patches until a rest point
   (`script_busy()` false and no map load pending) instead of 15 s; a partial
   patch only on SAVE or LEAVE. Tests: a 40 s scene with a battle sends nothing
   until it ends; LEAVE mid-scene sends the last resting state.
5. [x] **#84 step 2** Map-script steps: resting values only; classify the gym
   bytes BROCK to GIOVANNI as per player; a step for the window's own map waits
   for its next map load. Tests: one TM34 when a partner stands in Pewter Gym;
   the Vermilion dock with both in the city. Then `world_pull` logs the busy
   state, and `design.md` lists what is not shared.
6. [x] **#85** Vermilion Gym's locks stay while someone is in the city or gym:
   the entering window keeps them (D77); `vermilion_locks` shows the cans stay.
7. [x] **#24** (approved, D72; built as D84) the first player in drives a contested rival
   scene: every rival scene after the opening (Route 22 twice, Cerulean, S.S.
   Anne, Pokémon Tower, Silph Co.).
8. [x] **#88** Extend the autopilot stretch by stretch to the Hall of Fame:
   a new campaign reached both Halls of Fame on 2026-10-08 (resumed from
   snapshots after each fix); one unbroken run on the final commit is next.
9. [ ] **One unbroken run:** `playthrough_elite` from a new campaign on `main`
   in one go (snapshots on, D96), then Windows and Linux builds from that commit.
10. [ ] **#44** Hand-played session when the owner is ready: fresh Windows and
   Linux builds from one commit, `test-cases.md` as the checklist.
11. [ ] **#45** Android, deferred by the owner until after #44 (D72); **#50**
    German as games of its own (D95) on `coop/german` (its own draft PR):
    both dumps import, Rote plays to BROCK in two windows; the engine's own
    English lines and a Blaue playthrough remain; **#14** upstream 0.1.75 merged
    on `coop/upstream-sync` (D97), waiting on the owner's cartridge checks.

## Every task ends with

- GUT tests for the change, the co-op suites and the budget test passing, the
  whole suite when game code changed, `tools/release.sh --gates`;
- a two-window scenario run and its captures looked at, when it shows on screen;
- `test-cases.md`, `progress.md`, `tracking.md` and a D-entry where a decision
  was made; the issue commented; the branch pushed.
