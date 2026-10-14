# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-15 (after #26's pull request).

## Repository state

- Default branch `pokerecomp-online-coop` at d043d0d7 (merge of the workspace
  branch on 2026-10-14, after #154 / #20). `main` = upstream main (ed886823,
  0.1.78).
- Next decision number: D126.

## Open pull requests (the owner says when to merge)

- **#156** (draft) `coop/26-battle-session-events`, "Part of #26", not
  "Closes": D125 has the owner choosing to close the field's gaps rather than
  drive `Gen2BattleScreen` itself, and the field is still its own node.
  Ask the owner whether #26 closes with it. Test cases B37-B42, scenario
  `battle_flows` (needs a seed: `tools/coop_seed.gd red viridian_forest
  level=9`, then RED's lead at L14, 2030 EXP, 6 HP, SCRATCH/GROWL/EMBER/TACKLE
  and three POTIONs, as the scenario's header says). Verify run
  `20261014-235125`: all passed, suite 5200/5200; captures looked at; the
  catch scenario's BLUE presses were restored after it and rerun. No builds.
- The Gen 2 half of #28 is issue #149 (later milestone, D61).

## Next candidates

- The owner's retest of #140 (merged) with the private build
  `builds/140-picked-pad-only-490f0aad` (hand, P11 and K17).
- A hand-played session (test cases K17-K21, B34-B42, P10, P11, K16, T08,
  S20; `docs/coop/readiness.md`).
- Noticed, not filed: upstream's `Gen2NicknamePromptScreen.handle_button`
  scrolls the nickname question's `cont` on A only; the cartridge's
  `WaitForTextScrollButtonPress` also takes B (single-player too). Ask the
  owner whether to file or report upstream.
- Possible issue: the session menu's FIGHT list is fixed (BROCK, wild ONIX
  L60, PIDGEY L5, RATTATA L4 from `register_encounter`), not the map's wild
  table. Ask the owner before filing.
- Noticed, not filed: a mouse that also exposes a joystick interface is listed
  twice as a pad; harmless with a pick, odd under "Every controller". Ask
  before filing.

## Worktrees and background processes

- Main checkout on `pokerecomp-online-coop`, clean. One Superset worktree on
  `coop/26-battle-session-events`, clean and pushed. No background processes.

## Working notes (stable, keep short)

- `gh` and `git`: always pass `-R Clodmony/pokerecomp-online-coop`; without it
  `gh` answers for the upstream repository.
- Merge, when the owner says so: in the main checkout on
  `pokerecomp-online-coop` (or detached at `origin/pokerecomp-online-coop`),
  `git merge --no-ff <branch or sha> -m "Merge #N: ..."`, push, delete the
  merged branches. Never `gh pr merge`.
- `GODOT` must be the full path to the 4.8-dev7 binary (see `.superset/setup.sh`).
- One GUT file without pads: `XDG_DATA_HOME=<private dir>` plus the `gut1.sh`
  helper kept in scratch (bwrap; set `XDG_DATA_HOME` yourself).
- A scenario file can be a path: `tools/coop_screens.sh <path/to/x.sh> <out>`.
  With `P2_TOOL=split` p2's seconds lag p1's by about 10 s.
- A scenario passes when its windows don't fail, not when its captures show
  what its comments promise: look at every capture.
- Comment ceiling: `MAX_COMMENT_LINES` = 41583 and the tree is exactly at it;
  only `.gd` under `autoload/`, `game/` and `tools/` count, so every such
  change must be net zero (tests are free).
- `git checkout -- '*.import'` after an editor import.

## Cleanup the owner may approve

- Merged co-op branches still on the remote and local: `coop/128-controller-typing`,
  `coop/132-scenario-runner`, `coop/133-autoplay-brock-seed`,
  `coop/140-138-139-pads-tab-quit`, `coop/28-battle-offers`,
  `coop/44-private-builds`, `coop/53-local-split-screen` (check each is merged
  first).
- Old builds under `builds/`: `44-private-builds-0f58e0f8`,
  `53-local-split-screen-2f0d3c2f` and, once #140 is retested,
  `140-picked-pad-only-490f0aad`.
- Scratch under `~/dev-scratch/pokerecomp-online-coop/`: `port`,
  `pr-123-body.md`, `pr-workspace-body.md`, `build-0c6da178.txt`, old
  `verify/` runs, `verify-merge-all.txt`. The #26 seed is kept in `26/seed`
  until #156 merges (the rest of `26/` is deleted).
- The retired private repository and its checkout; close #57 when the owner
  agrees.
