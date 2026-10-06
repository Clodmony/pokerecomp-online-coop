# Co-op decisions

Architectural decisions and their trade-offs, newest last. Each entry says what
was decided, why, and what it costs.

## D1. Stay on Godot pokerecomp (2026-10-05)

The battle engine is already scene-free with injected randomness and explicit
question states, and the import pipeline, save model and tests are extensive.
Nothing found blocks multiplayer outright. Cost: the world layer assumes one
player and needs refactoring (#16, #17, #22).

## D2. A private repository carrying upstream history, not a GitHub fork (2026-10-05)

GitHub does not allow a private fork of a public repository. The repository was
created private (`Clodmony/pokerecomp-coop`), visibility verified before the
first push, and `main` pushed from upstream `696d1c9` with its full history.
`origin` is the private repository; `upstream` is `Decryptu/pokerecomp` with
its push URL disabled. Upstream tags are not pushed, because a `v*` tag would
trigger the release workflow. Cost: no GitHub fork network, so upstream changes
are merged by hand (#14).

## D3. Release automation off in the fork (2026-10-05)

`release.yml` publishes GitHub releases on a tag and `export-templates.yml`
runs a weekly seven-host build. Both jobs are guarded with
`if: github.repository == 'Decryptu/pokerecomp'`, and both workflows are
disabled on the private repository. CI (`ci.yml`) stays on.

## D4. AI authorship is disclosed; the repository stays private for now (2026-10-05)

The owner asked for the whole co-op project to be stated as built with AI and
for the repository to stay private until they choose to publish (#57). The
notice is at the top of `README.md` and in `AGENTS.md`. Upstream's pre-push
check that rejected attribution trailers is removed in the fork.

## D5. A host-authoritative co-op layer beside the engine, not a rewrite (2026-10-05)

`game/coop/` wraps the existing engine instead of first splitting
`Gen2WorldState`: campaign, player and battle-session state are new, small
classes; the battle rules stay in `Gen2Battle`. This proved the hard parts
(ownership, turn authority, joins, exactly-once progress, persistence) before
the large world refactor. Cost: until #17 the real world screens do not run on
co-op state.

## D6. An allied roster by appending to the engine's own party (2026-10-05)

A joining player's Pokémon are appended to the battle's player party with
`Gen2Party.add_members` (up to `MAX_ALLIED_SIZE`, twelve), and
`PokeCoopRoster` maps every index to its owner and uid. `Gen2Party.create`
still refuses more than six, and no save ever holds more than six. Appending
keeps every index the engine has handed out (participants, evolvable list,
move-learn queue) valid. Rejected: a merged twelve-member save.

## D7. Turn control is derived, commands are stamped, suggestions are separate (2026-10-05)

The controller is computed from the active Pokémon's owner, so a switch hands
control over without any extra state. Every accepted decision advances a
per-session revision and commands must carry it; message sequence numbers per
player catch repeats. Suggestions are a separate message type stored outside
the engine and cleared on every revision.

## D8. Joins at the boundary, applied immediately when already there (2026-10-05)

A join requested while the battle waits for an action applies at once and
advances the revision; otherwise it queues until the next such moment. Cost: a
controller's command in flight at that instant is refused as stale and must be
re-sent. The alternative, deferring every join to after the next turn, would
make a join wait a whole turn for no rule the cartridge has.

## D9. Traded experience reads each Pokémon's owner (2026-10-05)

`Gen2Battle._is_traded` compared every Pokémon with one battle-wide
`player_id`, which would pay a partner's own Pokémon as traded (1.5x). The
engine now reads `owner_trainer_ids[mon]` and falls back to `player_id`, so
single-player behaviour is unchanged.

## D10. Exactly-once progress and single unique encounters (2026-10-05)

Progress is applied by `PokeCoopCampaign.commit` under a stable id
(`victory:<encounter id>`); a repeat returns false and changes nothing. An
encounter that is unique or carries victory flags is claimed by one battle at a
time and released on a loss or flight. Battles are removed from the host when
they finish, so results and prizes cannot be applied twice.

## D11. ENet raw packets with plain-data encoding (2026-10-05)

`ENetMultiplayerPeer` is used as a packet peer, without `SceneMultiplayer` or
RPCs, so the protocol does not depend on node paths and the same host runs over
an in-memory loopback in tests. Messages are `var_to_bytes` of plain data and
decoded without objects. LAN and direct IP need no relay or paid service.

## D12. One versioned campaign file, saved only between battles (2026-10-05)

`PokeCoopSave` writes JSON with a campaign section and a section per player,
through a temporary file and a rename. Saving is refused while any battle runs,
so no session state is ever persisted. Recovery between checkpoints is #39.

## D13. Comment ceiling raised for the co-op subsystem (2026-10-05)

Upstream's ceiling sat exactly at its own count (41016), leaving no room for a
new subsystem. It was raised for `game/coop` and the co-op tools, to 41115 as
of the real-screen slice. Co-op code keeps upstream's comment style: only facts
the code cannot say.

## D14. SET battle style in shared battles (2026-10-05)

The SHIFT "will you switch" offer is a question in the middle of an enemy
replacement with no natural owner yet. Shared sessions use SET style until #28
gives it one.

## D15. Encounters are registered on the host; the slice uses synthetic content (2026-10-05)

A client asks for an encounter by id and never describes the enemy. Until the
host runs the world simulation (#25), encounters are registered by the host
tool or test. The tests and `tools/coop_session.gd` use the synthetic cache
from `tests/unit/battle_fixture.gd`, so no cartridge is needed or transmitted.

## D16. Captures are refused in shared sessions for now (2026-10-05)

A ball needs an explicit recipient and box handling (#35). Until then the
session refuses ball items rather than guessing an owner.

## D17. German support is a later issue (2026-10-05)

German Red/Blue is #50, with `einstein95/pokered-de` (linked at the end of the
brief) as the reference disassembly. It is not a prerequisite for the first
slice.

## D18. Shutdown waits for clients to leave (2026-10-06)

An `ended` notice sent just before the host closed never reached the clients,
in local runs and in CI run 37380076818. The likely cause is the ENet client
dropping undelivered packets when the disconnect arrives in the same poll; this
was not confirmed in the engine source. The host now sends
`ended`, ignores further messages, and closes once every client has left or
after a two-second grace; a client closes its side on `ended`.

## D19. Remote players are world actors (2026-10-06)

Upstream's mod actor seam (`Gen2ModHost.register_world_actor`, documented in
`docs/MODS.md`) already draws extra sprites with the map's objects, sorted by
row, with SMOOTH SCROLL and emotes. `PokeCoopRemoteActor` uses it, so the world
screen needed no change. Its `advance_frame` also reports the local position.

## D20. Each window explores its own world until the host simulates one (2026-10-06)

`tools/coop_play.gd` opens the unchanged world screen on a save built from the
player's host record. The host trusts warps that world reports and checks only
step length; local wild encounters and trainer sight are off, and battles come
from the session menu. Cost: collision is not checked by the host, and the
window's own party, bag and money are a copy taken at launch, so its menus do
not follow co-op results until the window restarts (#17, #18, #22).

## D21. A refused client is told why before it is let go (2026-10-06)

The lost-notice problem behind D18 also hid hello refusals over ENet. The host
sends the refusal and drops the peer after the same grace; a client closes on
a refused hello and keeps the reason.

## D22. The co-op battle panel is an overlay, not the battle screen (2026-10-06)

The slice shows a shared battle as a text panel over the frozen world: roster
with owners, who decides, the partner's suggestion marked on the list. Driving
`Gen2BattleScreen` from session events is #26. The panel takes the eight
buttons through `PokeButton`, so keyboard, pad and touch all reach it.

## D23. Windows and host trade world-state patches, not copies (2026-10-06)

Every field of the world state, snapshot, save and runtime has an owner in
`PokeCoopOwnership`; engine flags are split so badges are the campaign's. A
window sends the patch between its last-sent and current state; it applies the
patch between the last host state it saw and the new one. A stale copy can
therefore never overwrite a newer change on either side, dictionaries merge
entry by entry, and a window opened late takes the campaign instead of
pushing its blank state. The host trusts the patches until it simulates the
world (#22). Party rows are matched to uids by hint and fingerprint (original
trainer, DVs, catch data), and nobody missing from a window's party is lost.

## D24. A window's own battles go to the host through the takeover seam (2026-10-06)

Upstream's battle-takeover seam hands a mod every wild and trainer battle the
world opens, keeping the trigger, script branches, party commit and whiteout.
`PokeCoopBattleTakeover` claims them and asks the host for a session with the
exact enemies the world prepared, so tall grass and scripted trainers produce
joinable co-op battles and encounters no longer need to be off. To avoid paying
or charging twice the world's prize is zeroed (the host pays its split) and the
host does not charge the initiator a blackout (their world whites them out).
A trainer fought this way is the encounter `trainer:<class>:<index>`: a second
window walking into it joins the running fight, and once beaten it answers as
beaten without a fight.

## D25. The Red demo host marks Oak's intro done (2026-10-06)

`tools/coop_session.gd -- host <port> red` hands out starters itself, so a
fresh campaign sets EVENT_FOLLOWED_OAK_INTO_LAB, its second flag,
OAK_ASKED_TO_CHOOSE_MON, GOT_STARTER and BATTLED_RIVAL_IN_OAKS_LAB (from the
pinned pokered). Starting a campaign from the real intro is #34.

## D26. Launcher co-op is one session class held by the runtime (2026-10-06)

`PokeCoopSession` owns a device's run: the client, the in-process host when the
device hosts (it listens on ENet and its own player dials 127.0.0.1 like
anyone else), and the world screen with actor, takeover, link and panel.
`Gen2GameRuntime.coop` holds it so it survives the change from the launcher to
the world. Identities are remembered per cartridge, address and port in
`user://coop_identity.json`; the hosting player has its own key, and a device
whose remembered player is already connected joins as somebody new, so two
windows on one machine are two players.

## D27. Each world settles its own player after a host battle (2026-10-06)

Evolution and whiteout are the world's own sequences (`EvolveAfterBattle`,
`Script_BattleWhiteout`), so a window runs them for its player after any host
battle its world did not open, through `Gen2WorldScreen.evolve_after_battle`
and `white_out`. The host no longer charges a blackout, so the cost is paid
exactly where the player is sent home. Captures are rolled on the host with
`Gen2WorldPartyHost.roll_capture` and filed once to the recipient the thrower
named.

## D28. A session ends through one path and saves on the way (2026-10-06)

`PokeCoopSession.leave()` is the only way out of a running session: the
session menu's LEAVE SESSION, the end notice and the window closing all reach
it. A hosting device shuts its host down gracefully (the campaign is written,
every client is told) and keeps polling it from the runtime until the clients
are gone; a joining device closes its link. Either way the world returns to the
launcher and the session never reports ready again. A joiner told the session
ended shows why over the world for three seconds first. A joiner whose link
drops dials again as the same player every two seconds and gives up after ten
tries as `host_unreachable`; ENet peers time out after two to six seconds so a
lost player is freed for that. The host also writes the campaign whenever its
last running battle ends, so a crash loses at most the battle in progress.
