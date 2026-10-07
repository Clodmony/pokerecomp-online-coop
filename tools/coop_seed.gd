extends "res://tools/preview_world_story.gd"

## A two-player co-op campaign at a point of the Generation 1 story, the `SEED=<out dir>` of tools/coop_screens.sh:
##   Godot --headless --path . -s res://tools/coop_seed.gd -- <game> <last leg>|list <out dir>
## walks preview_world_story.gd's legs through <last leg>; p1 imports the save as a host's first player does, p2 a copy beside.

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
	quit(_seed(data, args[1], args[2]))


func _seed(data: GameData, last: String, out_dir: String) -> int:
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
	var written: Error = write_seed(data, save, out_dir, _beside(world))
	print("coop seed: %s on %s %s, badges %d, %s" % [
		last, world.map_id(), world.player_cell, world.state.badge_count(), error_string(written)])
	return 0 if written == OK else 1


static func _leg_name(leg: Callable) -> String:
	return String(leg.get_method()).trim_prefix("_gen1_").trim_suffix("_leg")


static func _beside(world: Gen2WorldAPI) -> Vector2i:
	for side: Vector2i in SIDES:
		var cell: Vector2i = world.player_cell + side
		if world.can_walk_to(cell) and world.warp_at(cell).is_empty():
			return cell
	return world.player_cell


static func write_seed(data: GameData, save: Gen2SaveData, out_dir: String, partner_cell: Vector2i) -> Error:
	var campaign := PokeCoopCampaign.create(String(data.id), data.id, data.sha1)
	PokeCoopPolicy.start_campaign(campaign)
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
