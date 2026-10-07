# Reevaluate: how co-op shares the world

A proposal from an outside, read-only review, for the agent that knows
pokerecomp-coop. It compares the co-op world model with sm64coopdx (Super Mario 64
co-op, played from start to finish) and proposes a change. The reviewer read
code and docs and ran nothing, so treat every claim as a hypothesis to check
against the code, the tests and the session logs.

## Your task

1. Check each claim C1–C7 against the code. Done when every claim has a verdict
   (**confirmed**, **refuted** or **needs a run**) and the evidence behind it
   (file:line, test, log line).
2. Answer every open question Q1–Q9, with evidence where there is any.
3. Give a verdict on the proposal: adopt, adopt with changes, or keep the
   current model. Include a revised plan with acceptance tests if you adopt it.
4. Hand all of this to the owner, with the decisions only the owner can make
   listed separately. Recording D66 and changing issues #22, #24 and #25 wait
   for the owner's go-ahead.

## What the review saw

- **pokerecomp-coop:** branch `coop/playthrough` at `e567b78b`, with D63–D65 and
  `tools/coop_autoplay.gd` still uncommitted. Line numbers below are from that
  state.
- **Files read:** `docs/coop/brief.md`, `design.md`, `architecture.md`,
  `progress.md`, `tracking.md` and `decisions.md` (D19–D65), plus
  `game/coop/coop_world_link.gd`, `coop_ownership.gd`, `coop_host.gd` (around
  `apply_world`) and `game/world/world_api.gd:4798`.
- **sm64coopdx:** `8cd6e5977d9f920d51ca71f2c61801d019ed79c6` (2026-05-31). A
  subagent read `src/pc/network/`, the save code and the behaviour files; the
  main claims were spot-checked against the source. To check them yourself:
  `git clone https://github.com/coop-deluxe/sm64coopdx && git -C sm64coopdx checkout 8cd6e597`.

## Reference: the sm64coopdx model

