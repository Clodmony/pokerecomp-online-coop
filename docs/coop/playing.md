# Playing co-op

How two people play a Red or Blue campaign together with this fork. Each
player needs their own copy of the game imported on the Play tab; nothing from
the cartridge is sent between devices.

## Starting

1. Open the launcher and go to the **Co-op** tab.
2. Under **You**, type your name and pick a starter. If the cartridge has a
   single-player save on this device, **Bring** can take that trainer instead:
   their team, PC, bag, money and place. The first player of a new campaign
   who brings a save brings its story and badges too.
3. One player presses **Host**. The card lists the addresses others on the same
   network can use, and the port (24680).
4. The other player types one of those addresses under **Join a campaign** and
   presses **Join**.

The host's device keeps the campaign (`coop_<game>_campaign.json` in the game's
user folder), and the checkpoint before the latest beside it as
`coop_<game>_campaign.json.bak`. A device remembers who it played as on each
host, so joining the same host again brings the same trainer back.

## In the world

- Both players explore freely, on the same map or on different ones. The
  partner is drawn on your map in their own colour, with a "!" while they are
  in a battle.
- Story flags, badges, beaten trainers and taken items on the ground are
  shared. Your team, PC, bag, money and position are yours.
- Key items, HMs and gift TMs one player is given reach the other too.
- The game's own SAVE asks the host to save the campaign; the host also saves
  after battles, every thirty seconds of changes and when it closes.

## Battles

- Wild and trainer battles your world starts are fought on the host, so the
  partner can join; their window says so ("RED is in a battle against wild
  RATTATA. SELECT to join."), and also when a player joins or leaves. **SELECT** opens the session menu: join a running battle
  (from any map), save the campaign, leave the session.
- A shared battle is one Pokémon a side, with both teams on your side (up to
  twelve), listed in the panel under each player's name in their colour.
  Whoever owns the Pokémon that is out decides; switching to the partner's
  Pokémon hands them the turn. Your cursor in the panel is a suggestion the
  partner sees ("◀ NAME") and never acts by itself.
- The panel works with the d-pad and A, or by touch or mouse: tap a row to put
  the cursor on it, tap it again to choose it.
- Balls are listed once per player ("GREAT BALL x10, catch for BLUE"): the
  catch goes to whoever you name.
- If the deciding player drops, the battle waits; after thirty seconds the
  other player decides for their Pokémon until they are back.
- Evolutions and the whiteout after a loss happen in each owner's own world.

## Trading

Both players go to a Pokémon Center's Cable Club receptionist, enter the Trade
Center, sit at the table facing right and press A. The trade screen shows the
partner's real party; trade-evolving Pokémon evolve on arrival.

## Leaving

LEAVE SESSION in the SELECT menu returns you to the launcher. When the host
leaves, everyone is told why and returned to the launcher. A dropped
connection is retried for about twenty seconds.

## Known limits

- The host trusts each window's world (positions, warps, the wild Pokémon it
  rolled).
- Shared battles are drawn as the cartridge draws them, intro to prize.
- A won trainer battle tells each player their own share of the prize.
- No phone or console builds yet.

See `progress.md` for what has been verified and how.
