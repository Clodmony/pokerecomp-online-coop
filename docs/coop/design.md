# Co-op design

Agreed behaviour for the cooperative Red/Blue campaign, initially for two
players. The brief is in [brief.md](brief.md); how the code implements this is
in [architecture.md](architecture.md). Rules marked **provisional** are defaults
the owner has not settled; they live in `PokeCoopPolicy` so they can change
without touching the simulation.

## What is shared and what is not

| Shared by the campaign | Owned by each player |
|---|---|
| Story event flags | Pokémon team (at most six) and box |
| Gym badges | Bag (items) |
| Unique encounter status (gyms, rival, bosses, legendaries) | Money |
| Campaign identity and cartridge identity | Position: map, cell, facing |
| | Return point while suspended in another player's battle |
| | Connection state |

A player's Pokémon never become another player's, inside or outside battle.
Every Pokémon, player, battle and encounter has a stable id; array positions are
never identity.

## Exploration

- Players explore independently, on the same map or on different maps.
- Connected players on the same map see each other. A player who left their
  map to join a battle elsewhere, or who is disconnected, is not shown there.
- The host keeps every position and the campaign; each window simulates the
  maps, NPCs and movement it shows (D72): the host accepts a step of up to two
  cells (a ledge hop) on the same map and trusts a warp the client's world
  reports. Collision is the window's own.
- Each window's world state follows the ownership table in
  `PokeCoopOwnership`: story flags, badges, map scenes, toggled objects and the
  other shared keys are the campaign's and appear in every window; the bag,
  wallet, step counters, Pokédex and the rest are the player's own.
  Vermilion Gym's trash-can locks are the campaign's, so both windows search
  the same cans; every other Gen 1 script byte (the SURF high score, the lucky
  slot machine) stays with its player (D63), and a window entering Vermilion
  City keeps the first lock while a partner is in the city or gym (D77). A
  change made in either window reaches the other as a patch, entry by entry,
  so two flags set at once both survive.
- **The campaign is shared at rest points** (D72, D79): what the cartridge
  would save, never what it is doing right now. A rest point is a moment the
  cartridge could save: no script, map load, forced walk, battle, overlay or
  fade holds the player. A scene (the stretch between two rest points) leaves
  the window as one patch when it ends, party included; the partner's changes
  wait until then too. A battle the scene opens sends the party first, and the
  world's SAVE sends the scene so far; LEAVE, a closed window or a lost link
  send nothing, so the scene replays from its start.
- **Not shared:** NPC wandering and every object position a script moves
  (the SUPER NERD's step, boulders) until the map loads again; a scene's
  animation, text boxes, menus, music and sounds in the partner's window (only
  its result arrives: flags, items, objects shown or hidden, resting
  map-script steps); a partner's step for the map a window stands on, until
  that window loads another map (an object hidden or shown lands at once);
  the map-script bytes of one player's walk and the eight gyms (D74, D79);
  wild encounters, trainer sight and map-load rolls; party and PC changes in
  the middle of a scene.
- The party a window shows follows the host: battle results replace it, and a
  heal, a gift, a deposit or a withdrawal made in the window goes to the host.
  A Pokémon missing from the window's party is kept in the host's box.
- A wild encounter or a trainer battle the window's own world starts is fought
  on the host as a co-op battle the partner can join. The world keeps its script
  branches and its whiteout; the host pays the prize. The session menu still
  offers the host's own encounters.
- The world's own SAVE asks the host for a campaign checkpoint.
- Each player is drawn in one colour in every window, by their place in the
  session; a player in a battle wears the "!" emote where the battle started.

