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
- The host keeps every position. Until the shared world simulation (#22) each
  window walks its own world: the host accepts a step of up to two cells (a
  ledge hop) on the same map and trusts a warp the client's world reports.
  Collision is the client's own until then.
- Each window's world state follows the ownership table in
  `PokeCoopOwnership`: story flags, badges, map scenes, toggled objects and the
  other shared keys are the campaign's and appear in every window; the bag,
  wallet, step counters, Pokédex and the rest are the player's own. A change
  made in either window reaches the other as a patch, entry by entry, so two
  flags set at once both survive.
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
  traded Pokémon; one with a foreign original trainer still is.
- SET battle style is used in shared sessions for now, so the "will you switch"
  offer never interrupts a turn (#28).

## Story and unique encounters

- A unique encounter (or any encounter carrying victory flags) has at most one
  active instance in the campaign. Defeating it marks it done for everybody;
  losing or fleeing releases it.
- Major progression (flags, badges, defeated encounters) is applied through a
  commit with a stable id (`victory:<encounter id>`), so it happens exactly once
  even if messages repeat.

## Sessions and connections

- Host-authoritative: clients send intentions; the host validates them and
  answers with what each player may see.
- Players reconnect by their player id. While the **required controller** of a
  battle is disconnected, that battle is paused; everything else, including the
  other player's exploration and battles, continues. A disconnected participant
  who is not the current controller does not pause the battle.
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

## Provisional policies

| Question | Provisional rule | Issue |
|---|---|---|
| Prize money | Split evenly among participants, remainder to the initiator; Pay Day money is added to the prize | #36 |
| Losing a battle | Each participant's own world whites them out and halves their own money | #36 |
| Capture recipient | Named by the thrower for each throw; the panel lists each ball once per participant | #35 |
| Withdrawal | None: a battle ends for all participants together | #31 |
| Late onboarding | A new player shares all story progress and starts with a starter of their choice at level 5, 3000 money, in Pallet Town; a new campaign begins after Oak's intro | #34 |
| Story gifts | A key item or HM one player is given (town map, bicycle, keys, S.S. ticket, coin case, itemfinder, Silph Scope, Poké Flute, Exp. All, rods, HM01 to HM05) and the TM behind any person's gift flag (gym leaders and others) reach every player, a late joiner included; into the PC's items when the bag is full. Items found on the ground, bought or traded for stay with whoever got them | L5 |
| Trades | Through the Cable Club's Trade Center with the partner the host names; the host swaps the two Pokémon and applies trade evolutions | #38 |
| Colosseum | Not a co-op battle: the takeover leaves link battles alone, so the window runs the cartridge's own link battle against a copy of the partner's team (not yet tried in a co-op run) | #38 |
| Controller lost | Pause; after 30 seconds another participant decides for the absent player's Pokémon, which stay theirs, until they reconnect and take it back | #30 |
| Exp. All in a shared battle | Off | #37 |
| Gen 2 enemy AI in host sessions | Random usable move; Gen 1 uses the cartridge's trainer AI | #27 |
