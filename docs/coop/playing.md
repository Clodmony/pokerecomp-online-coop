# Playing co-op

How two people play a Red or Blue campaign together with this fork. Each
player needs their own copy of the game imported on the Play tab; nothing from
the cartridge is sent between devices.

## Starting

1. Open the launcher and go to the **Co-op** tab. Its first screen shows your
   cartridges: **Ready**, **Re-import on Play** (imported, but this version
   cannot read it: import it again on the Play tab) or **Not imported**. Pick
   the one you play with; the line under them says which games play together
   (Red with Blue, Rote with Blaue Edition). The tab remembers your pick.
2. One player presses **HOST**. Each of the device's campaigns for that
   cartridge and for the other game of its pair is a card with the game it was
   started on ("Rote campaign"), its players, the cartridge each plays, badges,
   place and last save: a Blaue cartridge hosts a Rote campaign too, and its
   file stays in Rote's folder. Pick one and press **Host <name>**, or press
   **+ New campaign**: name it, choose the rival's name (one of the cartridge's
   own three, typed, or **Ask in Oak's speech**), type your name and choose how
   you start (below), then **Create and host**.
3. The **Hosting** screen shows the addresses others join at, each labelled by
   network (a VPN such as wg0 first, then the home network) with a **Copy**
   button, and the players as they join. Press **Enter the world** whenever you
   like; partners can join later too, and START > CO-OP shows the address
   (`IP ...`) for as long as you host.
4. The other player presses **JOIN**. Hosts on the same Wi-Fi or LAN appear
   under **Nearby** by themselves, with one button for each of your cartridges
   that fits ("Join with Blaue"); a host none of them fits says why. Over a VPN
   or the internet, type the address under **By address** (with `:port` if the
   host uses another port than 24680), or pick it from **Recent**.
5. Before anyone joins, the game asks the host about its campaign: the
   **Connecting** sheet shows each step (host found, same version, cartridges
   fit). A device the host knows sees **Join as <name>**; a new player names
   themself and chooses how they start, then presses **Join as <name>**.

How a new player starts:

- **Play Oak's opening** (the default): Oak's speech, your bedroom, Oak
  stopping you at the grass, his lab, your starter and the rival's challenge,
  as in the cartridge. See "The opening" below.
- **Start in Pallet Town** with one of the three starters, level 5, and 3000
  money.
- **Bring a trainer from a save**, if the cartridge has a single-player save on
  this device: that trainer's team, PC, bag, money and place. The first player
  of a new campaign who brings a save brings its story and badges too.

If nothing answers, the sheet keeps trying every few seconds for a minute (a
partner often presses Join before the host is ready), counts the time down and
lists what to check for that address: a VPN address gets VPN advice, a home
address the same Wi-Fi and the Windows firewall, a public address port
forwarding. **Try now** dials at once; **Cancel** or B stops. A host on another
version, or a cartridge that cannot play with the host's, is named exactly,
with the one of your cartridges that would fit.

The start screen's **Last session** row hosts your last campaign again, or
joins the host you last joined, in one press. Y (C on a keyboard) opens
**Troubleshooting**: the debug log switch and the logs folder.

Each campaign is its own file on the host's device, so a run with one friend
never overwrites a run with another: start a new campaign for each group.
The files are in the game's user folder under `coop_campaigns/<game>/`, each
with the checkpoint before the latest beside it as `<file>.json.bak`. A
campaign from an earlier build (`coop_<game>_campaign.json`) moves there by
itself and is listed as FIRST CAMPAIGN. Y on a campaign card (or a right click
or a long press, or **Rename or delete**) renames the campaign or its rival;
the new rival's name applies the next time the campaign is hosted.
**Delete campaign…** asks again and keeps the campaign's last state beside
the others as `<file>.json.bak`, which can be renamed back.

**To carry on where you left off**, the host picks that campaign and presses
Host on the same device, and the others join it again: everyone gets their own
trainer back, with their team, bag and place. A device remembers who it played
as in each campaign; a player joining from another device or address gets
their trainer back by typing the same name as before. Only the campaign the
host picked is played: the others see its name at the top of the CO-OP menu
(START > CO-OP).

On a phone held upright the tab is one column: the cartridges scroll sideways,
the screen's main button sits at the bottom, sheets rise from the bottom and
the address field opens the number keypad. Nearby needs the platform to allow
local network broadcast; where it does not, the address path still works.

With several controllers plugged in, every one of them plays until you pick
one under Settings > Controls > **Controller**; then only that one does, two
of one model show as (1) and (2), and an unplugged pick is taken back when it
is plugged in again. The keyboard and mouse always work. With only a
controller, press A on a field of the Co-op tab: keys open under it (digits
for the address), each key types at once, and B or **Done** goes back.

## The opening

Everyone who plays the opening plays it in their own world, at the same time
or one after another:

