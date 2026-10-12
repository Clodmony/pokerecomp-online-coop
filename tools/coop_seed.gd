extends "res://tools/preview_world_story.gd"

## A two-player co-op campaign at a point of the Generation 1 story, the `SEED=<out dir>` of tools/coop_screens.sh:
##   Godot --headless --path . -s res://tools/coop_seed.gd -- <game> <last leg>|list <out dir> [level=<n>] [party=<n>] [both]
## walks preview_world_story.gd's legs through <last leg>, the party filled to party= lead copies and grown to level=; p1 imports it, p2 a copy;
## `both` turns on wild Pokémon from both versions (D104).

const SIDES: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var legs: Array = _gen1_story_legs().map(_leg_name)
	if args.has("list"):
		print("\n".join(legs))
		quit(0)
		return
	if args.size() < 3 or not legs.has(args[1]):
		push_error("usage: <game> <last leg>|list <out dir>; legs: %s" % ", ".join(legs))
		quit(2)
		return
	if PokeToolPath.refuses(args[2]):
		quit(2)
		return
	var data: GameData = GameData.open(StringName(args[0]))
	if data == null or data.generation != RomRegistry.GEN1:
		push_error("coop seed: no imported Generation 1 cache for %s" % args[0])
		quit(1)
		return
	var options: Dictionary = {"level=": 0, "party=": 0}
	for arg: String in args.slice(3):
		for key: String in options:
			if arg.begins_with(key):
				options[key] = int(arg.trim_prefix(key))
	quit(_seed(data, args[1], args[2], options["level="], options["party="], args.has("both")))


func _seed(data: GameData, last: String, out_dir: String, level: int = 0, party: int = 0, both: bool = false) -> int:
	var story: Dictionary = _gen1_story_start(data)
	if not story.has("world"):
		push_error("coop seed: %s" % story.get("reason", ""))
		return 1
	var world: Gen2WorldAPI = story["world"]
	var save: Gen2SaveData = story["save"]
	var path: Array = []
	var began: int = Time.get_ticks_msec()
	for leg: Callable in _gen1_story_legs():
		var walked: Dictionary = leg.call(world, save, story["random"], data, path)
		print("coop seed: %s at %.1f s" % [_leg_name(leg), (Time.get_ticks_msec() - began) / 1000.0])
		if not bool(walked.get("ok", false)):
			push_error("coop seed: %s" % walked.get("reason", ""))
			return 1
		if _leg_name(leg) == last:
			break
	if world.gen1_step_out_of_door() and not bool(_gen1_settle(world, save, story["random"], data).get("ok", false)):
		push_error("coop seed: no rest after stepping out of the door")
		return 1
	save.world = world.snapshot()
	fill_party(data, save, party)
	if level > 0:
		_raise(data, save, level)
	var written: Error = write_seed(data, save, out_dir, _beside(world), both)
	print("coop seed: %s on %s %s, badges %d, party %d, %s" % [
		last, world.map_id(), world.player_cell, world.state.badge_count(), save.party.size(), error_string(written)])
	return 0 if written == OK else 1


static func _raise(data: GameData, save: Gen2SaveData, level: int) -> void:
	var editor := Gen2SaveEditor.new()
	editor.data = data
	editor.save = save
	for mon: Gen2SaveMon in save.party:
		editor.set_level(mon, level)
		var known: Array = data.moves_at_level(mon.species, level)
		for slot: int in Gen2SaveMon.MAX_MOVES:
			editor.set_move(mon, slot, int(known[slot]) if slot < known.size() else Gen2SaveEditor.NO_MOVE)
		mon.hp = editor.max_hp_for(mon)


static func fill_party(data: GameData, save: Gen2SaveData, size: int) -> void:
	var editor := Gen2SaveEditor.new()
	editor.data = data
	editor.save = save
	var lead: Gen2SaveMon = save.party.front() if not save.party.is_empty() else null
	var used: Array = save.party.map(func(held: Gen2SaveMon) -> int: return held.dvs)
	var top: int = Gen2Stats.MAX_DV
	for special: int in range(top, -1, -1):
		if lead == null or save.party.size() >= mini(size, Gen2SaveData.MAX_PARTY):
			return
		if used.has(Gen2Stats.pack_dvs(top, top, top, special)) \
				or not bool(editor.add_party_member(lead.species, lead.level).get("ok", false)):
			continue
		var mon: Gen2SaveMon = save.party.back()
		editor.set_dvs(mon, top, top, top, special)
		mon.hp = editor.max_hp_for(mon)
		used.append(mon.dvs)


static func _leg_name(leg: Callable) -> String:
	return String(leg.get_method()).trim_prefix("_gen1_").trim_suffix("_leg")


static func _beside(world: Gen2WorldAPI) -> Vector2i:
	for side: Vector2i in SIDES:
		var cell: Vector2i = world.player_cell + side
		if world.can_walk_to(cell) and world.warp_at(cell).is_empty():
			return cell
	return world.player_cell


static func write_seed(data: GameData, save: Gen2SaveData, out_dir: String, partner_cell: Vector2i, both: bool = false) -> Error:
	var campaign := PokeCoopCampaign.create(String(data.id), data.id, data.sha1)
	PokeCoopPolicy.start_campaign(campaign)
	campaign.both_versions = both
	campaign.rival_name = save.world.rival_name
	var players: Array = []
	for trainer: int in [save.player_id, save.player_id % 0xFFFF + 1]:
		var id: String = campaign.take_player_id()
		var player := PokeCoopPlayer.create(id, id.to_upper(), trainer)
		var own: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
		own.player_id = trainer
		for mon: Gen2SaveMon in own.party:
			mon.ot_id = trainer
			mon.original_trainer = player.name
		PokeCoopPolicy.import_save(own, player, campaign if players.is_empty() else null,
			PokeCoopOwnership.badge_flags(data), PokeCoopPolicy.own_entries(data))
		players.append(player)
	(players[1] as PokeCoopPlayer).cell = partner_cell
	var folder: String = ProjectSettings.globalize_path(out_dir)
	var target: String = folder.path_join(PokeCoopSession.campaign_path(data).trim_prefix("user://"))
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var port: int = PokeCoopEnetTransport.DEFAULT_PORT
	var known: Dictionary = {
		"%s/host:%d" % [data.id, port]: {campaign.campaign_id: "p1"},
		"%s/127.0.0.1:%d" % [data.id, port]: {campaign.campaign_id: "p2"},
	}
	var identity: FileAccess = FileAccess.open(
		folder.path_join(PokeCoopSession.identity_path.trim_prefix("user://")), FileAccess.WRITE)
	if identity == null or not identity.store_string(JSON.stringify(known, "\t")):
		return ERR_FILE_CANT_WRITE
	identity.close()
	return PokeCoopSave.write(target, campaign, players)
