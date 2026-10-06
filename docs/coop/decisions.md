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
so no session state is ever persisted; a host that closes first ends its
running battles as fled (D37). Recovery between checkpoints is #39.

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
tries as `host_unreachable` (the session's timers count milliseconds, since a
window draws far more than sixty frames a second); ENet peers time out after
two to six seconds so a
lost player is freed for that. The host also writes the campaign whenever its
last running battle ends, and at most every thirty seconds while anything has
changed and no battle runs, so a crash loses at most the battle in progress and
the last half minute.

## D29. A window's PC is the player's, copied whole against a revision (2026-10-06)

The host keeps each player's PC as `{uid, mon, box}` rows in Red and Blue's
twelve boxes of twenty and sends it to its owner's window only when it
changed. A window sends its party, and its PC when that changed, with the
`holdings_rev` it last took; the host refuses a copy from before its own latest
change (a capture, battle results) and the window then takes the host's copy.
A copy that is current is believed whole, so a Pokémon missing from it was
released or traded away. Rows are matched to uids by fingerprint, preferring
an unchanged row and then the window's hint, so two Pokémon sharing a
fingerprint keep their own uids. A window's world explores on a save with slot
0 under a scratch save root (`user://coop_window/<player>`), restored on leave:
the game's own checks pass, so Bill's PC and other services that validate the
save work, and nothing a window writes can touch a player's single-player
slots.

## D30. Story gifts reach every player (2026-10-06)

Story flags are the campaign's, so a gift event runs once, in whichever window
met it, and only that player was given the item. A partner without HM01 could
not Cut their way to Lt. Surge. `PokeCoopPolicy.share_gifts` hands every
other player the same item when a player gains one of Red and Blue's unique,
kept items (key items, rods, HM01 to HM05) or when the campaign first takes an
`EVENT_GOT_TMxx` flag. Each gift is a campaign commit (`gift:<item>`), so it
is given once, and a late joiner is handed every gift committed before. A full
bag sends the gift to the PC's items. Consumed exchange items (Oak's Parcel,
the Gold Teeth, the Bike Voucher) and fossils stay with whoever got them: the
first would be stuck in a partner's bag and the second would duplicate a
Pokémon.

## D31. Players trade through the cartridge's own Cable Club, swapped on the host (2026-10-06)

Gen 1 trade evolutions need a trade, and the cartridge's Cable Club already
runs every screen of one through `Gen2LinkTransport`, which upstream left open
for a network peer. `PokeCoopLinkTransport` is that peer: the partner the host
names (the other side of an offer, else the first other free player), with
their party as the host holds it. Two small upstream hooks let the Gen 1 trade
screen wait on `PENDING` and hear the partner's TRADE or CANCEL; the save-slot
peer answers at once as before. Once both said TRADE, `PokeCoopTrades` swaps
the two Pokémon on the host in one step, keeping their uids and applying any
trade evolution with the same helpers the screen uses, and the campaign is
saved. Each window's screen commits its own copy for the movie and the
evolution while its party sync is held, then takes the host's swap, so a
window that disagrees cannot copy or lose a Pokémon. Remote players are hidden
in the Cable Club rooms, where the game's own friend sprite is the partner. A
partner who never offers within 30 seconds, or never answers within 60, lets
the screen go back to its lists, from where CANCEL leaves.

## D32. A shared battle is drawn on the cartridge's battle field (2026-10-06)

The battle screen drives a local `Gen2Battle`, and a battle fought on the host
has none, so driving it from session events (#26) means replaying the host's
turns through it. Until then `PokeCoopBattleField` draws the host's battle view
with the screen's own `Gen2BattleRenderer` (both pictures, status panels and HP
bars) and plays each turn's events as Red and Blue's lines in the game's text
box, naming whoever was out when each happened, and after each "used" line the
cartridge's own animation for that move over both pictures, and each HP bar
drains in the turn's own order, a pixel a frame from where the turn found it.
A choice waits until the field has played the last turn out, as the
cartridge's menus do, so the battle never runs ahead of what is on screen. The
co-op panel beside it keeps the commands, the suggestions and the turn owner.
Each animation's own move sounds go through the world's audio player, a cry
move with the attacker's cry, and the battle's music plays while it is up, a
trainer's chosen by the class and index its encounter names, until the map's
own music comes back as it closes. A battle seen from its start opens with
"Wild X appeared!" and "Go! Y!" and their cries, a send-out later in the battle
has its cry, and a win plays the wild or trainer fanfare. The co-op events have
lines of their own: a join, an item used, and a throw with the cartridge's
catch or near-miss line. The field follows the battle's own `ANIMATION`
events as the battle screen does: a move ends with `PlayHitSound` by its
effectiveness and the blink or shake `AnimationTypePointerTable` names for it, a
burn's or poison's own shake plays, and the scroll and palette effects an
animation sets reach the renderer per scanline. With the battle scene off in
the options, moves skip their animation but keep the hit and the shake. Still
missing against the battle screen: the gym leaders' own fanfare, the thrown
ball and send-out animations, and the sliding intro.

