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
running battles as fled (D37). Story changes between checkpoints are journaled (D66).

## D13. Comment ceiling raised for the co-op subsystem (2026-10-05)

Upstream's ceiling sat exactly at its own count (41016), leaving no room for a
new subsystem. It was raised for `game/coop` and the co-op tools, to 41115 as
of the real-screen slice, to 41342 with the battle stage (D39), and to
41343 with upstream's own +1 in 0.1.75 (D97), to 41347 with wild Pokémon from both versions (D104), and to 41583 with upstream's own +229 in 0.1.76 to 0.1.78 (D110). Co-op code keeps upstream's comment style: only facts
the code cannot say.

## D14. SET battle style in shared battles (2026-10-05)

The SHIFT "will you switch" offer is a question in the middle of an enemy
replacement with no natural owner yet. Shared sessions use SET style until #28
gives it one. Superseded by D113.

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
A choice waits until the field has played the last turn out, its last line's
hold included, as the cartridge's menus do, so the battle never runs ahead of
what is on screen and a finished battle is not closed mid-line; a view the
field has not read yet counts as playing too, since the panel can see a press
before the field sees the view it answers. The
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
the options, moves skip their animation but keep the hit and the shake. A thrown
ball plays `TossBallAnimation`'s scripts from the throw event: the toss for the
ball, the poof, the Pokémon hidden in a ball that shakes once a wobble, and the
poof and the Pokémon back on a break-out, its tilemap handed from script to
script so a caught Pokémon stays inside while "All right!" plays with the
caught jingle. Faints, recalls and send-outs are D39; still missing is the
sliding intro.

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

## D38. A world held under the panel keeps its audio player running (2026-10-06)

The session holds the world screen (`PROCESS_MODE_DISABLED`) while the panel is
open, so the player stands still during a battle. The world's audio player is
a child of that screen, so it stopped too, and every co-op battle was silent
from its first frame: the field's music, cries and sounds were requested but
never mixed. Earlier checks counted the requests in log lines, and the
recordings' overworld audio hid the gap. The audio player is now set to
`PROCESS_MODE_ALWAYS` while the world is held and back to inheriting when it is
let go, so a paused game still pauses it. Sound in a battle is now checked by
measuring a recording's level, not by the calls.

## D39. The co-op field keeps the battle's own tilemap (2026-10-06)

The field passed the renderer no tilemap between animations, and seeded each
animation with the default one, so Red and Blue's player picture was read out
of Crystal's layout: every co-op battle showed the player's Pokémon scrambled.
`PokeCoopBattleStage` now keeps a Generation 1 tilemap the way the battle
screen keeps `_bg_map`: each animation starts from it and leaves its result in
it, and the battle's own events step it as the cartridge's routines do: a
`FAINTED` sinks the picture (`MonFaintedAnimation`) ahead of its line and takes
the panel with it, the send-out `ANIMATION` grows the next one out of the ball
(`AnimateSendingOutMon`, behind the poof on the player's side), and the recall
`ANIMATION` shrinks the player's (`AnimateRetreatingPlayerMon`). Each side's
panel shows the Pokémon that was out when the turn began until a `SENT_OUT`
names who came in, so a trainer's next Pokémon is not on the panel before its
predecessor has fainted. A battle seen from its start opens with "BROCK wants
to fight!" and "BROCK sent out GEODUDE!" for a trainer, and the battle view
carries the trainer's class and index, so a trainer fought from the session
menu also gets its own battle music. A faint plays `RemoveFaintedPlayerMon`'s
cry or a trainer's Pokémon's fall and thud, and a cry or sound is waited out as
`PlayCry` does before the next line. The trainer's closing is D41.

## D40. The campaign file keeps the checkpoint before it (2026-10-06)

The host already wrote the campaign to a temporary file and renamed it over
the old one, but it never asked whether the write itself succeeded: a full disk
would have replaced the campaign with a cut-off file. A failed write now leaves
the old file alone and reports the error. Before each rename, the file being
replaced is copied beside it as `<campaign>.bak`, but only if it still reads as
a campaign, so a damaged file never displaces the last good checkpoint. A
campaign that cannot be read is still left as it is (D37); the launcher now
names the backup. A damaged file is read without an engine error. The journal
and format migration followed in D66.

## D41. A trainer win closes as the cartridge's does (2026-10-06)

A won trainer battle ended on the fanfare. The world's takeover summary now
carries the request's trainer name, its win text and `lone_attack`, the window
decodes the win text and sends all three, and the host keeps them on the
encounter, bounded (`MAX_TRAINER_NAME`, `MAX_WIN_TEXT`), for every participant's
view. The host's final view also names each participant's share of the prize.
The field then plays `TrainerBattleVictory`'s order: the gym leader's or the
trainer's fanfare, "<PLAYER> defeated <TRAINER>!", the trainer's own line and
"<PLAYER> got ¥X for winning!", each window with its own player's name and
share; a wild win with Pay Day money says it was picked up. A trainer's name is
the request's, so a rival is called what the player named them. Session-menu
encounters carry `gym` themselves and no win text. The trainer slides back in
for the line (D42).

## D42. Co-op battles open with the sliding intro (2026-10-06)

A battle seen from its start now opens as `DoBattle` does: `Gen2BattleIntro`
slides the trainer or the wild Pokémon in from one side and the player's back
picture from the other; a trainer says "wants to fight!", slides out and sends
the first Pokémon out of the ball; a wild one cries, is named and gets its
panel; then, after `DoBattle`'s 40 frames, the player's back picture slides out
before "Go!". After a trainer win the trainer slides back in
(`TrainerBattleVictory`) between the defeat line and their own. The stage keeps
which trainer or back picture stands on a square, the renderer draws it, and a
joiner who arrives mid-battle sees no intro.

Driving the intro with Red's data showed that upstream's `Gen2BattleIntro`
put the back picture's head into OAM the Crystal and Gold way (six columns from
a six-row picture), which scrambles Red and Blue's seven-row picture in the
single-player battle screen too. `LoadPlayerBackPic` uses seven columns of
three from $A0, $38; `Gen2BattleIntro` now does so for Generation 1 (L8).

## D43. The field borrows the battle screen's words (2026-10-06)

The field worded a dozen events itself, so stat changes, status effects,
"But, it failed!", poison damage, multi-hit counts and the rest of a turn went
unsaid. The single-player screen's sentences live in its `GEN1_LINES` table
and handler methods that read only the game data and who is out, so the field
keeps one `Gen2BattleScreen` out of the tree and asks its `_describe` for every
event outside `WORDED`, telling it which species were out when the event
happened. The co-op events, the trainer's own lines, the learn offer's split and
the forgotten move stay the field's. `_describe` is upstream's private method;
a change to it shows up in the co-op tests.

## D44. Fixes from a review of the battle field work (2026-10-06)

A read-only review of everything since D38 found no state that stays stuck and
confirmed the Generation 1 intro sprites against `LoadPlayerBackPic`; it found
these, each now fixed:

- The campaign write trusted `FileAccess.get_error()`, which reports reads, so
  a write cut short by a full disk could still be renamed over the campaign;
  the write now checks `store_string` and reads the staging file back before
  anything is renamed (D40).
- Pressing Host with no cartridge imported raised a script error naming the
  backup file; hosting also no longer opens a socket it cannot use.
- A trainer's switch was neither worded nor drawn: the enemy's withdraw line is
  the screen's own now, and a send-out empties its square first, as the
  screen's `_clear_entering_square` does.
- A finished battle's last line stayed in the box through the next battle's
  intro; a battle not seen before clears the box and anything still queued.
- The player's send-out ignored `SendOutMon`'s other lines ("Do it!", "Get'm!",
  "The enemy's weak!"), a level-up lost its jingle, and the screen's lines
  named a trainer "Enemy"; the field now uses the event's line, leaves the
  level-up to the screen and gives it the trainer's name.
- Beating the Champion played the trainer fanfare; `RIVAL3_CLASS` gets the gym
  leader's, as `_gen1_victory_music` gives it.
- A final view that only adds an outcome to a turn already shown (an abandoned
  battle) replayed that turn; it now plays only its own closing.
- Two views of one battle read in the same poll kept only the second's events;
  the client now keeps both turns' events.

## D45. The co-op panel speaks to players (2026-10-06)

