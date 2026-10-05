# Brief

The repository owner's brief for the co-op project, kept verbatim below the line.
Where later decisions refine it, `decisions.md` says so.

---

Create a private GitHub development repository based on [https://github.com/Decryptu/pokerecomp](https://github.com/Decryptu/pokerecomp) and begin implementing the cooperative campaign described below.

Do the work: inspect the source, create the private repository, establish a practical issue backlog, and implement the first working milestone. Do not stop after producing a plan.

## Repository setup and privacy

- Use my authenticated GitHub account. Determine the account from the available tooling; ask only if the target owner is genuinely ambiguous.
- Preferred repository name: `pokerecomp-coop`.
- The repository MUST be private from creation.
- GitHub generally does not allow a private fork of a public repository. Verify the available options. If necessary, create a new private repository containing the upstream Git history instead of using GitHub’s fork feature.
- Preserve upstream history, license files, notices and attribution.
- Set my private repository as `origin` and the original project as `upstream`.
- Record the exact upstream commit used.
- Verify repository visibility before pushing.
- Never push changes to upstream or publish public releases, Pages sites, packages or artifacts.
- Do not overwrite an existing repository or force-push over existing work.
- Keep ROMs, extracted copyrighted assets, personal saves, credentials and local caches out of commits and CI artifacts.
- Inspect what the upstream repository actually tracks; do not assume that its branding or license statement establishes the provenance of every file.

Use feature branches and private pull requests for review. You may create the repository, issues, branches and draft pull requests without asking me for repeated confirmation.

## Product goal

Build a full cooperative Pokémon Red/Blue campaign, initially for two players.

Players share story progression and Gym badges but each owns their Pokémon team, inventory, money and position. Both can explore independently, including different maps.

A player can enter a battle while the other continues exploring or starts a separate battle. A player who is not already fighting can join an ongoing battle.

Shared battles retain the original one-active-Pokémon-per-side format:

- Both participating players’ Pokémon become available.
- With two full teams, the allied roster can contain twelve Pokémon.
- The active Pokémon’s owner controls the turn.
- Switching to the other player’s Pokémon transfers control.
- The other participant can move an advisory cursor and indicate a suggested action.
- Suggestions never execute an action or consume a turn.
- Joining takes effect at a safe turn boundary.
- No player or Pokémon may participate in two battles simultaneously.
- Shared story victories and badges advance the campaign for both players.

This is cooperative play against the game, not merely trading or PvP link battles.

## Working gameplay defaults

Implement these defaults unless source constraints require a documented alternative:

- Allow joining an ongoing fight from another map through a session menu.
- Suspend the joining player’s exploration and preserve their return location.
- The initiating player stays attached to the encounter location.
- Each player retains ownership of their Pokémon.
- Items come from the explicitly acting player’s inventory.
- Captures go to one explicitly selected player; never duplicate a caught Pokémon.
- Track experience participation per Pokémon and apply rewards to the correct owner.
- Unique trainers, bosses and story encounters can only have one active instance in a campaign.
- Major progression changes commit once, even if network messages repeat.
- For the initial prototype, loss of a required battle controller pauses that battle while another player’s exploration can continue.
- Host shutdown ends the session cleanly. Host migration is outside the initial scope.

Document unresolved rules such as prize splitting, withdrawal and late-campaign onboarding, choose sensible provisional behaviour, and keep those policies separate from core simulation.

## Platforms and distribution

Design for Windows, Linux, Android and iOS clients with cross-platform multiplayer.

Prioritize Windows/Linux development and hosting. Keep mobile input and lifecycle requirements in the architecture from the beginning.

- Use host-authoritative gameplay.
- Start with LAN/direct-IP connections.
- Plan for mobile suspend/resume and reconnection.
- Do not require a paid relay or external service for the first milestone.
- Dedicated servers, internet relays, local split-screen and host migration are later milestones.
- iOS App Store acceptance is an open investigation, not a promised outcome.
- Do not publish anything to an app store.
- Keep executable mod loading outside the initial iOS scope.
- German ROM support is a later issue, not a prerequisite for the first milestone.

## Validate the source before designing around it

A previous source review of PokeRecomp commit `696d1c9` found these useful starting points. Recheck them against the actual checkout:

- `game/battle/battle.gd` contains a scene-independent battle model with injected randomness and turn events.
- `game/world/world_api.gd` exposes world logic separately from its screen, but owns one player position and current map per instance.
- `game/world/world_state.gd` holds event flags and other mutable state, including some personal state that must not become shared accidentally.
- `autoload/game_runtime.gd` owns one selected mutable save.
- `game/world/world_screen.gd` orchestrates one active battle screen and associated save.
- `game/battle/party.gd` rejects parties larger than six.
- Save adapters and battle reward handling assume one player.
- Many classes have `Gen2` names even where the implementation also supports Gen1.

Treat these as review leads, not proof that multiplayer will work without refactoring. Check global state, mod hooks, random generators, screen-driven progression and save mutations.

Retain Godot PokeRecomp unless you find a concrete blocking problem. Do not switch engines or rewrite the entire game merely for architectural preference.

## Architecture

Introduce clear ownership boundaries, adapting names to repository conventions:

1. Campaign state:
   Shared story flags, badges, unique encounter status and campaign identity.

2. Player state:
   Stable identity, Pokémon ownership, inventory, money, location and connection state.

3. World simulation:
   Authoritative maps, NPCs, interactions and player movement, independent of local menus and battle presentation.

4. Battle sessions:
   Stable session ID, participants, Pokémon roster, controller, random generator, turn state and pending join requests.

5. Client presentation:
   Local input, menus, animation and advisory cursors.

6. Persistence:
   Versioned campaign saves containing shared and individual state.

The host validates commands and resolves outcomes. Clients display authoritative results.

Reuse the existing battle calculations and data import pipeline wherever practical. Do not combine two saves into a fake twelve-member single-player save. Keep each player’s team limit at six and introduce an ownership-aware battle roster.

Use player, Pokémon, encounter and battle IDs rather than relying on array positions as permanent identity.

Separate transient UI suggestions from authoritative commands. Include turn/revision identifiers where needed to reject stale or repeated actions.

Do not transmit ROMs or extracted game assets between players. Each client imports compatible content locally.

## GitHub issues and project documentation

Create a coherent GitHub issue backlog with milestones covering:

- Baseline builds and upstream maintenance.
- Campaign/player state separation.
- Networking and session lifecycle.
- Shared exploration and map simulation.
- Concurrent battles and cooperative turn ownership.
- Mid-battle joining and reconnection.
- Shared story, badges and unique encounter handling.
- Captures, rewards, evolution and player services.
- Campaign persistence and recovery.
- Co-op interface and input.
- Windows/Linux builds and mobile clients.
- Integration tests, campaign playthroughs and release readiness.
- Optional German support, relays and dedicated servers.
- Code/content provenance and iOS distribution feasibility.

Give immediate milestone issues concrete descriptions, dependencies and acceptance criteria. Later issues can be concise but must identify real deliverables. Avoid hundreds of empty placeholder issues or duplicate issues.

Create and maintain:

- `AGENTS.md`: development instructions and verification commands.
- `docs/coop/design.md`: agreed behaviour and ownership rules.
- `docs/coop/architecture.md`: current architecture and planned changes.
- `docs/coop/progress.md`: implemented, verified, incomplete and blocked work.
- `docs/coop/decisions.md`: architectural decisions and trade-offs.

Preserve existing documentation and instructions rather than replacing them blindly.

## First implementation milestone

Deliver a small end-to-end multiplayer slice that proves the difficult parts:

1. Two client instances connect to a host.
2. Each controls a separate player and can see the other when on the same map.
3. One player starts a battle while the other continues exploring.
4. The second player can start an independent battle.
5. A free player can request to join the first player’s ongoing battle.
6. Joining occurs at the next safe turn boundary.
7. Both owners’ Pokémon appear in the shared roster.
8. Switching Pokémon transfers turn control to its owner.
9. The other player’s advisory selection is visible without executing it.
10. Battle results update the correct Pokémon and player records.
11. A representative trainer victory updates a shared campaign flag exactly once.
12. Saving and reloading at a safe checkpoint preserves both players and shared progress.

Build this incrementally in reviewable commits. Begin with the smallest useful state separation and session skeleton, then connect real gameplay.

If completing the whole slice requires more than the available execution window, finish the largest coherent working increment, commit it and document the exact next steps. Do not claim the milestone is complete until its acceptance criteria work.

## Testing and validation

First establish what builds and tests already work.

Add targeted tests for:

- Isolation between simultaneous battle sessions.
- Combined rosters larger than six without changing individual team limits.
- Turn authority following Pokémon ownership.
- Suggestions never mutating authoritative battle state.
- Joining only at valid boundaries.
- Prevention of duplicate participation and rewards.
- Shared story changes with independent player locations.
- Save round-tripping and disconnect behaviour.

Run a two-client integration check when the environment permits. Use synthetic fixtures or original test content where possible. If a real ROM is needed, ask me to supply it locally; never download one.

Distinguish between static inspection, passing unit tests, a successful build and verified multiplayer gameplay. Never report an untested platform or feature as working.

## How to proceed

Start by checking the workspace, repository instructions, GitHub authentication and installed tools. Then perform the authorized setup and implementation.

Ask only when a missing credential, ambiguous repository owner or indispensable user-provided file blocks progress. Continue all unblocked local work if remote access is unavailable.

At the end, provide:

- The private GitHub repository URL and verified visibility.
- The upstream baseline commit.[https://github.com/einstein95/pokered-de/](https://github.com/einstein95/pokered-de/)
- Milestone and draft pull request links.
- What is implemented and how to run it.
- Tests and builds actually executed.
- Known limitations and the next concrete implementation step.