Friend battles and direct trades are an additional consent-based activity,
with healing, experience and return rules specified in [D100](decisions.md#d100-friends-battle-and-trade-from-their-current-locations-104-2026-10-11).
Their outcomes do not commit campaign story rewards.

## Battles

- A player starts a battle alone. The other player may keep exploring or start
  a separate battle; no player or Pokémon is in two battles at once.
- The format stays one active Pokémon per side.
- A free player can request to join a running battle, from any map. Their
  exploration is suspended and their return point kept; the initiator stays at
  the encounter location.
- **Joining happens at a safe turn boundary**: when the battle is waiting for
  an action. A request made during a forced replacement, a move-learn question
  or a Mimic choice waits for the next boundary. A request made at a boundary
  applies at once and advances the battle revision, so an in-flight command for
  the old revision is refused and must be re-sent.
- The joiner's Pokémon are appended behind the existing allied roster. With two
  full teams the roster holds twelve; each player's team stays at six.
- **The owner of the active Pokémon controls the turn.** Switching to the other
  player's Pokémon hands control to that player. A question about one Pokémon
  (replacing it after a faint, a move it wants to learn, Mimic) goes to the
  owner of that Pokémon; the replacement may be any standing allied Pokémon.
- While the co-op panel is open the player's own world stands still.
- **Leaving a battle** (D61, D62): a participant whose own world did not start
  the fight may LEAVE BATTLE. They are back where they were and explore; their
  Pokémon stay in the roster, fight on under whoever is present, and the
  results, experience and prize are still theirs. Until that battle ends they
  start or join no other: a fight their world opens waits, showing the old
  battle with REJOIN. REJOIN (also in the SELECT menu) takes them back in at
  once. A queued join can be called off the same way. The player whose world
  started the fight, or walked into the same trainer, stays in it.
- The other participant can move an advisory cursor and send a suggestion
  (move, switch, item, run, send out). A suggestion is shown to the battle's
  participants, never executes, never consumes a turn and is cleared when the
  revision advances. The controller cannot suggest to themselves.
- Every command carries the battle's revision; a stale or repeated command is
  refused and changes nothing.
- Items come from the acting player's bag; key items are not consumed. The
  panel offers the bag's battle items on the Pokémon that is out.
- A ball thrown at a wild Pokémon is rolled on the host with the cartridge's
  catch formula. The thrower names who the catch is for (any participant); a
  held ball ends the battle and the Pokémon goes once to that player, who is
  its trainer: team if there is room, else box, and their Pokédex. A trainer's
  Pokémon cannot be caught.
- After a shared battle each player's own window runs evolution for their
  Pokémon that grew, and after a loss each window whites out its own player:
  party healed, half their own money, back to the last spawn.
- Experience goes only to Pokémon that took part, as the cartridge decides, and
  is written to the owner's own record by uid. A partner's own Pokémon is not a
  traded Pokémon; one with a foreign original trainer still is. One EXP.ALL in
  any participant's bag counts for every team: each team gets the cartridge's
  split over its own party, as it would fighting alone (D61).
- SET battle style is used in shared sessions for now, so the "will you switch"
  offer never interrupts a turn (#28).
- A battle the cartridge plays by its own rules stays in the window and cannot
  be joined: the Safari Zone, and a GHOST in Pokémon Tower without the SILPH
  SCOPE, which can only be run from (D68).

## Story and unique encounters

- A unique encounter (or any encounter carrying victory flags) has at most one
  active instance in the campaign. Defeating it marks it done for everybody;
  losing or fleeing releases it.
- Red and Blue's one-off wild Pokémon (SNORLAX, the three birds, MEWTWO) are
  unique encounters too, by species and map; beating or catching one ends it
  for everybody.
- Gift Pokémon are each player's own (D61): EEVEE, LAPRAS, the Dojo's HITMONLEE
  or HITMONCHAN, the MAGIKARP for sale and a revived fossil can each be had once
  per player. Their flags and Poké Balls are the player's, not the campaign's.
- A gift two windows hand out at the same moment is kept once: the second
  window's change repeats story the campaign already has, so the items it
  gained with it are taken back, the first window's share standing in (#24).
- The Elite Four is one run for the team (D91): a member or the Champion beaten
  by either player, alone or joined, is beaten for both, and the room's exit
  opens in every window, so a partner arriving later walks through. Each window
  plays its own walk in, Oak's scene and Hall of Fame; a partner who meets the
  Champion after the team beat him wins at once. A whiteout's or Hall of Fame's
  reset of the run waits while anyone is in the League, and after the Champion
  until every player is inducted; then the next run fights them all again.
- Major progression (flags, badges, defeated encounters) is applied through a
  commit with a stable id (`victory:<encounter id>`), so it happens exactly once
  even if messages repeat.

## Sessions and connections

- Host-authoritative: clients send intentions; the host validates them and
  answers with what each player may see.
- Players reconnect by their player id. While the **required controller** of a
  battle is disconnected, that battle is paused; everything else, including the
  other player's exploration and battles, continues. A disconnected participant
  who is not the current controller does not pause the battle. After thirty
  seconds the others are asked to TAKE OVER or KEEP WAITING; nobody decides for
  another player's Pokémon without choosing to, and the owner takes them back on
  returning (D61). A battle nobody is left in waits as long as a window
  redials, about two minutes, then ends as fled.
- Host shutdown sends every client an `ended` message, stops accepting
  commands, and closes once every client has left or after a short grace
  period. Host migration is out of scope.
- Clients import compatible content locally. Cartridge identity (game id and
  SHA-1) must match the host's; no ROM or extracted content is transmitted.

## Saving

- The campaign saves only at a safe checkpoint: no battle running and no join
  pending. A save request during a battle is refused with a reason.
- The save is one versioned file with a campaign section and one section per
  player; it is never a merged single-player save.
- Between checkpoints, every change to the campaign is journaled with the
  players as they stand, so a crash loses no story change and nothing that came
  with it, only player changes made after the last story change (D66).

## Policies

Rules marked "owner, D61" are settled; the rest are still provisional. All of
them live in `PokeCoopPolicy`.

| Question | Rule | Issue |
|---|---|---|
| Prize money | Every participant receives the full prize, Pay Day included (owner, D61) | #36 |
| Losing a battle | Each participant's own world whites them out and halves their own money (owner, D61) | #36 |
| Gift Pokémon | One per player: EEVEE, LAPRAS, the Dojo's choice and the MAGIKARP sale are each player's own, as the fossils are (owner, D61) | #33 |
| Capture recipient | Named by the thrower for each throw; the panel lists each ball once per participant | #35 |
| Withdrawal and drop-outs | One rule: a participant who leaves or loses the link is absent; their Pokémon stay in the roster and their results stay theirs; the battle ends when nobody is left, kept about two minutes for redialling. The player whose world started the fight cannot leave it (owner, D61; D62) | #31 |
| Late onboarding | A new player plays the opening (Oak's speech, their bedroom, Oak at the grass, the lab, the rival) on a story of their own, hidden from the others, and meets them and takes the campaign's story once they have a starter and have left the lab; or skips it with a starter of their choice at level 5, 3000 money, in Pallet Town; or brings their trainer from one of their single-player saves. The first player to name the rival names him for the campaign, and the first to finish the opening sets the rival's starter. A new campaign's shared story begins after Oak's intro, or from the story of the save its first player brings (owner, D61) | #34, #40, D50 |
| Story items | Every item a player finds or is given along the story (an item ball, a person's present, a reward) reaches every player in the same number; the key items and HMs on the shared list (town map, bicycle, keys, S.S. ticket, coin case, itemfinder, Silph Scope, Poké Flute, Exp. All, rods, HM01 to HM05) and gift TMs reach a late joiner too; into the PC's items when the bag is full. A key item the story takes is taken from every player, fossils excepted. Bought, traded for, used and hidden items stay with whoever got them | L5, D52 |
| Trades | Through the Cable Club's Trade Center with the partner the host names; the host swaps the two Pokémon and applies trade evolutions | #38 |
| Colosseum | Not a co-op battle: the takeover leaves link battles alone, so the window runs the cartridge's own link battle against a copy of the partner's team (not yet tried in a co-op run) | #38 |
| Controller lost | Pause; after 30 seconds the other participants are asked whether to wait or take over for the absent player's Pokémon, which stay theirs, until they reconnect and take it back (owner, D61) | #30 |
| Exp. All in a shared battle | Any participant's counts for every team; each team gets the solo split over its own party (owner, D61) | #37 |
| Gen 2 enemy AI in host sessions | Random usable move; Gen 1 uses the cartridge's trainer AI. Co-op targets Red and Blue only (D61) | #27 |
