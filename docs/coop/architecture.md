# Co-op architecture

Current state of the co-op layer and the changes still planned. Behaviour is
specified in [design.md](design.md); status is in [progress.md](progress.md).

## Upstream baseline, re-checked

Baseline: `Decryptu/pokerecomp` at
`696d1c9a1d345ae08fd7febac8aa320aed6608b5` (0.1.72, Godot 4.8-dev4). The
review leads in the brief were checked against that checkout. The fork has
since merged upstream `v0.1.75` (`17c8da8`, Godot 4.8-dev7, D97) and `v0.1.78`
(`588d0f2`, D110); see
[Merging upstream](#merging-upstream).

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
   `PokeCoopVersus` extends this session for two human opponents, with a view
   mirrored per player, simultaneous choices and post-fight awards (D100).
5. **Client presentation**: `PokeCoopClient` sends numbered intentions and keeps
   the last state and battle views; no game rule runs on it.
   `PokeCoopRemoteActor` is registered as a world actor (D19): it draws the
   other connected players on the current map, eased between cells, in a fixed
   colour each, with the "!" emote while they battle, and reports this player's
   position. `PokeCoopMenu` is the session menu, START > CO-OP or SELECT on the
   map (fight an offered encounter, join or rejoin a running battle, invite a
   friend to battle or trade, leave),
   drawn on the world's own screen (D99). In a shared battle
   `PokeCoopBattlePanel` holds the choices, who decides and the partners'
   suggestions, `PokeCoopBattleMenu` shows them as the cartridge's
   FIGHT/PKMN/ITEM/RUN menus, and `PokeCoopBattleField` draws the battle inside
   the world's 160x144 screen (D98), its pictures
   kept in a `PokeCoopBattleStage` tilemap (D39), and
   `PokeCoopLinkTransport` is the Cable Club's cable to the partner (D31).
   `tools/coop_play.gd` assembles a
   window: data from the local cache, the world screen on a local save, the
   actor, the panel, and the world held still while the panel is open.
   `PokeCoopSession` is that assembly as one class, used by the launcher's
   Co-op tab (`PokeCoopPage`, its pieces in `PokeCoopTabParts`, the beacon,
   dial, memory and split screen in `PokeCoopLobby`) and by the tool; `Gen2GameRuntime.coop` holds the
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
| `trade` | `seq`, `partner`, and `slot` (an offer), `answer` (1 TRADE, 0 CANCEL), `leave`, or `end` (leave a direct pairing, D100) |
| `challenge` | `seq`, `partner`, `kind` (`battle` or `trade`), or `id`, `answer` (1 YES, 0 NO); host rechecks both players (protocol 6, D100) |
| `world` | `seq`, `patch` (synced world-state keys, `{set, erase}` or `{value}` each) |
| `party` | `seq`, `rows` (`uid` hint and `mon` per party member, in the window's order), `rev` (the `holdings_rev` the copy is based on), `current_box`, and `boxes` (`uid` hint, `mon` and `box` per stored Pokémon) when the PC changed; without `rev` only the team is replaced and nobody is released |
| `window_battle` | `seq`, `kind`, `trainer_class`, `trainer_index`, `enemy` (the world's enemy party as save-mon rows) |
| `hello` (new player) | adds `starter`, the species a new player chose, `opening` (true to play the opening, D50), `save` (a brought trainer), and `known` (this device's player in each campaign of the host, D49) |
| `hello` (protocol 3) | adds `logs` (`device`, `share`) for the debug stream (D59) |
| `opening` | `seq`, `rival`: Oak's speech is over and the name given to the rival |
| `log` | `lines` (no `seq`): a sharing device's own session-log lines; the host passes them on (D59) |
| `leave_battle` | `seq`, `battle`: back to the player's world while their Pokémon fight on, or a queued join called off (protocol 4, D62) |
| `stand_in` | `seq`, `battle`: decide for the Pokémon of an owner who dropped, once the view says `stand_in_due` (protocol 4, D62) |
| `probe` | `protocol`, `build`, `name`, `game_id`, `rom_sha1`, `known` (no `seq`): asked before `hello` on the same link, answered whatever the protocol and creating nobody (protocol 7, D103) |
| `hello` (protocol 7) | adds `via`, the address the device dialled; the host keeps it and the `game_id` with the player |
| `wild_tables` | `tables` (no `seq`): this cartridge's Generation 1 wild slots, `{grass, water}` by map number as `[species, level]` rows; sent after each `welcome` by a window of a paired game, kept on the host for the session only, never written (protocol 8, D104) |
| `scene` | `seq`, `map`, `on`: a rival scene in `PokeCoopPolicy.RIVAL_SCENES` started in the sender's world (`on` true) or reached its rest point after (`on` false); refused with `scene_taken` while another player drives that map's scene, `not_a_scene` for another map (protocol 5, D84) |

| Host to client | Fields |
|---|---|
| `probe` | the lobby view (`kind`, `protocol`, `build`, `game_id`, `rom_sha1`, `campaign`, `title`, `host`, `players` with `name`, `game`, `connected`, `badges`, `place`, `new_players`), `refused` (empty, `protocol_mismatch` or `content_mismatch`) and `you` (`player_id`, `name` of the trainer this device or name gets back, empty for a new player) |
| `welcome` | `protocol`, `player_id`, `last_seq` |
| `box` | `rev`, `rows` (`uid`, `mon`, `box`): the player's PC, sent before `state` whenever its revision changed |
| `state` | `campaign` summary with `world` (the shared world-state keys), `players` (public views, with `scene`: the map of the rival scene that player drives), `you` (private view, with the player's own `party` rows, `world` keys, `holdings_rev`, `box_rev`, `current_box`, `trade` (round `serial`, last `outcome`, the partner's offered `partner_slot`) and `trade_partner` (id, name, trainer id and party of whoever the Cable Club links to)), `nearby` (connected players on the same map), `battles` (running), `encounters` (id and label), `last_seq` |
| `battle` | `view`: id, revision, phase, controller, paused, participants, pending, active, allies (owner, uid, species, level, HP, status, moves, PP), enemy, suggestions, last events, outcome, `left`, `attached` (whose world opened the fight) and `stand_in_due`; a final view adds `evolvable` and `prizes` |
| `rejected` | `seq`, `reason` |
| `ended` | `reason` |
| `log` | `lines`: other devices' session-log lines, for a device that shares (D59) |
| `wild_tables` | `game_id`, `tables`: the other version's wild slots, sent to each player of the pair's other game while the campaign takes both versions, once a device of that version has sent them (protocol 8, D104) |

A private `you.challenge` carries incoming/outgoing invitations and the last
answer; `you.trade.direct` names the paired player and serial. Public players
carry `meeting` while paired. A `versus` battle view shows only the viewer's
team as allies, their choices and learning offer, with events mirrored for
the opponent. Friend battles stay private to their two participants.

The protocol is version 8 (`PokeCoopHost.PROTOCOL`; 8 added `wild_tables`, D104); a peer of another version is
refused with `protocol_mismatch`. A hosting session also sends the lobby view with its
ENet `port` as a JSON UDP beacon to port 24681 once a second (broadcast, each
network's `.255` and 127.0.0.1); the Co-op tab's Join screen lists the hosts heard in
the last four seconds (`PokeCoopLobby`). A version 6 host answers a `probe` with
`rejected` `hello_first`, which the tab reads as an older host.

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
| `game/world/world_party_host.gd` | `roll_capture()`, a public wrapper over the capture roll; `commit_link_trade` builds the trade movie's context before the trade evolution, so the movie shows the Pokémon as it was sent (D64), and clears the item of a Pokémon arriving in a Generation 1 game (D120) |
| `game/world/world_screen.gd` | `evolve_after_battle()` and `white_out()` for battles fought on the host, which on Generation 1 goes straight to the Pokémon Center once the co-op field has printed the blackout (D125); the takeover summary carries the trainer's name, win and loss text, gym marker and Gen 1 ghost kind (D68, D125); on Generation 1 the player does not walk while a map script walks someone (L10); `save_gate`, asked before the START menu's SAVE writes, so a co-op window's SAVE the host would refuse ends in the prompt's own FAILED step (L2); `save_written`, called by `persist_world_snapshot` after any SAVE (D80); a takeover's `team_won` carried into the battle result skips Generation 1's after-battle blackout (D88) |
| `game/world/nickname_prompt_screen.gd` | the text waits take B as well as A, as `WaitForTextScrollButtonPress` does (#26) |
| `game/world/world_api.gd` | a Generation 1 press faces its direction even when it does not turn (L11); `_gen1_box_held` notes a box that owed no press (D76); `gen1_end_of_battle` sets both map-load bits, so a wild fight's reload redraws a switch's block (#88) |
| `game/world/gen1_map_scripts.gd` | the link rooms' special warp and return close the wait box first (D71); a row's end closes a no-press box its tail held up (D76) |
| `tests/unit/test_world_api.gd` | `test_gen1_a_link_room_entered_or_reloaded_closes_the_wait_box` (D71); `test_gen1_a_wild_fights_reload_runs_the_maps_load_callback` (#88) |
| `tests/integration/test_world_frame_pump.gd` | `test_a_gen1_rows_end_takes_down_a_no_press_box_its_fade_held_up` (D76) |
| `game/battle/battle_intro.gd` | Generation 1's back-picture head as `LoadPlayerBackPic` lays it out (L8) |
| `game/world/oak_speech_screen.gd` | `preset_names`: a name settled before the speech is said rather than asked |
| `game/world/intro_screen.gd` | `writes_save`, `preset_names` and `spoken`, so a co-op window plays the opening without writing a save |
| `game/world/link_transport.gd` | `PENDING`, `answer_trade()` and `trade_answer()`, defaults that keep a save slot's peer as it was |
| `game/world/link_screen.gd` | the Gen 1 trade waits on `PENDING`, reports TRADE or CANCEL and cancels on the peer's CANCEL; its own slot rides in `choose_trade_slot`'s context |
| `autoload/game_runtime.gd` | `coop` slot driven from `_process`, told when the window closes (it says goodbye, then quits) and when the app is paused and resumed; `restart()` first asks `coop.continue_after_reset()`, so the Hall of Fame's reset continues the co-op world (D88) |
| `game/main/main.gd` | the Co-op tab |
| `tests/unit/test_source_budget.gd` | comment ceiling raised for `game/coop` |
| `tests/unit/test_link.gd` | `test_a_trade_evolver_is_shown_as_sent_and_arrives_evolved`, the regression test for D64 |
| `tools/preview_world_story.gd` | `_gen1_story_path` split into `_gen1_story_start` and `_gen1_story_legs`, so `tools/coop_seed.gd` can stop after a leg; output unchanged (D78) |
| `tools/checks/played.gd` | `_warp_press`: on Generation 1, a player standing on a stair warp with nothing to press against steps off it, so a route can take back the stairs it arrived by (#88) |
| `.github/workflows/ci.yml` | co-op ENet demo and three-process check steps; also runs on pushes to `pokerecomp-online-coop` |
| `.github/workflows/release.yml`, `export-templates.yml` | run only in `Decryptu/pokerecomp` |
| `.githooks/pre-push` | attribution-trailer check removed |
| `game/rom/rom_registry.gd` | `red_de` and `blue_de` rows, `base_of`, `pick`, `language_of` (D95, #50) |
| `game/gen1/gen1_layout.gd` | `for_id` arms for the German games (`Gen1LayoutDe`), the trainer AI shift, `pinned()` facility text, German title tiles, the alphabet stride and the credits count (#50) |
| `game/gen1/gen1_importer.gd` | the language switch, per-language name checks and font runs, pinned facility slots, the alphabet stride, empty German dex rating, metric dex entries, base-game fallbacks (#50) |
| `game/gen1/gen1_text.gd`, `game/data/game_data.gd` | the German charmap, chosen by the cache's game (#50) |
| `game/render/font.gd`, `pokedex_page.gd`, `naming_screen_page.gd`, `game/save/save_prompt.gd`, `game/battle/battle_screen.gd` | German Generation 1 lines from `Gen1LayoutDe.UI`; the Pokédex in metres and kilograms (#50) |
| `game/world/gen1_movie.gd`, `world_effects.gd`, `world_screen.gd`, `game/launcher/cartridge.gd`, `launcher_theme.gd`, `tools/checks/played.gd`, `tools/preview_world_story.gd` | tables and art fall back to the base game for the German ids (#50) |
| `tests/unit/test_gen1_layout.gd`, `test_gen1_text.gd`, `test_rom_verifier.gd`, `test_gen1_sram.gd` | German layout, charmap, registry and save-start cases (#50) |
| `docs/REFERENCES.md`, `references.lock` | einstein95/pokered-de and its symbols branch pinned (D95) |
| `autoload/input_runtime.gd`, `game/options/options.gd`, `game/launcher/controls_section.gd`, `game/input/input_actions.gd` | the owner's controller pick: `Gen2Options.pad`, applied by the new `game/input/pad_choice.gd` (`PokePadChoice`) after each install and plug; Settings > Controls > Controller; other pads' events are dropped in `_input`; Auto letters read the picked pad |
| `game/input/pad_choice.gd` | `held`: a split screen's half keeps its own controller over the one Settings picked (D116, #53) |
| `game/mods/mod_host.gd`, `game/world/world_api.gd`, `tests/unit/test_world_api.gd` | `unregister_wild_substitute`; the wild substitute's context carries the drawn `slot` (D104) |
| `game/mods/mod_host.gd`, `game/world/town_map_screen.gd`, `docs/MODS.md` | `register_town_map_marks`: more player icons on the Generation 1 region map and fly map (D106) |
| `game/world/world_api.gd`, `tests/unit/test_world_api.gd` | `sight_gate`, asked with a trainer's event row before it looks; a co-op window refuses a trainer the team is fighting or has beaten (D107) |
| `game/battle/battle_anim_player.gd`, `game/battle/battle_screen_map.gd`, `tests/unit/test_battle_anim_player.gd` | Generation 1's `_AnimationSlideMonUp` rises from below into its box and ends home (DIG drew a second picture at the top of the screen); a picture slid up or down stays inside its box's rows, as `CopyPicTiles` with fewer rows does |
| `game/world/world_pack.gd` | `gen1_bag_capacity`, the Generation 1 bag rows `receive_check` allows; the cartridge's twenty unless a co-op run raises it (D109) |
| `game/battle/battle_screen.gd` | `add_trainer_hud`, a static split out of `_add_trainer_hud`, so the co-op field lays out the party balls the same way (D108) |
| `.gutconfig.json` | `pre_run_script`: `tests/coop_test_folders.gd` keeps every run's co-op campaigns and session logs out of the player's folders |
| `README.md` | AI-authorship notice at the top |

`game/gen1/gen1_layout_de.gd` also carries the friend invitation and battle
menu translations (D100); no new world or battle engine seam was needed.

## Merging upstream

Upstream is merged by release tag, never by its `main` (#14, D97):

1. `git fetch upstream 'refs/tags/v<x>:refs/tags/v<x>'` (the remote is
   fetch-only, see `AGENTS.md`), then on `coop/upstream-sync` from `main`:
   `git merge --no-ff v<x>`.
2. Conflicts so far, all kept both sides: `rom_registry.gd`'s `ORDER`,
   `docs/REFERENCES.md` and `references.lock` (new references on each side),
   `test_rom_verifier.gd`, and `test_source_budget.gd`'s ceiling, which takes
   both raises added together. A file in the table above that upstream
   rewrote takes upstream's version when it already covers the fork's case.
3. Upstream code keyed by game id does not know `red_de` and `blue_de`: grep
   the merged diff for new tables keyed by `RomRegistry.RED`/`BLUE` and route
   them through `RomRegistry.pick`.
4. A new Godot pin moves `AGENTS.md`, `readiness.md` and the runner usage lines
   with it; a dev build's import rewrites `.import` files with new default
   keys, which upstream does not commit either.
5. Import, the whole suite, the boot smoke test, the ENet demo and the
   three-process check on the new pin; then the owner's cartridge checks
   (`playthrough_brock`, `cable_club_trade`) before the pull request merges.
   A new `RomCache.FORMAT_VERSION` makes the owner's caches stale. When the
   bump touched no Generation 1 import code, the checks run on a scratch copy
   of the Red cache with the new number in its manifest, passed as
   `REAL_USER_DIR` (D110); the owner's own folder stays as it was.

## Planned changes

In order of the backlog:

1. Per-player actors in a host-side world per active map (#22), with
   encounters and trainer sight generated on the host (#25).
2. Drive `Gen2BattleScreen` from session events (#26) in place of the field's replay,
   and share the enemy AI choice between the screen and sessions (#27).
3. Route map-script flags and badges through campaign commits (#32).
