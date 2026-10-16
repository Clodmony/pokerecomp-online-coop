# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session. It lives in the repository so it
survives any worktree path and any tool; per-checkout agent memory is not read
by a session that starts in another worktree. State goes here; stable recipes
go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-16 (M14 wave 1: three of five merged).

## Repository state

- Default branch `pokerecomp-online-coop` at 6731fdc0: #190, #191, #192
  merged (#175, #173, #178 closed), then the Gold and Silver test cases
  renumbered J01 on (the German cases already use G01 to G10).
  `main` = upstream main (ed886823, 0.1.78).
- Next free decision number: D136 (D131 to D135 are wave 1's).
- Co-op protocol 9 (#175). Gold and Silver (USA/Europe) are imported in this
  machine's own user folder, so Gold and Silver scenarios run here.
- History rewritten once (D129): the old co-op history is backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-links/backup-20261015.git`.

## M14 wave 1: five issues built in parallel (#189)

One agent, worktree (`~/dev-scratch/pokerecomp-online-coop/worktrees/<issue>`),
branch and draft PR per issue; the owner approved merging them in this order.

| Issue | PR | Decision | State |
|---|---|---|---|
| #175 the host's clock for every window | #190 | D133 | merged (74c4e31a) |
| #173 the opening, starters, gifts, wild tables | #191 | D131 | merged (9f83c8df) |
| #178 day care and eggs per player | #192 | D135 | merged (65d3ff16) |
| #174 sharing the Johto world | #193 | D132 | being reconciled with #191 by its agent (merge, no force-push) |
| #176 co-op battles on the Generation 2 screen | #194 | D134 | ready; merge after #193 |

- Owner's answers (2026-10-16): the rival steals per window (D131); New Bark
  Town's teacher gate, Elm's lab, Mom's Pokégear and Mr. Pokémon's house are
  each player's own (goes into #193's D132; its `johto_gate` scenario moves
  to a later team gate); a late joiner keeps the Pokégear, Pokédex, Potion and
  five Poké Balls (#191); an Amulet Coin carried in by any participant doubles
  every participant's prize (D134, in #194).
- Owner's answers to the PRs' questions (2026-10-16): daylight saving stays
  each window's own and never moves the shared clock (add "the owner's choice"
  to D133 with the next docs change that touches it); battles fought on the
  host take the campaign's time of day in a follow-up, #195 (after #194); a
  Pokémon keeps its uid through the day care, #196 (changes D135).
- Merging the last two: in the main checkout, `git merge --no-ff`, resolve the
  docs by keeping both sides (progress entries newest first, decisions by
  number, test cases by J number), run `tools/verify.sh` with the PR's
  scenarios plus `gold_and_silver`, look at the captures, then push.
- Watch: `enet-demo-gold` failed once at "red beats the leader" during verify
  under heavy load (5.7) and passed 9 of 9 runs alone or in parallel; every
  demo step shares a 600-frame budget and the leader battle's turns are
  random. File an issue if it recurs.

## After wave 1

- Wave 2 candidates: #177 phone and #179 Bug-Catching Contest (#175 merged),
  #183 seeds and autoplay (#173 merged; `coop_seed.gd -- gold new` and Johto
  autoplay of the opening exist), #180 roamers and legendaries (after #193),
  #181 Cable Club and Mystery Gift and #149 battle questions (after #194),
  #188 the Gold tool host's items and the tab's default name (small; #194
  gives the Gold tool host Johto items and FALKNER already), #195 battle time
  of day (after #194), #196 the day care keeps a uid.
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

- Main checkout on `pokerecomp-online-coop` at 6731fdc0.
- The Superset worktree is detached at the merge of #187 (no branch).
- Wave 1 worktrees: `~/dev-scratch/pokerecomp-online-coop/worktrees/<issue>`;
  173, 175 and 178 can go now (their branches are merged and deleted), 174 and
  176 once #193 and #194 merge.
- `~/dev-scratch/pokerecomp-online-coop/verify/` holds the wave's verify runs
  (Gold captures, local only); delete with the worktrees.

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
- Gold and Silver hand-test cases use the prefix J (`test-cases.md`); G is
  the German cases'.
- In a scenario, `keys=` is passed unquoted: a space inside an `@` pattern
  cuts off the rest of the key list; use `.` instead.
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
