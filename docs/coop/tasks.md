# Tasks: start here

The resume point for the next session. Read [playbook.md](playbook.md) for the
why; this is the what, in order. Tick a box in the same commit as the work, and
keep the snapshot below current.

## Snapshot (2026-10-07, end of session)

- **Branches and pull requests** (all drafts, stacked, merge in this order):
  #58 `coop/slice-1`, #79 `coop/m1-state-sync`, #80 `coop/launcher`, #81
  `coop/owner-rules`, #83 `coop/playthrough` (CI green before its last commits;
  whole suite 4989/4989 locally after the launcher merge).
- **Pushed, not merged:** `coop/autoplay-surge` at `79eb3529` (#87).
- **Next free decision number:** D72 (D61 to D71 are recorded).
- **Godot 4.8-dev4:** `~/Downloads/Godot_v4.8-dev4_linux.x86_64.zip`, unzip it
  into the session scratchpad; the system `godot` is 4.7 and cannot open the
  project. Export templates are installed.
- **Cartridge:** the owner's Red import is `rom_cache/red_ea9bcae6` in the user
  folder; the scenario runner links it read-only into a private one.
- **Not in git (lost on reboot):** run captures and logs under
  `/tmp/claude-1000/`, the agents' scratch scripts. The agents' worktrees under
  `.claude/worktrees/` can be removed once their branches are merged.

## Next tasks

1. [ ] **#86** Fix the Cerulean thief's stuck TM28 box (upstream), with a GUT
   test. Done when a no-press text followed by a fade leaves no box.
2. [ ] **#87** Merge `coop/autoplay-surge` into `coop/playthrough`. Conflicts
   expected in `tools/coop_autoplay.gd`. Then: co-op suites, whole suite,
   `playthrough_misty`, `cable_club_trade`, `playthrough_surge` (should pass
   after task 1), D72 onward for its three fixes, test-case rows (re-host inside
   a building; ticket, TM28 and HM01 for everyone; per-player city scripts;
   Vermilion Gym's door for both; CUT), progress rows, PR #83's description.
3. [ ] **Owner decisions** (playbook, "Decisions waiting on the owner"): ask
   at the start of the session; they gate tasks 4 and 6.
4. [ ] **#84 step 1** Hold a window's world patches until a rest point
   (`script_busy()` false and no map load pending) instead of 15 s; a partial
   patch only on SAVE or LEAVE. Tests: a 40 s scene with a battle sends nothing
   until it ends; LEAVE mid-scene sends the last resting state.
5. [ ] **#84 step 2** Map-script steps: resting values only; classify the gym
   bytes BROCK to GIOVANNI as per player; a step for the window's own map waits
   for its next map load. Tests: one TM34 when a partner stands in Pewter Gym;
   the Vermilion dock with both in the city. Then `world_pull` logs the busy
   state, and `design.md` lists what is not shared.
6. [ ] **#85** Vermilion Gym's locks kept by the host while someone is in the
   city or gym; scenario: a partner enters mid-search and the cans stay.
7. [ ] **#24** (only if approved) the first player in drives a contested rival
   scene.
8. [ ] **#88** Extend the autopilot stretch by stretch to the Hall of Fame;
   two or three agents in parallel, one stretch each, the lead merging.
9. [ ] **#44** Hand-played session when the owner is ready: fresh Windows and
   Linux builds from one commit, `test-cases.md` as the checklist.
10. [ ] **#45** Android once the SDK question is settled; **#50** German once a
    dump exists; **#14** upstream merge after the pull requests merge.

## Every task ends with

- GUT tests for the change, the co-op suites and the budget test passing, the
  whole suite when game code changed, `tools/release.sh --gates`;
- a two-window scenario run and its captures looked at, when it shows on screen;
- `test-cases.md`, `progress.md`, `tracking.md` and a D-entry where a decision
  was made; the issue commented; the branch pushed.
