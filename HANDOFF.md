# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-15 (after #165, PR #166).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #164 (fef64c24;
  #162 closed). `main` = upstream main (ed886823, 0.1.78).
- Next decision number: D128.

## Open pull requests (the owner says when to merge)

- **#166** (draft) `coop/165-route3-seeds`: Closes #165. `switch_offer`,
  `mimic_suggest`, `party_balls`, `trainer_busy` build their own ROUTE 3 seed
  (`SEED_ARGS`, three level 25 Pokémon spelt out with `mon=`, `at=`); tools and
  docs only. Verify run `20261015-092118` all passed (GUT 5207/5207, the four
  plus `trainer_status_moves`). No builds made.
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
- Open milestones otherwise: M10 (#44 builds, #45 Android, #46 iOS), M0 #15
  CI, M13 (#55, #56), M12 German (#50).
- Possible issues, ask before filing: `bag_forty` and `partner_tracker_cabins`
  still need a hand-moved `SEED=` and could build theirs with `SEED_ARGS` as
  #165 did (`brock_from_seed`, `german_screens`, `both_versions` and
  `vermilion_locks` take a seed on purpose); `coop_seed.gd`'s first `mon=`
  drops the `party=` copies, so the two options don't combine; the session
  menu's FIGHT list is fixed (BROCK, ONIX L60, PIDGEY L5, RATTATA L4), not the
  map's wild table; a mouse with a joystick interface is listed twice as a pad.

## Worktrees and background processes

- The Superset worktree holds `coop/165-route3-seeds`, pushed. No background
  processes. The main checkout is on `pokerecomp-online-coop`, behind
  `origin` (pull before merging there).

## Working notes (stable, keep short)

- A scenario can build its own seed (`SEED_ARGS`, `coop_seed.gd`'s `mon=`,
  `item=` and `at=` beside a trainer); in battles an `@` press walks one menu
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
