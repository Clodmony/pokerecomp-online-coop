# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-15 (after #171, PR #186).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #170 (108975b2;
  #167 closed). `main` = upstream main (ed886823, 0.1.78).
- History rewritten once (D129, 2026-10-15): the co-op commits lost their
  session links, so every co-op hash changed. The old history is backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-links/backup-20261015.git`.
- Next decision number: D130.

## Open pull requests (the owner says when to merge)

- **#186** (draft) `coop/171-gen2-scope`: Closes #171, plus D129's docs
  (the decision, `AGENTS.md`'s rules, the rewritten hashes in `progress.md`).
  Docs only: D128 (the
  owner's Gold and Silver choices), `design.md`'s Gold and Silver section,
  `playbook.md` phase 5, a progress entry. Release gates pass; verify not run
  (no code). **The owner approved merging it (2026-10-15): merge it first in
  the next session.**

## Next candidates

- **M14 Gold and Silver co-op** (milestone 16 in the API), in
  `playbook.md` phase 5's order. First: **#172**, the gate (`coop_lobby.gd`
  `GAMES`, `coop_policy.gd` `VERSION_PAIRS`, the Co-op tab, `coop_save.gd`),
  tested on `battle_fixture.gd`'s Generation 2 fixture, then a two-window
  scenario in New Bark Town (needs an imported Gold or Silver cartridge from
  the owner; ask whether one is imported). Open owner questions written into
  issues: the rival's stolen starter (#173), RED joined or per player (#184),
  the Time Capsule's design (#182).
- **The owner's hand-played session** of Red/Blue: two devices, Pallet Town to
  BROCK, `docs/coop/readiness.md`; also #140's retest with
  `builds/140-picked-pad-only-490f0aad` (P11, K17) and K21 (#161).
- Open milestones otherwise: M10 (#44 builds, #45 Android, #46 iOS), M0 #15
  CI, M13 (#55, #56), M12 German (#50).
- Possible issues, ask before filing: the session menu's FIGHT list is fixed
  (BROCK, ONIX L60, PIDGEY L5, RATTATA L4), not the map's wild table; a mouse
  with a joystick interface is listed twice as a pad;
  `partner_tracker_cabins`' `p2_hall` never photographs both in the hall from
  BLUE's side.

## Worktrees and background processes

- The Superset worktree holds `coop/171-gen2-scope`, pushed. No background
  processes. The main checkout is on `pokerecomp-online-coop` at 108975b2, up
  to date.

## Working notes (stable, keep short)

- A scenario can build its own seed (`SEED_ARGS`, `coop_seed.gd`'s `party=`,
  `mon=` (the first replaces the lead), `item=` and `at=` beside a trainer;
  the runner reads one line of it, so build a long one with `printf`); in battles an `@` press walks one menu
  level and is dropped while a turn's lines play (see `tools/coop_screens.sh`'s
  usage). A battle's outcome repeats for a fixed `seed=` in `HOST_ARGS` when
  the presses give the same turns.

- No session links in commits or PR bodies (owner's rule, 2026-10-15): no
  `Claude-Session:` trailer, PR bodies end with the "Generated with Claude
  Code" line only. The history and PR bodies were cleaned once (D129);
  GitHub Support's purge of the old PR refs is the owner's request.
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

- `~/dev-scratch/pokerecomp-online-coop/session-links/` (the pre-D129
  mirror, the hash map, the cleaned PR bodies) once GitHub Support purged the
  old refs.

- `builds/140-picked-pad-only-490f0aad` once #140 is retested;
  `builds/pokerecomp-online-coop-0c6da178` and its two zips, never listed.
- Superset lists a workspace of the retired repository
  (`honeysuckle-seahorse`) whose folder is gone; remove it in Superset.
- `~/dev-scratch/pokerecomp-coop/`: keep `rewrite.git` and the PvP patch
  (2026-10-11, five co-op files; friend battles have landed since, so it is
  likely superseded); the rest (`bag-size`, `migrate`, `verify`, the filter
  scripts, logs and body files) is migration leftovers.
