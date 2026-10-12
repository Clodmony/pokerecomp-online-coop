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
| Joining / soon | Kommt / gleich | Same box, a join waits for the next turn | |
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

Still English in German windows: the toasts over the world ("BLUE joined the
session.", "RED is in a battle against wild ... START > CO-OP to join."), the
launcher's Co-op tab, and the engine literals listed as open on #50.
