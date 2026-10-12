# German wording for the owner to check

The German cartridges (Rote and Blaue Edition, #50, D95) draw almost all of
their text from the cartridge itself: dialogue, names, items, moves, menus.
The engine writes some lines itself, and those come from the table `UI` in
`game/gen1/gen1_layout_de.gd` (English on the left, German on the right).

On 2026-10-12 every German line in that table was searched for in the owner's
Rote Edition dump (each piece between placeholders and line breaks encoded with
the German charmap): 182 of the 217 lines and all 12 `WORDS` are the
cartridge's own text, word for word. Three are too short to tell (JA, OK, OK),
and two that were not found as one string are the naming screen's own pieces
("DEIN " / "GEGNER-" / "NAME?"), so they are the cartridge's too.

On the same day the table grew to 356 lines for the rest of the game (#50): the
battle, item, PC, Pokédex, trainer card, option and TM lines the engine still
wrote in English. Each new line was taken from pokered-de's text for the same
label and searched the same way in both dumps, Rote and Blaue Edition: 267 of
the 356 are found in each word for word. Seven more are the cartridge's
although the search cannot find them in one piece: TYP/ (the cartridge places
TYP and the "/" apart), BSG (the party list's fainted word, written letter by
letter), the two naming-screen titles, and three lines the table spells with
POKéMON where the cartridge stores its `#` code. The other 82 are the project's
own wording below.

The cartridge also decides some layouts, which German games now follow: the
SAVE box starts a column further left (SPIELER), every JA/NEIN box is a column
wider, the battle menu's right column starts at 12 (FLUCHT), the Safari menu's
at 11 (KÖDER), the PC menus are wider (`<PKMN>` FREILASSEN), the Cable Club's
cancel box is 12 wide (ABBRECHEN) and the STATUS page writes AP in letters.
"GLUMANDA ben. KRATZER!" is the cartridge's own `_UsedMove1Text`, not a cut.

The lines below are the project's own wording: co-op text that no cartridge
has. Write the better German in the last column and the next session puts it
in. Line breaks (`/`) matter: a box row is 18 characters at most, a menu row
fewer.

## In a battle

| English | German now | Where | Better German |
|---|---|---|---|
| %s joined / the battle! | %s kämpft / jetzt mit! | Battle text when a partner joins | |
| %s is / deciding... | %s / überlegt... | Battle text while the partner chooses | |
| %s is away. / Waiting... | %s ist weg. / Warte... | Battle text while the deciding player is gone | |
| %s is away. / Take over? | %s ist weg. / Übernehmen? | YES/NO after 30 s away | |
| Rejoin the / battle? | Wieder mit- / kämpfen? | YES/NO after leaving a battle | |
| Leave the battle? / Your team stays. | Kampf verlassen? / Dein Team bleibt. | RUN in a battle you joined | |
| Cancel joining / the battle? | Doch nicht / mitkämpfen? | RUN while a join is queued | |
| Who gets / %s? | Wer bekommt / %s? | After choosing a ball, with two players | |
| decides | wählt | Left of FIGHT/PKMN/ITEM/RUN: "RED / wählt" | |
| For | Für | Same box, choosing for an absent partner | |
| Joining / soon | Kommt / bald | Same box, a join waits for the next turn | |
| %s decides. | %s wählt. | Text box | |
| %s suggests | %s rät: | Text box: "BLUE rät: / SCHIGGY" | |
| %s's POKéMON | POKéMON: %s | Party list, whose Pokémon the cursor is on | |
| %s for %s | %s für %s | A ball suggestion with its recipient | |
| Items cannot be / used here. | Items sind hier / nicht erlaubt. | ITEM in a friend battle | |

## Friend battles and trades

| English | German now | Where | Better German |
|---|---|---|---|
| BATTLE | KAMPF | Menu when talking to the partner, START > CO-OP | |
| wants to battle! | möchte kämpfen! | "RED / möchte kämpfen!" | |
| wants to trade! | möchte tauschen! | "RED / möchte tauschen!" | |
| Invitation sent. | Anfrage gesendet. | After choosing KAMPF or TAUSCH | |
| Invitation: %s | Anfrage: %s | The answer: angenommen, abgelehnt, ... | |
| accepted | angenommen | | |
| declined | abgelehnt | | |
| timeout | abgelaufen | No answer in 30 s | |
| left | gegangen | The partner left the session | |
| partner busy | Freund beschäftigt | The partner is in a battle or trade | |
| no fit pokemon | Kein kampffähiges PKMN | A team with nobody able to fight | |

## START > CO-OP

| English | German now | Where | Better German |
|---|---|---|---|
| JOIN %s | HILF %s | Join a partner's battle | |
| VS %s | GEGEN %s | Second row: against whom | |
| REJOIN | WIEDER HELFEN | Back into a battle you left | |
| LEAVE SESSION | SITZUNG VERLASSEN | | |
| Leave the co-op / session? | Die Sitzung / verlassen? | Its YES/NO question | |
| IN A BATTLE | IM KAMPF | Where a partner is | |
| IN THE OPENING | AM ANFANG | A partner still in Oak's opening | |
| NO PARTNER YET | NOCH ALLEIN | | |
| NOT SAVED YET | NICHT GESICHERT | Last save | |
| SAVED JUST NOW | GERADE GESICHERT | | |
| SAVED %d SEC. AGO | GESICHERT: %d SEK. | | |
| SAVED %d MIN. AGO | GESICHERT: %d MIN. | | |

## START menu and boxes

| English | German now | Where | Better German |
|---|---|---|---|
| CO-OP | KOOP | START menu row and the CO-OP menu's title | |
| HOME | BEENDEN | START menu row back to the launcher | |
| quit this game? | Spiel beenden? | Its question, after "Möchtest Du das" | |
| MOVES | ATTACKE | START menu row for field moves (an option) | |
| You pressed the / RESET buttons. / Reset the game? | Du hast die RESET- / Tasten gedrückt. / Spiel neu starten? | The reset chord's one-time question | |
| Save failed: | Nicht gesichert: | SAVE refused, with the reason under it | |
| battle in progress / no save path / unknown | Kampf läuft. / Kein Speicherort. / Unbekannt. | The reasons | |
| %s was used. | %s / wurde eingesetzt. | An item with no other line | |
| You have no POKE BALLS! | Du hast keine / BÄLLE! | BALL with none left | |
| The capture could not be completed. | Das Fangen / schlug fehl. | A throw the world refused | |
| soon | bald | "Kommt / bald" left of the battle menu (was "gleich", which the German box cuts) | |

## Co-op messages over the world

Drawn in the window's own font, not the cartridge's, so any length fits.

| English | German now | Better German |
|---|---|---|
| %s joined the session. | %s ist der Sitzung beigetreten. | |
| %s left the session. | %s hat die Sitzung verlassen. | |
| %s is in a battle against %s. START > CO-OP to join. | %s kämpft gegen %s. Mitkämpfen: START > KOOP. | |
| … against wild %s | … gegen ein wildes %s | |
| %s is facing the rival here. Wait, or join from START > CO-OP. | %s trifft hier auf den Rivalen. Warte oder kämpfe mit: START > KOOP. | |
| Campaign saved. | Kampagne gesichert. | |
| %s saved the campaign. | %s hat die Kampagne gesichert. | |
| The campaign was not saved: %s. | Die Kampagne wurde nicht gesichert: %s. | |
| The session ended: %s. | Die Sitzung ist beendet: %s. | |
| host shutdown / host unreachable / ended / refused: content mismatch / refused: protocol mismatch | der Host hat sie geschlossen / Host nicht erreichbar / beendet / andere Edition / andere Programmversion | |
| Back in the session. | Wieder in der Sitzung. | |
| Lost the host: reconnecting... | Host verloren: verbinde neu... | |
| The battle you left was won. / was lost. / ended in a catch. / is over. | Der Kampf, den Du verlassen hast, ist gewonnen. / ist verloren. / endete mit einem Fang. / ist vorbei. | |

## Refusals in a co-op battle

Shown in the battle's text box, wrapped at 18 characters.

| English | German now | Better German |
|---|---|---|
| It is not your turn. | Du bist nicht am Zug. | |
| The battle moved on; try again. | Der Kampf ging weiter. Nochmal! | |
| The battle is waiting for a player to come back. | Der Kampf wartet auf einen Spieler. | |
| No room left for a catch. | Kein Platz für einen Fang. | |
| You can't catch a trainer's POKéMON! | Sei kein Dieb! (the cartridge's) | |
| Not saved: a battle is running. | Nicht gesichert: ein Kampf läuft. | |
| You are already in a battle. | Du kämpfst bereits. | |
| No room for more POKéMON in that battle. | In diesem Kampf ist kein Platz mehr. | |
| Someone is already fighting that. | Dagegen kämpft schon jemand. | |
| That battle is over. | Dieser Kampf ist vorbei. | |
| It won't have any effect. | Das hätte keinen / Effekt! (the cartridge's) | |
| None of your POKéMON can fight. | Keines Deiner POKéMON kann kämpfen. | |
| The campaign could not be saved. | Die Kampagne konnte nicht gesichert werden. | |
| Beaten already in this campaign: it counts as won. | In dieser Kampagne schon besiegt: zählt als gewonnen. | |
| Your own world started this battle: you stay in it. | Deine Welt hat diesen Kampf begonnen: Du bleibst dabei. | |
| Your POKéMON are still in a battle. | Deine POKéMON kämpfen noch. | |
| That move can't be used now. | Diese Attacke geht jetzt nicht. | |
| A partner met the rival first: the battle is one for both. | Ein Freund traf den Rivalen zuerst: Ihr kämpft zusammen. | |
| Refused: %s | Abgelehnt: %s | |

Still English in German windows: the launcher, its Co-op tab and its messages
(they serve every game and have no translation yet), the test host's own
encounter names in `tools/coop_session.gd` ("wild PIDGEY L5"), the Nuzlocke
rule lines, and failure lines for states a played game does not reach ("No
save is loaded.", "Purchase failed: …").
