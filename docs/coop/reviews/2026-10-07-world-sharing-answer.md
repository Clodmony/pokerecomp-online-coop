# Answer: how co-op shares the world

Reply to `pokerecomp-coop-world-sharing-review.md`, written by the agent
working on pokerecomp-coop, 2026-10-07. Code references are to
`coop/playthrough` at `9c730eb8` (pushed) unless they name
`coop/autoplay-surge` (`79eb3529`, pushed, not reviewed or merged yet).

**Short version:** adopt the rule, with changes. "Share what the cartridge
would save, never what it is doing right now" matches what the playthroughs
found. The review read `e567b78b`. Since then:
- P2 shipped as D67, with a 15 s cap.
- The Surge branch made two city script bytes per-player.

What is left is closing D67's cap gap, P3 for Vermilion Gym's locks, and a
short, owner-approved P4. Nothing below is recorded as a decision, and issues
#22, #24 and #25 are unchanged.

## Verdicts on C1–C7

| Claim | Verdict | Evidence |
|---|---|---|
| C1. A window pushes every dirty frame, whatever its scripts are doing | **Confirmed at `e567b78b`, refuted now** | D67 (`6320f060`): `PokeCoopWorldLink.advance()` neither pushes nor pulls while `_holding_world()` (`coop_world_link.gd:59-66, 77-83`); the session sets `link.hold_world = ... screen.world().script_busy()` (`coop_session.gd:270`). The hold lapses after `HOLD_MSEC` = 15 s (`coop_world_link.gd:8`), so a scene longer than that still leaks mid-scene patches. |
| C2. A window applies the host's changes mid-scene; no co-op code calls `script_busy()` | **Confirmed at `e567b78b`, refuted now** | The same hold covers pulls. Test: `test_a_window_in_a_script_takes_the_partners_story_once_the_script_ends`. |
| C3. `gen1_map_scripts` is the campaign's | **Confirmed on `coop/playthrough`; partly changed on `coop/autoplay-surge`** | `coop_ownership.gd:39` (`CAMPAIGN`). On the Surge branch the key is `BY_FLAG`, with `PLAYER_MAP_SCRIPTS` = `wCeruleanCityCurScript` (31) and `wVermilionCityCurScript` (58) per player (`coop_ownership.gd:18, 40, 206` there); about 120 other bytes stay shared. |
| C4. The campaign can store a mid-scene step the cartridge never saves | **Confirmed for scenes over 15 s, otherwise refuted by D67**; the cartridge half is right | Gen 1 scripts run as `world._gen1_steps` (`gen1_map_scripts.gd:245-246`, `_gen1_holding`), and START is not taken while they hold the player. Within the cap, a scene's steps reach the host only as its final, resting values. |
| C5. D51, D63's cost and a mid-scene drop share a root cause | **Confirmed, and wider than listed** | The Surge run found three more cases from the same cause, all from map-script bytes crossing windows: (1) Vermilion's dock sailor check looped forever, because a partner's window reset `wVermilionCityCurScript` to its default; (2) a partner's window replayed the Cerulean thief's after-battle script and its TM28 lines; (3) TM34 was handed out twice in one run of five, from Brock's after-battle script replayed in the partner's window (gym bytes are still shared). D63's cost is open: a partner arriving re-rolls Vermilion's first lock. |
| C6. `script_busy()` is a candidate rest-point signal | **Confirmed as good enough for the cases found; gaps listed under Q1** | `world_api.gd:4795-4799`: `_gen1_holding` or an active script or a queued one. It fixed the DOME FOSSIL (item and flag now leave in one patch, D67, seen in two windows). |
| C7. The host trusts patches; an opening's campaign half goes to a private copy | **Confirmed** | `coop_host.gd:455-458` (opening branch) and `463-469` (`apply_world`: story move, D62 `keep_once`, D52 sharing). |

## Answers to Q1–Q9

- **Q1. Is `script_busy()` the right signal?**
  - It is true for every Gen 1 step list: talks, item and gift scripts, map scripts, trainer engagement and its battle request (`gen1_map_scripts.gd:82`), Cut and boulder dust.
  - It is false while the player can't open START:
    - mid-step or mid-hop;
    - during a warp or map load (`gen1_map_load_pending`);
    - while a spinner or forced movement runs (`scripted_movement_in_progress`);
    - while a grass encounter waits on the takeover (there are no steps then).
  - None of those write campaign state mid-way, except the map-load rolls in Q5, so they are harmless for sharing.
  - It is true but a save would be harmless when a sign's text is open; that only delays.
  - **Proposed signal:** `script_busy()` plus "a map load is pending". The cap should be counted in rest points rather than seconds (see the plan).
- **Q2. A battle inside a scene.**
  - The script branches on the takeover's own result, not on a pulled flag: the battle request is a step, and its result picks the branch (`gen1_map_scripts.gd:811-817`, `_gen1_result`).
  - Holding pulls until the scene ends breaks nothing found so far.
  - Today's 15 s cap is what lets a long battle scene leak.
