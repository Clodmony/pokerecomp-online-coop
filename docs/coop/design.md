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
- Players on the same map see each other. A player who left their map to join a
  battle elsewhere is not shown there until they return.
- The host is authoritative for every position. The first slice accepts a step
  to an adjacent cell or a warp to another map; collision and warp validation
  arrive with the shared world simulation (#22).

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
- The other participant can move an advisory cursor and send a suggestion
  (move, switch, item, run, send out). A suggestion is shown to the battle's
  participants, never executes, never consumes a turn and is cleared when the
  revision advances. The controller cannot suggest to themselves.
- Every command carries the battle's revision; a stale or repeated command is
  refused and changes nothing.
- Items come from the acting player's bag; key items are not consumed.
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
- Host shutdown sends every client an `ended` message and closes the session.
  Host migration is out of scope.
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
| Losing a battle | Each participant pays the blackout cost from their own money (half) | #36 |
| Capture recipient | Not in the slice: balls are refused in shared sessions until a recipient is named explicitly | #35 |
| Withdrawal | None: a battle ends for all participants together | #31 |
| Late onboarding | A new player shares all story progress, starts with no Pokémon and 3000 money at a host-chosen location | #34 |
| Controller lost | Pause indefinitely until they reconnect | #30 |
| Exp. All in a shared battle | Off | #37 |
| Gen 2 enemy AI in host sessions | Random usable move; Gen 1 uses the cartridge's trainer AI | #27 |
