extends "res://tools/preview_world_story.gd"

## A two-player co-op campaign at a point of the Generation 1 story, the `SEED=<out dir>` of tools/coop_screens.sh:
##   Godot --headless --path . -s res://tools/coop_seed.gd -- <game> <last leg>|list <out dir> [level=<n>] [party=<n>] [both] [mon=<SPECIES>:<level>[:moves=A/B][:nick=X][:traded][:status=PSN|BRN|PAR|SLP|FRZ][:hp=<n>][:exp=<n>]]... [item=<ITEM>:<n>]... [at=<group>:<number>:<x>,<y>[:<partner x>,<partner y>]]
## walks preview_world_story.gd's legs through <last leg>, the party filled to party= lead copies and grown to level=, the first mon= replacing the lead and each next one joining; p1 imports it, p2 a copy; `both` turns on wild Pokémon from both versions (D104).
## `gold new <out dir> [at=...] [at2=<group>:<number>:<x>,<y>] [mon=<p1|p2>:<SPECIES>:<level>[:moves=A/B][:<ITEM>]]... [care=<p1|p2>:<SPECIES>:<level>[:<SPECIES>:<level>][:egg]]... [event=[-]<flag>]... [event=<p1|p2>:<flag>]... [phone=<p1|p2>:<contact>]... [level=<n>] [item=<ITEM>:<n>]... [clock=HH:MM[:D]]` seats two new Johto players, at2= putting the second elsewhere, mon= replacing that player's starter (each next one joining) with moves A/B and holding ITEM, care= filling one's day care (`egg`: the pair's egg waits a step from hatching), event= setting (or with - clearing) a campaign flag or with p1:/p2: one player's own, phone= a number in one player's POKéGEAR, level= growing both teams, item= stocking both bags, clock= starting the campaign's clock there.

const TRADER: String = "TRADER"
const JOHTO_NEW: String = "new"
const DAY_CARE_KEYS: Array[String] = ["day_care_man", "day_care_lady", "day_care_mons", "steps_to_egg", "day_care_egg"]
const SIDES: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var legs: Array = _gen1_story_legs().map(_leg_name)
	if args.has("list"):
		print("\n".join(legs))
		quit(0)
		return
	if args.size() >= 3 and args[1] == JOHTO_NEW:
		quit(_johto_seed(GameData.open(StringName(args[0])), args[2], Array(args.slice(3))))
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
	var extras: Array = Array(args.slice(3)).filter(func(arg: String) -> bool: return arg.begins_with("mon=") or arg.begins_with("item=") or arg.begins_with("at="))
	quit(_seed(data, args[1], args[2], options["level="], options["party="], args.has("both"), extras))


func _seed(data: GameData, last: String, out_dir: String, level: int = 0, party: int = 0, both: bool = false, extras: Array = []) -> int:
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
	var refused: String = shape(data, save, extras)
	if not refused.is_empty():
		push_error("coop seed: %s" % refused)
		return 1
	var partner: Vector2i = _beside(world)
	for extra: String in extras.filter(func(arg: String) -> bool: return arg.begins_with("at=")):
		var parts: PackedStringArray = extra.trim_prefix("at=").split(":")
		save.world.map_id = Vector2i(int(parts[0]), int(parts[1]))
		save.world.player_cell = _cell(parts[2])
		partner = _cell(parts[3]) if parts.size() > 3 else save.world.player_cell + Vector2i.LEFT
	var written: Error = write_seed(data, save, out_dir, partner, both)
	print("coop seed: %s on %s %s, badges %d, party %d, %s" % [
		last, save.world.map_id, save.world.player_cell, world.state.badge_count(), save.party.size(), error_string(written)])
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


