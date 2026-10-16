# Agent instructions: pokerecomp-coop

This repository ([Clodmony/pokerecomp-online-coop](https://github.com/Clodmony/pokerecomp-online-coop))
is a **public fork** of
[Decryptu/pokerecomp](https://github.com/Decryptu/pokerecomp) that adds a
cooperative two-player Red/Blue campaign. The co-op project is built entirely
with AI: every change after upstream commit `696d1c9` is written by an AI coding
agent directed by the repository owner. Keep that disclosure in `README.md` and
here.

Read before working:

- **Start here:** [HANDOFF.md](HANDOFF.md), the session handoff note (state,
  open pull requests, next candidates), and the open issues on GitHub (the only
  task list); work follows the issue loop under *Workflow*.
- [docs/coop/playbook.md](docs/coop/playbook.md): the plan to a fully playable run, the world-sharing rule and the owner's open decisions.
- [docs/coop/brief.md](docs/coop/brief.md): the owner's brief, the source of
  truth for goals and constraints.
- [docs/coop/design.md](docs/coop/design.md): agreed behaviour and ownership rules.
- [docs/coop/architecture.md](docs/coop/architecture.md): what exists and what changes next.
- [docs/coop/progress.md](docs/coop/progress.md): implemented, verified, incomplete, blocked.
- [docs/coop/decisions.md](docs/coop/decisions.md): decisions and trade-offs.
- [docs/coop/playing.md](docs/coop/playing.md): how players host, join, battle and trade.
- [docs/coop/readiness.md](docs/coop/readiness.md): what to check before a private build.
- [docs/coop/test-cases.md](docs/coop/test-cases.md): the hand-test cases and what covers each.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md): upstream's rules, which still apply
  (file budget, comment budget, test rules, style, no cartridge data).

## Hard rules

- **Two kinds of branches.** `main` is an exact copy of upstream's `main`: never
  commit to it; bring it up to date with
  `git fetch upstream && git push origin upstream/main:main`. The co-op line is
  `pokerecomp-online-coop`, the default branch: issue branches come off it and
  draft pull requests go into it. Upstream fixes come in by merging `main` into
  it (see `architecture.md`).
- The fork is public, its releases are not. Never publish releases, Pages
  sites, packages, store builds or artifacts. The release and export-template
  workflows are guarded to run only in `Decryptu/pokerecomp` and stay disabled
  here; keep both.
- Never push to `upstream`. Its push URL is disabled on purpose. Never
  force-push over existing work (the one exception, D129, was the owner's).
- No personal data in commits, docs, issues or pull requests (names, emails,
  hardware, local paths). Commits are authored as `Claude <noreply@anthropic.com>`
  (the clone's local git config).
- Never commit or upload ROMs, saves, extracted cartridge content, credentials
  or local caches. Screenshots of the game show cartridge graphics: keep them
  local, never in commits, issues or pull requests. Tests use the synthetic cache in
  `tests/unit/battle_fixture.gd`. A check that needs a real cartridge asks the
  owner to supply it locally and never downloads one.
- Work on feature branches (`coop/<issue>-<topic>`) and open **draft** pull
  requests against `pokerecomp-online-coop`. Reference the issue the work closes.
- Commits may carry `Co-Authored-By` trailers; the fork's pre-push hook allows
  them. No session links (`Claude-Session:`, claude.ai URLs) in commits or pull
  requests (D129).
- Do not claim something works on a platform or in a mode that was not run.
  `progress.md` separates static inspection, passing tests, builds and played
  sessions.

## Workflow

- **One issue per session.** Pick the issue with the owner, branch
  `coop/<issue>-<topic>` from `pokerecomp-online-coop`, reproduce the problem (a failing GUT test
  or scenario first), fix it, run `tools/verify.sh`, update the docs below, push
  and open a draft pull request that says `Closes #N`. Then rewrite
  `HANDOFF.md` (open pull requests, branch state, next candidates, cleanup)
  and stop: the owner starts a fresh session for the next issue.
- **The handoff lives in the repository.** `HANDOFF.md` is rewritten at the end
  of every session and committed on the issue branch. When a session ends
  without a pull request, or the note must be visible before the owner merges,
  commit it alone (`handoff: <date>`) and push it to `pokerecomp-online-coop`
  directly: it is the one file that may land there without a pull request.
  Per-checkout agent memory is not read from another worktree, so state goes
  into this file, not into memory.
- **Worktrees.** One worktree per issue: a Superset workspace, or
  `git worktree add` under scratch. Superset runs `.superset/setup.sh` when it
  creates a workspace; run it by hand in any other worktree (identity, hooks,
  upstream remote, tool check). Remove a worktree when its pull request is
  merged.
- **GitHub issues are the task list.** New work, bugs found on the way and
  follow-ups become issues; there is no task file in the repository.
- **The owner merges.** A pull request is merged only when the owner says so.
- **Scratch lives on disk, outside the repository**, under
  `~/dev-scratch/pokerecomp-online-coop/`: captures, seeds, logs, verify runs, extra
  git worktrees, pull request bodies. /tmp is a small RAM disk on the owner's
  machine. Delete an issue's scratch when its pull request is open.

## Setup

```bash
git config core.hooksPath .githooks   # ROM guard on commit, release gates on push
git config user.name Claude && git config user.email noreply@anthropic.com
git remote add upstream https://github.com/Decryptu/pokerecomp.git
git remote set-url --push upstream DISABLED   # fetch only; merges follow architecture.md
```

Godot **4.8-dev7** is required (the CI pin in `.github/workflows/ci.yml`);
distribution packages of 4.7 do not open this project. The official build is
`Godot_v4.8-dev7_linux.x86_64.zip` from
<https://github.com/godotengine/godot-builds/releases/tag/4.8-dev7>. Upstream moved
to it in 0.1.73; the fork followed with the 0.1.75 merge (D97).

## Verification commands

Run from the repository root with `godot` being the 4.8-dev7 binary. The usual
check of a branch is one command, unattended, with a summary at the end:

```bash
# Import, GUT, release gates, boot, ENet demo, three processes (both on free UDP
# ports, so a game hosted on 24680 can keep running), then the named two-window
# scenarios; logs in ~/dev-scratch/pokerecomp-online-coop/verify/<stamp>/.
# --builds[=<dir>] also exports, boots and zips private Windows and Linux builds of HEAD.
# <scenario>=<seed dir> runs that scenario on a seed; the others start fresh.
GODOT=godot tools/verify.sh [--coop] [--builds[=<dir>]] [scenario[=<seed dir>] ...]
```

The single steps, for debugging one of them:

```bash
# Import and class scan; required after adding a script with class_name.
godot --headless --editor --path . --quit

# Whole suite (what CI runs).
godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit

# Only the co-op suites.
godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gselect=test_coop -gexit

# Co-op slice over real localhost ENet sockets (exits non-zero on failure).
godot --headless --path . -s res://tools/coop_session.gd -- demo

# The same slice as three processes (host, p1, p2); exits non-zero if any fails or hangs.
GODOT=godot tools/coop_two_process.sh 24690

# Two windows on the imported cartridge, driven by a scenario, captures outside the
# repository and a private user folder (the owner's campaigns are never touched).
GODOT=godot tools/coop_screens.sh leave_rejoin_takeover ~/dev-scratch/pokerecomp-online-coop/coop_screens/leave
# Two windows that play themselves from Oak's speech to BROCK's (or MISTY's) badge,
# about five (ten) minutes; exits non-zero if either window fails.
GODOT=godot tools/coop_screens.sh playthrough_brock ~/dev-scratch/pokerecomp-online-coop/coop_screens/brock
# A campaign at a later point of the story (`list` names the legs), then a stretch
# played from it: SEED= starts the run there, the autopilot's from=<leg> skips ahead
# (partner=none when the other window is not autoplayed: it meets nobody, as brock_from_seed does).
godot --headless --path . -s res://tools/coop_seed.gd -- red pokemon_tower ~/dev-scratch/pokerecomp-online-coop/seeds/tower
SEED=~/dev-scratch/pokerecomp-online-coop/seeds/tower GODOT=godot tools/coop_screens.sh story_seed ~/dev-scratch/pokerecomp-online-coop/coop_screens/seed
# An autoplayed run's host snapshots the campaign and each window's leg every 10 s; rerun a
# stalled or killed run from its last snapshot (or <n>, or -<seconds> before its end).
GODOT=godot tools/coop_resume.sh ~/dev-scratch/pokerecomp-online-coop/coop_screens/elite [<n> | -600] [out dir]

# Session logs (user://coop_logs): one timeline, a summary, or a host log replayed
# (replay needs the cartridge imported); demo and check write logs only with `logs`.
godot --headless --path . -s res://tools/coop_log.gd -- merge user://coop_logs out=$HOME/dev-scratch/pokerecomp-online-coop/merged.jsonl
godot --headless --path . -s res://tools/coop_log.gd -- summary user://coop_logs
godot --headless --path . -s res://tools/coop_log.gd -- replay <host log>.jsonl

# Two processes: a host, then one client per player in other terminals.
godot --headless --path . -s res://tools/coop_session.gd -- host 24680
godot --headless --path . -s res://tools/coop_session.gd -- client 127.0.0.1 24680 p1

# The real game from the launcher: the Co-op tab hosts or joins (Red or Blue imported).
godot --path .

# The real game with a locally imported Red dump (never committed):
godot --headless --path . -s res://tools/import_rom.gd -- "/path/to/Pokemon Red.gb"
godot --headless --path . -s res://tools/coop_session.gd -- host 24680 red
godot --path . -s res://tools/coop_play.gd -- 127.0.0.1 24680 p1 red   # window 1
godot --path . -s res://tools/coop_play.gd -- 127.0.0.1 24680 p2 red   # window 2
# In a window, SELECT opens the session menu (fight, join, save). Scripted runs:
#   keys=SELECT,A,D,A   capture=$HOME/dev-scratch/pokerecomp-online-coop/shot.png@600

# Engine-free gates (version, release notes, comment ceiling); also the pre-push hook.
tools/release.sh --gates

# Boot smoke test.
godot --headless --path . --quit-after 30
```

The fork's CI (`ci.yml`) runs the import, the whole suite, the boot smoke test
and the co-op ENet demo on every pull request. Run the same steps locally
before pushing.

## Where co-op code lives

| Path | Owns |
|---|---|
| `game/coop/coop_campaign.gd` | `PokeCoopCampaign`: shared flags, badges, unique encounters, exactly-once commits |
| `game/coop/coop_player.gd` | `PokeCoopPlayer`: one player's team (uids), box, bag, money, position |
| `game/coop/coop_roster.gd` | `PokeCoopRoster`: owner and uid of every allied battle index |
| `game/coop/coop_battle_session.gd` | `PokeCoopBattleSession`: one battle, turn authority, suggestions, joins, results |
| `game/coop/coop_versus.gd` | `PokeCoopVersus`: friend battle, both human sides, mirrored views and post-fight healing/experience |
| `game/coop/coop_policy.gd` | `PokeCoopPolicy`: provisional rules kept out of the simulation |
| `game/coop/coop_johto.gd` | `PokeCoopJohto`: Gold and Silver's own rules (D130), asked by `PokeCoopPolicy`: the opening's end, its story and a late joiner's (D131), each player's gifts, Johto's gift items, the wild tables by time of day; the campaign's one clock (D133); each player's own flags and map scenes, the team's engine flags, contested scenes and League run (D132); their prize money (D134) |
| `game/coop/coop_host.gd` | `PokeCoopHost`: authoritative validation, protocol, save checkpoints, lifecycle |
| `game/coop/coop_client.gd` | `PokeCoopClient`: intentions out, authoritative state in |
| `game/coop/coop_transport.gd` | `PokeCoopTransport`: message transport base and in-memory loopback |
| `game/coop/coop_enet_transport.gd` | `PokeCoopEnetTransport`: LAN/direct-IP over ENet |
| `game/coop/coop_save.gd` | `PokeCoopSave`: versioned campaign file |
| `game/coop/coop_remote_actor.gd` | `PokeCoopRemoteActor`: other players as world actors; reports this player's position |
| `game/coop/coop_battle_panel.gd` | `PokeCoopBattlePanel`: a battle's rows, presses, refusals and closing |
| `game/coop/coop_menu.gd` | `PokeCoopMenu`: START > CO-OP, the session menu on the world's own screen |
| `game/coop/coop_touch_gestures.gd` | `PokeCoopTouchGestures`: swipes and taps over the screen while a co-op menu or battle is up |
| `game/coop/coop_battle_menu.gd` | `PokeCoopBattleMenu`: a battle's rows as the cartridge's FIGHT/PKMN/ITEM/RUN, move, party and bag lists (Gold and Silver's pack pockets) and YES/NO boxes, with partners' marks |
| `game/coop/coop_ownership.gd` | `PokeCoopOwnership`: owner of every world, save and runtime field; patches and routing |
| `game/coop/coop_world_link.gd` | `PokeCoopWorldLink`: a window's world state, party and PC kept in step with the host |
| `game/coop/coop_battle_field.gd` | `PokeCoopBattleField`: a co-op battle drawn on the world's own 160x144 screen, the touch pad free beside it |
| `game/coop/coop_battle_stage.gd` | `PokeCoopBattleStage`: the field's tilemap, faints, recalls, send-outs and per-side panels |
| `game/coop/coop_trades.gd` | `PokeCoopTrades`: Cable Club trades between players, swapped on the host |
| `game/coop/coop_link_transport.gd` | `PokeCoopLinkTransport`: the Cable Club's cable to the partner the host names |
| `game/coop/coop_battle_takeover.gd` | `PokeCoopBattleTakeover`: a window's own battles fought on the host |
| `game/coop/coop_session.gd` | `PokeCoopSession`: one device's co-op run, held by `Gen2GameRuntime.coop` |
| `game/coop/coop_page.gd` | `PokeCoopPage`: the launcher's Co-op tab, its screens and sheets |
| `game/coop/coop_tab_parts.gd` | `PokeCoopTabParts`: the tab's cards, chips, steps, its sheet and a controller's keys |
| `game/coop/coop_lobby.gd` | `PokeCoopLobby`: LAN beacon and listener, the dial that retries and probes, addresses, cartridges, the tab's memory, the split screen's second window (`SplitScreen`) |
| `game/coop/coop_log.gd` | `PokeCoopLog`: a device's session log, its debug-stream batches and the setting that shares them |
| `tools/coop_log.gd` | `merge`, `summary` and `replay` of session logs |
| `tools/coop_session.gd` | `demo [gold]`, `check host\|p1\|p2`, `host [port] [game] [snapshots=<dir>]` and `client` runners |
| `tools/coop_two_process.sh` | the three-process ENet check CI runs |
| `tools/verify.sh` | one unattended check of a branch: CI's stages, then two-window scenarios and the private builds, with a short summary |
| `tools/coop_play.gd` | one player's window on the real world screen |
| `tools/coop_screens.sh`, `tools/coop_screens/*.sh`, `tools/coop_resume.sh` | the two-window runner, its scenarios, and a rerun from a run's snapshot |
| `tools/coop_relay.gd` | a UDP relay between one scenario window and the host that cuts the link on cue (`RELAY=p2`, `cut`) |
| `tools/coop_autoplay.gd` | a window that plays itself with `tools/checks/played.gd`'s legs (#48); on Gold or Silver, its opening (#173) |
| `tools/coop_launcher_play.gd` | one player's window on the launcher's Co-op tab, then the world (D69); `tour=` photographs every screen, `clock=HH:MM[:D]` starts a new Gold campaign's clock there, `name=` with nothing keeps the name the tab offers |
| `tools/coop_seed.gd` | a two-player campaign at any leg of upstream's Gen 1 story walk, for `SEED=` (D78); `level=<n>` grows the party, `party=<n>` fills it to n with copies of the lead, `mon=` and `item=` shape it, `at=<group>:<number>:<x>,<y>` puts both players there (beside a trainer); `gold new` seats two Johto players, `at2=` puts the second elsewhere, `care=` fills one's day care, `event=[-]<flag>` sets or clears a campaign flag |
| `tests/unit/test_coop_state.gd`, `tests/unit/test_coop_battle.gd`, `tests/unit/test_coop_ownership.gd`, `tests/unit/test_coop_log.gd`, `tests/unit/test_coop_lobby.gd`, `tests/integration/test_coop_session.gd`, `tests/integration/test_coop_device.gd`, `tests/integration/test_coop_three_players.gd`, `tests/integration/test_coop_save_refusal.gd`, `tests/integration/test_coop_logs_session.gd`, `tests/integration/test_coop_gold_silver.gd`, `tests/integration/test_coop_johto_day_care.gd`, `tests/integration/test_coop_johto_world.gd`, `tests/integration/test_coop_johto_battles.gd` | co-op tests |

## Conventions specific to the fork

- Upstream's comment ceiling (`MAX_COMMENT_LINES` in
  `tests/unit/test_source_budget.gd`) was raised once for the co-op subsystem;
  see `decisions.md`. Keep co-op comments as sparse as upstream's.
- New scripts get a `.gd.uid` file from the first editor import; commit the
  generated files rather than writing `uid://` values by hand.
- Keep upstream files' changes small and listed in `architecture.md` so upstream
  merges stay cheap.
- Update `docs/coop/progress.md` in the same pull request as the work.
- Every feature adds its hand-test cases to `docs/coop/test-cases.md`, and a
  scenario under `tools/coop_screens/` when it shows on screen. Run the
  scenario, look at every capture, and record the run in `progress.md`.
