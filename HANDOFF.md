# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-14 (after #20 and the workspace pull request).

## Repository state

- Default branch `pokerecomp-online-coop` at 1037cf46 (merge of #153 on
  2026-10-14; #140 closed). `main` = upstream main (ed886823, 0.1.78).
- Next decision number: D125.

## Open pull requests (the owner says when to merge)

- **#154** (draft) `coop/20-resume-stale-link`, Closes #20. D124, test case S20,
  no scenario (nothing new on screen). Verify run `20261014-192005`: all
  passed, suite 5192/5192, `leave_rejoin_takeover` and `launcher_host_join`
  captures looked at. No builds made. The owner declined reconnection secrets
  (friends-only hosting); the fix keeps `PokeCoopSession.process`'s
  join-as-new fallback (`_retry_as_new`) to before the first welcome. The
  phone suspend check moved to #45.
- The workspace pull request (`coop/workspace-handoff`): this file,
  `.superset/`, `CLAUDE.md`, the AGENTS.md pointers.
- The Gen 2 half of #28 is issue #149 (later milestone, D61).

## Next candidates

- The owner's retest of #140 (merged) with the private build
  `builds/140-picked-pad-only-490f0aad` (hand, P11 and K17).
- A hand-played session (test cases K17-K21, B34-B36, P10, P11, K16, T08,
  S20; `docs/coop/readiness.md`); #26 battle screen from session events
  (partial: find what is still local).
- Possible issue: the session menu's FIGHT list is fixed (BROCK, wild ONIX
  L60, PIDGEY L5, RATTATA L4 from `register_encounter`), not the map's wild
  table. Ask the owner before filing.
- Noticed, not filed: a mouse that also exposes a joystick interface is listed
  twice as a pad; harmless with a pick, odd under "Every controller". Ask
  before filing.

## Worktrees and background processes

- Main checkout on `pokerecomp-online-coop`. One Superset worktree on
  `coop/20-resume-stale-link`, clean and pushed. One scratch worktree on
  `coop/workspace-handoff`. No background processes.

## Working notes (stable, keep short)

- `gh` and `git`: always pass `-R Clodmony/pokerecomp-online-coop`; without it
  `gh` answers for the upstream repository.
- Merge, when the owner says so: detach at `origin/pokerecomp-online-coop`,
  `git merge --no-ff <head sha> -m "Merge #N: ..."`, push
  `HEAD:pokerecomp-online-coop`, `git pull --ff-only` in the main checkout,
  delete the merged branches. Never `gh pr merge`.
- `GODOT` must be the full path to the 4.8-dev7 binary (see `.superset/setup.sh`).
- One GUT file without pads: `XDG_DATA_HOME=<private dir>` plus the `gut1.sh`
  helper kept in scratch (bwrap; set `XDG_DATA_HOME` yourself).
- A scenario file can be a path: `tools/coop_screens.sh <path/to/x.sh> <out>`.
  With `P2_TOOL=split` p2's seconds lag p1's by about 10 s.
- Comment ceiling: `MAX_COMMENT_LINES` = 41583 and the tree is exactly at it;
  only `.gd` under `autoload/`, `game/` and `tools/` count, so every such
  change must be net zero (tests are free).
- `git checkout -- '*.import'` after an editor import.

## Cleanup the owner may approve

- Old builds under `builds/`: `44-private-builds-0f58e0f8`,
  `53-local-split-screen-2f0d3c2f` and, once #140 is retested,
  `140-picked-pad-only-490f0aad`.
- Scratch under `~/dev-scratch/pokerecomp-online-coop/`: `port`,
  `pr-123-body.md`, `build-0c6da178.txt`, old `verify/` runs,
  `verify-merge-all.txt`.
- The retired private repository and its checkout; close #57 when the owner
  agrees.
