# Playing co-op

How two people play a Red or Blue campaign together with this fork. Each
player needs their own copy of the game imported on the Play tab; nothing from
the cartridge is sent between devices.

## Starting

1. Open the launcher and go to the **Co-op** tab.
2. Under **You**, type your name and choose how a newcomer starts (this only
   matters the first time you join a campaign):
   - **The opening: Play it** (the default): Oak's speech, your bedroom, Oak
     stopping you at the grass, his lab, your starter and the rival's
     challenge, as in the cartridge. See "The opening" below.
   - **Skip it**: start in Pallet Town with the **Starter** you pick, level 5.
   - **Bring**, if the cartridge has a single-player save on this device: that
     trainer's team, PC, bag, money and place. The first player of a new
     campaign who brings a save brings its story and badges too.
3. One player picks a **Campaign** under **Host a campaign**: one of this
   device's campaigns (the latest is picked), or **A new campaign** with a name
   such as WITH ALEX, then presses **Host**. The card lists the addresses
   others on the same network can use, and the port (24680).
4. The other player types one of those addresses under **Join a campaign** and
   presses **Join**.

The tab remembers the name and address you last used.

Each campaign is its own file on the host's device, so a run with one friend
never overwrites a run with another: start **A new campaign** for each group.
The files are in the game's user folder under `coop_campaigns/<game>/`, each
with the checkpoint before the latest beside it as `<file>.json.bak`. A
campaign from an earlier build (`coop_<game>_campaign.json`) moves there by
itself and is listed as FIRST CAMPAIGN. To back a campaign up, copy its file;
to delete one, delete its file.

**To carry on where you left off**, the host picks that campaign and presses
Host on the same device, and the others press Join with the host's address:
everyone gets their own trainer back, with their team, bag and place. A
device remembers who it played as in each campaign; a player joining from
another device or address gets their trainer back by typing the same name as
before. Only the campaign the host picked is played: the others see its name
at the top of the CO-OP menu (START > CO-OP).

## The opening

Everyone who plays the opening plays it in their own world, at the same time
or one after another:

- Oak asks for your name and already knows it from the Co-op tab. The rival's
  name is asked only until somebody has named him; after that Oak remembers
  it for everyone.
- Each player wakes up in their own bedroom and plays the opening alone: you
  do not see each other, and nobody else sees you, until you have left Oak's
  lab with your starter. Then you meet in Pallet Town.
- Oak, the three POKé BALLs and the rival are yours alone: you can both take
  CHARMANDER. The rival's fight in the lab is yours alone too: nobody can join
  it.
- Once you leave the lab with your starter, the campaign's story is yours: the
  same shared flags, badges and beaten trainers as everyone else's. The rival
  keeps the starter he took in the first opening to finish. Someone still in
  the opening shows in the CO-OP menu's list but not in the world.

## Playing over the internet

- **Same version, same cartridge.** Both players run builds made from the same
  version of this project, and import Red or Blue of the same language: Red
  with Red or Blue, Rote with Rote or Blaue Edition. Each world has its own
  cartridge's wild Pokémon and Game Corner prizes, so trade the exclusives. The
  host checks both and the Co-op tab says which one failed.
- **Easiest: a VPN you are both on** (WireGuard or the like). The
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
  in a battle, and blocks your way like any person on the map.
- Story flags, badges, beaten trainers and taken items on the ground are
  shared. Your team, PC, bag, money and position are yours.
- Every item one player finds or is given along the story reaches the other
  too, in the same number: POKé BALLs on the ground, presents from people,
  key items, HMs and TMs. A key item the story takes (OAK's PARCEL, the BIKE
  VOUCHER, the GOLD TEETH) is taken from everyone; fossils are not, so each of
  you revives your own. What you buy, trade for or use stays yours. Hidden
  items are each player's own to find.
- **Saving**: START > SAVE saves the whole campaign, everyone in it. You see
  "Campaign saved." and the others see "BLUE saved the campaign."; a save
  refused during a battle says so. The host also saves by itself after
  battles, every thirty seconds of changes and when it closes, and START > CO-OP
  shows when it last saved. Nobody has to save before leaving.

## Battles

