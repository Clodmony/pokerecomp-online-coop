# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session. It lives in the repository so it
survives any worktree path and any tool; per-checkout agent memory is not read
by a session that starts in another worktree. State goes here; stable recipes
go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-18 (#206 the Gold demo's stalled move: draft PR open; before it, the owner's first split-screen session: #217 and #218 merged as #219 and #220).

## Repository state

- Default branch `pokerecomp-online-coop` at the eight wave 2 merges, one
  fix commit (b2aae3cf), #219 and #220 (c97aa81a), plus handoff commits. `main` = upstream main
  (ed886823, 0.1.78).
- Co-op protocol 10 (#177, #179, #181). Next free decision number: D142.
  Hand-test cases run to J91, K22 and G11 without gaps.
- Gold and Silver (USA/Europe) are imported in this machine's own user folder,
  so Gold and Silver scenarios run here; English Blue is not (`red_and_blue`
  can't run here), the German Rote and Blaue are.
- History rewritten once (D129): the old co-op history is backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-links/backup-20261015.git`.

## Open pull requests

- #206's PR from `coop/206-gold-demo-leader` (draft, `Closes #206`): the
  Gold ENet demo chose move slot 0 always and stalled once SLASH ran out of
  PP (10 of 192 runs failed); it now picks a move with PP, and a failing step
  prints each battle's state. Tools only (`tools/coop_session.gd`). Verify on
  5250e71b: all passed. Needs the owner's word to merge.

## M14 wave 2 (#198, merged 2026-10-16)

Merged in the owner's order into a local branch, one agent per merge, each
code-conflict merge reviewed by another agent, then pushed together once the
final head passed.

| Issue | PR | Merge | State |
|---|---|---|---|
| #195 host battles use the clock | #199 | 5481a98f | closed |
| #188 Gold tool host, tab name | #200 | 381ae876 | closed |
| #149 Gen 2 battle questions | #201 | d98bac35 | closed |
| #181 Cable Club, link battles, Mystery Gift | #207 | 3fcf5c27 | closed |
| #180 roamers, legendaries (D138: ELECTRODEs the team's, owner) | #204 | 8e83010f | closed |
| #177 Pokégear and phone | #202 | 337e4c69 | closed |
| #179 Bug-Catching Contest | #205 | 01468600 | closed |
| #183 seeds, autoplay to BUGSY | #203 | 10fd71c6 | open: WHITNEY to the Elite Four |

- b2aae3cf (after #207's review): `johto_trade`'s check expects the starter's
  uids, since one `gold new mon=` (#149's) replaces the starter in place.
- Seed options after the merges: `gold new` takes `mon=` (one implementation),
  `level=`, `item=`, `clock=`, `phone=`, `event=<p1|p2>:<flag>`; Gold legs take
  Red's `level=`, `party=`, `mon=`, `item=`, `at=`. Known: `level=` rewrites the
  moves that `mon=...:moves=` set, so the order of the two matters (review of
  #204, cosmetic, not fixed).
- Verify on b2aae3cf: GUT 5297/5297, gates, boot, both ENet demos, three
  processes, every wave 2 scenario (`johto_battle`, `johto_baton_pass`,
  `johto_trade`, `johto_mystery_gift`, `johto_colosseum`, `johto_legendaries`,
  `johto_phone`, `johto_rematch`, `johto_bug_contest`, `johto_day_care`,
  `gold_and_silver`), `playthrough_falkner`: ok. `playthrough_bugsy` failed once (GOLD lost a wild battle on Route 32 and the autoplay could not recover from the blackout) and passed alone; both windows reached BUGSY.
- The session build's verify on the same commit: `local_split`, `split_quit`,
  `cable_club_trade`, `versus_from_menus`, `switch_and_suggest`, `german_menus`
  ok; Linux and Windows builds boot.
- Per-merge verifies: #202, #204, #205 all passed. #199, #200, #201 failed
  `johto_battle` (SILVER never joined: scripted windows still heard pads
  before #181's `coop_play.gd` change; passes on the final head) and #199's
  GUT failed only `test_coop_device` (the fixed port 24791 held by a parallel
  run; 41/41 alone). #207 failed only `johto_trade`'s old check (fixed in
  b2aae3cf).

## The owner's split-screen session (Red/Blue, 2026-10-16)

- Played 19:07 to 19:13 on Rote Edition, top and bottom, a new campaign: three
  wild battles, a friend battle, eleven saves; the logs show no error and no
  refusal. The notes page stayed empty.
- Found: #217 both halves played their music (PR #219: the right half plays
  effects only, `Gen2AudioPlayer.music_scale`, D141); #218 ä, ö and ü drew as
  `?` because the Co-op tab's cartridge listing left Gen1Text on the English
  charmap (PR #220: the session sets its game's charmap in `open_start()` and
  `open_world()`). Both verified (GUT 5298/5298 and every headless stage),
  merged on the owner's word and verified again on c97aa81a (GUT 5299/5299);
  neither was run in two windows (the PC was in use), so the owner's next
  session is their screen test (K22, G11).
- Next session's build: `builds/session-red-fixes-fbf78301` (with zips), built
  before the merge from a local branch since deleted; its code is c97aa81a's
  (only `HANDOFF.md` differs). Verify with `--builds` passed (GUT 5299/5299,
  Linux and Windows boot). Fallback:
  `builds/session-red-wave2-b2aae3cf`. The private Superset page points at both.
- The owner's campaigns, settings and save slots are backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-backup-20261016/`.
- Virtual game controllers from other software can be connected to this
  machine and press buttons. Godot sees them: scripted scenario windows and
  the launcher can be moved by them, and `local_split` hands its right half
  the first connected pad (one run got such a pad and failed).

## Next candidates

- The owner's next session on `session-red-fixes-fbf78301`: K22 (one tune in
  split screen) and G11 (umlauts) by hand; a joined battle still plays its
  effects in both halves (D141), a follow-up if it bothers.
- #183's remaining stretches (WHITNEY to Johto's Elite Four, from seeds).
- Filed during the wave, owner-approved: #208 no friend battles or trades
  during the contest; #209 Red and Blue's Colosseum as a link battle; #210
  Mystery Gift decorations per player; #211 Elm's call and TOGEPI egg for
  every player; #212 the tool host's players as GOLD and SILVER; #213 a shared
  flag redraws the partner's map objects; #214 Gold's link-screen text bugs.
- Need the owner first: #182 the Time Capsule's design; #184 RED on Mt.
  Silver joined or per player. #185 Crystal comes last.
- Outside M14: #140's retest (P11, K17), K21 (#161); M10 (#44, #45, #46), M0
  #15, M13 (#55, #56), M12 German (#50).
- Test harness (filed): #215 `test_coop_device`'s fixed port breaks parallel
  runs; #216 scripted scenario windows use whatever controller is connected.
- Possible issues, ask before filing: the session
  menu's FIGHT list on Red and Blue is fixed (BROCK, ONIX L60, PIDGEY L5,
  RATTATA L4), not the map's wild table; a mouse with a joystick interface is
  listed twice as a pad; `partner_tracker_cabins`' `p2_hall` never photographs
  both in the hall from BLUE's side; the autoplay can't recover from a
  blackout (a lost wild battle on Route 32 stalled `playthrough_bugsy` once;
  the owner chose not to file it for now).

## Worktrees and background processes

- Main checkout on `pokerecomp-online-coop`, behind the pushed merges (pull
  when convenient; its `builds/` holds the session builds).
- The Superset worktree `quilted-acoustic` (now on `coop/206-gold-demo-leader`; the local branch `session/red-fallback` at 59016792, the fallback build's commit, is still there) and `~/dev-scratch/pokerecomp-online-coop/worktrees/wave2-merge` (branch `wave2/merge`, pushed): remove both after the session.
- No background processes.

## Working notes (stable, keep short)

- Merge, when the owner says so: `git merge --no-ff <branch> -m "Merge #N: ..."`
  on a local branch at the integration branch's tip (the main checkout, or a
  scratch worktree as for wave 2), push it to `pokerecomp-online-coop`, delete
  the merged branch. Never `gh pr merge`. The owner's push guard refuses a merge
  whose tree equals the branch tip (a branch cut from the integration branch's
  tip): its review sees no commit; a guard fix waits for the owner in
  `~/dev-scratch/pokerecomp-online-coop/push-guard-merge-fix.md`. The guard's
  files are the owner's to change. Its secret scan refuses any diff touching
  the `"buenas_password": CAMPAIGN` line in `coop_ownership.gd`.
- Parallel verify runs: `test_coop_device` listens on the fixed port 24791, so
  two GUT stages at once fail it ("Couldn't create an ENet host"); rerun it
  alone, or give each run a network of its own (a `bwrap` first in PATH that
  adds `--unshare-net`; the lobby and device suites pass there).
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

- After the session: the Superset worktree `quilted-acoustic` once #206's PR
  is merged, and the branch `session/red-fallback`; the worktree `wave2-merge` and branch `wave2/merge`;
  `~/dev-scratch/pokerecomp-online-coop/session/` (the page's source) and
  `session-backup-20261016/`; the three session builds and their zips in
  `builds/`.
- `~/dev-scratch/pokerecomp-online-coop/push-guard-merge-fix.md` once the
  owner applied or declined it.
- `~/dev-scratch/pokerecomp-online-coop/session-links/`, `pr-links.tsv`,
  `issue-links.tsv` and `coop7.txt` once GitHub Support purged the old refs.
- `builds/140-picked-pad-only-490f0aad` once #140 is retested;
  `builds/pokerecomp-online-coop-0c6da178` and its two zips.
- Superset's workspace of the retired repository (`honeysuckle-seahorse`).
- `~/dev-scratch/pokerecomp-coop/`: keep `rewrite.git` and the PvP patch; the
  rest is migration leftovers.