- Oak asks for your name and already knows it from the Co-op tab. The rival's
  name is asked only until somebody has named him (or the host named him when
  creating the campaign); after that Oak remembers it for everyone.
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

## Split screen on one PC

On Linux or Windows, two players can share one computer: press **Split
screen** on the Hosting screen, then pick **Side by side** (the default) or
**Top and bottom**. The window moves to the left (or top) half of the screen
and a second window opens on the right (or bottom), already joining the
session; the second player names themself there and joins as usual. Together the
halves cover the whole screen, the taskbar too where the system lets a window
cover it. On KDE Plasma it does not: set the panel to Auto hide (or Windows
can cover) first, or it stays visible below the game.

Before the second window opens, **Who plays where?** asks each half's player
to press A on their controller, or Enter to play by keyboard (one half
only). The controller picked in Settings > Controls plays on the left (top)
half without asking. Each half then hears only its own controller, so a controller nobody
pressed, a virtual one included, moves neither player. With no controller
plugged in, both halves play by keyboard, each while it has the focus. The
halves stay above other windows while you play. The second half remembers its
player, so the same trainer comes back next time. The layout picked is offered
first the next time you split, until the game closes.

**Quitting.** SELECT > **QUIT BOTH** (on either half) saves the campaign and
closes both windows; so does closing the host's (left or top) window. To play
on alone, the second player picks LEAVE SESSION: their window closes and the
host's gets its own size back. LEAVE SESSION on the host's half ends the
session for both and goes back to the Co-op tab.

## Playing over the internet

- **Same version, same cartridge.** Both players run builds made from the same
  version of this project, and import Red or Blue of the same language: Red
  with Red or Blue, Rote with Rote or Blaue Edition. Each world has its own
  cartridge's wild Pokémon and Game Corner prizes, so trade the exclusives. The
  host checks both before anyone joins and the Connecting sheet says which one
  failed.
- **Easiest: a VPN you are both on** (WireGuard, Tailscale or the like). The
  host's Hosting screen lists each address with the network it belongs to,
  for example `10.0.0.1` on wg0, and marks the one a partner used last time;
  the other player joins the VPN one. No router setup is needed and it works
  behind any NAT.
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
- **Finding each other**: while the partner is off your screen, a small
  arrow in their colour blinks on the screen's edge and points at them. When
  they went through a door, up or down stairs or onto the next route, the
  arrow stands over that door or points the way to it; inside a building it
  stands over the way out. START > CO-OP > TOWN MAP (and the TOWN MAP item)
  shows their icon in their colour where they are.
- Hold **B** while walking to run at the bike's pace. The bike and surfing
  keep their own speed.
- Story flags, badges, beaten trainers and taken items on the ground are
  shared. Your team, PC, bag, money and position are yours.
- Every item one player finds or is given along the story reaches the other
  too, in the same number: POKé BALLs on the ground, presents from people,
  key items, HMs and TMs. A key item the story takes (OAK's PARCEL, the BIKE
  VOUCHER, the GOLD TEETH) is taken from everyone; fossils are not, so each of
  you revives your own. What you buy, trade for or use stays yours. Hidden
  items are each player's own to find.
- **Wild Pokémon from both versions** (a switch in New campaign and Edit
  campaign, off by default): where the other version has a Pokémon in the same
  place and slot that your version never has in the wild (such as MAUZI or
  KNOFENSA in Rote, MENKI or MYRAPLA in Blaue), half the wild Pokémon met in
  that slot are that one, at the slot's level. Everything both versions have
  keeps your cartridge's odds. It needs a player of each version in the session, since
  each device only knows its own cartridge's tables; until one joins, the
  Hosting screen says which version it waits for and everyone meets their own.
  Fishing, the Game Corner's prizes and the in-game trades stay your own
  version's.
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
- A question about one Pokémon goes to its owner: which Pokémon replaces it
  after a faint, which move it forgets for a new one (even while your
  Pokémon is out), which move its MIMIC copies. Your partner sees the same
  list and may point at an answer.
- After choosing a ball you pick whom the catch is for.
- With BATTLE STYLE SHIFT in your OPTION menu, a trainer about to send out its
  next Pokémon asks "Will RED change POKéMON?" whenever your Pokémon is out;
  your partner's own setting decides for theirs. With SET you are not asked.
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
invitation when their current scene ends and they are back on the map, out of
every menu; B or no answer for 30 seconds
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
game's data folder: "Open the logs folder" under Troubleshooting (Y on the
Co-op tab) opens it. On Linux it
is `~/.local/share/godot/app_userdata/pokerecomp/coop_logs`, on Windows
`%APPDATA%\Godot\app_userdata\pokerecomp\coop_logs`. The last 30 sessions are
kept. With "Share debug logs" on (the default), your file
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