static func shape(data: GameData, save: Gen2SaveData, extras: Array) -> String:
	var editor := Gen2SaveEditor.new()
	editor.data = data
	editor.save = save
	var first: bool = true
	for extra: String in extras.filter(func(arg: String) -> bool: return not arg.begins_with("at=")):
		var parts: PackedStringArray = extra.substr(extra.find("=") + 1).split(":")
		var number: int = named(data, "item" if extra.begins_with("item=") else "species", parts[0])
		if number <= 0:
			return "no %s named %s" % [extra.get_slice("=", 0), parts[0]]
		if extra.begins_with("item="):
			var stocked: Dictionary = editor.set_item_quantity(number, int(parts[1]) if parts.size() > 1 else 1)
			if not bool(stocked.get("ok", false)):
				return "%s: %s" % [extra, stocked.get("message", "")]
			continue
		var lead: bool = first and not save.party.is_empty()
		first = false
		if lead:
			editor.remove_party_member(0)
		var added: Dictionary = editor.add_party_member(number, int(parts[1]) if parts.size() > 1 else 5)
		if not bool(added.get("ok", false)):
			return "%s: %s" % [extra, added.get("message", "")]
		if lead:
			editor.move_party_member(save.party.size() - 1, 0)
		var refused: String = _dress(editor, save.party.front() if lead else save.party.back(), parts.slice(2))
		if not refused.is_empty():
			return "%s: %s" % [extra, refused]
	return ""


static func _dress(editor: Gen2SaveEditor, mon: Gen2SaveMon, options: PackedStringArray) -> String:
	for part: String in options:
		var value: String = part.get_slice("=", 1)
		match part.get_slice("=", 0):
			"moves":
				teach(editor, mon, Array(value.split("/")).map(func(move: String) -> int: return named(editor.data, "move", move)))
			"nick":
				editor.set_nickname(mon, value.replace("_", " "))
			"traded":
				mon.ot_id = editor.save.player_id % 0xFFFF + 7
				mon.original_trainer = TRADER
			"status":
				editor.set_status(mon, {"SLP": 3, "PSN": 8, "BRN": 16, "FRZ": 32, "PAR": 64}.get(value, 0))
			"hp":
				editor.set_hp(mon, int(value))
			"exp":
				mon.exp = int(value)
			_:
				return "no option %s" % part
	return ""


static func teach(editor: Gen2SaveEditor, mon: Gen2SaveMon, moves: Array) -> void:
	for slot: int in range(Gen2SaveMon.MAX_MOVES - 1, -1, -1):
		editor.set_move(mon, slot, Gen2SaveEditor.NO_MOVE)
	for slot: int in mini(moves.size(), Gen2SaveMon.MAX_MOVES):
		editor.set_move(mon, slot, int(moves[slot]))


static func named(data: GameData, kind: String, name: String) -> int:
	var count: int = data.species_count() if kind == "species" else (data.move_count() if kind == "move" else data.item_count())
	for number: int in range(1, count + 1):
		var row: Dictionary = data.species(number) if kind == "species" else (data.move(number) if kind == "move" else data.item(number))
		if _plain(String(row.get("name", ""))) == _plain(name):
			return number
	return 0


static func _plain(name: String) -> String:
	var kept: String = ""
	for letter: String in name.to_upper().replace("É", "E").replace("é", "E"):
		kept += letter if (letter >= "A" and letter <= "Z") or (letter >= "0" and letter <= "9") else ""
	return kept


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


static func _cell(text: String) -> Vector2i:
	return Vector2i(int(text.get_slice(",", 0)), int(text.get_slice(",", 1)))


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
	PokeCoopPolicy.start_campaign(campaign, data)
	campaign.both_versions = both
	campaign.rival_name = save.world.rival_name
	var players: Array = []
	for trainer: int in [save.player_id, save.player_id % 0xFFFF + 1]:
		var id: String = campaign.take_player_id()
		var player := PokeCoopPlayer.create(id, id.to_upper(), trainer)
		var own: Gen2SaveData = Gen2SaveData.from_dict(save.to_dict())
		own.player_id = trainer
		for mon: Gen2SaveMon in own.party.filter(func(mon: Gen2SaveMon) -> bool: return mon.original_trainer != TRADER):
			mon.ot_id = trainer
			mon.original_trainer = player.name
		PokeCoopPolicy.import_save(own, player, campaign if players.is_empty() else null,
			PokeCoopOwnership.badge_flags(data), PokeCoopPolicy.own_entries(data))
		players.append(player)
	(players[1] as PokeCoopPlayer).cell = partner_cell
	return _write(data, campaign, players, out_dir)