The panel beside the battle field read like a debug list: battle ids, revision
numbers, one flat roster with `[OWNER]` tags, host refusal codes. It now names
the opponent ("Wild PIDGEY L3", "BROCK's ONIX L14"), lists each player's
Pokémon under their name in the colour their world draws them in, says whose
turn it is in words, groups the choices under FIGHT, POKéMON and BAG, marks the
partner's suggestion with "◀ NAME", and turns a refusal into a sentence that
fades after a few seconds. Every row is a link: a tap or a click puts the cursor
on it (which is a suggestion when it is not your turn) and a second one chooses
it, so touch play does not depend on the on-screen d-pad. The session menu says
who else is playing and what a running battle is against. Rows keep their
command text for scripts and tests; what is shown is a separate label; the
session menu also says where each partner is, by the town map's name for the
area ("With RED (ROUTE 1)"). Over the
world, a line on a dark backdrop says when a partner joins or leaves the session
and when they start a battle this player is free to join ("RED is in a battle
against wild RATTATA. SELECT to join."), so a battle on another map is not
missed.

## D46. Reconnecting outlives a phone's pause (2026-10-06)

A dropped link was redialled ten times, two seconds apart, before the window
gave up and went back to the launcher, so a hosting phone sent to the
background for twenty seconds ended its partner's session, and a joining phone
coming back from a pause sat on a link that looked open until ENet timed it
out. The window now redials for about two minutes with "Lost the host:
reconnecting..." over the world and says "Back in the session." when the host
takes it back. `Gen2GameRuntime` forwards `NOTIFICATION_APPLICATION_RESUMED`
to the session, and a joining device that was paused for more than three
seconds closes its link and dials straight away. A battle the world starts
while the link is down is fought in the world itself, as before (D24).

## D47. A shared battle fills every participant's Pokédex (2026-10-06)

The single-player battle screen marks an enemy seen as it appears
(`_register_enemy_sight`, for the opener and each send-out), but a co-op
battle is fought on the host without that screen, so battles added nothing to
"seen" for anybody; only a catch reached the recipient's Pokédex. Each battle
session now keeps the species that appeared, and the host marks them seen for
every participant when the battle ends, through the same player-owned world
patch a catch uses, so each window's Pokédex picks it up. A player who joined
late is credited with the whole battle; the cartridge's own rule would only
count what they saw.

## D48. Saving says that it saved (2026-10-06)

A save from the SELECT menu succeeded silently and only a refusal was shown,
and nothing said that the game's own START > SAVE does the same or that the
host saves by itself. The host's state now carries when the campaign was last
written and how many saves players asked for, and by whom. A new save, from
either menu, shows "Campaign saved." to the player who asked and "<NAME> saved
the campaign." to the others; the session menu reads "Saved 8 seconds ago. It
also saves itself after battles and every thirty seconds of changes." and its
row says "Save the campaign (same as START > SAVE)". A returning player is
also recognised by name when their device lost the id it remembered for the
host (D44's review noted the id was keyed by address).

## D49. A device keeps several campaigns (2026-10-06)

The host kept one campaign file per cartridge, so a playthrough with a second
group overwrote the first. Each campaign is now its own file under
`user://coop_campaigns/<game>/`, named by an id made when it is started
(`<game>-<unix>-<tag>`), and carries a title the host types. The Co-op tab
lists them, latest saved first, with players, badges and when each was saved,
and starts a new one on request. The single file of earlier builds moves into
the folder as the default campaign and is listed as FIRST CAMPAIGN.

A device remembered one player id per host address, so a device that was p2
in one campaign would have taken p2's trainer in another campaign on the same
host. The identity file now maps each host to a player per campaign id: the
hello carries that map, the host looks up its own campaign in it, and the
welcome names the campaign so the device can remember it. Old entries are
ignored and their players are found by name (D48). Deleting or backing up a
campaign is left to the file manager.

## D50. A new player can play the opening (2026-10-06)

A new player used to start after Oak's intro with a starter picked on the
Co-op tab. The tab now offers the opening, played by default: the window shows
the cartridge's copyright screen and Oak's speech (the player's name comes from
the tab, so only the rival is named, and only by whoever reaches him first),
then the player's bedroom. The host keeps that player's story apart from the
campaign's until the opening is over: the campaign half of each world patch
goes to the player's own copy, the state sent to that window carries it in
place of the campaign's, and a battle the window opens is neither a campaign
encounter nor joinable. Nobody else is drawn, and the player is drawn to
nobody, for the whole opening: each player has their own Oak, rival and POKé
BALLs, so a partner walking through that scene looks wrong (the owner first had
them meet outside the house, then asked for the lab). With a starter and Oak's
lab left behind, the copy is dropped, the window takes the campaign's story, and
the rival's starter becomes the campaign's if nobody set it before. The
starter ends the opening rather than the rival fight because the lab's
challenge can be walked past (L10). A campaign's own story still begins after
the intro, so players who skip it and players who play it share one campaign.

## D51. A window keeps its own unconfirmed world changes (2026-10-06)

A window sent its world changes as patches and applied the host's back as
patches against the host state it last saw. A state the host sent before it
had a window's newer change carried the older value, so the window rewound
its own change until the next state arrived; a map script that moves on two
frames in a row ran an earlier step again. The window now keeps each patch it
sent until the host's state reports that sequence number as applied, and
leaves the entries of unconfirmed patches out of what it applies.

## D52. Story items reach every player (2026-10-07)

Only the key items and HMs on a fixed list and gift TMs were shared, so an item
ball one player picked up (gone for everyone, since taken objects are the
campaign's) or a present like OAK's five POKé BALLs reached only them. The owner
asked to give every item to every player for now. An item a player gains in the
same world patch that moves the shared story (a flag set, an object taken) now
reaches every other player in the same number, and a key item that patch takes
away (OAK's PARCEL delivered, the BIKE VOUCHER exchanged) is taken from
everyone, except the three fossils, which each player revives on their own.
Purchases, trades, use and hidden items move no shared story and stay personal;
hidden items are each player's own flags already. A late joiner still receives
only the shared list and gift TMs.

## D53. A partner blocks the way (2026-10-07)

Remote players were drawn but not solid, so two players could stand on one
cell and hide each other. They are now solid actors, as people on the map are:
the player's own steps and NPCs' wandering stop at them, while scripted and
forced movement goes through as before.

## D54. A Generation 1 script walking someone holds the player (2026-10-07)

The cartridge's map scripts set `wJoyIgnore` around `MoveSprite`, and upstream
does not model that byte, so the player could walk while the rival went to his
POKé BALL and leave Oak's lab before his challenge (L10, also in single
player). The world screen now refuses the player's own steps while any object
walks a scripted stream on Generation 1, which is the narrow part of
`wJoyIgnore` this needs; modelling the byte everywhere would also need every
engine path that clears it.

## D55. Three or more players in battles and trades (2026-10-07)

The panel showed only the first partner's suggestion. It now marks every
partner's suggestion, each named in that partner's colour, several on one row
in join order; two players see the same single mark as before. The Cable Club
named the first free player by id as the trade partner, so a third player was
pointed at someone already trading. The partner is now an offer either side
made; else the player's mate in the Trade Center or Colosseum, paired in id
order and kept while both stay; else, from outside, someone waiting alone in a
room; else the first other free player with no mate and no offer. A third
player in a room of two gets no cable. A team the twelve-place allied roster has
no room for now joins with its first fit Pokémon in party order instead of being
refused, and the rest sit the battle out untouched; with no room left the join
is refused (`roster_full`). If the alliance loses, everyone in the battle whites
out, a trimmed joiner included.

## D56. A SAVE the host would refuse fails in the game's own box (2026-10-07)

A window's START > SAVE wrote its save and printed the cartridge's "<NAME> saved
the game!" before asking the host for a checkpoint, so a refusal during a battle
was only a notice over a line saying the opposite (L2). The host's state now
carries why a checkpoint would be refused (`saved.blocked`, the rule
`save_checkpoint` uses), and the world screen asks a `save_gate` before the START
menu's SAVE writes. A window's gate answers with that reason, so the prompt takes
its own FAILED step ("Save failed: battle in progress") and ends as a NO: nothing
is written and no checkpoint is asked for. Only START > SAVE is gated; a
service's save (box change, Cable Club, Hall of Fame) still writes the window's
scratch save, so a partner's battle holds none of them up, and the host saves
the campaign after the battle anyway. A battle that starts between the host's
last state and the request is still refused by the host and told by the notice.

## D57. A Generation 1 press faces its direction (2026-10-07)

`.handleDirectionButtonPress` stores the pressed direction in
`wPlayerDirection` before it decides whether to turn, so on the cartridge a
press that bumps or does not turn still faces the pressed way. The world kept
the old facing, and its turn rule only turns on a fresh press from a standstill,
so a press made on the frame the player stopped never turned them (L11). After
the Viridian Mart gives OAK'S PARCEL, the script leaves the player on the exit
mat facing the counter, and pressing DOWN neither turned nor left the shop. The
world now faces a pressed direction whenever no forced movement owns the step.

## D58. A campaign begins where a played opening leaves the story (2026-10-07)

A new campaign marked the intro done with five flags and nothing else, so for a
player who skipped the opening Oak's lab was still in its state before the intro:
no Oak, the rival by the table and all three POKé BALLs, and OAK's PARCEL could
not be delivered (L17). The state a real opening leaves was captured from a
played one on Red: the five flags and EVENT_OAK_APPEARED_IN_PALLET, the lab's
script at step 18, Pallet Town's at 5 and the house's at 1, and four objects
toggled (the town map, the lab's rival and two starter balls). A new campaign
starts with it, and a campaign from an earlier build that began after the intro
is given whatever of it is missing when it is hosted, without moving on any
script step it already has. The rival's own starter is still set by the first
player to finish an opening (D50).

## D59. Every device logs its session and shares it (2026-10-07)

The owner asked for host and client logs complete enough to retrace a session,
and a debug stream so each player's file holds every player's lines. Each device
writes one JSON-lines file per session to `user://coop_logs`, keeping the last 30
files and at most 256 MB. Every line carries unix ms, frame, a random device id
and the player's name, a per-device number, a source, a player id where there is
one, a kind and plain JSON data. The host logs its start (the campaign and
players as a save holds them, encounters, the generator's seed and state), every
message it takes in full with its result, battles with their seeds and each
revision's view, commits, saves and its end state; with these,
`tools/coop_log.gd replay` re-runs a fresh host and checks it ends the same.
Clients log everything they send, a digest of every state change apart from
other players' steps (the whole state after a welcome and every 30 s), battle
views, refusals and the end. The window logs maps, pulled patches and the echoes
it dropped, takeovers, whiteouts, evolutions, notices and the opening. Engine
errors during a session are copied in. Sharing is on by default (Co-op tab,
`user://coop_settings.json`): a sharing client sends its own lines to the host
every 2 s in batches of at most 64 KB, the overflow counted in a
`stream_dropped` line and a line over 8 KB sent without its data; the host takes
only never-relayed lines of the sender's own device and passes them to every
other sharing device, its own included, with a 256 KB backlog for late joiners.
Receivers mark lines `relay` and never send them on. Protocol 3. This is a
second record beside upstream's engine log, kept because a co-op bug needs both
devices' timelines side by side.

## D60. A closing window says goodbye before the app quits (2026-10-07)

Closing a hosting window closed the session at once with no grace, so the
joiner never heard "ended", kept redialling for two minutes, and missed the
host's last log lines (L19). While a session runs the window no longer quits on
its own: the close request starts the same shutdown as leaving (the host sends
`ended` and its last lines, a joiner its last log batch), and the app quits once
that is out, at most 2.5 s later on a host and 0.6 s on a joiner. Quitting is
the app's own again as soon as the session is closed.

## D61. The owner settles the open co-op rules (2026-10-07)

The owner answered every open policy and scope question. Guiding rule: a shared
battle should feel as close to a solo run as it can.

- **Leaving and dropping are one rule** (#31, #30). LEAVE BATTLE and a lost link
  both make a participant absent: they go back to their world (return point),
  their Pokémon stay in the roster, results and experience stay theirs, and they
  may rejoin. A battle ends for everyone only when nobody is left in it.
- **A battle everyone has left waits as long as a window redials** (about two
  minutes), not 30 s, so a phone's pause does not lose a gym fight.
- **A stand-in is asked, not imposed.** After 30 s without the controller the
  other participants are offered WAIT or TAKE OVER.
- **Prize money** (#36): every participant receives the full prize, Pay Day
  included. Blackout stays as on the cartridge: each loser pays half their own
  money.
- **Gift Pokémon** (#33): one per player. EEVEE, LAPRAS and the Dojo's choice
  are each player's own, as the fossils already are.
- **Exp. All** (#37): one carried by any participant counts for every team, and
  each team gets the solo split over its own party: the fighters' block halved,
  the other half shared over that player's own team, never over the joint
  roster.
- **Late joiners** (#34): unchanged, a level 5 starter and 3000 money in
  Pallet Town, or a played opening, or a brought save.
- **World simulation** (#22, #24, #25): the host locks a scripted NPC or gift
  while one window uses it; windows stay trusted and the host-side world stays
  parked.
- **Scope**: Red and Blue only. The Generation 2 parts of #27 and #28 move to
  the later milestone.
- **Repository**: #58, #79 and #80 stay drafts until the hand-played session;
  upstream (0.1.74) is merged after they land (#14); the upstream bugs stay
  fork-only issues for now; the repository stays private with no publishing
  plan (#57).
- **Next after these rules**: the scripted playthrough to BROCK (#48), the
  Android build (#45), then German Red/Blue (#50). The owner has a Windows PC, a
  second Linux machine, an Android phone and a Mac with an Apple account for
  device checks.

## D62. How the settled rules are built (2026-10-07)

- **Leaving** is a second kind of absence: `PokeCoopBattleSession` keeps who
  left beside who dropped. A participant who left is absent until they rejoin,
  whatever their link does; one who dropped is absent until they reconnect.
  While the owner deciding has left, the first present participant decides at
  once; while they have dropped, the battle waits until a present participant
  sends `stand_in` once `stand_in_due` (30 s). Only a participant whose own
  world did not open the fight may leave: the initiator's world, and a second
  window that walked into the same trainer, wait on the battle's outcome, so
  leaving would show them a frozen map. Protocol 4 adds `leave_battle` and
  `stand_in`.
- **Pokémon in a battle fight nothing else.** A player who left keeps the
  battle's id on the host: they may walk, but start and join nothing, and a
  fight their world opens waits in the takeover until that battle ends, the
  panel showing the old battle with REJOIN. Their window gets no panel when
  the battle they left ends, only a line saying how it went; their evolutions
  and a whiteout still follow.
- **Exp. All per team** needed one upstream change: `Gen2Battle.exp_all_groups`,
  the party indices each EXP.ALL pass splits over (the whole party when
  empty). A session sets one group per owner and turns EXP.ALL on when any
  participant's bag holds one. The participants' pass is unchanged, so two
  Pokémon that fought share as two of one player's would.
- **Gift Pokémon per player**: event flags and toggled objects are owned entry
  by entry, as engine flags already were. `PokeCoopPolicy.OWN_GIFTS` names
  EVENT_GOT_HITMONLEE, EVENT_GOT_HITMONCHAN, EVENT_BOUGHT_MAGIKARP and the
  EEVEE and two Dojo balls (pokered's numbers, checked against the flags the
  policy already used); EVENT_DEFEATED_FIGHTING_DOJO stays the campaign's.
  LAPRAS's `BIT_GOT_LAPRAS` is in `wStatusFlags4`, an engine-flag run, so it was
  already each player's.
- **The gift race (#24) is settled on the host, not with a lock.** A lock would
  need every NPC script in a window to wait for a host round trip inside
  upstream's world code. Instead, a window's change that sets story flags or
  objects the campaign already has (it lost the race) has its item gains taken
  back, the first window's share standing in; a change that also spent money is
  left alone, since a purchase may be in it. Gift Pokémon no longer race at all.
  Cost: the second window may show the doubled item for a frame before the
  host's count arrives, and a race that also moves new story is not caught.

## D63. Gen 1 script bytes are owned byte by byte (2026-10-07)

`gen1_bytes` holds the Generation 1 script bytes the world keeps by name, and
the host dropped them all because campaign tables took only numbered entries
(#82). It is now owned entry by entry, like the engine and event flags:
Vermilion Gym's three trash-can lock bytes are the campaign's, since the puzzle
is in one shared gym whose lock event flags are already the campaign's and both
windows must hide the switches in the same cans. Every other byte is its
player's: the lucky slot machine, the SURF high score, and
`cur_map_text_ptr_high`, scratch nobody reads, kept with its player because one
key has no window-only half. A name not listed goes to the player, so a byte
added later never reaches a partner before it is classified. Cost: the first
lock re-rolls whenever any player's window loads Vermilion City, as it does on
the cartridge for one player, so a partner arriving can move the first switch
while someone is still searching for it.

## D64. The trade movie shows the Pokémon as it was sent (2026-10-07)

A Cable Club trade of a MACHOKE showed MACHAMP in the trade movie before the
evolution played (#66). The cause was upstream's
`Gen2WorldPartyHost.commit_link_trade`, which built the movie's context after
applying the trade evolution; the co-op cable hands the window the partner's
row from before the swap, so no co-op code was involved. The context is now
built before the evolution, as the cartridge's `.doTrade` (the movie on
`wTradedEnemyMonSpecies`, then `TryEvolvingMon`) and upstream's own NPC trade
do. Single-player link trades had the same bug, so this is a candidate to offer
upstream.

## D65. Two-window checks run from scenarios, and a window can play itself (2026-10-07)

The owner asked for a two-window check of every feature and a list of hand-test
cases (`test-cases.md`). `tools/coop_screens.sh` runs the cartridge host and two
windows from a scenario file, at 60 frames a second (the display is faster, and
key timing counts frames), with a private `XDG_DATA_HOME`: the windows find the
imported cartridge through a link to its cache, and the owner's campaigns,
identity and logs are never touched, so runs can go side by side. Captures go
outside the repository. `tools/coop_autoplay.gd` is a window that plays
itself: it reuses the legs of upstream's `tools/checks/played.gd` (path
finding, warps, talking, the save editor's grind) on its world, plays the
opening, and fights from the co-op panel, so the run to BROCK (#48) needs no
hand-written key list. The upstream check is loaded at run time, since a
preload compiles it before the autoloads exist.

## D66. A journal keeps story changes between checkpoints; format 2 settles the intro once (2026-10-07)

The campaign file is written only between battles (D12, D28), so a crash lost
every story change since the last checkpoint, and with one player fighting
while the other explores that could be minutes (#39). The host now appends a
line to `<campaign>.json.journal` at the end of every poll in which the
campaign's revision moved past the last checkpoint or line, and every
successful checkpoint removes the journal. Reading a campaign takes the
checkpoint, then the newest whole journal line of the same campaign whose
revision is above the checkpoint's: a torn last line is skipped, each line
opens with its newline so the next one still reads, and lines a crash left
behind a newer checkpoint are older by revision and change nothing. A line is
the state, not the change: the campaign and every player, each PC left out
while its `box_rev` is the one the last checkpoint wrote. Replaying campaign
changes alone was rejected: the patch that sets a story flag hands over its
item (OAK'S PARCEL, an HM, a gym TM to the partner) and a battle's commit
brings its prize or catch, so a flag recovered without its item would strand
the story. A late-game line measured 37 KB and 1.5 ms on a desktop, against
169 KB and 12 ms for a checkpoint.

The format had been version 1 from the start. `PokeCoopHost.create` settled
every hosted campaign with the intro's world (D58), and since a script step
back at 0 and an object shown again are erased from their tables, each hosting
put them back. Format 2 marks a settled campaign: `PokeCoopSave.from_dict`
settles a format 1 file once, and later steps follow as `if version < N`. An
older build refuses a format 2 file and leaves it untouched. Limits: no fsync
(a process crash is covered, a power loss may not be); a journal without a
checkpoint is not read; restoring `.bak` by hand should remove the journal.

## D67. A window sends what a script changed in one patch (2026-10-07)

The autoplayed run to MISTY (D65) found the DOME FOSSIL reaching only the
player who took it, though story items reach every player (D52). The fossil's
script gives the item, waits on "got DOME FOSSIL!", and only then sets the
flag, so the window's item and flag went out in two patches, and the host
shares only what a patch that moves the story brings. Any gift with a text box
between the item and the flag had the same gap. While the window's world runs
a script (`script_busy`) its link now neither sends nor takes world patches,
and sends everything the script changed in one patch when it ends; the
partner's story changes wait until then too, so a running script is never
changed under it. A script still running after 15 s (a long cutscene, a
trainer battle) stops holding, as before. Cost: the partner sees a story change
up to a script's length later.

## D68. An unidentified GHOST stays in the window's own battle (2026-10-07)

In Pokémon Tower without the SILPH SCOPE a wild Pokémon is a GHOST that nobody
can hit or catch and that every run escapes (`IsGhostBattle`); upstream's battle
models it with `gen1_ghost`. A takeover rebuilt the fight on the host from the
enemy's rows, so it became a plain GASTLY that a co-op party could beat or
catch. The takeover summary now carries the world's ghost kind (one line in
`world_screen.gd`), and the co-op takeover leaves an unidentified GHOST to the
window's own cartridge battle, as it already leaves the Safari Zone; the
partner cannot join it, and there is nothing to do in it but run. The SILPH
SCOPE's unveiled MAROWAK is an ordinary fight and stays on the host.

## D69. The launcher path is checked in two windows (2026-10-07)

Players start co-op from the launcher's Co-op tab, which no window check
covered. `tools/coop_launcher_play.gd` drives the real launcher's Co-op tab
through its own tab button, fields, choice rows and buttons, round after round,
so leaving and hosting again run as a player does them; the runner gains
`HOST_TOOL=none` (the first window hosts) and a scenario `check()` that can fail
a run. The runs found five things, all fixed with tests: a pad landing on Host
scrolled past it while the page still took its height; the first partner in a
new campaign went unannounced; a partner in the opening was placed in Pallet
Town in the session menu (now "in the opening"); leaving landed on the Play tab
with no reason (now the Co-op tab, with "You left the session." or why the host
ended it); and the tab forgot the name and address (now `user://coop_tab.json`).
Left as they are: the campaign list clips long labels (upstream's sheet
layout), and the toast covers a row until it fades.

## D70. A failed save leaves no YES/NO behind (2026-10-07)

A window's SAVE that the host would refuse ends in the prompt's own "Save
failed" step (D56), which co-op makes common: any battle a partner fights
refuses it. That step kept the YES/NO drawn with YES picked under the failure
line. Upstream's prompt marks a box with no question by a negative cursor, and
its failure step asks nothing (any press ends it as a NO does), so it now sets
the cursor to -1. One line in `save_prompt.gd`.

## D71. A link room closes the wait box it was entered with (2026-10-07)

The autoplayed Cable Club trade found upstream's Generation 1 link rooms
keeping a finished box on screen: "OK, please wait just a moment." after the
special warp into the Trade Center, "Just a moment." after the trade screen
closed. On the cartridge both `SpecialEnterMap` and `ReturnToCableClubRoom`
load the room again, so no box survives. The two steps now send the world
screen's existing `text_closed` event first (two lines in
`gen1_map_scripts.gd`). Every co-op trade shows the room clean, and so does a
single-player link session.

## D72. The owner settles world sharing and the open scope questions (2026-10-07)

The owner answered the six questions the playbook left open.

- **Share the campaign at rest points (#84).** The rule is "share what the
  cartridge would save, never what it is doing right now". A rest point is a
  moment the cartridge could save: no script holds the player and no map load
  is pending; a scene is the stretch between two. A window holds its world
  patches until its next rest point however long that takes, replacing D67's
  15 s cap; a partial patch goes out only when the window must answer the host
  anyway (its world's SAVE). Battles are not touched: they run on the host and
  are joined live.
- **Accepted costs:** a partner sees a scene's result, not the scene; a scene
  cut off by a disconnect replays from its start; a long scene reaches the
  partner only when it ends; windows stay trusted (the host does not
  re-simulate them).
- **The brief's world-simulation item is read as:** "the host is authoritative
  for the campaign and for battles; each window simulates the maps, NPCs and
  movement it shows, and shares the campaign at rest points". #22 closes on
  it, and #25 (host-side encounters and trainer sight) is won't-do: windows
  roll encounters, the host fights them.
- **Contested scenes (#24):** "the first player in drives a contested scene" is
  the lock asked for in D61. It applies to every rival scene after the
  opening: Route 22 (both), Cerulean City, S.S. Anne, Pokémon Tower and Silph
  Co. A second window on that map starts no copy of the scene, is held until
  it ends and sees its result; SELECT > JOIN stays open.
- **Android (#45)** is deferred until after the Hall of Fame run and the
  hand-played session. **German (#50)** waits for the owner's own dump.

## D73. A window opens its world as a Continue does (2026-10-07)

A window built its world on a blank state and pulled the host's story a frame
later, so a map's entry and coord scripts ran on no story: a player reopened on
the Cerulean thief's coord cell fought him again and was handed TM28 twice. The
window also forgot `wLastMap` and `wLastBlackoutMap`, so a campaign hosted again
with a player inside a building sent its LAST_MAP doors to Pallet Town. The
window's save now carries a world snapshot as a Continue would: the player's
map, cell and facing, the host's world with the player's keys over it, and the
two outside maps, which each step reports and the host keeps with the player.
A player brought from a single-player save brings them from its snapshot.

## D74. The map scripts of one player's walk are that player's (2026-10-07)

`gen1_map_scripts` was the campaign's, so a state one window reached ran in
every window on that map: at Vermilion's dock a partner's window reset
`wVermilionCityCurScript` and the ticket check looped forever, and in Cerulean
a partner's window ran the thief's after-battle script. The bytes are now
owned one by one, like `gen1_bytes` (D63): `wCeruleanCityCurScript` and
`wVermilionCityCurScript` are each player's, every other byte stays the
campaign's until #84 classifies the rest.

## D75. A pulled story flag can owe the window a map load (2026-10-07)

`GymTrashScript` sets `BIT_CUR_MAP_LOADED_2` with `EVENT_2ND_LOCK_OPENED`, so
the door to LT. SURGE redraws in the window that found the switch. A partner
already in the gym took the flag with a pull and no map load, and kept a shut
door. The link now knows its world and owes it the map load a pulled flag
needs, a table with one row so far (`MAP_LOADS_OWED_BY_FLAG`). The merge also
drops the Surge branch's poison cure from the autopilot: the heal merged
beside it already clears every status.

## D76. A Generation 1 row's end closes a box that owed no press (2026-10-07)

After the Cerulean Rocket thief, the "recovered TM28!" box stayed drawn over a
map that took input again, and the autopilot (and upstream's `played` check)
waited on it forever (#86, also in single player). On the cartridge
`DisplayTextID` ends every row in `CloseTextDisplay`, which takes the window
down whether or not `wDoNotWaitForButtonPressAfterDisplayingText` skipped the
last press; the thief's row prints the receipt with no press and then fades out
and back in (`CeruleanHideRocket`) before it ends. The world screen keeps a
no-press box up while a wait is pending behind it, which is right during the
fades, but nothing closed it at the row's end. The world now notes a box
served with no press (`_gen1_box_held`, cleared on a map load), and the row's
end sends `text_closed` for it as it already did for a balance window. The same
tail closes Pallet Town's "Hey! Wait!", the Game Corner poster and the Pokémon
Mansion switches. Left as it is: the receipt's `text_waitbutton` draws an arrow
and an empty last page where the cartridge keeps "Bye!" through the fade.

## D77. A window entering Vermilion City keeps the first lock while a partner is near (2026-10-07)

D63 left a cost: `VermilionCity_Script`'s `.setFirstLockTrashCanIndex` rolls
the first lock on every load of the city, so a partner walking in moved the
first switch while someone was still searching the gym (#85). As agreed with
the owner, the locks stay while anyone is in Vermilion City or its gym, a
window entering takes them instead of rolling, and with nobody there the next
entry rolls as on the cartridge. No can is searched in the city, so a first
lock that differs from the one the window last synced is the city's roll;
while the host's player list shows another connected player in the city or
gym, `PokeCoopWorldLink._keep_locks` puts the synced value back before the
window's patch goes out and logs `locks_kept`. A wrong second can is a search
in the gym, so its reset still reaches everyone. Rejected: the host refusing a
first-lock change, since the window would keep its own roll without a new
correction message, and the host would have to tell a roll from a reset by a
`move` that can arrive after the patch. Costs: a player stepping out of the gym
while the partner is inside keeps the lock rather than re-rolling; two players
arriving at the same moment may both roll, and the later roll wins before
anyone searches; a dropped partner does not count as present.

## D78. Stretch seeds come from upstream's story walk (2026-10-07)

Extending the autopilot to the Hall of Fame one stretch at a time (#88) needs a
campaign at each stretch's start, and the only ones came from the end of the
previous stretch's two-window run, so stretches had to go one after another.
`tools/coop_seed.gd` runs `preview_world_story.gd`'s Gen 1 legs to a named one
(upstream's walk, split into `_gen1_story_start` and `_gen1_story_legs` with its
output unchanged), steps out of the last door as the cartridge does, and
imports the save as a campaign's first player brings one
(`PokeCoopPolicy.import_save`): `p1` brings the story, `p2` gets its own copy on
a free cell beside, with its own trainer as each Pokémon's OT. Costs: the
story's thin party (one or two Pokémon, which the autopilot's grinding makes
up), only the trainers the story fought, and no host `defeated` encounters or
gift commits (event flags still stop re-fights). A stretch is proven from a
seed; the Hall of Fame run is proven from a new campaign.

## D79. How rest points are built (2026-10-07)

D72 adopted the rule; this is how a window keeps it (#84).

- **A rest point** is a frame where the cartridge could save.
  `PokeCoopWorldLink.unrest(screen)` names what holds the window instead: the
  session panel, a script, a map load, a forced walk or scripted NPC, a battle
  (the world's own or one fought on the host), a whole-screen overlay, or a
  locked screen (a fade, a trainer's approach). A scene's map-script states
  hand over with one frame between them that nothing holds, so a rest point
  counts after three such frames in a row (`REST_FRAMES`). D67's 15 s cap is
  gone: the 15 s cap and the narrow `script_busy` signal had let a long scene's
  middle steps out, and a world frozen under the panel pushed Oak's lab at
  its after-battle step.
- **Away from a rest point the window sends and takes nothing**, world or
  party. Two exceptions answer the host: a battle the world asks for sends the
  party first (the host fights with it), and the world's SAVE through the
  START menu sends the scene so far. A heal, purchase or gift writes a fresh
  snapshot and still asks for a checkpoint, but sends nothing of the scene.
  LEAVE, closing the window and a lost link send nothing: the host keeps the
  last resting state, and the scene replays. When a scene ends, its world patch
  and the party leave in the same frame.
- **A partner's step for the map a window stands on** waits until that window
  has loaded another map (`_owe_step`), then the host's latest value lands
  unless the window's own unconfirmed patch touched the byte. A pulled object
  hide or show lands at once (`load_object_masks`), as `HideObject` does: the
  first two-window run had Mt. Moon's fossils barring a partner's only way out.
- **Map-script bytes that rest on a value one player's walk sets are that
  player's**: the eight gyms (so a partner never replays a leader's lines or
  gift; TM34 had been handed out twice), Mt. Moon B2F, Museum 1F, the Safari
  Zone gate, the Champion's room and Seafoam B3F and B4F, beside D74's two
  cities. The offsets follow pokered's `ram/wram.asm`. Every other byte stays
  the campaign's: story steps whose resting value is permanent, Bill's house
  (so a partner sees Bill come out), and transient spinner and forced-walk
  states, which `movement` holds.
- **Logs:** `world_pull` lines carry `held` (frames the scene held the pull),
  `held_by` and `owed`.
- **Costs:** every change leaves three frames late; a partner standing on a map
  sees its story step only after leaving it; a partner's news waits while a
  window is in a scene, the panel or a menu. Per-walk event flags such as
  `EVENT_IN_SAFARI_ZONE` are still the campaign's.

## D80. Only a real SAVE asks for a campaign checkpoint (2026-10-07)

The link took any fresh world snapshot in the window's save for the world's
SAVE, and every heal, purchase and gift writes one (`Gen2WorldTransaction`):
about 40 "Campaign saved." lines in a ten-minute run, each a host checkpoint.
The world screen now calls `save_written` (beside `save_gate`, one line in
`persist_world_snapshot`) after any SAVE: the START menu's, a link room's, a
box change's or the Hall of Fame's. Only that asks the host for a checkpoint;
a transaction still sends the party at the next rest point, and the host's
own autosave keeps the rest.

## D81. Each player's Safari Game is their own, and a ball is no SAVE (2026-10-07)

The autoplayed KOGA stretch (#88) found two things. `EVENT_SAFARI_GAME_OVER` and
`EVENT_IN_SAFARI_ZONE` were campaign flags, and `_gen1_safari_check` runs on
every map while the second is set, so when one player paid, the partner's
window (holding no SAFARI BALL) ran the game-over warp from Route 14 to the
gate, and leaving then ended the game of the player still inside. Both flags
now join `PokeCoopPolicy.OWN_GIFTS`, beside the game's balls and steps, which
were already each player's. And a capture commits a world transaction, so each
SAFARI BALL wrote a snapshot the link took for a SAVE ("P1 saved the
campaign." per ball, refused during a partner's battle): a snapshot written
while the window's own battle is up is no SAVE (D80 later asks for checkpoints
only on a real SAVE, so this also keeps the party from being pushed mid-battle).
A campaign saved with someone inside the Safari Zone before this keeps the two
flags as the campaign's; none exists.

## D82. Pokémon Tower's purified zone is each player's (2026-10-08)

The autoplayed tower stretch (#88) found `EVENT_IN_PURIFIED_ZONE` shared: one
player stepped into Pokémon Tower 5F's purified zone and set it, the partner's
5F script (that player outside the zone) cleared it, and the first player's
window pulled the clear, healed and printed "Entered purified, protected
zone!" again about every 1.2 s, holding both players on 5F. The flag joins
`PokeCoopPolicy.OWN_GIFTS`. The same runs found a partner's picked-up item
ball staying solid on the map (6F's RARE CANDY, the only way south), which
D79's `load_object_masks` already fixes. A 2F rival met by both players is one
host battle, but each window plays the rival's lines and exit (#24); MAROWAK
is not a unique host encounter, and no second fight was seen.

## D83. The battle panel names a disabled move and one out of PP (2026-10-08)

The autoplayed ERIKA stretch (#88) met a Route 10 POKéMANIAC's SLOWPOKE using
DISABLE on the only damaging move left with PP. The panel kept offering it
unmarked and the host refused it (`_move_allowed`) with only "Refused:
invalid_move", so the autoplayed window sent it over a thousand times while
both windows sat in the joined fight. The battle view now carries the out
Pokémon's disabled slot, the FIGHT rows say (DISABLED) or (NO PP) as the
cartridge's move menu tells, and the refusal reads "That move can't be used
now." The same runs met the Game Corner poster's no-press box (D76 fixes it),
the Game Corner, Celadon Gym and Rocket Hideout B4F map-script steps crossing
windows and a partner's item ball and GIOVANNI staying drawn (D79 fixes them),
and one cost left as D79 states: a partner's poster switch opens the stairs in
a window already in the Game Corner only when it reads the poster or enters
again.

## D84. The first window into a rival scene drives it (2026-10-08)

D72's lock (#24) covers the rival scenes after the opening: Route 22 (both
fights), Cerulean City, S.S. Anne 2F, Pokémon Tower 2F and Silph Co. 7F
(`PokeCoopPolicy.RIVAL_SCENES`, by map, with the `w<Map>CurScript` states each
scene runs in; the byte is what the cartridge dispatches on, so no table of
trigger cells is kept). A window whose own byte enters one of those states
claims the scene on the host (`scene`, protocol 5) and gives it back at its
first rest point after the byte has left them, the world patch with the result
going out first in the same frame. The host keeps one driver per map, shows it
in that player's public view, refuses a second claim (`scene_taken`) and lets
go when the driver drops, leaves or steps onto another map. A partner on that
map waits from its next rest point with no step under way: its world stands
still under "<name> is facing the rival here. Wait, or join the battle with
SELECT.", SELECT > JOIN fights the rival together, and the frozen world counts
as resting, so the result is pulled during the wait. The wait ends at the
partner's next rest point, where the scene's script step for its map lands at
once (S.S. Anne 2F's rival is guarded by no flag, only by its byte resting at
NOOP, and a partner let go replayed his lines). Two windows that start the
scene before either hears of the other both play it: the claim the host reads
first drives, and the loser's battle joins the driver's as one unique
encounter; the rival scenes give no items, so both copies leave the same
result, and a rollback was rejected. A dropped driver lets the partner go at
once and meets the rival again from the start (D72). Costs: Pokémon Tower 2F
and Silph Co. 7F open with a text box before their byte moves, so a partner
waits one box late and may start its own copy in that gap (the race rule
covers it); anyone anywhere in Cerulean City waits out the Nugget Bridge
scene; a window whose link drops while it waits stays frozen until it is back.

## D85. What the SABRINA stretch showed about Saffron and Silph Co. (2026-10-08)

The autoplayed stretch from KOGA to SABRINA (#88) needed no co-op code change.
What it settles, as built: Saffron's gate drink (`BIT_GAVE_SAFFRON_GUARDS_DRINK`,
`wStatusFlags1` bit 6) and LAPRAS (`BIT_GOT_LAPRAS`, `wStatusFlags4` bit 0) are
Generation 1 engine flags, which `PokeCoopOwnership` gives each player (only
badges are the campaign's), so each player buys and hands over their own FRESH
WATER and is given their own LAPRAS. Silph Co.'s CARD KEY reaches every player
once as a story key item, and the president's MASTER BALL once each as a found
item. GIOVANNI on 11F starts his fight from a cell the partner cannot reach
past the door, so the partner joins through SELECT > JOIN; with D84 the 7F
rival held the second window, which joined his fight and did not replay the
scene. Left as it is: a card-key door a partner opens on the floor a window
stands on stays drawn shut there until that player opens it with the shared
CARD KEY (the floor draws closed doors only on a map load). Whether the gate
guards should be the campaign's is asked of the owner.

## D86. What the BLAINE stretch showed about Cinnabar Island (2026-10-08)

The autoplayed stretch from SABRINA to BLAINE (#88) made four sharing choices.
The Pokémon Mansion's switch (`EVENT_MANSION_SWITCH_ON`) joins
`PokeCoopPolicy.OWN_GIFTS`: `CinnabarIsland_Script` clears it on every frame a
player stands on the island, so as a campaign flag a partner outside reset the
other player's doors, and a partner's press toggled them. The fossil lab's
`EVENT_GAVE_FOSSIL_TO_LAB` and the two flags after it are each player's, as
`wFossilMon` already is (D52), so each player gives and revives their own.
Cinnabar Gym's six quiz gates stay the campaign's: a window already in the gym
owes itself a `MAP_LOADED_1_BIT` redraw when a partner's answer sets one
(`MAP_LOADS_OWED_BY_FLAG`, beside Vermilion Gym's second lock), so either
player's right answer opens the gate for both. A Generation 1 window reopened
on a water cell starts surfing, as a Continue does, since the host keeps the
position but not `wWalkBikeSurfState`. The SECRET KEY is a shared key item;
VOLCANOBADGE is the campaign's and TM38 is given once to each player.

## D87. Each player's Elite Four run is their own (provisional, #88, 2026-10-08)

The Indigo Plateau run flags 0x8E0 to 0x901 and the script bytes of the four
rooms and the Hall of Fame are each player's (`PokeCoopPolicy.ELITE_FOUR_RUN`,
`PLAYER_MAP_SCRIPTS`). The lobby after a whiteout and the Hall of Fame clear
that range, so shared flags would let one player's reset undo the partner's
run. As with every trainer, the members and the Champion are one encounter
for the campaign: a partner who joined, or who arrives later, talks to the
member and the host's `encounter_done` ends the fight at once as won, setting
that player's own flag. The Champion's room keeps its per-player byte and has
no rival-scene lock (D84): the scene gives no items, and two windows meeting
him at once join one battle. The Hall of Fame's hiding of the Cerulean Cave
guard stays the campaign's. Costs: rematches after the first Hall of Fame are
wins without a fight; a partner who never fought gets the same instant wins;
the host keeps no Hall of Fame records, so the PC's list is empty after the
reopen. Asked of the owner: confirm, or have a joined win set the joiner's
flag through the host, or forget the League's `defeated` once everyone is
inducted.

## D88. A side that wins blacks out nobody; a reset continues the co-op world (#88, 2026-10-08)

Generation 1 checks for a living party member after every battle, so the
initiator of a joined win whose own team fell was blacked out to the Plateau.
The takeover now reports `team_won` and the world skips that check, so only
lost battles white out, as `design.md` says. The Generation 1 Hall of Fame
saves and then resets: any save the world reports (`save_written`) now sends
the scene so far, as a real SAVE does (D80), and `Gen2GameRuntime.restart()`
lets the session freeze the world, wait until the host has applied what was
sent, and reopen it as a Continue. A player the credits left in the Hall of
Fame flies to Pallet Town, the cartridge's own Continue rule, and the reopened
panel drops finished battles. A reset in a co-op window continues the same way
instead of dropping to the saves page. Costs: both players land on the same
Pallet Town cell; play time comes back from the host; the reset writes one
extra checkpoint.

## D89. Victory Road's switches are the campaign's; boulders are each window's (#88, 2026-10-08)

A switch flag set in one window opens that floor's wall in every window
standing on it, through a map load the window owes (`MAP_LOADS_OWED_BY_FLAG`),
as for Vermilion's door and Cinnabar's gates (D86). The cartridge resets the
puzzle in three places (Victory Road 2F clears the 1F switch, leaving Victory
Road clears the 2F and 3F ones, the Indigo Plateau lobby clears the 1F one),
and those resets stay the campaign's, but a window still on any Victory Road
floor keeps the switches it holds open until it leaves, so a partner who gets
out first never walls in the one still inside. Boulder positions are each
window's: a window that never saw the switch set pushes its own boulder, as on
the cartridge.

## D90. A Generation 1 wild battle re-enters the map (#88, 2026-10-08)

`gen1_end_of_battle` sets both map-load bits, as pokered's `.battleOccurred`
does before `EnterMap`, so the reload after a wild fight runs the map's load
callback and redraws the blocks a switch or script replaced. Before, a wild
battle on a Victory Road floor closed the wall its switch had opened, also in
single-player. A two-line upstream change, listed in `architecture.md`.

## D91. The players are a team: a story gate one clears is cleared for both (owner, 2026-10-08)

Asked whether Saffron's gate guards should be the campaign's (D85) and how a
shared Elite Four run should work (D87, provisional), the owner answered: "we
work together as a team so only one needs to provide the drink", and the same
for the Elite Four. The rule for sharing questions from here on: a story gate,
unlock or progress flag one player clears is cleared for both; Pokémon and
items each player keeps (LAPRAS, TMs, fossils) stay each player's. So one
FRESH WATER lets both through Saffron's gates, and the Elite Four is one run
for the team: a member beaten by either player is beaten for both. This
replaces D85's gate drink and D87; the built details follow in their own
entries.

## D92. One drink opens Saffron's gates for the team (2026-10-08)

Following D91, `BIT_GAVE_SAFFRON_GUARDS_DRINK` (`wStatusFlags1` bit 6) is the
campaign's: `PokeCoopOwnership.campaign_engine_flag` routes it with the
badges, and the other `wStatusFlags1` bits (STRENGTH, the surf check) stay
each player's. The campaign keeps engine flags beyond the badges in its
`world`, so the drink is saved without a format change, and a save from
before this in which a player kept their own drink has it moved to the
campaign on load. The gate scripts read the flag each time they run, so a
partner already standing in a gate walks on with no map load. The autopilot's
SABRINA stretch has one player buy and hand over the only FRESH WATER. This
replaces D85's drink; LAPRAS stays each player's.

## D93. The Elite Four is one run for the team (replaces D87, #88, 2026-10-08)

Following D91, the Indigo Plateau's beaten flags are the campaign's: LORELEI,
BRUNO, AGATHA, LANCE (0x8F9, 0x8FE) and the Champion (0x901). A member beaten
by either player, alone or joined, is beaten for both; a window standing in
that room owes itself a `MAP_LOADED_1` redraw (`LEAGUE_EXITS_REDRAWN`), so the
exit opens there too, and a partner arriving later walks through without a
fight. LANCE's room needs nothing: its script returns early once 0x8FE is set.
The walks in (`EVENT_AUTOWALKED_INTO_*_ROOM`) and LANCE's door lock stay each
player's (`OWN_GIFTS`), as do the rooms', the Champion's room's and the Hall
of Fame's script bytes. Only AGATHA's end-of-battle script readies the
Champion's room, so a window the team's AGATHA win reaches sets its own byte
to PLAYER_ENTERS; the late player then meets the rival, whose fight the host
ends at once as won (`encounter_done`), and gets Oak's scene and its own Hall
of Fame, credits and Continue (D88). The lobby after a whiteout and the Hall
of Fame clear the run; the host holds that clear while a connected player is
in the League and, once the Champion fell, until every connected player is
inducted, and the clearing window takes the held flags back. Applied, the
clear erases the run and forgets the League's encounters and their `victory:`
commits, so the next run fights everyone again. Costs: the hold lives in the
host's memory, so a host restart keeps the run open until the next clear; a
connected player who never comes to the League after the Champion fell holds
rematches back, and anyone walking in meanwhile gets another instant Champion
win and Hall of Fame entry; a disconnected player inside holds nothing.

## D94. Being in the Seafoam Islands is each player's (#88, 2026-10-08)

`EVENT_IN_SEAFOAM_ISLANDS` (0x500) joins `PokeCoopPolicy.OWN_GIFTS`, beside
the Safari flags (D81). Seafoam 1F sets it on every frame and Route 20 clears
it, resetting the boulders while the puzzle is unfinished; as a campaign flag,
a partner on Route 20 cleared it and sent that reset, so a boulder one player
had dropped vanished from B1F and the B3F current never calmed. A host opening
a campaign drops the walk flags the cartridge clears itself (`OWN_WALKS`: the
two Safari flags and this one), so an older save does not keep resetting
Route 20. This and D81 overtake D79's note that per-walk flags such as
`EVENT_IN_SAFARI_ZONE` stay the campaign's. Costs: the boulders' hide and show
stay the campaign's, so a player who leaves through Route 20 with the puzzle
unfinished resets it for a partner still inside, as the cartridge resets it
for one player.

## D95. German Red and Blue are separate games (owner, #50, 2026-10-08)

German and English are separate games: German plays only with German, English
only with English, and mixed-language sessions are out of scope. German gets
its own game ids, `red_de` and `blue_de`, in `RomRegistry` rather than a
language flag on `red`, so the host's existing game-id checks refuse mixed
joins and campaigns, and caches and saves stay apart by id. The owner's own
dumps (Rote Edition and Blaue Edition, Germany, SGB Enhanced) are verified
locally and are never copied, committed or uploaded. einstein95/pokered-de,
which builds both byte for byte, is pinned as a reference like pret/pokered:
addresses and constants only, never its asm, text, graphics or symbol files.

## D96. Autoplayed runs snapshot every 10 s and resume from each window's leg (owner's request, 2026-10-08)

Long autoplayed runs failed hours in, and resuming meant copying the campaign
and guessing one `FROM` for both windows, though a stall often leaves them on
different legs. The owner asked for a snapshot every 10 seconds or so. An
autoplayed scenario's host now writes, every 10 s in which something changed
and only between battles, a `SEED=`-shaped snapshot: the content a checkpoint
would write (`PokeCoopHost.write_copy`; no SAVE counted, the checkpoint
untouched), the identity file, and each window's leg. The autopilot sends its
running leg as an unnumbered `note` once the world link has rested since the
leg began, so the host already holds the world the leg starts from; a recorded
leg can lag the window but never leads it. Repeated leg names are
`<name>#<n>`. All snapshots of the last 30 minutes are kept, older ones one
per 5 minutes. `tools/coop_resume.sh` reruns the scenario through
`coop_screens.sh` from the last snapshot, a numbered one, or one so many
seconds before the end, each window with its own `P1_FROM` / `P2_FROM`. It is
not a memory image: the game is recompiled, and the host's campaign plus the
leg is what a window reopens from. Cost: one tool-only message type the host
ignores for game state; the autopilot's in-between steps before a resumed leg
are skipped, as with `FROM`.

## D97. Upstream 0.1.75 merged; the fork moves to Godot 4.8-dev7 (owner's request, #14, 2026-10-09)

The owner asked for upstream's latest release in the fork, with nothing pushed
upstream. D61 had named 0.1.74; 0.1.75 is the latest release, so the merge is
the `v0.1.75` tag (`17c8da8`), not upstream's `main`, whose later commits are
unreleased Generation 3 import work. Upstream moved to Godot 4.8-dev7 in
0.1.73, so the fork's pin follows: CI, `AGENTS.md`, the readiness checklist and
the runner usage lines say dev7, and local runs and private builds need the
dev7 editor and its stock export templates. `upstream` is a fetch-only remote
with its push URL disabled. Conflicts kept both sides; the title backdrop takes
upstream's lettering rectangles, which already treat `red_de` and `blue_de` as
non-Yellow Generation 1, so the fork no longer changes that file. The
Generation 3 cartridges stay behind upstream's dev setting and never reach the
Co-op tab, whose game list is Red and Blue in English and German. Upstream's
cache format went from 163 to 170, so every imported cartridge, English and
German, is imported again; the co-op campaign format and upstream's saves are
unchanged. Cost: the owner's dev4 editor and templates are replaced; checks
that need a cartridge were not run in the merging session.

## D98. A co-op battle uses the cartridge's own menus on the world's screen (owner's request, #99, 2026-10-10)

Replaces the overlay of D22 and the side panel of D32. On an iPhone the panel
covered the on-screen controller, its rows were too small to hit, and a
finished battle could not be closed by touch (#98). A co-op battle is now drawn
inside the world screen's own 160x144 `Gen2Screen` with the cartridge's
menus: FIGHT/PKMN/ITEM/RUN, the move list with TYPE/PP, the party list six
rows at a time over every player's Pokémon (the text box names the owner of
the row under the cursor), the Gen 1 bag list, YES/NO boxes, and a name list
for whom a ball catches for. The panel keeps the flat list of choices as the
model; `PokeCoopBattleMenu` turns presses into those choices, so the
autopilot and scripted `@ROW` keys still pick rows. A partner's suggestion is
a hollow ▷ at every level (on FIGHT, PKMN, ITEM or RUN, and on the exact
row), a partner's initial with three or more players, and an idle
controller's text box spells it out ("BLUE suggests / SQUIRTLE") in turns
with the menu. The other player walks the same menus; resting the cursor on a
row suggests it, and A sends it again rather than acting. RUN flees for the
player whose world started the fight and asks everyone else whether to leave
(their team stays); take over and rejoin are YES/NO questions. A finished
battle closes once its last line has played. Trade-offs: marks are
monochrome rather than in player colours, nicknames are not shown (the view
has species only), items are used on the Pokémon that is out, and the bag
lists only items usable in a battle.

## D99. The session menu is START > CO-OP on the cartridge's screen, with swipes and taps (owner's request, #99, 2026-10-10)

The session menu is a CO-OP row in the cartridge's START menu, registered
through upstream's mod seam (`MENU_START`, visible only while a co-op world is
up), drawn on the world's 160x144 screen with the cartridge's font, boxes and
cursor: FIGHT offers, JOIN <partners> / VS <foe>, REJOIN, LEAVE SESSION
(asked YES/NO) and CANCEL, under a box with each partner, where they are and
the last save. SAVE stays START > SAVE (D80). SELECT on the map still opens
it; it does not where the world reads SELECT itself (the START menu and bag, a
world battle, the party). While the CO-OP menu or a co-op battle is open, a
swipe over the game screen is one d-pad press per 16 hardware pixels and a
tap is A, fed as ordinary button presses; touches on the on-screen pad and
two-finger touches are left alone, and walking on the map is untouched. No
new size setting: the menus are drawn at the game screen's scale, upstream's
zoom is keyboard and wheel only, and the pad has its own SIZE.


## D100. Friends battle and trade from their current locations (#104, 2026-10-11)

The owner's request, begun by Claude and continued by Codex: talking to the
partner opens BATTLE / TRADE / CANCEL; START > CO-OP also lists each free
partner. An invitation needs the recipient's YES, displayed at a rest point.
NO, B or 30 seconds unanswered declines it; the host expires a pending
invitation after 60 seconds and rechecks availability on acceptance.

`PokeCoopVersus` extends the existing battle session because both sides now
need human commands, replacements, private mirrored views and learning prompts.
The campaign host remains authoritative and uses the existing battle engine.
Choices from both players may use the same round revision; learning answers
have a separate minimum revision per side. Forced turns continue on the host.
A dropped opponent pauses human choices and is allowed the existing two-minute
reconnection grace; the other player cannot stand in for them.

At the end both parties recover HP, PP and status where they stood, without
money, story rewards or whiteout. Each Pokémon receives the full trainer EXP
and stat EXP for every distinct opposing Pokémon it faced, whether its player
won or lost; teammates do not split that award. Normal traded-Pokémon boosts,
level growth, learning and evolution still belong to the existing engine.
RUN forfeits. Items are unavailable in this friend battle.

A trade pairs the two consenting players in `PokeCoopTrades`, opens the
existing native trade screen in each world, and uses the existing cable and
exactly-once swap. Cancellation or disconnection releases both players without
moving them. Ordinary Cable Club trading continues to use its room pairing.
Protocol 6 carries invitations and these private views; both builds must match.

## D101. Red and Blue play one campaign together (owner's request, 2026-10-12)

The owner asked for Red and Blue in one session. Both cartridges share the
engine, maps, story, Pokémon, moves and items; they differ in what each world
draws from its own cartridge: wild Pokémon tables (and so the version
exclusives), Game Corner prizes and the title. Each window already runs its
world on its own cartridge, and the host's battles use stats and moves both
share, so the only gate was the host's hello, which wanted the campaign's own
game and SHA-1. It now also lets in the other game of the same pair (Red with
Blue, Rote with Blaue Edition, `PokeCoopPolicy.VERSION_PAIRS`) when both are
the registry's verified dump of their game; another revision, a hack, Yellow
or another language is still refused (D95). A save brought from the partner
game is kept. The campaign stays the host's game. Cost: a Blue player's
exclusives reach a Red player by trade, as between the two cartridges.

## D102. German games say everything in the cartridge's words (owner's request, #50, 2026-10-12)

German games draw the engine's own lines through `Gen1LayoutDe.UI`. Where the
cartridge has the line, the German is pokered-de's text for the same label and
must be found in both owner dumps (267 of 356 lines word for word, 7 more in
the cartridge's pieces); co-op and engine-only lines are project wording,
listed in `german-wording.md` for the owner. Layouts the German cartridge
changed follow it (SAVE box, JA/NEIN boxes, battle and Safari menu columns, PC
boxes, the Cable Club cancel box), keyed on the German cartridge being open and
on nothing in English games. The launcher stays English until it has its own
translation system. Cost: small lookups and column offsets in 19 upstream
files.

## D103. The Co-op tab is a flow of screens; joining asks the host first (owner's request, protocol 7, 2026-10-12)

The single scrolling form became Start (cartridge tiles with Ready, Re-import on
Play or Not imported; HOST and JOIN; Last session), Host (campaign cards with
each player's cartridge; edit, rename the rival, delete to `.bak`), New
campaign (name; the rival from the cartridge's presets, typed, or asked in
Oak's speech; how you start), Hosting (addresses by network with Copy and the
live players; the session runs while the launcher shows it), Join (Nearby from
a UDP beacon on 24681, By address, Recent), Connecting and Failure sheets, and
New player, in both launcher themes and a phone layout. A client sends `probe`
before `hello` on the same ENet link; the host answers whatever the protocol,
without creating a player, with the campaign, version, cartridge fit and the
trainer it knows. Dialling retries every 3 s for a minute, because partners
often press Join first, and the checklist depends on the kind of address.
Discovery is optional (one listener per device; iOS may need the multicast
entitlement); the address path is complete without it. The host's START >
CO-OP header shows its address. Rejected: mDNS (no Godot API), joining without
a probe (mismatches found only after a player was created), X for secondary
actions (not a launcher action; Y is used).

## D104. Wild Pokémon from both versions (owner's request, protocol 8, 2026-10-12)

A per-campaign switch, off by default and also offered by Edit campaign for
existing campaigns. With it on, each wild Pokémon met in the grass or the water
is, on the upper half of a 0 to 255 roll from the world's own encounter
generator, the other version's Pokémon from the same map and slot (so its level
and rarity stay the cartridge's), through upstream's
`Gen2ModHost.register_wild_substitute`, but only when that Pokémon is one the
player's own version never has in the wild (the owner's choice, the same day):
a slot both versions share, a slot where the other version only shuffles
Pokémon both have (Viridian Forest's HORNLIU and RAUPY, the Nidoran swaps,
Seafoam's ENTON and FLEGMON; 82 of the 175 slots that differ between Rote and
Blaue), and a map the other version has no table for keep the cartridge's own
odds. So the switch only adds the other version's ten wild exclusives, each
taking half of its slot. Nothing is taken from a
cartridge the device does not have: each window of a paired game sends its own
wild slots to the host after every welcome (about 10 KB, in the session only),
and the host passes the other version's to each player of the pair's other
game, so it works once a device of each version (Red and Blue, or Rote and
Blaue) has been in the session; until then the Hosting screen says which
version it waits for and every world keeps its own. The roll is drawn only
while a window holds the other tables, so a campaign without the switch keeps
the cartridge's encounter stream. Fishing, the Game Corner's prizes and the
in-game trades stay each player's own version. The substitute's context gained
the drawn `slot` (one line in `world_api.gd`) and `Gen2ModHost` an
`unregister_wild_substitute` for a session that ends. Protocol 8, because a
version 7 host refuses an unsequenced message it does not know by closing the
link. Rejected: a lookup by species and level instead of the slot (two slots
can share both and differ in the other version), shipping the other version's
tables with the build (cartridge data), and caching them in the campaign file
(the owner asked for in-session only). The comment ceiling rose by four for the
rule and its helpers (D13).

## D105. Hold B to run in a co-op run (owner's request, 2026-10-12)

The owner asked for a run button. Upstream already has the RUN BUTTON mod
policy: while one is registered, a walk with B held takes the bike's four
passes, a recording keeps the run state, and the bike and surf keep their own
pace. A co-op session registers `PokeCoopRemoteActor` as that policy for as
long as it holds a client, so every player of a run can run and a solo game
walks as the cartridge does. A partner's steps are eased over the time between
their reports, eight frames when they run or ride and sixteen when they walk.
Cost: B is held for nothing else on the map in Gen 1, so no cartridge input
is lost; there is no setting to turn it off.

## D106. Finding the partner: an arrow on the screen and the TOWN MAP (owner's request, 2026-10-12)

The owner found it easy to lose the partner and asked for an arrow or a map.
Both are there. On the world's own screen, a partner who is not on it is an
8x8 arrow in their colour, drawn over the map and under every text box and
menu, and only while the player walks about (no menu, script, battle or
screen of the world's own up). It points at them through a breadth-first
search of the maps from the player's: where connections alone reach their map
(the next route, the town beyond it) they have a place in this map's cells
and the arrow points at them exactly; past a door or stairs the arrow points
at, or stands over, the last warp on a map that can be placed, so it leads to
the right building and floor. Indoors, `LAST_MAP` exits resolve to this
player's own last map, and only until the search has left their building, so
an unrelated house never short-cuts back. Where nothing joins the two (a
partner who flew or is across the sea before the search reaches them), the
arrow takes the TOWN MAP's direction from one area to the other. The search
is cached per pair of maps and the player's last map. The TOWN MAP (the item,
and a TOWN MAP row in START > CO-OP for players without it) shows each
partner's icon in their colour, through a new `register_town_map_marks`
mod seam (`Gen2ModHost`, `Gen2TownMapScreen`), under the player's own icon,
on the map and the fly map but not the dex's AREA. Rejected: a minimap
(a second picture of the world over a 160x144 screen), and arrows through
menus. The comment ceiling rose by three for the search and the seam (D13).

## D107. A trainer the team is fighting or has beaten spots nobody else (#118, owner's report, 2026-10-12)

The owner was fighting a trainer on the S.S. Anne when the partner walked past
it, and the trainer spotted the partner too. Trainer sight is each window's own
(design.md), and until now a window spotted by a trainer the partner was
fighting joined that fight (L1, #60): on purpose, but not what players expect.
The world now asks a `sight_gate` (an upstream `Gen2WorldAPI` field, empty in
a solo game) before a trainer looks; a co-op window refuses every trainer the
host names as running in a battle or as beaten for the campaign. The second
covers the seconds between the host's win and the beaten flag reaching the
partner's world after the trainer's last line. A lost or fled fight releases
the trainer, so it spots again. Talking to the trainer, or SELECT > JOIN, still
joins the running fight. Left open: a partner spotted during the first
player's walk-up and before-battle text, before the host knows of the fight,
still joins it. The comment ceiling rose by four for the gate and the locked-in turn (D13).

## D108. A co-op battle shows the party balls (owner's question, 2026-10-13)

The owner asked where the balls went that tell how many Pokémon the opponent
has left. The single-player screen draws them (`DrawAllPokeballs`,
`DrawEnemyPokeballs`); the co-op field never did. Now, as on the cartridge,
both rows stand under "X wants to fight!" (only the player's under "Wild X
appeared!"), and the trainer's row comes back after its Pokémon faints, until
the next one comes out. The host's view carries each enemy member's HP and
status (`enemy_states`, no protocol change: an older host's view shows
the trainer's row empty). The player's row is the viewer's own Pokémon, not the whole allied
party, which can hold twelve. One difference: the cartridge shows the
trainer's row under SHIFT's "about to use" question and clears it before "X
sent out"; co-op asks no such question, so the row stands under "X sent out"
for a beat instead. The comment total stays at the ceiling.

## D109. A co-op bag holds forty rows (#124, owner's request, 2026-10-13)

The owner asked for a bag that fits more. Red and Blue keep one list of
twenty rows, and in co-op it fills sooner: every shared key item and HM
(`SHARED_ITEMS`) takes a row in both bags. A co-op run now gives each player
forty (`PokeCoopPolicy.BAG_CAPACITY`). The world asks one upstream seam,
`Gen2WorldPack.gen1_bag_capacity`, which every "is there room" check
(pickups, Marts, the PC, gifts) goes through. The session raises it when its
world opens and puts back the cartridge's twenty when it closes, so a solo
game is unchanged. The host's own spill of a gift to the PC uses the same
forty. A co-op bag never reaches a cartridge `.sav`: windows save JSON slots,
and only the launcher exports solo saves. The PC keeps its fifty.

## D110. Upstream 0.1.78 merged (owner's choice, #126, 2026-10-13)

The owner picked an upstream sync as the next issue. The merge is the
`v0.1.78` tag (`588d0f2`), three releases of Generation 3 field work since
0.1.75; upstream's `main` past the tag only lists the release in its AltStore
source. Godot stays at 4.8-dev7. The only conflict was the comment ceiling:
both sides had raised 41017 (co-op +337, upstream +229), so it takes both
raises, 41583. Upstream's export-template workflow gained a push trigger on
`main`; its job keeps the `Decryptu/pokerecomp` guard, so it never runs in
the fork. No upstream table keyed by game id was added, so the German ids need
nothing. Upstream's cache format went from 170 to 174 through Generation 3
imports only; no Generation 1 import code changed, so the cartridge checks ran
on a private copy of the Red cache stamped 174 (`REAL_USER_DIR`), and the
owner's own caches show "Update needed" until each dump is imported again.
The co-op campaign format and saves are unchanged.

## D111. Co-op menus read buttons where the cartridge's screens do (#43, owner's choice, 2026-10-13)

The owner chose an audit of co-op input on keyboard, controller and touch pad.
The CO-OP menu and the battle panel read buttons in `_input`. Godot sends
`_input` to later nodes first, so they took each event before
`Gen2InputRuntime`, whose filter turns a stick's stream of motion events into
one press, gives a held direction the cartridge's repeat and holds back a
stalled menu's presses. One stick push walked seven rows, and a held key or
touch-pad button moved one row, or three where the OS repeated the key. Both now read in
`_unhandled_input`, after the filter, as `Gen2WorldScreen` and
`Gen2BattleScreen` do. They still come before the world, since they sit under
the world screen. A Control holding focus over the world would take `ui_*`
presses first, as it would from the world itself. The launcher's Co-op tab
already moved by focus; typing in its fields with a controller is #128.


## D112. Private builds come from `tools/verify.sh --builds` (#44, 2026-10-13)

The owner chose private Windows and Linux builds as the next issue. They were
exported by hand from the working tree, so a build could carry uncommitted
changes, a folder named after a guess, and a Windows build zipped without its
guide. `tools/verify.sh --builds[=<dir>]` makes them as one more stage of the
branch's check rather than a new script (CONTRIBUTING: extend, do not add):
it refuses a tree with uncommitted changes, exports both from a `git archive`
of HEAD, so they share the commit and its protocol and nothing untracked
reaches them, boots the Linux build headless and the Windows build under Wine
in the run's private user folder and a fresh prefix, and zips each with
`BUILD.txt` and `docs/coop/playing.md`. Each commit gets its own folder, so
a build someone is playing is never replaced under them.


## D113. SHIFT's offer goes to the owner of the Pokémon that is out, by their own setting (#28, owner's choice, 2026-10-13)

Co-op battles used SET style (D14), so a trainer's next Pokémon came out
without "Will RED change POKéMON?". The owner chose the cartridge's own
rule for each player: the question goes to the player whose Pokémon is out
(or whoever stands in for them), and only if that player's own OPTIONS say
SHIFT. A window sends its BATTLE STYLE with every battle it starts, opens or
joins (`"shift"`, no protocol change: an older window sends none and counts
as SET, an older host ignores it). The session asks in a new `offer` phase:
YES is a switch to any standing ally, which hands the turn over as any switch
does, and NO (`stay`) keeps the one out; then the trainer's Pokémon comes out.
The field says "X is about to use Y!" to every window, the deciding window
asks the question, and a partner may suggest either answer. As on the
cartridge, the trainer's balls stand under the question and go before "X sent
out" (D108's one difference is gone where SHIFT asks), and its YES/NO, like
"Use next POKéMON?"'s, stands where the battle screen puts `OfferSwitch`'s,
over the player's own Pokémon. A scripted window's `auto_battle` leaves the
question up three seconds before it answers NO, so a capture can catch it. Baton Pass and
the Generation 2 half of #28 stay with the later milestone (D61); Mimic
already asks the owner of the Pokémon that used it.

## D114. A verify run names a seed per scenario (#132, 2026-10-13)

`SEED=<dir> tools/verify.sh a b c` gave the seed to every scenario, so one
written for a fresh campaign ran on the seed and its loose check still passed;
and `tools/coop_screens.sh` with a `GODOT` that named no program (an
unexpanded `~`) started nothing and reported "done". Now verify takes
`<scenario>=<seed dir>`, runs the others with no seed and refuses an
exported `SEED` rather than guess which scenarios want it (playthroughs take
one optionally). The runner fails when `GODOT` is no program and when its
tool host never listens; `run.env` records the seed a run started from.


## D115. A controller types on the Co-op tab's own keys (#128, owner's choice, 2026-10-13)

A controller reached every field on the Co-op tab but could not type in one:
the fields are plain `LineEdit`s and a desktop has no keyboard on screen. The
owner chose one on-screen keyboard over the cartridge's naming screen. A on a
field, from a pad or the touch pad, opens a sheet of keys
(`PokeCoopTabParts.keys`): letters, digits, `-` and `.`, Space, Delete and Done
for names and titles; 0 to 9, `.` and `:` for the address. Each key types into
the field at once, so B and Done both keep what was typed. A keyboard, a mouse
and touch still type in the field itself, and Enter still joins. The keys stay
in the co-op tab: upstream's own fields (save names, mod sources) are
unchanged.

Found with it, from a played session: Join read the form, which only learned
what a field held when it was edited, so a remembered address showed in the
field and Join said "Type the host's address first" until a digit was deleted
and typed again. A field now enters the form with what it shows.


## D116. Split screen is a second window on the same PC (#53, owner's choice, 2026-10-13)

`Gen2GameRuntime` is one per process and holds the save, the world and the
co-op session, so two players in one process would mean a runtime, a save and
a world per player across upstream's code. The owner chose the cheap way:
Split screen on the Hosting screen starts a second game process that joins
127.0.0.1 like any partner, and the two windows share the screen side by
side, borderless, as one split screen. Desktop only (Linux and Windows); a
phone runs one process.

The halves ask for the whole monitor, not its work area, and stay on top, so
they cover the taskbar where the system allows it. KWin does not: it caps a
window's size at the work area, so an always-visible Plasma panel stays below
the game (1400 of 1440 lines on the owner's monitor) unless it is set to Auto
hide. Only a fullscreen window may cover it, and one window per half cannot
be fullscreen. The owner asked for one window holding both games instead;
that needs either embedding another process's window, which Godot offers
only to its editor in C++, or streaming the second game's picture into the
first, both far larger than this, so the owner kept two windows.

The second window gets its request as one base64 JSON argument after `--`
(port, game, controller, screen), so exported builds, which ignore `-s`, start
it through the launcher. It keeps its own tab memory (`coop_tab_split.json`),
so its player's name and identity do not overwrite the host's, and the same
trainer comes back next time. Controllers: one goes to the right half and the
keyboard plays on the left; two give each half its own; none leaves both
halves on the keyboard of whichever has the focus. A half's controller is
held in `PokePadChoice.held`, over the one Settings picked, because the
runtime re-applies the Settings pick whenever mods load, and nothing is
written to the options file. Both halves turn off
`ignore_joypad_on_unfocused_application`, which the project sets, so the half
without the focus still hears its pad. The right window quits when its
session ends; the left gets its size, frame, controller and that setting back
once the right window's process is gone.

## D117. A split screen's halves take the controller their player presses (#140, 2026-10-13)

Split screen gave the left half the first connected controller and the right
half the second, ignoring Settings' pick. On a machine where another program
plugs in virtual pads (two "Microsoft X-Box pad" devices, the same GUID and
name, no serial), the halves got whichever came first, and a virtual pad
pressed by that program moved a player by itself. Godot cannot tell a virtual
pad from a real one, so the players say which is theirs: before the second
window starts, a sheet asks each half to press A (or Enter for the keyboard,
one half only); a controller already taken does not count. Settings' pick, if
plugged in, plays on the left without asking. With no controller, both halves
play by keyboard as before. In a normal window the pick already kept the
virtual pads out: a probe with two virtual pads pressing showed their buttons
in Godot's raw joypad state but no game action, also after one was unplugged
and plugged back in.

## D118. QUIT BOTH, and the right half's exit code (#139, 2026-10-13)

The halves are borderless, so neither has a close button. SELECT > QUIT BOTH
on either half closes both: on the host it is the window's own goodbye
(`quit_after_goodbye`), which the right half already follows out; on the right
half it says goodbye and quits with exit code 3, which the host reads from
its child process (`OS.get_process_exit_code`) and follows. No protocol
message was needed. The right half no longer redials a host that dropped:
the host runs on the same device, so a dropped link means its window is gone,
and the right half gives up at once instead of after 60 tries of 2 s.

## D119. The split's layout is its own step before Who plays where? (#144, 2026-10-14)

The owner asked for a top-and-bottom split beside side by side. Split screen
now opens **How to split the screen?** with two choices, Side by side first
and focused, so one press keeps the old layout. It is a sheet of its own
because Who plays where? listens for A and Enter to hand out the halves, so a
choice on it could not be pressed with a controller or the keyboard; and with
no controller plugged in, Who plays where? never opens. The layout travels to
the second window in its argument (`stacked`, side by side when absent), and
`SplitScreen.half` cuts the screen along its height instead of its width.
The choice lasts until the game closes and is not written to the tab's
memory; the issue asked for a default, not for remembering it.

## D120. A Generation 1 trade keeps the catch rate out of the item (#65, 2026-10-14)

A Red or Blue link trade with the other save slot refused a RATTATA: upstream's
`Gen2LinkTransport.peer_from_save` sends a Generation 1 Pokémon's catch rate in
the item byte, which the Time Capsule turns into a Generation 2 held item, and a
Generation 1 save receiving that row held item 255, which its validator refused
(`candidate_save_invalid`). Co-op trades never took this path since the cable
sends the host's rows. Upstream's `commit_link_trade` now clears the item of a
Pokémon arriving in a Generation 1 game, which has no held items; the catch rate
travels in its own field. The save-slot row stays as it was, because the Time
Capsule reads it. Like D64, a candidate to offer upstream; that is the owner's
call.

## D121. Every Red and Blue battle question has an owner, and the partner may suggest its answer (#28, 2026-10-14)

The questions a Red or Blue battle asks are the replacement after a faint
("Use next POKéMON?" in the wild), a move to learn, Mimic and SHIFT's offer
(D113). Each goes to the owner of the Pokémon it is about: the one out, or for a
move to learn the learner, which may be the partner's Pokémon that fought
earlier. Session tests now cover each. The partner's window showed nothing while
Mimic or a move to learn was asked, and the host refused a suggestion for
either; now it shows the owner's list, its pointer is a suggestion (`mimic`,
`learn`, `decline`), and the owner's list wears the partner's mark as the move
list does. A scripted window's `auto_battle` leaves Mimic's list up three
seconds, as it does SHIFT's question, then copies the first move. Baton Pass
and Generation 2's questions stay with the later milestone (D61).

## D122. "Use next POKéMON?" is a question the partner may suggest on too (#151, 2026-10-14)

D121 gave every Red and Blue battle question an owner and let the partner
suggest its answer, but the replacement after a faint in the wild stopped
short: the partner's window went straight to the party list, so they could
point at a Pokémon but never at running, and the owner's YES/NO box carried no
mark. Now the partner's window shows the same "Use next POKéMON?" box, where NO
suggests `run` and YES opens their party list, and the owner's box wears their
mark on NO, or on YES while they point at a Pokémon. A trainer battle asks no
such question, so neither window shows it there. The owner's A alone answers,
as before.

## D123. A pick stays on the pad it found while look-alikes come and go (#140, 2026-10-14)

Settings' pick is found again by GUID, then by serial, else by name and its
place among the pads of its model. A virtual pad another program makes copies
a real model's GUID and name and carries no serial, so a pick made on a pad
without a serial is only a place in the order, and that place moves when twins
come and go: a twin plugged in later takes a freed lower device number, the
real pad becomes the second of its model, and the pick followed it onto the
twin, which the other program then moved. Now the device a pick found stays
the pick while it stays plugged in. A serial still wins, so a pick with one
that is plugged back in beside the twin that played meanwhile takes over
again, and a split half's own pad is a new want that resolves afresh. The
owner's own pick (a DualSense Edge, with a serial) was never at risk; the
normal window they reported was probed a second time, with Steam Input's
desktop layout active for the virtual pads this time, and again nothing
reached an action. The build they played predates D117 and D118: its right
half held the second connected pad, a virtual one in that device order, and
stayed up for two minutes after its host left, which is a window that looks
like a normal one. A fresh private build is the way to retest.

## D124. No reconnection secrets; a redial stays the same trainer (#20, 2026-10-14)

#20 asked for a per-player secret issued on first join and required on
reconnect. The owner turned it down: sessions are hosted among friends on a
LAN or a direct address, with no relay and no dedicated server, so a player is
still taken back by id, or by name when their device lost it (D48).

What #20 found instead: a device whose link died without the host hearing it
(a phone back from the background before its network is up, a Wi-Fi hiccup)
redials while the host still holds the old link, which it lets go after at
most six seconds, and is refused `already_connected` meanwhile. A session that
dialled with this device's remembered players (player id empty: the new-player
path, or any earlier campaign on that host) treated that refusal as the sign of
a second window on the device playing as the remembered player and joined as
somebody new, so the device came back as a new trainer with a new starter. That
fallback now applies only before the first welcome; a redial waits the refusal
out as the same trainer, as it already did when the player id was given.

## D125. The co-op battle field plays what the battle screen would (#26, owner's choice, 2026-10-14)

#26 asked for the battle screen itself to replay the host's events. The owner
chose to close the field's gaps instead, flows included, and leave the
7,800-line upstream screen alone. The host already sent every event the screen
reads, so the field now:

- words every event outside co-op's own (joins, item and ball lines, the
  switch offer and the learn offer) with the screen's `_describe`. Each
  Pokémon is named by its nickname, which the host's view now carries. This
  brings in "used instead,", "One-hit KO!", "a boosted", "with EXP.ALL," and
  the "learned" jingle;
- applies the statuses, a Transform, the Substitute doll and Minimize's dot at
  their own event. The doll and the dot come from both the events and the
  animation's commands, and the host's view carries both for a window joining
  mid-battle;
- plays an event's own sound, RUN's sound, Jump Kick's shake and the engine's
  pauses. It sounds the low-HP alarm while the drawn bar is red and colours
  its text box with the player's Pokémon's palette. Generation 1 cries have no
  stereo, so there is nothing to pan;
- shows the level-up stats box beside the last level's line, asks "Delete an
  older move?" before the forget list (NO asks "Abandon learning?", whose NO
  asks again), and shows a medicine's party screen with its bar filling. The
  POKé FLUTE says its own boxes with the tune between them. The host's item
  line now names the target, its HP before the enemy's move and the effect;
- blacks out on a loss: the first rival slides back in with their line (the
  takeover now carries the loss text), then the black palette and "blacked
  out". The lab fight is spared, as `HandlePlayerBlackOut` spares it. A world
  whose window showed that line goes straight to the Pokémon Center; one that
  left the battle still prints the world's own line;
- shows a catch's recipient, in their window only, "New POKéDEX data", the
  entry page and the nickname prompt (with BILL's PC line for a full team).
  The name goes to the host as `name_catch`, accepted once from that player
  for that battle, and reaches the windows as a new holdings revision.
  WILD_FLED's run sound is left out: pret notes the prompt's click outranks it.

What stays the field's own is the drawing: the field is still a separate node
from `Gen2BattleScreen`; the owner accepted that as closing #26.

## D126. #27 closes for Red and Blue; the Generation 2 AI joins #149 (owner's choice, 2026-10-15)

#27 asked for the battle screen's enemy choice to move into a scene-free
helper that host sessions share. For Generation 1 that helper is
`Gen1TrainerAI`, and both the screen and `PokeCoopBattleSession` already call
it: the session builds its battle with the trainer's class, so the class's
layers score the moves, and `Gen2Battle` takes the class's items and switches
inside the turn for both. The owner closed #27 with two co-op tests that pin
it (layer 1 against a paralysed Pokémon, BROCK's FULL HEAL), each shown to fail
when the session loses the class. The Generation 2 half (`Gen2BattleAI`'s
choice from the trainer's flags, a random usable move in sessions until then)
joins #149 with Generation 2's other battle questions, in the later milestone
(D61). `battle_screen.gd` is left alone.

## D127. A traded Pokémon disobeys in co-op as it would alone (2026-10-15)

`CheckForDisobedience` compared a Pokémon's OT with the battle's one
`player_id`, which a co-op session leaves unset (each Pokémon's owner is in
`owner_trainer_ids`, D62), so in co-op every Pokémon obeyed: `battle_text`'s
traded KADABRA L30 with no badge obeyed every turn. `check_obedience` now asks
`_is_traded`, the owner-aware check experience already uses: a Pokémon obeys
its own owner, and one traded to them obeys up to the campaign's badge level,
the battle's badge mask as before. The exemptions (link, tower, locked, called,
the enemy) are unchanged and still draw no roll. This follows the brief's rule
that a shared battle feels like a solo run, so it needs no new owner decision.

## D128. Generation 2's scope and sharing rules (owner, 2026-10-15)

Generation 1 co-op is feature-complete, and the owner asked to scope Generation
2, which D61 had moved to a later milestone. Asked in #171, the owner chose:

- **Games**: Gold and Silver first, a version pair as Red and Blue are; Crystal
  follows once they play, with Crystal only.
- **Clock**: the host's clock is the campaign's one clock; every window shows
  its time of day and weekday.
- **Phone**: each player's own Pokégear, contacts, calls and rematches.
- **Day care and eggs**: one day care per player, breeding only that player's
  Pokémon.
- **Bug-Catching Contest**: both players can be in the same contest; each is
  judged on their own catch and gets their own prize.
- **Ruins of Alph**: a puzzle one player solves is solved for both (D91); the
  Unown each player catches are theirs.
- **Roaming beasts**: one RAIKOU, ENTEI and SUICUNE per player, each roaming
  that player's world.
- **Story legendaries and one-off Pokémon** (LUGIA, HO-OH, the red GYARADOS,
  SUDOWOODO, SNORLAX and the like): one per player. This replaces D10's
  once-per-campaign rule for Generation 2; Red and Blue keep D10.
- **Kanto after Johto**: in the same milestone, after Johto's Elite Four, up to
  RED on Mt. Silver.
- **Mystery Gift and the Time Capsule**: both in. Mystery Gift works between
  the two players as between two Game Boy Colors; the Time Capsule trades
  between a Gold or Silver player and a Red or Blue player.
- **#149** (Baton Pass, SHIFT, Mimic and the Generation 2 trainer AI) joins
  the milestone.

D61 (gifts one per player, full prize money, leaving and absence), D91 (a
story gate one clears is cleared for both) and D72 (sharing at rest points)
carry over unchanged.

## D129. Session links leave the history (owner, 2026-10-15)

375 co-op commits ended with a `Claude-Session:` link to the agent session, and
26 pull request descriptions ended with one. The owner asked to remove them as
the personal data was removed when the fork went public (2026-10-13). Deleting the repository and
recreating it would have turned every merged pull request into a closed issue
and re-dated everything, so the owner chose a rewrite in place instead: the
co-op commits' messages lost the line (trees, authors and dates unchanged; three
messages that cite a commit by hash cite its rewritten hash), both branches were
force-pushed once at the owner's request, and the pull request descriptions were
edited. The rule from here on: no session link in commits or pull requests.
GitHub still serves the old commits through each pull request's own ref until
GitHub Support purges them; that request is the owner's.

## D130. Gold and Silver's rules in their own file (owner, 2026-10-16)

Asked during #172 whether Generation 2 co-op could be built apart from Red and
Blue's, so Johto work cannot break the Red and Blue campaign. A full copy of the
co-op subsystem would make every networking, lobby and save fix twice, break
upstream's file and comment budgets, and leave the Time Capsule (#182) needing a
bridge between two systems. The owner chose the middle way: the core stays
shared (transport, host, client, battle sessions, saves, the Co-op tab, the
session menu), and every Gold and Silver story rule lives in
`game/coop/coop_johto.gd` (`PokeCoopJohto`), which `PokeCoopPolicy` asks by the
cartridge's generation. Red and Blue's rules stay in `PokeCoopPolicy` as they
are. This adds a file against `CONTRIBUTING.md`'s "extend, do not add" on the
owner's decision. Red and Blue keep their GUT suites, ENet demo and two-window
scenarios on every pull request; the ENet demo also runs a Gold campaign Silver
joins (`demo gold`).

## D132. Sharing Johto's world (#174, 2026-10-16)

Gold and Silver ran on Red and Blue's tables: their map scenes (`map_scenes`,
keyed `group:number`) were dropped by the host's well-formed check, so no scene
reached the campaign or a partner and a window reopened with every scene at
zero; every event flag was the campaign's, temporary ones too; engine flags
were each player's but the badges, so a Ruins puzzle one player solved unlocked
the Unown only in their world; Red's gift TM flags and unique items fired on
other Johto events (flag 41 handed every player Red's TM item 242, a POKé BALL
was a "unique item"); SNORLAX and the birds were one encounter per campaign;
and the rival locks, the League run and its redraws named Kanto's maps.
Following D91 (a gate one clears is cleared for both) and D72 (a walk's own
state stays with it), `PokeCoopJohto` now holds Johto's answers, asked by
generation, and Red and Blue's stay as they were:

- **Map scenes** are owned scene by scene like event flags. The campaign keeps
  the story's (New Bark Town's teacher, the Ruins' inner chamber, the gates of
  Ecruteak, Mahogany and Route 43, the rival's); each player keeps a walk's:
  the link rooms, the Fast Ship and its ports, the Magnet Train's stations, the
  contest's gates, the League's rooms and the Hall of Fame, the bicycle gates,
  the Trainer House and the Unown dex.
- **Event flags**: each player keeps the eight `EVENT_TEMPORARY_UNTIL_MAP_RELOAD`
  flags (dropped from a campaign when it is hosted), the League rooms' shut
  entrances and LANCE's room after him; everything else stays the campaign's.
- **Engine flags** the team shares beside the badges: the four unlocked Unown
  sets (a puzzle solved for both, D128) and the Rockets' hold (the radio
  signal, the Radio Tower and Mahogany).
- **Key items** kept for good reach every player once (D52): the BICYCLE,
  COIN CASE, ITEMFINDER, the three rods, S.S. TICKET, CARD KEY, BASEMENT KEY,
  PASS, SQUIRTBOTTLE and the seven HMs; other items found with the story reach
  everyone as before. Red's gift TMs and its one-off wild Pokémon do not apply
  to Johto: gifts one per player are #173's, story legendaries #180's.
- **Contested scenes** (D72, D84): a Johto scene has no script byte that moves
  while it plays, so a window claims a map while a script runs there that one
  of the map's contested scenes (by its coordinate event or map entry) or a
  story talk (by the person's hide flag) started: the rival in Cherrygrove,
  Azalea, Sprout Tower, the Burned Tower, Olivine, Goldenrod's underground,
  Victory Road and Mt. Moon; the Radio Tower's 5F; LANCE in Mahogany's mart and
  the Rocket base's B2F and B3F; Team Rocket and KURT in Slowpoke Well; LANCE at
  the Lake of Rage; the DRAGON FANG in the Dragon's Den.
- **The Elite Four** is one run for the team as in Kanto (D93): the four, LANCE
  and each room's open exit are the campaign's, the lobby's clear is held while
  a player is in the League, and a window standing in a room or a Ruins chamber
  when the team's win lands reloads that map so its exit or floor opens.

Costs: a scene pulled for the map a window stands on applies at once (Johto's
coordinate events read it on the next step, and map entry scripts run only on
entry); the gift scenes of the opening (ELM's lab, Mom's POKéGEAR, MR.
POKéMON's house) stay the campaign's until #173 decides them; the Burned
Tower's beasts wait for #180; the League's and the Ruins' redraws are written
but not seen on a cartridge yet.
