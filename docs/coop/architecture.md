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
   team of at most six `{uid, Gen2SaveMon}` rows, PC rows `{uid, mon, box}` in
   twelve boxes of twenty, bag, money, map, cell, facing, return point, battle
   id and connection flag. Uids are `<player id>:<serial>` and never reused.
   `holdings_rev` rises with every change the host makes to the team or the PC
   (D29).
3. **World simulation**: not yet shared. Each window runs the unchanged world
   on its own save; the host keeps positions, checks step length and trusts
   reported warps (D20). `PokeCoopOwnership` classifies every world, snapshot,
   save and runtime field; the campaign keeps the shared world-state keys and
   each player their own (D23). `PokeCoopWorldLink` keeps a window's world state
   in step with the host by patches and its party and PC by whole copies based
   on `holdings_rev`, and `PokeCoopBattleTakeover`
   sends the window's own battles to the host (D24). #22 moves `Gen2WorldApi` to
   per-player actors.
4. **Battle sessions** (`PokeCoopBattleSession`): wraps one `Gen2Battle` with
   its own seeded generator and a revision that advances on every accepted
   decision. The controller is derived, never stored: the owner of the active
   allied Pokémon, or of the Pokémon a move-learn question is about. Enemy
   replacements are settled by the session; Gen 1 enemy moves come from
   `Gen1TrainerAI.select_slot`. Joins queue and apply at the next boundary by
   appending to the allied party (`Gen2Party.add_members`). Results are grouped
   by owner and uid; evolvable Pokémon are reported by uid.
5. **Client presentation**: `PokeCoopClient` sends numbered intentions and keeps
   the last state and battle views; no game rule runs on it.
   `PokeCoopRemoteActor` is registered as a world actor (D19): it draws the
   other connected players on the current map, eased between cells, in a fixed
   colour each, with the "!" emote while they battle, and reports this player's
   position. `PokeCoopBattlePanel` is a `PanelContainer` on a `CanvasLayer` over
   the world: SELECT opens the session menu (fight an offered encounter, join a
   running battle, save), and a shared battle shows the roster with owners, who
   decides and the partner's suggestion (D22). Under it `PokeCoopBattleField`
   draws the same battle on the cartridge's battle field (D32), its pictures
   kept in a `PokeCoopBattleStage` tilemap (D39), and
   `PokeCoopLinkTransport` is the Cable Club's cable to the partner (D31).
   `tools/coop_play.gd` assembles a
   window: data from the local cache, the world screen on a local save, the
   actor, the panel, and the world held still while the panel is open.
   `PokeCoopSession` is that assembly as one class, used by the launcher's
   Co-op tab (`PokeCoopPage`) and by the tool; `Gen2GameRuntime.coop` holds the
   live session and drives it each frame. After a host battle the session runs
   the window's own evolution and whiteout for its player (D26, D27).
6. **Persistence** (`PokeCoopSave`): JSON with `kind`, `format_version` (2), the
   campaign section and one section per player, written atomically through a
   temporary file, the replaced checkpoint kept as `.bak`. Refuses unknown kinds
   and newer versions; a format 1 file is settled once on read. Between
   checkpoints the host appends the state after each story change to
   `<campaign>.json.journal`, which the next checkpoint removes; `read` returns
   the newest whole line newer than the checkpoint (D66).

## Protocol

Transport: `PokeCoopTransport` delivers Dictionaries. The base class links
endpoints in memory (tests, same-process clients); `PokeCoopEnetTransport` uses
`ENetMultiplayerPeer` raw packets on one reliable channel. Packets are
`var_to_bytes` of a value stripped to plain data (`wire_value`), decoded with
`bytes_to_var` (no objects) and dropped above 64 KiB or if not a Dictionary.
Peer 1 is the host.