## D33. A participant stands in for a controller who stays away (2026-10-06)

A battle whose controller dropped pauses, as the brief asks, but a device that
never comes back left its partner stuck in the battle for good. After
`PokeCoopPolicy.STAND_IN_MSEC` (30 seconds) the first present participant
decides for the absent player's active Pokémon; ownership, rewards and results
stay the owner's, the view names both (`controller`, `owner`), and the owner
takes control back on reconnecting. The host announces the change itself,
since no message arrives while everyone waits.

## D34. A new player may bring a trainer from a single-player save (2026-10-06)

The Co-op tab lists the cartridge's own valid save slots beside the starter
choice. A new player who brings one sends it with their hello; the host checks
its Pokémon and PC with the game's own validator (the world is left out, since
the campaign places the player) and takes their team, PC with its boxes, bag,
money, place and own world keys. The first player of a new campaign brings
their story too: its flags, badges and shared world keys become the
campaign's, so a player can carry an existing Red run into co-op. A returning
player is never replaced by a brought save, and nothing is written back to the
single-player slot.

## D35. The host reads every client field as untrusted (2026-10-06)

A seeded fuzz test (`test_malformed_messages_are_refused_without_breaking_the_host`)
sends every message type with wrong field types, commands at the battle's own
revision, hellos over fresh links, and world patches and party rows in shapes
no window sends; GUT fails on any script error. What it found is fixed at the
boundary: text and numbers are read with `PokeCoopTransport.text` and
`number`, a world patch keeps only entries in their key's own shape and type
(`PokeCoopOwnership.well_formed`, and only plain numbered entries for the
campaign's tables, which reach every window), a sent Pokémon is decoded only
when every field has a save's type (`PokeCoopPlayer.mon_from`), a brought save
is rebuilt from such parts, and a team is never replaced by an empty one. A
packet may be up to 2 MiB, since a full PC is about a quarter of a megabyte;
the old 64 KiB cap dropped the PC message of anyone with more than about sixty
stored Pokémon.

## D36. Red and Blue's one-off wild Pokémon are campaign encounters (2026-10-06)

A legendary bird, MEWTWO or a SNORLAX is a scripted wild battle that looks like
a grass encounter in the world's request, so two windows could each fight and
catch the same ARTICUNO. None of those species is ever met in the grass in Red
and Blue, so `PokeCoopPolicy.UNIQUE_WILD` names them and the host makes a
window's battle against one the encounter `static:<species>:<map>`: a second
window joins the running fight, and once it is beaten or caught it is done for
the campaign; losing or running leaves it, as on the cartridge. A caught unique
encounter now counts as done as a beaten one does; before, a catch released it.
Gift Pokémon (EEVEE, LAPRAS, the fossils, the Hitmons) stay with whoever is
given them first. The world only takes won, lost or ran back from a battle it
handed over, so a catch is reported to it as a win: on the cartridge a caught
static Pokémon is gone as a beaten one is, and its event flag reaches the
partner's world with the rest of the story.

## D37. Fixes from a review of the co-op code (2026-10-06)

A read-only review of `game/coop` found twelve defects, each confirmed against
the code and covered by a test:

- A join still queued when its battle ended (a faint, then everyone gone) left
  the joiner marked in battle for good; the end now releases queued joiners
  too.
- A participant away when their battle ended never heard how; final views now
  wait per player and go out when they are back.
- A window sent world patches and party copies while its link was down and
  counted them sent, so a deposit made then could later be lost or copied; the
  link and the remote actor now hold until the host has the player back, and
  the first position after a reconnect counts as a warp.
- A move offered on the last knockout ended the battle unasked; the battle now
  waits on it, and the panel lists the learner's own moves and the new one.
- A battle everyone left kept every save refused until the host closed; after
  the stand-in time it ends as fled, as do battles still running at shutdown,
  so items used and damage taken stay consistent with the saved campaign.
- A trainer brought from a save got a new trainer id, which made their own
  Pokémon count as traded; the save's id is kept.
- The redial budget was per session rather than per drop; it now resets each
  time the host welcomes the player back.
- An unreadable or newer campaign file was silently replaced by a new
  campaign; hosting now refuses and leaves it as it is.
- Every battle a window handed over looked like a world SAVE to the link; a
  SAVE is now a snapshot of the live world, whose frame count moved, which the
  copy of the last snapshot a battle puts back never is. (A window's world
  writes no file of its own, so the file cannot be the signal.)
- A ball thrown for a player with no room anywhere lost the catch; it is
  refused and kept, as the cartridge refuses it.
