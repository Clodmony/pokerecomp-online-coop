# Co-op architecture

Current state of the co-op layer and the changes still planned. Behaviour is
specified in [design.md](design.md); status is in [progress.md](progress.md).

## Upstream baseline, re-checked

Baseline: `Decryptu/pokerecomp` at
`696d1c9a1d345ae08fd7febac8aa320aed6608b5` (0.1.72, Godot 4.8-dev4). The
review leads in the brief were checked against that checkout:

| Lead | Finding at `696d1c9` |
|---|---|
| Scene-independent battle model | Confirmed. `Gen2Battle` (`game/battle/battle.gd`) is a `RefCounted` taking an injected `RandomNumberGenerator`; `take_actions`, `replace_fallen`, `learn_move` and `use_bag_item` return event arrays. Questions (replacement, move learn, Mimic, Baton Pass, use-next) are explicit states. The enemy side answers its own Mimic and Baton Pass. |
| World logic separate from its screen | Confirmed, but `Gen2WorldApi` owns one `current_map`, one `player_cell` and one `player_facing` per instance. |
| Mutable world state mixes shared and personal state | Confirmed. `Gen2WorldState` keeps event and engine flags (badges are engine flags) next to the bag, PC items, money, coins, step counters, day care, phone contacts, Pokédex seen/caught and Gen 1 map-script bytes. |
| One selected mutable save | Confirmed. `Gen2GameRuntime` keeps one `_save` for every screen. |
| One active battle per world screen | Confirmed. `Gen2WorldScreen` holds one `_battle_host` and one `_active_battle_save`. |
| Party capped at six | Confirmed in `Gen2Party.create`. The engine itself indexes the player party by position (participants, Exp. Share, evolvable indices, move-learn queue) and has no other six-member limit on the player side. |
| Single-player save and reward handling | Confirmed. `Gen2SaveBattleAdapter.from_world_battle` writes back to one save; `world_battle.gd` pays `battle_reward` and `pay_day_money` into one wallet; `Gen2Battle._is_traded` compared every Pokémon with one battle-wide `player_id`. |
| `Gen2` names on Gen 1 code | Confirmed: `Gen2Battle` runs Gen 1 rules through `is_gen1()`. |

Further findings that shape the design:

- `Gen2Battle.create_parties` installs its `Gen2Rules` globally
  (`Gen2Rules.install`). Concurrent sessions are safe only because a campaign
  plays under one rule set; per-session rules would need that global removed.
- Mods are global (`Gen2ModHost` singleton, experience scale and bystander
  share hooks) and per-save mod data lives in `Gen2SaveData.mods`. Co-op
  campaigns need a decision on per-campaign versus per-player mod data.
- Story progress is written by map scripts running in the world layer
  (`Gen1MapScripts`, `Gen2WorldScript`) directly into `Gen2WorldState`; routing
  those writes through campaign commits is #32.
- World generators are seeded per run (`run_seed`); battles take an injected
  generator, so each co-op session owns one.
- Tracked content provenance: see #55. Two App Store screenshots in
  `.github/altstore/` show rendered cartridge graphics.

## Ownership boundaries

```
 clients (input, menus, presentation, advisory cursor)
     | intentions: move, start_battle, command, suggest, join, save
     v
 PokeCoopHost ------------------------------- PokeCoopSave (versioned file)
   | validates, sequences, broadcasts             ^
   |-- PokeCoopCampaign   shared flags, badges, unique encounters, commits
   |-- PokeCoopPlayer x N team (uids), box, bag, money, position, return point
   |-- PokeCoopBattleSession x M
   |      id, rng, revision, participants, suggestions, pending joins
   |      |-- PokeCoopRoster   allied index -> (player id, Pokémon uid)
   |      '-- Gen2Battle       upstream engine, unchanged rules
   '-- PokeCoopPolicy   provisional rules
```

1. **Campaign state** (`PokeCoopCampaign`): campaign id, cartridge identity,
   shared event flags, Kanto badge bits, unique encounter registry
   (free, active with its battle id, done) and the set of applied commit ids.
   Every progression change goes through `commit(commit_id, changes)`.
2. **Player state** (`PokeCoopPlayer`): stable player id, in-game trainer id,
   team of at most six `{uid, Gen2SaveMon}` rows, box, bag, money, map, cell,
   facing, return point, battle id and connection flag. Uids are
   `<player id>:<serial>` and never reused.
