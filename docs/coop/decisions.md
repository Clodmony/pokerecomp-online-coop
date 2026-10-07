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
of the real-screen slice and to 41342 with the battle stage (D39). Co-op code keeps upstream's comment style: only facts
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