| Part | How it works | Evidence |
|---|---|---|
| Host | A player that relays packets, decides who joins, holds the settings and is the only one that writes the save. It runs no authoritative simulation: every machine simulates the level its player is in | `save_file.c:407-412` (a client's save only asks the host); `packet.c:222-233` (relay) |
| Save file | A joiner receives the host's whole save once. After that, any flag a player sets is broadcast and OR-ed in on every machine; nothing clears a flag over the network. Clients keep the save in memory only | `packet_join.c:103-129`; `packet_save_set_flag.c:47-49`; `save_file.c:668-674` |
| Location | Course, act, level and area. The act is part of the key, so different acts of one course are separate instances. The castle hub is forced to act 0 so it is never instanced | `network_player.h:34-37`; `packet_change_level.c:35-41` |
| Area state | Exists only in the memory of the players inside the area. The server has a player already there send it to a newcomer, in one ordered group. With nobody there, the level loads fresh. It is gone when the last player leaves | `packet_change_level.c:6-30`; `packet_area.c:34-129`; `level_script.c:732-746` |
| Sync valid | Until a newcomer has the area's state, it sends no world updates (player, objects, spawns, collections, respawn info) | `packet_player.c:228`; `packet_object.c:318-321` |
| Objects | Owned by the nearest player, recomputed every frame with no handshake; a few types are owned by the lowest global index. 98 of 226 behaviour files never register for sync and run locally | `sync_object.c:293-331`; `network_player.c:144-159` |
| Scenes | Dialogs and cutscenes play for the local player only. Time never stops, and pause never pauses, while more than one player is connected. A star's cutscene plays for its collector only. At Bowser, the first player in plays the intro and the others idle until synced | `object_helpers.c:3253-3258, 3326-3347`; `network_utils.c:57-60`; `bowser.inc.c:1396-1439` |
| Star collected | The collector broadcasts it. Everyone gains the flag wherever they are; players in the same level see the star vanish; nobody else is moved | `packet_collect_star.c:69-121`; `interaction.c:928-946` |
| Host leaves | The session ends; there is no migration | `network_player.c:236-248` |

Why it holds from start to finish: the only state that persists across the
network is a small set of flags that are only ever set, so a repeated or late
update does no harm. Everything a level is doing right now dies with the level.

## Claims about pokerecomp-coop

- **C1.** A window pushes its world patch on every frame its state is dirty,
  whatever its scripts are doing (`coop_world_link.gd:55-81`).
- **C2.** A window applies the host's changes as soon as they arrive,
  mid-scene included (`coop_world_link.gd:96-116`). No co-op code calls
  `script_busy()`; the only caller found is `tools/coop_autoplay.gd:239`.
- **C3.** `gen1_map_scripts` belongs to the campaign (`coop_ownership.gd:39`).
  Per-map script steps therefore become campaign state as they happen: both a
  resting value ("parcel delivered") and a mid-scene step ("Oak walking to the
  table").
- **C4.** So the campaign can store, and a partner can load, a mid-scene step
  that the cartridge never saves, since START cannot be reached while a script
  holds the player. The cartridge half of this claim is from memory; check it.
- **C5.** D51 (a stale echo rewinding a map script), D63's cost (a partner
  arriving re-rolls Vermilion Gym's first lock mid-search), and the open risk
  of a window dropping mid-scene share this root cause.
- **C6.** `Gen2WorldAPI.script_busy()` (`world_api.gd:4798`) is a candidate
  rest-point signal: `_gen1_holding()`, an active script, or a non-empty script
  queue. Whether it covers text boxes, forced movement, warps and the battle
  takeover's wait is unverified.
- **C7.** The host trusts patches (`coop_host.gd:450-467`). An opening player's
  campaign half already goes to a private copy (`coop_host.gd:452-456`), which
  is a mechanism shaped like a transaction.

## The proposal

**Rule:** share what the cartridge would save, never what it is doing right now.

A **rest point** is a moment the cartridge itself could save: the player is
free, no script holds them, no text box is open. A **scene** is the stretch
between two rest points.

There are three tiers:

| Tier | sm64coopdx counterpart | Holds | Shared how |
|---|---|---|---|
| Campaign | The save file | Flags, badges, toggled objects, resting map-script steps, beaten encounters | Host-kept; reaches it only at rest points |
| Map instance | The area | What a map is doing now: NPC positions, a scene in progress, map-load rolls | Lives in the windows on that map; handed to an arriving partner; never patched |
| Player | Mario | Team, bag, money, position, menus, own scenes | As today |

The host stays a hub and the keeper of the save; windows keep simulating
(D20, D61).

### Plan

- **P1. Decision.** D66 records the rule:
  - #22: close it; the host stays a hub.
  - #25: won't do; windows roll encounters and the host fights them.
  - #24: rescope to rest points plus "first player in drives a scene".
- **P2. Commit at rest points.** While the window's world is busy,
  `PokeCoopWorldLink.advance()` neither pushes nor pulls world patches. At the
  next rest point the scene's changes go out as one patch. Holdings keep their
  own channel. Acceptance tests:
  - a patch made mid-scene is held until rest;
  - a partner's change waits for rest;
  - a window dropped mid-scene leaves the campaign at its last rest, and the
    scene replays;
  - the existing story-item and gift-race tests pass.
- **P3. Map handover on entry.** A window entering a map a partner stands on
  takes that map's load-time state rather than rolling its own; the first case
  is Vermilion Gym's locks, kept by the host only while someone is inside. An
  empty map rolls fresh, as on the cartridge. Scenario: a partner enters
  mid-search and the cans do not move.
- **P4. The first player in drives a contested scene,** only where P2 and P3
  leave real conflicts. A second window on that map starts no scene there until
  the first ends (held as in D54) and sees its result. The scenes are listed
  one by one, not covered by a general lock.
- **P5. `design.md` says what is not shared:** NPC wandering, a scene's
  animation in the partner's window (they see the result), music and text
  boxes.
- **P6. Verify:**
  - the autopilot run to BROCK (#48);
  - scenarios: both players in Oak's lab for the parcel; a partner entering
    Vermilion Gym mid-search; a window killed during the Route 22 rival scene,
    then the campaign checked and the scene replayed.

### Accepted costs

- A partner on the same map sees a scene's result, not the scene.
- A scene cut off by a disconnect replays from its start.
- A long scene, including a battle inside it, reaches the partner only when
  it ends.
- Windows stay trusted.

## Open questions

- **Q1.** Is `script_busy()` the right rest-point signal? Name every state
  where the player cannot open START but `script_busy()` is false (text boxes,
  ledge hops, spinner tiles, warps, the takeover wait), and any state where it
  is true yet a save would be harmless.
- **Q2.** In a scene with a battle inside it (the Route 22 rival, Oak's lab),
  does the window's script branch on the takeover's result or on a flag pulled
  from the host? What breaks if pulls wait until the scene ends?
- **Q3.** D52's `share_found_items` runs only when the same patch moves the
  story (`coop_host.gd:465-466`), and D62's `keep_once` reads one patch's items
  and money (`coop_host.gd:462-463`). Do scenes today send their item and their
  flag in separate frames' patches, so an item escapes sharing? Would one patch
  per scene fix that, or break `keep_once`?
- **Q4.** Is it safe to apply a partner's resting change to the map you stand
  on right away, or should it wait for your next map load? Is there a resting
  script step that assumes where the player stands?
- **Q5.** Besides Vermilion Gym's locks, which map-load rolls or inits come out
  differently in each window?
- **Q6.** Should P2 hold changes in the window, or should the host open a scene
  transaction by reusing the opening's private copy (`coop_host.gd:452`)? Which
  survives a crash and a reconnect better?
- **Q7.** Do the session logs from the autopilot and scenario runs
  (`tools/coop_log.gd -- summary`) show `world_pull` changes landing in a busy
  world, or a partner's mid-scene steps arriving? Logged evidence outranks this
  static reading.
- **Q8.** D61 records the owner asking for the host to lock a scripted NPC or
  gift while a window uses it; D62 settled the race on the host instead. Is P4
  that lock, and does the owner need to confirm it again?
- **Q9.** Closing #22 and #25 departs from the brief's "authoritative maps,
  NPCs, interactions and player movement". Which wording does the owner need to
  approve?

## What to hand back

- A verdict table for C1–C7, with evidence.
- Answers to Q1–Q9.
- Adopt, adopt with changes, or keep the current model, with the revised plan
  and its acceptance tests.
- The decisions only the owner can make.