3. **World simulation**: not yet shared. The host keeps positions and accepts
   adjacent steps and warps; #22 moves `Gen2WorldApi` to per-player actors.
4. **Battle sessions** (`PokeCoopBattleSession`): wraps one `Gen2Battle` with
   its own seeded generator and a revision that advances on every accepted
   decision. The controller is derived, never stored: the owner of the active
   allied Pokémon, or of the Pokémon a move-learn question is about. Enemy
   replacements are settled by the session; Gen 1 enemy moves come from
   `Gen1TrainerAI.select_slot`. Joins queue and apply at the next boundary by
   appending to the allied party (`Gen2Party.add_members`). Results are grouped
   by owner and uid; evolvable Pokémon are reported by uid.
5. **Client presentation** (`PokeCoopClient`): sends numbered intentions, keeps
   the last state and battle views. No game rule runs on the client. The real
   world and battle screens are not connected yet (#13).
6. **Persistence** (`PokeCoopSave`): JSON with `kind`, `format_version`, the
   campaign section and one section per player, written atomically through a
   temporary file. Refuses unknown kinds and newer versions.

## Protocol (version 1)

Transport: `PokeCoopTransport` delivers Dictionaries. The base class links
endpoints in memory (tests, same-process clients); `PokeCoopEnetTransport` uses
`ENetMultiplayerPeer` raw packets on one reliable channel. Packets are
`var_to_bytes` of a value stripped to plain data (`wire_value`), decoded with
`bytes_to_var` (no objects) and dropped above 64 KiB or if not a Dictionary.
Peer 1 is the host.

| Client to host | Fields |
|---|---|
| `hello` | `protocol`, `game_id`, `rom_sha1`, `player_id`, `name` (no `seq`) |
| `move` | `seq`, `map`, `cell`, `facing` |
| `start_battle` | `seq`, `encounter` (an id registered on the host) |
| `command` | `seq`, `battle`, `command` (`type`, `revision`, and `slot`, `index`, `item`, `target`, `move_slot`, `forget_slot` or `choice`) |
| `suggest` | `seq`, `battle`, `suggestion` (`type`, `value`) |
| `join` | `seq`, `battle` |
| `save` | `seq` |

| Host to client | Fields |
|---|---|
| `welcome` | `protocol`, `player_id`, `last_seq` |
| `state` | `campaign` summary, `players` (public views), `you` (private view), `nearby`, `battles` (running), `last_seq` |
| `battle` | `view`: id, revision, phase, controller, paused, participants, pending, active, allies (owner, uid, species, level, HP, status, moves, PP), enemy, suggestions, last events, outcome; a final view adds `evolvable` |
| `rejected` | `seq`, `reason` |
| `ended` | `reason` |

Sequence numbers are per player and strictly increasing; the host refuses a
number it has already seen (`duplicate`) and tells a reconnecting client where
to continue. Battle commands additionally carry the session revision
(`stale_revision`). Encounters are registered on the host, never described by a
client.

## Upstream files the fork changes

Kept small so upstream merges stay cheap (#14):

| File | Change |
|---|---|
| `game/battle/party.gd` | `MAX_ALLIED_SIZE` and `add_members()`; `create()` unchanged |
| `game/battle/battle.gd` | `owner_trainer_ids`, read by `_is_traded` |
| `game/save/save_battle_adapter.gd` | `keep_party_fields()` extracted from `from_battle_party` |
| `tests/unit/test_source_budget.gd` | comment ceiling raised for `game/coop` |
| `.github/workflows/ci.yml` | co-op ENet demo step |
| `.github/workflows/release.yml`, `export-templates.yml` | run only in `Decryptu/pokerecomp` |
| `.githooks/pre-push` | attribution-trailer check removed |
| `README.md` | AI-authorship notice at the top |

## Planned changes

In order of the backlog:

1. Connect the slice to the real screens with a locally imported cartridge:
   remote player sprites, a co-op battle panel (#13).
2. Classify every `Gen2WorldState`, `Gen2WorldSnapshot`, `Gen2SaveData` and
   `Gen2GameRuntime` field (#16), then run the existing world logic against a
   campaign-plus-player projection whose writes split back to their owners
   (#17), and give `Gen2GameRuntime` a co-op mode (#18).
3. Per-player actors in a host-side world per active map (#22), with
   encounters and trainer sight generated on the host (#25).
4. Drive `Gen2BattleScreen` from session events (#26) and share the enemy AI
   choice between the screen and sessions (#27).
5. Route map-script flags and badges through campaign commits (#32).
