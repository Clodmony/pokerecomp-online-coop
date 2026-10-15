# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session (issue loop, last step). It lives in the
repository so it survives any worktree path and any tool; per-checkout agent
memory is not read by a session that starts in another worktree. State goes
here; stable recipes go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-15 (after the group #158-#161, PR #PRNUM).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #157 (#27 closed,
  D126). `main` = upstream main (ed886823, 0.1.78).
- Next decision number: D128.

## Open pull requests (the owner says when to merge)

- **#PRNUM** (draft) `coop/158-scripted-hand-cases`: Closes #158, #159, #160,
  part of #161 (K16 done; K21 needs the cartridge file on the Play tab, a
  hand case). Scenarios for K16, K18, K20, S09, S24, B37-B40, B43; two co-op
  battle bugs fixed (nicknames named by species; traded Pokémon never
  disobeyed, D127, an upstream-file change in `effect_commands.gd`). Verify
  run VERIFYSTAMP.
- #149 holds the Gen 2 halves of #28 and #27 (later milestone, D61).

## Next candidates

- **The owner's hand-played session** before Gen 2: two devices, Pallet Town
  to BROCK, `docs/coop/readiness.md`; also #140's retest with
  `builds/140-picked-pad-only-490f0aad` (P11, K17) and K21.
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
- #162: JUMP KICK's crash (B38), B43's second half, S24's dead link.
- Open milestones otherwise: M10 (#44 builds, #45 Android, #46 iOS), M0 #15
  CI, M13 (#55, #56), M12 German (#50).
- Possible issues, ask before filing: the session menu's FIGHT list is fixed
  (BROCK, ONIX L60, PIDGEY L5, RATTATA L4), not the map's wild table; a mouse
  with a joystick interface is listed twice as a pad.

## Worktrees and background processes

- The Superset worktree holds `coop/158-scripted-hand-cases`, pushed. No
  background processes.

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

- `builds/140-picked-pad-only-490f0aad` once #140 is retested;
  `builds/pokerecomp-online-coop-0c6da178` and its two zips, never listed.
- Superset lists a workspace of the retired repository
  (`honeysuckle-seahorse`) whose folder is gone; remove it in Superset.
- `~/dev-scratch/pokerecomp-coop/`: keep `rewrite.git` and the PvP patch
  (2026-10-11, five co-op files; friend battles have landed since, so it is
  likely superseded); the rest (`bag-size`, `migrate`, `verify`, the filter
  scripts, logs and body files) is migration leftovers.
- The owner's own user folder holds 15 test caches under `rom_cache`
  (`coophost*`, `coopclient*` from 2026-10-06/07, `daycaretest`,
  `evolutiontest`, `testgen1name`, `testred` from 2026-10-13): suites run
  outside `tools/verify.sh` left them. About 16 MB; the owner may delete them.
