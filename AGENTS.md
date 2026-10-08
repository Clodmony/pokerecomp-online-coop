# Agent instructions: pokerecomp-coop

This repository is a **private fork** of
[Decryptu/pokerecomp](https://github.com/Decryptu/pokerecomp) that adds a
cooperative two-player Red/Blue campaign. The co-op project is built entirely
with AI: every change after upstream commit `696d1c9` is written by an AI coding
agent directed by the repository owner. Keep that disclosure in `README.md` and
here.

Read before working:

- [docs/coop/tasks.md](docs/coop/tasks.md): **start here**, the next tasks in order and the current state.
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

- **GitHub, private repository only.** GitHub use resumed on 2026-10-07 after a
  pause: push feature branches to `origin`, open draft pull requests, and keep
  the issues current. Verify locally with Godot 4.8-dev4 before pushing; CI
  runs the same steps on pull requests.
- The repository stays **private**. Never publish releases, Pages sites,
  packages, store builds or artifacts. The release and export-template
  workflows are guarded to run only in `Decryptu/pokerecomp` and are disabled
  on this repository; keep both.
- Never push to `upstream`. Its push URL is disabled on purpose. Never
  force-push over existing work.
- Never commit or upload ROMs, saves, extracted cartridge content, credentials
  or local caches. Screenshots of the game show cartridge graphics: keep them
  local, never in commits, issues or pull requests. Tests use the synthetic cache in
  `tests/unit/battle_fixture.gd`. A check that needs a real cartridge asks the
  owner to supply it locally and never downloads one.
- Work on feature branches (`coop/<topic>`) and open **draft** pull requests
  against `main`. Reference the issue the work closes.
- Commits may carry AI attribution trailers; the fork's pre-push hook allows them.
- Do not claim something works on a platform or in a mode that was not run.
  `progress.md` separates static inspection, passing tests, builds and played
  sessions.

## Setup

```bash
git config core.hooksPath .githooks   # ROM guard on commit, release gates on push
```

Godot **4.8-dev4** is required (the CI pin in `.github/workflows/ci.yml`);
distribution packages of 4.7 do not open this project. The official build is
`Godot_v4.8-dev4_linux.x86_64.zip` from
<https://github.com/godotengine/godot-builds/releases/tag/4.8-dev4>.

## Verification commands

Run from the repository root with `godot` being the 4.8-dev4 binary:

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
GODOT=godot tools/coop_screens.sh leave_rejoin_takeover /tmp/coop_screens/leave
# Two windows that play themselves from Oak's speech to BROCK's (or MISTY's) badge,
# about five (ten) minutes; exits non-zero if either window fails.
GODOT=godot tools/coop_screens.sh playthrough_brock /tmp/coop_screens/brock
# A campaign at a later point of the story (`list` names the legs), then a stretch
# played from it: SEED= starts the run there, the autopilot's from=<leg> skips ahead.
godot --headless --path . -s res://tools/coop_seed.gd -- red pokemon_tower /tmp/seeds/tower
SEED=/tmp/seeds/tower GODOT=godot tools/coop_screens.sh story_seed /tmp/coop_screens/seed

# Session logs (user://coop_logs): one timeline, a summary, or a host log replayed
# (replay needs the cartridge imported); demo and check write logs only with `logs`.
godot --headless --path . -s res://tools/coop_log.gd -- merge user://coop_logs out=/tmp/merged.jsonl
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
#   keys=SELECT,A,D,A   capture=/tmp/shot.png@600

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
| `game/coop/coop_policy.gd` | `PokeCoopPolicy`: provisional rules kept out of the simulation |
| `game/coop/coop_host.gd` | `PokeCoopHost`: authoritative validation, protocol, save checkpoints, lifecycle |
| `game/coop/coop_client.gd` | `PokeCoopClient`: intentions out, authoritative state in |
| `game/coop/coop_transport.gd` | `PokeCoopTransport`: message transport base and in-memory loopback |
| `game/coop/coop_enet_transport.gd` | `PokeCoopEnetTransport`: LAN/direct-IP over ENet |
| `game/coop/coop_save.gd` | `PokeCoopSave`: versioned campaign file |
| `game/coop/coop_remote_actor.gd` | `PokeCoopRemoteActor`: other players as world actors; reports this player's position |
| `game/coop/coop_battle_panel.gd` | `PokeCoopBattlePanel`: session menu and co-op battle overlay over the world screen |
| `game/coop/coop_ownership.gd` | `PokeCoopOwnership`: owner of every world, save and runtime field; patches and routing |
| `game/coop/coop_world_link.gd` | `PokeCoopWorldLink`: a window's world state, party and PC kept in step with the host |
| `game/coop/coop_battle_field.gd` | `PokeCoopBattleField`: a co-op battle drawn on the cartridge's battle field |
| `game/coop/coop_battle_stage.gd` | `PokeCoopBattleStage`: the field's tilemap, faints, recalls, send-outs and per-side panels |
| `game/coop/coop_trades.gd` | `PokeCoopTrades`: Cable Club trades between players, swapped on the host |
| `game/coop/coop_link_transport.gd` | `PokeCoopLinkTransport`: the Cable Club's cable to the partner the host names |
| `game/coop/coop_battle_takeover.gd` | `PokeCoopBattleTakeover`: a window's own battles fought on the host |
| `game/coop/coop_session.gd` | `PokeCoopSession`: one device's co-op run, held by `Gen2GameRuntime.coop` |
| `game/coop/coop_page.gd` | `PokeCoopPage`: the launcher's Co-op tab |
| `game/coop/coop_log.gd` | `PokeCoopLog`: a device's session log, its debug-stream batches and the setting that shares them |
| `tools/coop_log.gd` | `merge`, `summary` and `replay` of session logs |
| `tools/coop_session.gd` | `demo`, `check host\|p1\|p2`, `host [port] [game]` and `client` runners |
| `tools/coop_two_process.sh` | the three-process ENet check CI runs |
| `tools/coop_play.gd` | one player's window on the real world screen |
| `tools/coop_screens.sh`, `tools/coop_screens/*.sh` | the two-window runner and its scenarios |
| `tools/coop_autoplay.gd` | a window that plays itself with `tools/checks/played.gd`'s legs (#48) |
| `tools/coop_launcher_play.gd` | one player's window on the launcher's Co-op tab, then the world (D69) |
| `tools/coop_seed.gd` | a two-player campaign at any leg of upstream's Gen 1 story walk, for `SEED=` (D78); `level=<n>` grows the party, `party=<n>` fills it to n with copies of the lead |
| `tests/unit/test_coop_state.gd`, `tests/unit/test_coop_battle.gd`, `tests/unit/test_coop_ownership.gd`, `tests/unit/test_coop_log.gd`, `tests/integration/test_coop_session.gd`, `tests/integration/test_coop_device.gd`, `tests/integration/test_coop_three_players.gd`, `tests/integration/test_coop_save_refusal.gd`, `tests/integration/test_coop_logs_session.gd` | co-op tests |
| `docs/coop/tracking.md` | issue status and the issue numbers of items first tracked locally (`L1` and on) |

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