func _johto_seed(data: GameData, out_dir: String, options: Array) -> int:
	if not PokeCoopJohto.plays(data) or PokeToolPath.refuses(out_dir):
		push_error("coop seed: no imported Gold or Silver cache, or no out dir")
		return 1
	var campaign := PokeCoopCampaign.create(String(data.id), data.id, data.sha1)
	var players: Array = []
	for index: int in 2:
		var id: String = campaign.take_player_id()
		var player := PokeCoopPlayer.create(id, ["GOLD", "SILVER"][index], 17800 + index)
		player.money = PokeCoopPolicy.new_player_money()
		PokeCoopPolicy.set_up_new_player(data, player, 0, index)
		players.append(player)
	var dressed: Dictionary = {}
	for option: String in options:
		var parts: PackedStringArray = option.substr(option.find("=") + 1).split(":")
		if option.begins_with("at="):
			for index: int in 2:
				var cell: Vector2i = _cell(parts[2 + index]) if parts.size() > 2 + index else _cell(parts[2]) + Vector2i.LEFT * index
				(players[index] as PokeCoopPlayer).place(Vector2i(int(parts[0]), int(parts[1])), cell, Gen2WorldSprite.FACING_DOWN)
		elif option.begins_with("at2="):
			(players[1] as PokeCoopPlayer).place(Vector2i(int(parts[0]), int(parts[1])), _cell(parts[2]), Gen2WorldSprite.FACING_DOWN)
		elif not _johto_option(data, campaign, players, option, dressed):
			return 1
	var written: Error = _write(data, campaign, players, out_dir)
	print("coop seed: Johto, %s, %s" % [(players as Array).map(func(member: PokeCoopPlayer) -> String: return "%s on %s %s" % [member.name, member.map, member.cell]), error_string(written)])
	return 0 if written == OK else 1


static func _johto_dress(data: GameData, players: Array, option: String, parts: PackedStringArray, dressed: Dictionary) -> String:  ## mon=, care=, level=, item=
	var player: PokeCoopPlayer = players[1 if parts[0] == "p2" else 0]
	if option.begins_with("mon="):
		var lead: bool = not dressed.has(parts[0])
		dressed[parts[0]] = true
		return _johto_party(data, player, parts.slice(1), lead)
	if option.begins_with("care="):
		return _day_care(data, player, parts.slice(1))
	if option.begins_with("level=") or option.begins_with("item="):
		return _stock(data, players, option, parts)
	return ""


static func _johto_party(data: GameData, player: PokeCoopPlayer, parts: PackedStringArray, lead: bool) -> String:
	var level: int = int(parts[1]) if parts.size() > 1 else 5
	var moves: Array = []
	var item: int = 0
	for extra: String in parts.slice(2):
		if extra.begins_with("moves="):
			moves = Array(extra.trim_prefix("moves=").split("/")).map(func(move: String) -> int: return named(data, "move", move))
		else:
			item = named(data, "item", extra)
			if item <= 0:
				return "no item named %s" % extra
	var saved: Gen2SaveMon = _johto_mon(data, player, parts[0], level, moves)
	if saved == null:
		return "no species named %s" % parts[0]
	saved.item = item
	if lead and not player.team.is_empty():
		player.team[0]["mon"] = saved
	elif player.add_mon(saved).is_empty():
		return "no room in the party"
	return ""


static func _johto_mon(data: GameData, player: PokeCoopPlayer, species_name: String, level: int, moves: Array = []) -> Gen2SaveMon:
	var species: int = named(data, "species", species_name)
	var mon: Gen2BattleMon = Gen2BattleMon.create(data, species, level, moves if not moves.is_empty() else data.moves_at_level(species, level)) if species > 0 else null
	if mon == null:
		return null
	var saved: Gen2SaveMon = Gen2SaveBattleAdapter.from_battle_mon(mon)
	saved.ot_id = player.trainer_id
	saved.original_trainer = player.name
	return saved


