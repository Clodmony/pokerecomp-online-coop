# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session. It lives in the repository so it
survives any worktree path and any tool; per-checkout agent memory is not read
by a session that starts in another worktree. State goes here; stable recipes
go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-16 (M14 wave 1 done: five issues merged).

## Repository state

- Default branch `pokerecomp-online-coop` at dfd0641f, the merge of #194.
  `main` = upstream main (ed886823, 0.1.78). No open pull requests.
- Next free decision number: D136.
- Co-op protocol 9 (#175). Gold and Silver (USA/Europe) are imported in this
  machine's own user folder, so Gold and Silver scenarios run here.
- History rewritten once (D129): the old co-op history is backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-links/backup-20261015.git`.

## M14 wave 1 (#189, closed)

Five issues built in parallel by one agent each, merged in the owner's order,
each merge verified with `tools/verify.sh` before its push:

| Issue | PR | Decision | Merge |
|---|---|---|---|
| #175 the host's clock for every window | #190 | D133 | 74c4e31a |
| #173 the opening, starters, gifts, wild tables | #191 | D131 | 9f83c8df |
| #178 day care and eggs per player | #192 | D135 | 65d3ff16 |
| #174 sharing the Johto world | #193 | D132 | 5f8077de |
| #176 co-op battles on the Generation 2 screen | #194 | D134 | dfd0641f |

- Last verify (on dfd0641f): GUT 5259/5259, gates, boot, both ENet demos,
  three processes, `johto_battle`, `start_coop_menu`, `johto_gate`,
  `gold_and_silver`: all passed.
- The owner's answers are in the decisions: the rival steals per window
  (D131); the opening's scenes (New Bark Town's teacher, Elm's lab, Mom, Mr.
  Pokémon, Route 29's tutorial) are each player's own (D132); a late joiner
  gets the Pokégear, Pokédex, Potion and five Poké Balls (D131); one Amulet
  Coin doubles every participant's prize (D134). Daylight saving stays each
  window's own and never moves the shared clock (owner, 2026-10-16: add "the
  owner's choice" to D133 with the next docs change that touches it).
- Gold and Silver hand-test cases use the prefix J (J01 to J54): the German
  cases already had G01 to G10. The renumbering (6731fdc0) went straight onto
  the integration branch during the merges, outside a pull request.
- Not seen on a cartridge yet: a Ruins puzzle (its board is random), a Johto
  rival lock, the League and its exit redraw, the Fast Ship, shiny, Unown,
  weather and a catch in a joined battle, both-versions wild Pokémon in a
  window, the day care's own deposit menus, an egg laid by walking.
- Watch: `enet-demo-gold` failed once at "red beats the leader" under heavy
  load and passed 9 of 9 runs alone or in parallel; every demo step shares a
  600-frame budget and the leader battle's turns are random. File an issue if
  it recurs.

## Next candidates

- Wave 2, all unblocked now (prerequisites merged), one agent each as in
  wave 1: #177 phone per player, #179 Bug-Catching Contest, #180 roamers and
  legendaries, #181 Cable Club, link battles and Mystery Gift, #183 seeds and
  autoplay (`coop_seed.gd -- gold new` with `at=`, `at2=`, `event=`, `care=`
  and Johto autoplay of the opening exist), #149 Generation 2 battle
  questions, #195 host battles use the campaign's time of day, #196 the day
  care keeps a uid, #188 small leftovers (tab default name, the Gold tool
  host's items, `johto_day_care`'s party capture). Likely overlaps: #181 and
  #149 and #195 in the battle files; #177 and #179 in the clock and ownership.
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

- Main checkout on `pokerecomp-online-coop` at dfd0641f.
- The Superset worktree is detached at the merge of #187 (no branch).
- Wave 1's worktrees and branches are removed. No background processes.
- `~/dev-scratch/pokerecomp-online-coop/verify/` and `.../wave1/` hold the
  wave's verify runs (Gold captures, local only); the owner may delete them.

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
