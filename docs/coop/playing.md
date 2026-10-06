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
`coop_<game>_campaign.json.bak`.

**To carry on where you left off**, the host presses Host again on the same
device and the others press Join with the host's address: the campaign loads
by itself and everyone gets their own trainer back, with their team, bag and
place. A device remembers who it played as on each host; a player joining
from another device or address gets their trainer back by typing the same
name as before.

## Playing over the internet

- **Same version, same cartridge.** Both players run builds made from the same
  version of this project, and both import the same game file: the same game
  (Red with Red, Blue with Blue) and the same revision. The host checks both and
  the Co-op tab says which one failed.
- **Easiest: a VPN you are both on** (WireGuard, Tailscale or the like). The
  host's Co-op tab lists each address with the network it belongs to, for
  example `10.0.0.1  (wg0)`; the other player joins the VPN one. No router
  setup is needed and it works behind any NAT. The tab keeps the list current,
  so a tunnel brought up after the game started shows up too.
- **Without a VPN**, the host forwards UDP port 24680 on their router to their
  device and gives the other player their public address. This does not work
  behind carrier-grade NAT or DS-Lite, which many connections have.
- **Firewall.** The host's device must let UDP 24680 in: on Linux with ufw,
  `sudo ufw allow 24680/udp`; Windows asks the first time a build hosts.
- **Windows builds are unsigned**, so SmartScreen warns on first start: choose
  "More info", then "Run anyway".
- If the host cannot be reached, joining gives up after fifteen seconds and
  says what to check.

## In the world

- Both players explore freely, on the same map or on different ones. The
  partner is drawn on your map in their own colour, with a "!" while they are
  in a battle.
- Story flags, badges, beaten trainers and taken items on the ground are
  shared. Your team, PC, bag, money and position are yours.
- Key items, HMs and gift TMs one player is given reach the other too.
- **Saving**: START > SAVE and "Save the campaign" in the SELECT menu do the
  same thing: the host saves the whole campaign, everyone in it. You see
  "Campaign saved." and the others see "BLUE saved the campaign."; a save
  refused during a battle says so. The host also saves by itself after
  battles, every thirty seconds of changes and when it closes, and the SELECT
  menu shows when it last saved. Nobody has to save before leaving.

## Battles

- The session menu (SELECT) says where your partner is ("With RED (ROUTE 1)").
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
connection is retried for about two minutes ("Lost the host: reconnecting...",
then "Back in the session."), so a host that restarts or a phone that comes
back from the background picks up where it was.

## Known limits

- The host trusts each window's world (positions, warps, the wild Pokémon it
  rolled).
- Shared battles are drawn as the cartridge draws them, intro to prize.
- A won trainer battle tells each player their own share of the prize.
- No phone or console builds yet.

See `progress.md` for what has been verified and how.