static func _stock(data: GameData, players: Array, option: String, parts: PackedStringArray) -> String:  ## level= or item=, for both
	var item: int = named(data, "item", parts[0]) if option.begins_with("item=") else 0
	if option.begins_with("item=") and item <= 0:
		return "no item named %s" % parts[0]
	for member: PokeCoopPlayer in players:
		if item > 0:
			member.give_item(item, int(parts[1]) if parts.size() > 1 else 1)
			continue
		var save := Gen2SaveData.new()
		save.party = member.team.map(func(entry: Dictionary) -> Gen2SaveMon: return entry["mon"])
		_raise(data, save, int(parts[0]))
	return ""


static func _day_care(data: GameData, player: PokeCoopPlayer, parts: PackedStringArray) -> String:
	var state := Gen2WorldState.new()
	var egg: bool = parts[-1] == "egg"
	for slot: int in mini((parts.size() - int(egg)) / 2, 2):
		var saved: Gen2SaveMon = _johto_mon(data, player, parts[slot * 2], int(parts[slot * 2 + 1]))
		if saved == null:
			return "no species named %s" % parts[slot * 2]
		state.set_day_care_mon(slot, saved)
		state.set_day_care_has_mon(slot, true)
	var random := RandomNumberGenerator.new()
	var built: Gen2SaveMon = Gen2WorldDayCare.make_egg(data, state.day_care_mon(0), state.day_care_mon(1), player.name, player.trainer_id, random) if egg else null
	if egg and built == null:
		return "an egg needs two Pokémon"
	if built != null:
		built.happiness = 1
		state.set_day_care_egg(built)
		state.set_day_care_man_flags(state.day_care_man_flags() | Gen2WorldDayCare.MAN_HAS_EGG)
	else:
		Gen2WorldDayCare.init_breeding(state, data, player.name, player.trainer_id, random)
	var world: Dictionary = state.to_dict()
	var kept: Dictionary = {"step_count": Gen2WorldState.EGG_STEP_PHASE - 1 if egg else 0}
	for key: String in DAY_CARE_KEYS:
		kept[key] = world[key]
	player.apply_world_patch(PokeCoopOwnership.patch({}, kept))
	return ""


static func _johto_option(data: GameData, campaign: PokeCoopCampaign, players: Array, option: String, dressed: Dictionary = {}) -> bool:  ## event=, phone=, clock=, the rest _johto_dress's
	var parts: PackedStringArray = option.substr(option.find("=") + 1).split(":")
	if option.begins_with("phone=") or (option.begins_with("event=") and parts.size() == 2):
		(players[1 if parts[0] == "p2" else 0] as PokeCoopPlayer).apply_world_patch({  ## one player's number or own flag (D139)
			"phone_contacts" if option.begins_with("phone=") else "event_flags": {"set": {parts[1].to_int(): true}, "erase": []}})
	elif option.begins_with("event="):
		var flag: int = absi(parts[0].to_int())
		if parts[0].begins_with("-"):
			campaign.flags.erase(flag)
		else:
			campaign.flags[flag] = true
	elif option.begins_with("clock="):
		var pin: Dictionary = Gen2WorldClock.parse_pin(PackedStringArray([Gen2WorldClock.PIN_ARGUMENT + option.trim_prefix("clock=")]))
		campaign.clock = PokeCoopJohto.set_to(pin, Gen2WorldClock.host_seconds()) if not pin.is_empty() else campaign.clock
	else:
		var refused: String = _johto_dress(data, players, option, parts, dressed)
		if not refused.is_empty():
			push_error("coop seed: %s: %s" % [option, refused])
			return false
	return true


static func _write(data: GameData, campaign: PokeCoopCampaign, players: Array, out_dir: String) -> Error:
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
