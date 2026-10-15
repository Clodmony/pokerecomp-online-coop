# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-16 (after #172, PR #187).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #186 (7f10f0c1;
  #171 closed). `main` = upstream main (ed886823, 0.1.78).
- History rewritten once (D129, 2026-10-15): the co-op commits lost their
  session links, so every co-op hash changed. The old history is backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-links/backup-20261015.git`.
- Next decision number: D131.
- Gold and Silver (USA/Europe) are imported in this machine's own user folder
  (from the owner's ROM folder, 2026-10-16), so Gold scenarios run here.

## Open pull requests (the owner says when to merge)

- **#187** (draft) `coop/172-gold-silver-gate`: Closes #172. Gold and Silver a
  version pair on the Co-op tab, starting in New Bark Town; Johto's rules in
  `game/coop/coop_johto.gd` (D130, the owner's choice: shared core, Johto's
  rules in their own file); `coop_session.gd demo gold` in CI and verify; new
  scenario `gold_and_silver`. Verify all passed (GUT 5215/5215, both ENet
  demos, `gold_and_silver`, `launcher_host_join`).

## Next candidates

- **M14 Gold and Silver**, `playbook.md` phase 5's order. Next: **#173** (the
  opening, starters, gifts, wild tables), its rules in `PokeCoopJohto` (D130).
  First steps: the host ends a player's opening on Red and Blue's lab flag
  (`coop_host.gd`, `OPENING_LAB` / `OPENING_DONE_FLAG`), so the tab hides
  "Play Oak's opening" for Gold (`coop_page.gd` `_start_choice`); Gold's
  opening itself plays (clock question, Oak's speech) in a `coop_play.gd ...
  gold opening` window. Red and Blue rules in `PokeCoopPolicy` still apply to
  a Gold campaign and need Johto's answer in #173 or #174: `SHARED_ITEMS` and
  `GIFT_TMS` (`share_gifts`), `share_found_items`, `UNIQUE_WILD`,
  `RIVAL_SCENES`, the League's flags. Owner questions open in issues: the
  rival's stolen starter (#173), RED joined or per player (#184), the Time
  Capsule's design (#182).
- **The owner's hand-played session** of Red/Blue: two devices, Pallet Town to
  BROCK, `docs/coop/readiness.md`; also #140's retest with
  `builds/140-picked-pad-only-490f0aad` (P11, K17) and K21 (#161).
- Open milestones otherwise: M10 (#44 builds, #45 Android, #46 iOS), M0 #15
  CI, M13 (#55, #56), M12 German (#50).
- Possible issues, ask before filing: the session menu's FIGHT list is fixed
  (BROCK, ONIX L60, PIDGEY L5, RATTATA L4), not the map's wild table; a mouse
  with a joystick interface is listed twice as a pad;
  `partner_tracker_cabins`' `p2_hall` never photographs both in the hall from
  BLUE's side; `coop_session.gd host gold`'s scripted players get Red and
  Blue's item ids (could go with #183); the tab's name field starts at RED on
  any cartridge.

## Worktrees and background processes

- The Superset worktree holds `coop/172-gold-silver-gate`, pushed. No
  background processes. The main checkout is on `pokerecomp-online-coop` at
  7f10f0c1, up to date.

## Working notes (stable, keep short)

- A scenario can build its own seed (`SEED_ARGS`, `coop_seed.gd`'s `party=`,
  `mon=` (the first replaces the lead), `item=` and `at=` beside a trainer;
  the runner reads one line of it, so build a long one with `printf`); in battles an `@` press walks one menu
  level and is dropped while a turn's lines play (see `tools/coop_screens.sh`'s
  usage). A battle's outcome repeats for a fixed `seed=` in `HOST_ARGS` when
  the presses give the same turns.
- A launcher scenario's seconds count from each window's launch: p2's clock
  runs about four seconds behind p1's (`gold_and_silver`).
- No session links in commits or PR bodies (owner's rule, 2026-10-15): no
  `Claude-Session:` trailer, PR bodies end with the "Generated with Claude
  Code" line only. The history and PR bodies were cleaned once (D129);
  the owner opened a GitHub Support ticket (2026-10-15)
  to drop the old commits from 34 PR refs and garbage-collect them.
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
  only `.gd` lines under `autoload/`, `game/` and `tools/` that start with `#`
  count (a trailing `##` after code does not), so every such change must be
  net zero (tests are free).
- `git checkout -- '*.import'` after an editor import.

## Cleanup the owner may approve

- `~/dev-scratch/pokerecomp-online-coop/session-links/` (the pre-D129
  mirror, the hash map, the cleaned PR bodies) once GitHub Support purged the
  old refs.
- `~/dev-scratch/pokerecomp-online-coop/verify/` (two #172 runs with Gold
  captures).
- `builds/140-picked-pad-only-490f0aad` once #140 is retested;
  `builds/pokerecomp-online-coop-0c6da178` and its two zips, never listed.
- Superset lists a workspace of the retired repository
  (`honeysuckle-seahorse`) whose folder is gone; remove it in Superset.
- `~/dev-scratch/pokerecomp-coop/`: keep `rewrite.git` and the PvP patch
  (2026-10-11, five co-op files; friend battles have landed since, so it is
  likely superseded); the rest (`bag-size`, `migrate`, `verify`, the filter
  scripts, logs and body files) is migration leftovers.