- **START > CO-OP** (or SELECT on the map) says where your partner is ("BLUE
  ROUTE 1") and when the campaign was last saved, and lists the battles you
  can join from any map, REJOIN and LEAVE SESSION.
- Wild and trainer battles your world starts are fought on the host, so the
  partner can join; their window says so ("RED is in a battle against wild
  RATTATA. START > CO-OP to join."), and also when a player joins or leaves.
- A battle uses the game's own screen and menus: FIGHT, PKMN, ITEM, RUN. A
  shared battle is one Pokémon a side, with both teams on your side (up to
  twelve) in the PKMN list; the text box names whose Pokémon the cursor is on.
  Whoever owns the Pokémon that is out decides ("RED decides" on the left of
  the menu); switching to the partner's Pokémon hands them the turn.
- When it is your partner's turn you still move through the menus: where your
  cursor rests is a suggestion, shown on their screen as a hollow ▷ on the
  menu and on the row, and spelled out in their text box while they wait
  ("BLUE suggests / EMBER"). It never acts by itself.
- After choosing a ball you pick whom the catch is for.
- If the deciding player drops, the battle waits. After thirty seconds the
  others are asked "Take over?": YES decides for that player's Pokémon until
  they are back, NO goes on waiting. Nobody plays your Pokémon unless they
  choose to.
- If you joined a partner's battle, RUN asks whether to leave: YES takes you
  back to your world. Your Pokémon stay in the fight under the partner and
  keep what they earn, so you cannot start another battle until it ends;
  REJOIN in START > CO-OP takes you back in. RUN in a battle your own world
  started flees as usual. A finished battle returns to the world by itself.
- On a phone the on-screen pad stays usable below the battle. While the
  CO-OP menu or a co-op battle is open you can also swipe over the game
  screen to move the cursor (one row per swipe of about a row) and tap to
  choose.
- A won battle pays every participant the whole prize. One EXP.ALL in anyone's
  bag shares experience over each player's own team, as it would alone.
- Gift Pokémon (EEVEE, LAPRAS, a HITMON, the MAGIKARP for sale, fossils) can
  be had once by each player.
- Evolutions and the whiteout after a loss happen in each owner's own world.

## Battle a friend

Talk to the other player and choose BATTLE, or open START > CO-OP and choose
BATTLE followed by their name (SELECT also opens it). They receive a YES/NO
invitation when their current scene ends; B or no answer for 30 seconds
means NO. Both players choose their own moves, switches and replacements.
RUN forfeits; items are unavailable. Afterwards both teams recover full HP,
PP and status at their original positions, with experience for the opponents
each Pokémon faced. No prize or whiteout occurs.

## Trading

Talk to the partner and choose TRADE, or choose TRADE and their name from
START > CO-OP. After they accept, both see the normal trade screen wherever
they are. Select a Pokémon, select TRADE, advance the text and confirm TRADE.
To leave, move below your party to CANCEL and press A; both return to their
worlds in place. A disconnected player also ends the direct pairing.


Both players go to a Pokémon Center's Cable Club receptionist, enter the Trade
Center, sit at the table facing right and press A. The trade screen shows the
partner's real party; trade-evolving Pokémon evolve on arrival.

## Leaving

LEAVE SESSION in START > CO-OP asks YES/NO, then returns you to the launcher's Co-op tab,
which says "You left the session.". When the host leaves, everyone is told why
and returned to the Co-op tab, which says so again. A dropped
connection is retried for about two minutes ("Lost the host: reconnecting...",
then "Back in the session."), so a host that restarts or a phone that comes
back from the background picks up where it was.

## Logs

Every session is written to a file on your device, in `coop_logs` in the
game's data folder: the Co-op tab's "Open the logs folder" opens it. On Linux it
is `~/.local/share/godot/app_userdata/pokerecomp/coop_logs`, on Windows
`%APPDATA%\Godot\app_userdata\pokerecomp\coop_logs`. The last 30 sessions are
kept. With "Share debug logs with the other players" on (the default), your file
also gets the other players' lines, so one file usually shows the whole session;
turned off, your device neither sends nor receives them. To report a bug, send
the file for that session's date and time (`..._host_...` or `..._join_...`)
privately to whoever is debugging. The files hold player names, the host's
addresses and some of the game's own text, so never post them publicly.

## Known limits

- The host trusts each window's world (positions, warps, the wild Pokémon it
  rolled).
- Shared battles are drawn as the cartridge draws them, intro to prize.
- No phone or console builds yet.

See `progress.md` for what has been verified and how.
