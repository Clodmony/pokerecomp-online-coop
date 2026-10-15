# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session. It lives in the repository so it
survives any worktree path and any tool; per-checkout agent memory is not read
by a session that starts in another worktree. State goes here; stable recipes
go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-16 (#187 merged; M14 wave 1 started).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #187 (98e253c1;
  #172 closed). `main` = upstream main (ed886823, 0.1.78).
- Next free decision number: D136 (D131 to D135 are reserved for wave 1).
- Gold and Silver (USA/Europe) are imported in this machine's own user folder
  (2026-10-16), so Gold and Silver scenarios run here.
- History rewritten once (D129): the old co-op history is backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-links/backup-20261015.git`.

## M14 wave 1: five issues built in parallel (#189)

The owner asked (2026-10-16) for a group of issues built at once: one agent,
one worktree under `~/dev-scratch/pokerecomp-online-coop/worktrees/`, one
branch and one draft pull request per issue. Each depends only on #172.

| Issue | Branch | Decision | State |
|---|---|---|---|
| #173 the opening, starters, gifts, wild tables | `coop/173-johto-opening` | D131 | agent running |
| #174 sharing the Johto world | `coop/174-johto-world` | D132 | agent running |
| #175 the host's clock for every window | `coop/175-host-clock` | D133 | agent running |
| #176 co-op battles on the Generation 2 screen | `coop/176-johto-battles` | D134 | agent running |
| #178 day care and eggs per player | `coop/178-johto-day-care` | D135 | agent running |

- Owner's answer for #173 (2026-10-16): the rival steals per window, as the
  cartridge: in each player's own opening, the starter strong against that
  player's pick.
- Merging the wave: in the order the owner approves, in the main checkout
  (see Working notes). Expect conflicts only in the docs (`progress.md`'s
  top, `test-cases.md`, `decisions.md`'s end, `AGENTS.md`'s table) and maybe
  in `coop_ownership.gd`'s tables (#174 and #178) or `coop_world_link.gd`
  (#174 and #175): keep both sides. After each merge, run
  `tools/verify.sh gold_and_silver` on the result before the next.

## After wave 1

- Wave 2 candidates, once their prerequisite merged: #177 phone and #179
  Bug-Catching Contest (need #175), #180 roamers and legendaries (needs #174),
  #181 Cable Club and Mystery Gift (needs #176), #183 seeds and autoplay
  (needs #173), #149 Generation 2 battle questions (after #176), #188 the Gold
  tool host's items and the tab's default name (small).
- Need the owner first: #182 the Time Capsule's design; #184 RED on Mt.
  Silver joined or per player. #185 Crystal comes last.
- Outside M14: the owner's hand-played Red/Blue session (`readiness.md`), #140's
  retest with `builds/140-picked-pad-only-490f0aad` (P11, K17), K21 (#161);
  M10 (#44, #45, #46), M0 #15, M13 (#55, #56), M12 German (#50).
- Possible issues, ask before filing: the session menu's FIGHT list is fixed
  (BROCK, ONIX L60, PIDGEY L5, RATTATA L4), not the map's wild table; a mouse
  with a joystick interface is listed twice as a pad;
  `partner_tracker_cabins`' `p2_hall` never photographs both in the hall from
  BLUE's side.

## Worktrees and background processes

- Main checkout on `pokerecomp-online-coop` at the merge of #187.
- The Superset worktree is detached at that merge (no branch).
- Wave 1 worktrees: `~/dev-scratch/pokerecomp-online-coop/worktrees/<issue>`,
  one per agent; remove each once its pull request is merged.

## Working notes (stable, keep short)

- Merge, when the owner says so: in the main checkout on
  `pokerecomp-online-coop`, `git merge --no-ff <branch> -m "Merge #N: ..."`,
  push, delete the merged branch. Never `gh pr merge`.
- `gh` and `git`: always pass `-R Clodmony/pokerecomp-online-coop`.
- No session links in commits or PR bodies (D129); PR bodies end with the
  "Generated with Claude Code" line only. The owner's GitHub Support ticket
  (2026-10-15) asks to drop the old commits from 34 PR refs.
- `GODOT` = the full path to the 4.8-dev7 binary (`.superset/setup.sh`).
- GUT never on the owner's user folder: set `XDG_DATA_HOME` to a private
  folder and run under `bwrap --dev-bind / / --dev /dev` (no pads).
- Johto's rules go in `game/coop/coop_johto.gd` (`PokeCoopJohto`, D130);
  `PokeCoopPolicy` asks it by generation. Red and Blue's rules stay as they are.
- Scenarios: `tools/coop_screens.sh <name or path> <out>`; a scenario passes
  when its windows don't fail, so look at every capture. Launcher windows'
  seconds count from each launch, p2 about four seconds behind p1. A seed:
  `SEED_ARGS` / `coop_seed.gd` (`party=`, `mon=`, `item=`, `at=`).
- Comment ceiling: `MAX_COMMENT_LINES` = 41583, the tree exactly at it; only
  `.gd` lines under `autoload/`, `game/`, `tools/` that start with `#` count
  (a trailing `##` after code does not): every change nets zero.
- `git checkout -- '*.import'` after an editor import.

## Cleanup the owner may approve

- `~/dev-scratch/pokerecomp-online-coop/session-links/` once GitHub Support
  purged the old refs.
- `builds/140-picked-pad-only-490f0aad` once #140 is retested;
  `builds/pokerecomp-online-coop-0c6da178` and its two zips.
- Superset's workspace of the retired repository (`honeysuckle-seahorse`).
- `~/dev-scratch/pokerecomp-coop/`: keep `rewrite.git` and the PvP patch; the
  rest is migration leftovers.
