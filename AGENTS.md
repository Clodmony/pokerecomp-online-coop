# Agent instructions: pokerecomp-coop

This repository is a **private fork** of
[Decryptu/pokerecomp](https://github.com/Decryptu/pokerecomp) that adds a
cooperative two-player Red/Blue campaign. The co-op project is built entirely
with AI: every change after upstream commit `696d1c9` is written by an AI coding
agent directed by the repository owner. Keep that disclosure in `README.md` and
here.

Read before working:

- [docs/coop/brief.md](docs/coop/brief.md): the owner's brief, the source of
  truth for goals and constraints.
- [docs/coop/design.md](docs/coop/design.md): agreed behaviour and ownership rules.
- [docs/coop/architecture.md](docs/coop/architecture.md): what exists and what changes next.
- [docs/coop/progress.md](docs/coop/progress.md): implemented, verified, incomplete, blocked.
- [docs/coop/decisions.md](docs/coop/decisions.md): decisions and trade-offs.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md): upstream's rules, which still apply
  (file budget, comment budget, test rules, style, no cartridge data).

## Hard rules

- The repository stays **private**. Never publish releases, Pages sites,
  packages, store builds or artifacts. The release and export-template
  workflows are guarded to run only in `Decryptu/pokerecomp` and are disabled
  on this repository; keep both.
- Never push to `upstream`. Its push URL is disabled on purpose. Never
  force-push over existing work.
- Never commit or upload ROMs, saves, extracted cartridge content, credentials
  or local caches. Tests use the synthetic cache in
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

# Two processes: a host, then one client per player in other terminals.
godot --headless --path . -s res://tools/coop_session.gd -- host 24680
godot --headless --path . -s res://tools/coop_session.gd -- client 127.0.0.1 24680 p1

# Engine-free gates (version, release notes, comment ceiling); also the pre-push hook.
tools/release.sh --gates

# Boot smoke test.
godot --headless --path . --quit-after 30
```

The fork's CI (`ci.yml`) runs the import, the whole suite, the boot smoke test
and the co-op ENet demo on every pull request, so a pushed draft PR is a
verification run even without a local Godot.

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
| `tools/coop_session.gd` | `demo`, `host` and `client` runners |
| `tests/unit/test_coop_state.gd`, `tests/unit/test_coop_battle.gd`, `tests/integration/test_coop_session.gd` | co-op tests |

## Conventions specific to the fork

- Upstream's comment ceiling (`MAX_COMMENT_LINES` in
  `tests/unit/test_source_budget.gd`) was raised once for the co-op subsystem;
  see `decisions.md`. Keep co-op comments as sparse as upstream's.
- New scripts get a `.gd.uid` file from the first editor import; commit the
  generated files rather than writing `uid://` values by hand.
- Keep upstream files' changes small and listed in `architecture.md` so upstream
  merges stay cheap.
- Update `docs/coop/progress.md` in the same pull request as the work.
