# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-15 (after #167, PR #170).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #169 (bc8202f8;
  #168 closed). `main` = upstream main (ed886823, 0.1.78).
- Next decision number: D128.

## Open pull requests (the owner says when to merge)

- **#170** (draft) `coop/167-scenario-seeds`: Closes #167. `bag_forty`
  (`viridian_forest` plus twenty `item=`) and `partner_tracker_cabins`
  (`ss_anne at=0:95:20,7:24,7`) build their own seed with `SEED_ARGS`.
  Scenarios and docs only. Verify run `20261015-201845` all passed (GUT
  5208/5208, both scenarios, every capture looked at). **The owner approved
  merging it (2026-10-15): merge it first in the next session.**
- #149 holds the Gen 2 halves of #28 and #27 (later milestone, D61).

## Next candidates

- **The owner's hand-played session** before Gen 2: two devices, Pallet Town
  to BROCK, `docs/coop/readiness.md`; also #140's retest with
  `builds/140-picked-pad-only-490f0aad` (P11, K17) and K21 (#161, needs the
  cartridge file picked on the Play tab).
- **Gen 2 (the owner asked, 2026-10-15)**: Gen 1 is feature-complete (M1-M9,
  M11 have no open feature issue) but only 8 of 205 hand cases are played.
  Gen 2 overturns D61's scope, so the owner decides it. If yes: one scoping
  issue first for the owner's choices (clock and time of day, phone, day care
  and eggs, Bug-Catching Contest, Unown, roaming beasts, the Kanto story after
  Johto, the Gen 2 trainer AI from #149), then a milestone of about 8-12
  issues. The code survey of what is Gen 1 only (2026-10-15): the gate
  (`coop_lobby.gd:13` GAMES, `coop_policy.gd:75` VERSION_PAIRS), policy
  (starters, opening, gifts, wild tables), `coop_ownership.gd` map-script
  bytes, `coop_world_link.gd` rest points and story locks, the battle menu's
  cursor and bag layout, the field's animations (none outside Gen 1), Cable
  Club trades and the link battle, `coop_seed.gd` and `coop_autoplay.gd` legs;
  `coop_save.gd` and the battle stage are generation-agnostic.
  **Next issue (the owner chose, 2026-10-15): the Gen 2 scoping issue.** File
  it with the choices above as questions for the owner, ask them, record the
  answers (decisions from D128), then propose the milestone's issues.
- Open milestones otherwise: M10 (#44 builds, #45 Android, #46 iOS), M0 #15
  CI, M13 (#55, #56), M12 German (#50).
- With #170 merged, every scenario but `brock_from_seed`, `german_screens`,
  `both_versions`, `vermilion_locks` and `story_seed` (seed on purpose) runs
  unattended in `tools/verify.sh`.
- Possible issues, ask before filing: the session menu's FIGHT list is fixed
  (BROCK, ONIX L60, PIDGEY L5, RATTATA L4), not the
  map's wild table; a mouse with a joystick interface is listed twice as a pad;
  `partner_tracker_cabins`' `p2_hall` (p2's clock lags) already shows RED gone
  into the cabin, so it never photographs both in the hall from BLUE's side.

## Worktrees and background processes

- The Superset worktree holds `coop/167-scenario-seeds`, pushed. No
  background processes. The main checkout is on `pokerecomp-online-coop` at
  bc8202f8, up to date.

## Working notes (stable, keep short)

- A scenario can build its own seed (`SEED_ARGS`, `coop_seed.gd`'s `party=`,
  `mon=` (the first replaces the lead), `item=` and `at=` beside a trainer;
  the runner reads one line of it, so build a long one with `printf`); in battles an `@` press walks one menu
  level and is dropped while a turn's lines play (see `tools/coop_screens.sh`'s
  usage). A battle's outcome repeats for a fixed `seed=` in `HOST_ARGS` when
  the presses give the same turns.

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

- `builds/140-picked-pad-only-490f0aad` once #140 is retested;
  `builds/pokerecomp-online-coop-0c6da178` and its two zips, never listed.
- Superset lists a workspace of the retired repository
  (`honeysuckle-seahorse`) whose folder is gone; remove it in Superset.
- `~/dev-scratch/pokerecomp-coop/`: keep `rewrite.git` and the PvP patch
  (2026-10-11, five co-op files; friend battles have landed since, so it is
  likely superseded); the rest (`bag-size`, `migrate`, `verify`, the filter
  scripts, logs and body files) is migration leftovers.
