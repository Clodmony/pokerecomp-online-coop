# Readiness checklist for private builds

What to run and check before handing a private co-op build to the players
(#49). Nothing here publishes anything.

## Automated, on the commit being built

- [ ] Import and class scan: `godot --headless --editor --path . --quit`.
- [ ] Whole suite: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
      exits 0 with every test passing (the co-op suites include the fuzz test
      and the real-socket device tests).
- [ ] ENet demo: `godot --headless --path . -s res://tools/coop_session.gd -- demo`
      reports all steps passed.
- [ ] Boot smoke: `godot --headless --path . --quit-after 30` with no errors.
- [ ] Release gates: `tools/release.sh --gates`.

## By hand, two devices on one network, each with its own imported cartridge

The full list, with what already covers each case, is in
[test-cases.md](test-cases.md); the short round below is the minimum.

- [ ] Host from the Co-op tab with a new campaign; join from the other device
      by the listed address. Both worlds open in Pallet Town with the chosen
      starters.
- [ ] Walk together; each sees the other move. Walk onto different maps.
- [ ] Start a wild battle in one world; join it from the other through SELECT.
      Take turns, suggest a move, switch to the partner's Pokémon.
- [ ] Throw a ball for the partner; the catch lands in their party or PC.
- [ ] Beat a trainer together; the badge or flag shows in both worlds.
- [ ] Use a Pokémon Center, a Mart and the PC in each world.
- [ ] Trade at a Cable Club, including a trade evolution if one is at hand.
- [ ] Save from the game's START menu; close and reopen both; the campaign and
      each player come back as they were.
- [ ] Close the joining window mid-battle; the battle waits, then the host side
      may decide for it; reopen and take it back.
- [ ] LEAVE SESSION on the host; the joiner is told and returns to the
      launcher.

## Before giving out a build

- [ ] Export templates for the pinned engine are installed locally
      (`~/.local/share/godot/export_templates/4.8.dev7/`, the stock
      `Godot_v4.8-dev7_export_templates.tpz` checked against the release's
      `SHA512-SUMS.txt`); the build stays private.
- [ ] `GODOT=godot tools/verify.sh --builds=builds` on a clean tree passes:
      both builds come from one commit (a `git archive` of HEAD, so the co-op
      protocol matches and nothing untracked, no cartridge or cache, is in
      them), the Linux build boots headless and the Windows build under Wine,
      and each is zipped with `BUILD.txt` (version, protocol, commit) and
      `docs/coop/playing.md` (same cartridge, VPN or the forwarded port,
      SmartScreen) as `builds/pokerecomp-<branch>-<commit>-{linux,windows}.zip`.
      Exported builds ignore `-s`; scripted checks use the editor binary.
- [ ] No ROM, extracted asset, save or screenshot with cartridge graphics is
      attached anywhere public.
- [ ] `progress.md` lists what was verified for this build, by which run.
