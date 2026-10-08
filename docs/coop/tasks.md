# Tasks: start here

The resume point for the next session. Read [playbook.md](playbook.md) for the
why; this is the what, in order. Tick a box in the same commit as the work, and
keep the snapshot below current.

## Snapshot (2026-10-08, second session, halted at the usage limit)

- **Branches and pull requests** (all drafts, stacked, merge in this order):
  #58 `coop/slice-1`, #79 `coop/m1-state-sync`, #80 `coop/launcher`, #81
  `coop/owner-rules`, #83 `coop/playthrough` (now with `coop/autoplay-surge`
  merged, #87).
- **Owner decisions:** all six answered (D72); none waiting.
- **Halted mid-round** (all pushed; the agents' git worktrees keep their
  scratch files):
  - Merged into `coop/playthrough` and chained in ROUTES: `erika` (D83),
    `tower` (D82), `koga` (D81), `sabrina` (D85); #24 (D84, protocol 5);
    D80 (a checkpoint only on a real SAVE).
  - The chained run's Rocket Hideout car stall was the autopilot choosing the
    wrong floor and blocking the car's door path (`coop/elevator-stall`, merged).
    The chained run then stalled on Pokémon Tower 7F for a partner arriving
    after Mr. Fuji's rescue (`coop/tower-7f-late`, in progress).
  - `coop/autoplay-blaine` merged (D86): Cinnabar and BLAINE, chained after
    `sabrina`; two seeded runs pass.
  - `coop/autoplay-victory` (WIP commit): GIOVANNI, Route 22's second rival,
    Victory Road; unfinished.
  - `coop/autoplay-elite` merged (D87 provisional, D88): the Elite Four, the
    Champion and each player's Hall of Fame, chained after `blaine` until
    `victory` lands between them.
  - Questions for the owner: should Saffron's gate guards be the campaign's
    (today each player hands over their own drink, D85)? How should a shared
    Elite Four run work? Built provisionally as D87 (each player's own run,
    the members one encounter for the campaign); confirm or choose otherwise.
  - Seeds (lost on reboot) were under `/tmp/claude-1000/lead/seeds/`; rebuild
    with `tools/coop_seed.gd`.
- **Next free decision number:** D89 (D72 to D88 are recorded).
- **Godot 4.8-dev4:** `~/Downloads/Godot_v4.8-dev4_linux.x86_64.zip`, unzip it
  into the session scratchpad; the system `godot` is 4.7 and cannot open the
  project. Export templates are installed.
- **Cartridge:** the owner's Red import is `rom_cache/red_ea9bcae6` in the user
  folder; the scenario runner links it read-only into a private one.
- **Seeds:** `SEED=<dir>` starts a scenario from a campaign and the autopilot's
  `from=<leg>` skips the legs before it; `tools/coop_seed.gd -- red <leg> <dir>`
  writes one at any leg of upstream's story walk in seconds (D78). Seeds are
  never committed.
- **Not in git (lost on reboot):** run captures, logs, seeds and the agents'
  scratch scripts; the agents' git worktrees can be removed once their
  branches are merged.

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
8. [ ] **#88** Extend the autopilot stretch by stretch to the Hall of Fame;
   two or three agents in parallel, one stretch each, the lead merging.
9. [ ] **#44** Hand-played session when the owner is ready: fresh Windows and
   Linux builds from one commit, `test-cases.md` as the checklist.
10. [ ] **#45** Android, deferred by the owner until after #44 (D72); **#50**
    German once the owner supplies a dump; **#14** upstream merge after the
    pull requests merge.

## Every task ends with

- GUT tests for the change, the co-op suites and the budget test passing, the
  whole suite when game code changed, `tools/release.sh --gates`;
- a two-window scenario run and its captures looked at, when it shows on screen;
- `test-cases.md`, `progress.md`, `tracking.md` and a D-entry where a decision
  was made; the issue commented; the branch pushed.