| Client to host | Fields |
|---|---|
| `hello` | `protocol`, `game_id`, `rom_sha1`, `player_id`, `name` (no `seq`) |
| `move` | `seq`, `map`, `cell`, `facing`, `warp` (the client's world changed map or jumped) |
| `start_battle` | `seq`, `encounter` (an id registered on the host) |
| `command` | `seq`, `battle`, `command` (`type`, `revision`, and `slot`, `index`, `item`, `target`, `move_slot`, `forget_slot` or `choice`) |
| `suggest` | `seq`, `battle`, `suggestion` (`type`, `value`) |
| `join` | `seq`, `battle` |
| `save` | `seq` |
| `trade` | `seq`, `partner`, and `slot` (an offer), `answer` (1 TRADE, 0 CANCEL) or `leave` |
| `world` | `seq`, `patch` (synced world-state keys, `{set, erase}` or `{value}` each) |
| `party` | `seq`, `rows` (`uid` hint and `mon` per party member, in the window's order), `rev` (the `holdings_rev` the copy is based on), `current_box`, and `boxes` (`uid` hint, `mon` and `box` per stored Pokémon) when the PC changed; without `rev` only the team is replaced and nobody is released |
| `window_battle` | `seq`, `kind`, `trainer_class`, `trainer_index`, `enemy` (the world's enemy party as save-mon rows) |
| `hello` (new player) | adds `starter`, the species a new player chose, `opening` (true to play the opening, D50), `save` (a brought trainer), and `known` (this device's player in each campaign of the host, D49) |
| `hello` (protocol 3) | adds `logs` (`device`, `share`) for the debug stream (D59) |
| `opening` | `seq`, `rival`: Oak's speech is over and the name given to the rival |
| `log` | `lines` (no `seq`): a sharing device's own session-log lines; the host passes them on (D59) |
| `leave_battle` | `seq`, `battle`: back to the player's world while their Pokémon fight on, or a queued join called off (protocol 4, D62) |
| `stand_in` | `seq`, `battle`: decide for the Pokémon of an owner who dropped, once the view says `stand_in_due` (protocol 4, D62) |

| Host to client | Fields |
|---|---|
| `welcome` | `protocol`, `player_id`, `last_seq` |
| `box` | `rev`, `rows` (`uid`, `mon`, `box`): the player's PC, sent before `state` whenever its revision changed |
| `state` | `campaign` summary with `world` (the shared world-state keys), `players` (public views), `you` (private view, with the player's own `party` rows, `world` keys, `holdings_rev`, `box_rev`, `current_box`, `trade` (round `serial`, last `outcome`, the partner's offered `partner_slot`) and `trade_partner` (id, name, trainer id and party of whoever the Cable Club links to)), `nearby` (connected players on the same map), `battles` (running), `encounters` (id and label), `last_seq` |
| `battle` | `view`: id, revision, phase, controller, paused, participants, pending, active, allies (owner, uid, species, level, HP, status, moves, PP), enemy, suggestions, last events, outcome, `left`, `attached` (whose world opened the fight) and `stand_in_due`; a final view adds `evolvable` and `prizes` |
| `rejected` | `seq`, `reason` |
| `ended` | `reason` |
| `log` | `lines`: other devices' session-log lines, for a device that shares (D59) |

The protocol is version 4 (`PokeCoopHost.PROTOCOL`); a peer of another version is
refused with `protocol_mismatch`.

A refused `hello` is answered with `rejected` (`seq` -1) and the peer is dropped
after `SHUTDOWN_GRACE_MSEC`. On shutdown the host sends `ended`, ignores further messages and closes once all
clients have left or `SHUTDOWN_GRACE_MSEC` has passed; a client closes on
`ended`. Sequence numbers are per player and strictly increasing; the host refuses a
number it has already seen (`duplicate`) and tells a reconnecting client where
to continue. Battle commands additionally carry the session revision
(`stale_revision`). Encounters are registered on the host, never described by a
client.

## Upstream files the fork changes

Kept small so upstream merges stay cheap (#14):

| File | Change |
|---|---|
| `game/battle/party.gd` | `MAX_ALLIED_SIZE` and `add_members()`; `create()` unchanged |
| `game/battle/battle.gd` | `owner_trainer_ids`, read by `_is_traded`; `exp_all_groups`, the party indices each EXP.ALL pass splits over (D62) |
| `game/save/save_battle_adapter.gd` | `keep_party_fields()` extracted from `from_battle_party` |
| `game/save/save_prompt.gd` | the failure step draws no YES/NO (D70) |
| `game/world/world_party_host.gd` | `roll_capture()`, a public wrapper over the capture roll; `commit_link_trade` builds the trade movie's context before the trade evolution, so the movie shows the Pokémon as it was sent (D64) |
| `game/world/world_screen.gd` | `evolve_after_battle()` and `white_out()` for battles fought on the host; the takeover summary carries the trainer's name, win text, gym marker and Gen 1 ghost kind (D68); on Generation 1 the player does not walk while a map script walks someone (L10); `save_gate`, asked before the START menu's SAVE writes, so a co-op window's SAVE the host would refuse ends in the prompt's own FAILED step (L2) |
| `game/world/world_api.gd` | a Generation 1 press faces its direction even when it does not turn (L11); `_gen1_box_held` notes a box that owed no press (D76) |
| `game/world/gen1_map_scripts.gd` | the link rooms' special warp and return close the wait box first (D71); a row's end closes a no-press box its tail held up (D76) |
| `tests/unit/test_world_api.gd` | `test_gen1_a_link_room_entered_or_reloaded_closes_the_wait_box` (D71) |
| `tests/integration/test_world_frame_pump.gd` | `test_a_gen1_rows_end_takes_down_a_no_press_box_its_fade_held_up` (D76) |
| `game/battle/battle_intro.gd` | Generation 1's back-picture head as `LoadPlayerBackPic` lays it out (L8) |
| `game/world/oak_speech_screen.gd` | `preset_names`: a name settled before the speech is said rather than asked |
| `game/world/intro_screen.gd` | `writes_save`, `preset_names` and `spoken`, so a co-op window plays the opening without writing a save |
| `game/world/link_transport.gd` | `PENDING`, `answer_trade()` and `trade_answer()`, defaults that keep a save slot's peer as it was |
| `game/world/link_screen.gd` | the Gen 1 trade waits on `PENDING`, reports TRADE or CANCEL and cancels on the peer's CANCEL; its own slot rides in `choose_trade_slot`'s context |
| `autoload/game_runtime.gd` | `coop` slot driven from `_process`, told when the window closes (it says goodbye, then quits) and when the app is paused and resumed |
| `game/main/main.gd` | the Co-op tab |
| `tests/unit/test_source_budget.gd` | comment ceiling raised for `game/coop` |
| `tests/unit/test_link.gd` | `test_a_trade_evolver_is_shown_as_sent_and_arrives_evolved`, the regression test for D64 |
| `.github/workflows/ci.yml` | co-op ENet demo and three-process check steps |
| `.github/workflows/release.yml`, `export-templates.yml` | run only in `Decryptu/pokerecomp` |
| `.githooks/pre-push` | attribution-trailer check removed |
| `README.md` | AI-authorship notice at the top |

## Planned changes

In order of the backlog:

1. Per-player actors in a host-side world per active map (#22), with
   encounters and trainer sight generated on the host (#25).
2. Drive `Gen2BattleScreen` from session events (#26) in place of the panel,
   and share the enemy AI choice between the screen and sessions (#27).
3. Route map-script flags and badges through campaign commits (#32).
