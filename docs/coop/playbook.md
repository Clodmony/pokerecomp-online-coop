# Playbook: to a fully playable co-op run

The plan agreed with the owner on 2026-10-07 for getting from "a third of the
game works in two windows" to "two players can play Red or Blue from Oak's
speech to the Hall of Fame". What to do next, in order, is in
[tasks.md](tasks.md); this file says why and how.

## Where we stand

Upstream already plays single-player Red from the bedroom to the Hall of Fame
(`tools/preview_world_story.gd`), so the gaps are in the co-op layer. Checked by
two self-playing windows on the owner's local Red import (`tools/coop_autoplay.gd`,
D65):

| Stretch | Status |
|---|---|
| Opening, OAK'S PARCEL, Viridian Forest, BROCK | works: several clean runs, a joined BROCK fight |
| Mt. Moon, the fossil, MISTY | works; the DOME FOSSIL reaches both (D67) |
| Cable Club trade with a trade evolution | works (`cable_club_trade`) |
| Nugget Bridge, Bill, S.S. Anne, CUT, LT. SURGE | works: `playthrough_surge` from a new campaign, about 21 minutes (#87, #86 fixed) |
| Celadon to the Hall of Fame | not tried in co-op (#88) |

The automated runs heal between fights and grind with the save editor, so they
prove the co-op flow, not balance or feel; a hand-played session (#44) is the
real test. Windows has only run under Wine and there is no Android build.

## The world-sharing rule (#84)

**Share what the cartridge would save, never what it is doing right now.**

- Two channels: **battles** run on the host as their own sessions; joining,
  turns, suggestions, catches and prizes are live in both windows and are not
  touched by this rule. The **story** (flags, items, map-script steps written
  into the world) is what the rule delays: it goes out when a scene ends, not
  step by step.
- A rest point is a moment the cartridge could save: no script holds the player
  and no map load is pending. A scene is the stretch between two rest points.
- A partner can still walk into the same trainer or SELECT > JOIN and fight from
  the first turn; what reaches them a few seconds later, after the trainer's
  last line, is the "beaten" flag and the gift. The host marks a unique trainer
  beaten the moment the battle is won, so nobody fights it twice meanwhile.
  Runs with D67 in place had joined Brock, Jr. Trainer and Bug Catcher battles.
- Why: most bugs found past BROCK came from map-script state crossing windows
  mid-scene (the fossil, the Vermilion dock loop, the Cerulean thief replayed,
  TM34 handed out twice, LT. SURGE's lines replayed). Fixing the cause once
  saves chasing it in every later town.
- Compared with sm64coopdx in `reviews/2026-10-07-world-sharing-review.md`
  (the outside review) and `reviews/2026-10-07-world-sharing-answer.md` (the
  verdict on its claims and questions).
- Not the alternative: a host-side world would mean rewriting upstream's
  9,350-line world API around many players.

## Phases

### 1. Unblock and merge

- **#86** Upstream: the Cerulean thief's TM28 box stays on screen. Fix it with a
  GUT test; it blocks the autopilot past Cerulean.
- **#87** Review and merge `coop/autoplay-surge` into `coop/playthrough`: the
  route to LT. SURGE and three co-op fixes (a window opens its world as a
  Continue does; Cerulean's and Vermilion's city scripts per player; Vermilion
  Gym's door in the partner's window). Rerun the suites and scenarios, write
  D72 onward, update PR #83.

### 2. Share at rest points

- **#84** step by step: hold until a rest point instead of 15 s; map-script
  steps share their resting value only, per-walk bytes per player, the gym
  bytes classified BROCK to GIOVANNI; a step for the map a window stands on
  applies at its next map load; `world_pull` log lines carry the busy state;
  `design.md` says what is not shared.
- **#85** Vermilion Gym's locks stay put while someone is in the city or gym.
- **#24** (approved): the first player in drives a contested rival scene, the
  partner waits and sees the result, SELECT > JOIN stays open.

### 3. Play on to the Hall of Fame (#88)

One `ROUTES` stretch at a time with its scenario: Celadon and ERIKA, Pokémon
Tower, SNORLAX, Silph Co. and SABRINA, Fuchsia with the Safari Zone and KOGA,
Cinnabar and BLAINE, GIOVANNI, Victory Road, the Elite Four and the Hall of
Fame. Each stretch has taken an agent a few hours and found one to three co-op
bugs. Watch: Safari Zone catches (its battles stay in the window), STRENGTH
boulders (positions per window, switches shared), the Elite Four's back-to-back
battles, and a freeze seen once on S.S. Anne 2F. Done when both windows reach
the Hall of Fame from a new campaign in one run with 0 script errors.

### 4. The owner's session and the platforms

- **#44** a hand-played session on the owner's Windows PC and second Linux
  machine with builds from one commit; `test-cases.md` is the checklist.
- **#45** Android, once the owner settles the SDK licence (#20, #43 follow).
- **#50** German Red/Blue, once the owner supplies a dump.
- **#14** the upstream merge to 0.1.74 after #58, #79, #80, #81 and #83 merge.

Rough estimate, a guess: two to four working sessions with two or three agents
in parallel to reach the Hall of Fame in two windows, before the hand-played
session.

## The owner's decisions (2026-10-07, D72)

1. The rest-point rule (#84) is adopted.
2. The brief's world-simulation item reads: "the host is authoritative for the
   campaign and for battles; each window simulates the maps, NPCs and movement
   it shows, and shares the campaign at rest points". #22 closes, #25 is
   won't-do.
3. #24: the first player in drives a contested scene, for every rival scene
   after the opening.
4. The costs are accepted: a partner sees a scene's result, not the scene; a
   scene cut off by a disconnect replays from its start; a long scene reaches
   the partner when it ends; windows stay trusted.
5. Android (#45) waits until after the Hall of Fame run and #44.
6. German (#50) waits for the owner's own dump.

## How the work is done

- Owner's rules (2026-10-07): keep building and stop only for a hard blocker or
  a design question that cannot wait; every feature adds its cases to
  `test-cases.md` and gets a two-window check the agent looks at; parallel agents
  where work splits.
- Agents work in git worktrees on their own `coop/<topic>` branch, run Godot
  with a private `XDG_DATA_HOME`, never touch the owner's user folder, commit
  without pushing, and leave `docs/` to the lead, who merges, writes the
  D-entries in order and runs the scenarios again on the merged branch.
- The comment-line ceiling (41342) is at its limit: every change is net zero.
- Two-window checks: `GODOT=<4.8-dev4> tools/coop_screens.sh <scenario> <out
  outside the repo>`; windows run at 60 frames a second; captures stay local.