- **Q3. Item and flag in separate patches.**
  - Yes, they were separate. The Misty run found the DOME FOSSIL reaching one player only: the item came one frame, the flag after its text box.
  - One patch per scene fixed it (D67, `test_a_gift_given_before_its_scripts_flag_still_reaches_every_player`).
  - `keep_once` still works: a losing window's scene patch repeats the story, so its gains are taken back. Its whole scene counts as one race, which is the intent.
  - The doubled TM34 is the remaining hole: a replayed script whose patch sets no new flag. That is fixed by per-player or resting script steps (C3), not by D52 or D62.
- **Q4. Apply a partner's resting change to your own map at once?** Not always.
  - The Surge branch needed Vermilion Gym's door redrawn at the next map load when the partner opened the second lock (`51eb1b98`).
  - City script steps that follow one player's walk must not cross at all (dock sailor, thief).
  - Proposed rule: flags and items apply at once; a map-script step for the map you stand on waits for your next map load; per-walk steps stay per-player.
- **Q5. Other map-load rolls that differ per window.**
  - Known:
    - Vermilion Gym's first lock (D63; now shared but re-rolled by any window entering the city);
    - the Game Corner lucky slot (per player, which is fine);
    - NPC wandering and wild encounters (per window by design);
    - boulder positions in Seafoam and Victory Road (object positions per window, while their switch flags are the campaign's).
  - **Needs a run** to list the rest.
- **Q6. Hold in the window or a host transaction?**
  - Keep the hold in the window (shipped). It needs no protocol, and the partner never sees a half scene.
  - Crash cases:
    - **A window dropping mid-scene** loses the scene, which then replays: the Surge branch opens a reopened window on the host's story, as a Continue does (`7b5d06b9`).
    - **A host crash** is covered by D66's journal.
  - A host transaction (the opening's private copy) would add protocol for no case we have.
- **Q7. Do the logs show changes landing mid-scene?**
  - Yes, as outcomes in logged autoplay runs: the fossil, the dock loop, the thief replay and the doubled TM34 (`coop_log.gd summary` and the host logs of those runs).
  - Window logs record `world_pull` but not the busy state at that moment. Adding `busy` to `world_pull` lines would make this direct; that's a small change.
- **Q8. Is P4 the lock the owner asked for?**
  - Yes, it is the narrow form of D61's "lock a scripted NPC or gift while a window uses it". D62 settled gifts on the host instead.
  - The owner should confirm P4, because it changes what a second player sees: they wait, then see the result.
- **Q9. Brief wording.**
  - The brief asks for "authoritative maps, NPCs, interactions and player movement".
  - Closing #22 and #25 needs the owner to approve this wording: "the host is authoritative for the campaign (story, badges, beaten encounters, holdings) and for battles; each window simulates the maps, NPCs and movement it shows, and shares the campaign only at rest points."

## Verdict: adopt with changes

**Revised plan:**

1. **Rest points instead of a timer.** Replace D67's 15 s cap:
   - Hold until a rest point (`script_busy()` false and no map load pending), however long.
   - Push a partial patch only when the window must answer the host anyway (its world's SAVE, leaving), so a stuck scene can't stall the campaign forever.
   - Tests: a 40 s scene with a battle sends nothing until it ends; a scene interrupted by LEAVE sends its last resting state; the existing D52 and D62 tests pass.
2. **Map-script steps share their resting value only.**
   - With item 1, mid-scene steps already never leave the window.
   - Per-walk bytes are the player's (start from the Surge branch's two, then classify the gym bytes Brock to Giovanni, so a partner never replays a leader's after-battle lines).
   - A step for the map the window stands on applies at its next map load.
   - Tests: the Surge branch's three; Brock beaten by one player while the other stands in the gym gives one TM34; the Vermilion dock with both players in the city.
3. **P3, map handover on entry**, first case Vermilion Gym:
   - The host keeps the lock bytes while anyone is in the gym or city.
   - A window entering takes them instead of rolling.
   - Scenario: a partner enters mid-search and the cans stay.
4. **P4, only if the owner agrees**, scene by scene:
   - The first window in a contested scene (Route 22 rival, the S.S. Anne rival, the Silph Co rival) drives it.
   - A second window on that map is held, as in D54, until it ends, and sees the result.
   - Scenario: a window killed during the Route 22 rival scene, then the campaign checked and the scene replayed.
5. **`design.md`** states what is not shared: NPC wandering, a scene's animation in the partner's window, music, text boxes.
6. **Logs:** `world_pull` lines carry the busy state, so a later review can check this from evidence.

Order: 1 and 2 first (they close the bugs already found), then 3, then 4 if approved. The Surge branch should be merged before 2, since 2 builds on it.

## Decisions only the owner can make

1. **Adopt the rule** "share what the cartridge would save, never what it is doing right now"? This would be recorded as the next free D-number (D72 or later; D66 is taken by the journal).
2. **Brief wording for #22 and #25** (Q9): close #22 ("the host stays a hub and keeper of the campaign") and mark #25 won't-do ("windows roll encounters, the host fights them")?
3. **#24 and P4** (Q8): is "the first player in drives a contested scene, the partner waits and sees the result" the lock you asked for in D61, and should it apply to the rival scenes listed?
4. **Accepted costs:**
   - a partner sees a scene's result, not the scene;
   - a scene cut off by a disconnect replays from its start;
   - a long scene reaches the partner only when it ends;
   - windows stay trusted.
