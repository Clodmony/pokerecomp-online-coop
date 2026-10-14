# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-15 (after #27's pull request, #157).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #156 (2026-10-15;
  #26 closed: the co-op field plays what the battle screen would, D125, and
  upstream's nickname prompt scrolls with B). `main` = upstream main
  (ed886823, 0.1.78).
- Next decision number: D127.

## Open pull requests (the owner says when to merge)

- **#157** (draft) `coop/27-session-trainer-ai`, Closes #27. D126: Gen 1
  sessions already shared `Gen1TrainerAI` with the battle screen; two co-op
  tests pin it (each shown failing on a deliberate break), test case B43, no
  scenario (nothing on screen). Verify run `20261015-012534`: all passed,
  suite 5202/5202. No builds made.
- #149 now holds the Gen 2 halves of #28 and #27 (later milestone, D61).

## Next candidates

- The owner's retest of #140 (merged) with the private build
  `builds/140-picked-pad-only-490f0aad` (hand, P11 and K17).
- A hand-played session (test cases K17-K21, B34-B43, P10, P11, K16, T08,
  S20; `docs/coop/readiness.md`).
- No battle issue is left in M4. Open milestones next: M10 (#44 private
  builds: check what is left; #45 Android; #46 iOS), M0 #15 private CI, M13
  provenance (#55, #56), M12 German (#50).
- Possible issue: the session menu's FIGHT list is fixed (BROCK, wild ONIX
  L60, PIDGEY L5, RATTATA L4 from `register_encounter`), not the map's wild
  table. Ask the owner before filing.
- Noticed, not filed: a mouse that also exposes a joystick interface is listed
  twice as a pad; harmless with a pick, odd under "Every controller". Ask
  before filing.

## Worktrees and background processes

- Main checkout on `pokerecomp-online-coop`, clean. The Superset worktree
  that held #26 now holds `coop/27-session-trainer-ai`, pushed. The local
  branch `coop/26-battle-session-events` (merged, gone on the remote) can be
  deleted. No background processes.

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
  `coop/44-private-builds`, `coop/53-local-split-screen`, and the local
  `coop/26-battle-session-events` (check each is merged first).
- Old builds under `builds/`: `44-private-builds-0f58e0f8`,
  `53-local-split-screen-2f0d3c2f` and, once #140 is retested,
  `140-picked-pad-only-490f0aad`.
- Scratch under `~/dev-scratch/pokerecomp-online-coop/`: `port`,
  `pr-123-body.md`, `pr-workspace-body.md`, `build-0c6da178.txt`, old
  `verify/` runs, `verify-merge-all.txt`.
- The retired private repository and its checkout; close #57 when the owner
  agrees.
