# Handoff

The session note for this repository. Read it first in a fresh session and
rewrite it at the end of every session. It lives in the repository so it
survives any worktree path and any tool; per-checkout agent memory is not read
by a session that starts in another worktree. State goes here; stable recipes
go into `docs/coop/`; personal data and hardware never.

Last updated 2026-10-16 (M14 wave 2 opened: eight draft PRs, #198).

## Repository state

- Default branch `pokerecomp-online-coop` at the merge of #197 (a0d0a54b)
  plus handoff commits. `main` = upstream main (ed886823, 0.1.78).
- Co-op protocol 9 on the integration branch; #177, #179 and #181 each bump it
  to 10 (one bump for the wave, the same line in each).
- Decisions: wave 2 uses D136 (#149), D137 (#181), D138 (#180), D139 (#177),
  D140 (#179); D141 to D143 were reserved and not used, so the next free
  number after the wave is D141.
- Hand-test cases: J56 to J91 were reserved in blocks per issue (#198); close
  the gaps with one renumbering commit after the last merge.
- Gold and Silver (USA/Europe) are imported in this machine's own user folder,
  so Gold and Silver scenarios run here.
- History rewritten once (D129): the old co-op history is backed up in
  `~/dev-scratch/pokerecomp-online-coop/session-links/backup-20261015.git`.

## M14 wave 2 (#198): eight draft pull requests, none merged

The owner asked to group the unblocked issues again and build them at once,
one agent, worktree, branch and draft PR each, as wave 1 (#189). Each PR was
verified on its own (`tools/verify.sh` with its scenarios). Table order =
suggested merge order.

| Issue | PR | Head | Closes | Verify | Owner question |
|---|---|---|---|---|---|
| #195 host battles use the clock | #199 | 61fda8fb | yes | all passed | none |
| #188 Gold tool host, tab name | #200 | bfd269ea | yes | all passed | scripted players GOLD/SILVER? |
| #149 Gen 2 battle questions | #201 | 720cc78e | yes | all passed | none |
| #181 Cable Club, link battles, Mystery Gift | #207 | d6591474 | yes | all passed | Red/Blue Colosseum; decorations |
| #180 roamers, legendaries | #204 | a6b6d0f3 | no (Part) | all passed | Rocket base ELECTRODEs |
| #177 Pokégear and phone | #202 | a37ea183 | yes | all passed | Elm's aide call; Crystal |
| #179 Bug-Catching Contest | #205 | 352f6f8d | yes | Gold demo flake (#206) | challenges in the park |
| #183 seeds, autoplay to BUGSY | #203 | 2f1c7a0f | no (Part) | all passed | none |

- #181: earlier runs failed in the scenarios' second window: this machine's
  pads and the keyboard focus reached scripted windows. `tools/coop_play.gd`
  now gives a scripted window (`keys=` or `capture=`) no keyboard focus and no
  pads; every scenario's windows change with it. Then all passed (at 4b7ea72b,
  docs only after it).
- #179's only failure was `enet-demo-gold` at "red beats the leader" (passed
  3 of 3 alone): the second time, so #206 is filed.
- #180's scenario changed after its verify (timing only), passed 3 runs alone.
- #183 stays open: WHITNEY to Johto's Elite Four not written.

### Merge plan (each merge verified before its push, as wave 1)

- Code conflicts: `tools/coop_seed.gd` (#149, #177, #179, #180, #181);
  `coop_johto.gd` (#177 with #180 and #181); `coop_player.gd` (#179 with
  #181). #183 merges cleanly with every branch. Docs conflict everywhere
  (`progress.md`, `test-cases.md`, `decisions.md`, `AGENTS.md`,
  `architecture.md`).
- `coop_seed.gd -- gold new` options added twice: `mon=` (#149, #179, #181),
  `level=` (#177, #180); keep one implementation each. Others: `item=`
  (#180), `clock=` (#179), `phone=` and `event=<p1|p2>:<flag>` (#177).
- #195 folds the host's battle registrations into `_open_battle(session)`;
  #181's `_colosseum` must call it after both are in.
- `PokeCoopHost._dispatch` is at the complexity ceiling (20) in #181: a new
  arm from another branch breaks the budget test.
- #177 renames `PokeCoopJohto.prize_shares` to `pay`.
- The push guard's secret scan refuses any diff that touches the
  `"buenas_password": CAMPAIGN` line in `coop_ownership.gd`; keep it out of
  every merge resolution.
- `test_coop_device` listens on the fixed port 24791: two GUT runs at once
  fail it with "Couldn't create an ENet host"; rerun alone.

### Seen during the wave, not filed

- #183: SILVER in the Slowpoke Well when GOLD beat the Rockets kept seeing
  them until it left the map (the flag arrived, the map's objects weren't
  redrawn).
- #181: Gold's versus box prints `<BOLD_V><BOLD_S>` instead of VS (upstream
  `Gen2LinkPage.VERSUS_VS`, also solo); a Mystery Gift decoration's box can
  name the wrong item ("PUT IT AWAY").
- #179: the contest's results warp happens only when the script ends (judging
  shows in the Route 35 gate, also solo); `VAR_CONTESTMINUTES` is missing
  upstream too; `verify.sh`'s summary lists a neighbouring passing test as a
  second FAILED line.

## Next candidates

- Merge wave 2 in the table's order, then close the J gaps and #198.
- #206 the Gold demo's leader step (log the outcome, then fix the rolls).
- #183's remaining stretches (WHITNEY to Johto's Elite Four, from seeds).
- Need the owner first: #182 the Time Capsule's design; #184 RED on Mt.
  Silver joined or per player. #185 Crystal comes last.
- Outside M14: the owner's hand-played Red/Blue session (`readiness.md`), #140's
  retest with `builds/140-picked-pad-only-490f0aad` (P11, K17), K21 (#161);
  M10 (#44, #45, #46), M0 #15, M13 (#55, #56), M12 German (#50).
- Possible issues, ask before filing: the session menu's FIGHT list on Red and
  Blue is fixed (BROCK, ONIX L60, PIDGEY L5, RATTATA L4), not the map's wild
  table; a mouse with a joystick interface is listed twice as a pad;
  `partner_tracker_cabins`' `p2_hall` never photographs both in the hall from
  BLUE's side.

## Worktrees and background processes

- Main checkout on `pokerecomp-online-coop` (behind by this handoff commit).
- Wave 2 worktrees, one per PR, under
  `~/dev-scratch/pokerecomp-online-coop/worktrees/<issue>-<topic>`: remove
  each when its PR is merged (`git worktree remove`).
- The Superset worktree `quilted-acoustic` (detached) coordinated the wave.
- Wave scratch: `~/dev-scratch/pokerecomp-online-coop/wave2/` (the
  `verify-slot.sh` wrapper that kept two verify runs at a time, each issue's
  verify runs and PR body); delete it after the merges. Left from before:
  `gut1.sh` and the D129 leftovers (`session-links/`, `pr-links.tsv`,
  `issue-links.tsv`, `coop7.txt`), which wait for GitHub Support.

## Working notes (stable, keep short)

- Merge, when the owner says so: in the main checkout on
  `pokerecomp-online-coop`, `git merge --no-ff <branch> -m "Merge #N: ..."`,
  push, delete the merged branch. Never `gh pr merge`. The owner's push guard
  refuses a merge whose tree equals the branch tip (a branch cut from the
  integration branch's tip): its review sees no commit. The owner pushed #197's
  merge with `--no-verify`; a guard fix waits for the owner in
  `~/dev-scratch/pokerecomp-online-coop/push-guard-merge-fix.md`. The guard's
  files are the owner's to change.
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

- The Superset worktree `quilted-acoustic` once wave 2 is merged.
- The wave 2 worktrees and `wave2/` scratch, as their PRs merge.
- `~/dev-scratch/pokerecomp-online-coop/push-guard-merge-fix.md` once the
  owner applied or declined it.
- `~/dev-scratch/pokerecomp-online-coop/session-links/`, `pr-links.tsv`,
  `issue-links.tsv` and `coop7.txt` once GitHub Support purged the old refs.
- `builds/140-picked-pad-only-490f0aad` once #140 is retested;
  `builds/pokerecomp-online-coop-0c6da178` and its two zips.
- Superset's workspace of the retired repository (`honeysuckle-seahorse`).
- `~/dev-scratch/pokerecomp-coop/`: keep `rewrite.git` and the PvP patch; the
  rest is migration leftovers.
