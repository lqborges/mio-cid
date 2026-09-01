extends Node3D
## a2_tagus: Tagus / Toledo marches. Three-day court. Forced yes.

const BEAT_ID := &"a2_tagus"
const DEST := &"a2_bodas"
const DEST_SCENE := "res://content/chapters/a2_bodas/world.tscn"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const NAMED_FLAG := &"babieca_named"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_tagus.horse_name"
const PARDON_EVENT := &"pardon"
const MARRY_EVENT := &"accept_marriages"
const PARDON_FLAG := &"pardon"
const MARRY_FLAG := &"marriages_accepted"
const ARRIVE_KEY := "a2_tagus.arrive"
const PLACE_KEY := "a2_tagus.place_name"
const DIALOGUE_PATH := "res://content/chapters/a2_tagus/tagus.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DATA_PATH := "res://data/honor_events/tagus.json"

var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var intro_played: bool = false
var court_day: int = 1
var _talking: bool = false
var _pardoned: bool = false
var _accepted: bool = false
var _left: bool = false
var _data: Dictionary = {}


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if ChapterRunner and ChapterRunner.has_method("add_flag"):
		ChapterRunner.add_flag(HORSE_FLAG)
		if ChapterRunner.has_method("has_flag") and not bool(ChapterRunner.has_flag(HUB_LOCK)):
			ChapterRunner.add_flag(String(HUB_LOCK))
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_load_data()
	_ensure_roster()
	_bind_mesnada()
	_hide_plazo_bar()
	_connect_court_zone()
	_connect_rest_zone()
	_connect_bodas_exit()
	_show_place_name()
	_name_horse()
	_label_npcs()
	_whisper(ARRIVE_KEY)
	intro_played = true


func start_cue(cue: String) -> void:
	if cue == "pardon" or cue == "day1":
		start_pardon()
	elif cue == "day2" or cue == "rest":
		start_day2()
	elif cue == "ask" or cue == "marriages" or cue == "yes":
		start_ask()
	elif cue == "leave" or cue == "bodas":
		travel_to_bodas()
	elif cue == "court":
		start_court()


func start_court() -> void:
	if court_day <= 1:
		start_pardon()
	elif court_day == 2:
		start_day2()
	else:
		start_ask()


func start_pardon(_cue: String = "pardon") -> void:
	if _pardoned or _talking:
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		grant_pardon()
		return
	if _try_balloon(resource, "pardon"):
		return
	await _walk_lines(resource, "pardon")
	_talking = false
	grant_pardon()


func run_pardon() -> void:
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "pardon")
	_talking = false
	grant_pardon()


func grant_pardon() -> bool:
	if _pardoned:
		return false
	_pardoned = true
	_apply_honor(PARDON_EVENT)
	_set_flag(PARDON_FLAG)
	court_day = maxi(court_day, 2)
	_advance_court_day()
	_whisper("a2_tagus.pardon")
	return true


func start_day2(_cue: String = "day2") -> void:
	if _talking:
		return
	if not _pardoned and not _has_flag(PARDON_FLAG):
		_whisper("a2_tagus.pardon_first")
		return
	if court_day >= _court_days():
		start_ask()
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		rest_day2()
		return
	if _try_balloon(resource, "day2"):
		return
	await _walk_lines(resource, "day2")
	_talking = false
	rest_day2()


func run_day2() -> void:
	if not _pardoned and not _has_flag(PARDON_FLAG):
		_whisper("a2_tagus.pardon_first")
		return
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "day2")
	_talking = false
	rest_day2()


func rest_day2() -> bool:
	if not _pardoned and not _has_flag(PARDON_FLAG):
		_whisper("a2_tagus.pardon_first")
		return false
	if court_day >= _court_days():
		return false
	court_day = _court_days()
	_advance_court_day()
	_whisper("a2_tagus.day3")
	return true


func start_ask(_cue: String = "ask") -> void:
	if _accepted or _talking:
		return
	if not _ready_for_ask():
		_whisper("a2_tagus.ask_first")
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		accept_marriages()
		return
	if _try_balloon(resource, "ask"):
		return
	await _walk_lines(resource, "ask")
	_talking = false
	accept_marriages()


func run_ask() -> void:
	if not _ready_for_ask():
		if not _pardoned:
			await run_pardon()
		if court_day < _court_days():
			await run_day2()
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "ask")
	_talking = false
	accept_marriages()


func accept_marriages() -> bool:
	if _accepted:
		return false
	if not _ready_for_ask():
		_whisper("a2_tagus.ask_first")
		return false
	_accepted = true
	_apply_honor(MARRY_EVENT)
	_set_flag(MARRY_FLAG)
	_set_flag(&"tagus_done")
	_whisper("a2_tagus.yes")
	return true


func refuse_marriages() -> bool:
	# v1: refusing would break the pardon; there is no refuse option.
	_whisper("a2_tagus.cannot_refuse")
	return false


func travel_to_bodas() -> bool:
	if not _accepted and not _has_flag(MARRY_FLAG):
		_whisper("a2_tagus.yes_first")
		return false
	return _travel(DEST)


func can_leave_to_bodas() -> bool:
	if not _accepted and not _has_flag(MARRY_FLAG):
		return false
	return _can_travel(DEST)


func is_pardoned() -> bool:
	return _pardoned or _has_flag(PARDON_FLAG)


func is_accepted() -> bool:
	return _accepted or _has_flag(MARRY_FLAG)


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func horse_display_name() -> String:
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("display_name"):
		return str(horse.call("display_name"))
	return _loc(HORSE_KEY)


func _ready_for_ask() -> bool:
	if not _pardoned and not _has_flag(PARDON_FLAG):
		return false
	return court_day >= _court_days()


func _advance_court_day() -> void:
	var clock := _autoload("CampaignClock")
	if clock and clock.has_method("advance_calendar"):
		clock.advance_calendar(1)


func _name_horse() -> void:
	_set_flag(NAMED_FLAG)
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("apply_name"):
		horse.call("apply_name", HORSE_ID, HORSE_KEY)
	var label: Label3D = get_node_or_null("Horse/Name") as Label3D
	if label:
		label.text = _loc(HORSE_KEY)
		label.visible = true


func _label_npcs() -> void:
	var alfonso: Label3D = get_node_or_null("Alfonso/Name") as Label3D
	if alfonso:
		alfonso.text = _loc("char.alfonso")
	var ferran: Label3D = get_node_or_null("FerranGonzalez/Name") as Label3D
	if ferran:
		ferran.text = _loc("char.ferran_gonzalez")
	var diego: Label3D = get_node_or_null("DiegoGonzalez/Name") as Label3D
	if diego:
		diego.text = _loc("char.diego_gonzalez")


func _connect_court_zone() -> void:
	var zone: Area3D = get_node_or_null("CourtZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_court_entered):
		zone.body_entered.connect(_on_court_entered)


func _on_court_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_court()


func _connect_rest_zone() -> void:
	var zone: Area3D = get_node_or_null("RestZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_rest_entered):
		zone.body_entered.connect(_on_rest_entered)


func _on_rest_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_day2()


func _connect_bodas_exit() -> void:
	var zone: Area3D = get_node_or_null("BodasExit") as Area3D
	if zone and not zone.body_entered.is_connected(_on_bodas_entered):
		zone.body_entered.connect(_on_bodas_entered)


func _on_bodas_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		travel_to_bodas()


func _bind_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	var roster: Variant = _roster()
	if roster and mesnada.has_method("bind_roster"):
		mesnada.bind_roster(roster)
	if "lanza_body_limit" in mesnada and roster and "lanzas" in roster:
		mesnada.lanza_body_limit = int(roster.lanzas)
		if mesnada.has_method("_sync_lanza_bodies"):
			mesnada.call("_sync_lanza_bodies")


func _ensure_roster() -> void:
	var honor := _honor()
	if honor == null:
		return
	if honor.get("roster") != null:
		return
	honor.roster = MesnadaRoster.from_starting_seed()


func _roster() -> Variant:
	if GameState and GameState.has_method("roster"):
		var found: Variant = GameState.roster()
		if found != null:
			return found
	var honor := _honor()
	if honor:
		return honor.get("roster")
	return null


func _honor() -> Node:
	return _autoload("HonorService")


func _apply_honor(event_id: StringName) -> void:
	var honor := _honor()
	if honor == null:
		return
	if honor.has_method("apply_id"):
		honor.apply_id(event_id)
	elif honor.has_method("apply"):
		honor.call("apply", event_id)


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _show_place_name() -> void:
	var label: Label3D = get_node_or_null("PlaceName") as Label3D
	if label == null:
		return
	label.text = place_name_text()
	label.visible = true


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


func _load_data() -> void:
	_data = {}
	for path in PackedStringArray([DATA_PATH, "res://content/chapters/a2_tagus/beats.json"]):
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for key in parsed.keys():
				if key != "events" and key != "steps" and not _data.has(key):
					_data[key] = parsed[key]


func _tunable_int(key: String) -> int:
	if _data.is_empty():
		_load_data()
	return int(_data.get(key, 0))


func _court_days() -> int:
	return maxi(1, _tunable_int("court_days"))


func _travel(to_id: StringName) -> bool:
	if _left:
		return false
	var runner := _runner()
	if runner == null or not runner.has_method("travel"):
		return false
	if "current_id" in runner:
		runner.current_id = BEAT_ID
	if not bool(runner.travel(to_id)):
		return false
	_left = true
	_checkpoint()
	var loop := Engine.get_main_loop()
	var tree: SceneTree = loop as SceneTree if loop is SceneTree else null
	if tree == null or tree.current_scene != self:
		return true
	if not ResourceLoader.exists(DEST_SCENE):
		_whisper("a2_tagus.bodas_wait")
		return true
	if runner.has_method("goto"):
		runner.goto(to_id)
	return true


func _can_travel(to_id: StringName) -> bool:
	var runner := _runner()
	if runner == null or not runner.has_method("can_travel"):
		return false
	var from_id: StringName = BEAT_ID
	if "current_id" in runner and String(runner.current_id) != "":
		from_id = runner.current_id
	var flags := PackedStringArray()
	if "flags" in runner:
		flags = runner.flags
	return bool(runner.can_travel(from_id, to_id, flags))


func _has_flag(flag_id: StringName) -> bool:
	var runner := _runner()
	if runner != null and runner.has_method("has_flag"):
		return bool(runner.has_flag(flag_id))
	if runner != null and "flags" in runner:
		return String(flag_id) in runner.flags
	return false


func _set_flag(flag_id: StringName) -> void:
	var runner := _runner()
	if runner == null:
		return
	if runner.has_method("add_flag"):
		runner.add_flag(String(flag_id))
		return
	if "flags" in runner:
		var packed: PackedStringArray = runner.flags
		if String(flag_id) not in packed:
			packed.append(String(flag_id))
			runner.flags = packed


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


func _loc(key: String) -> String:
	var loc := _autoload("Loc")
	if loc != null and loc.has_method("text"):
		return str(loc.text(key))
	return key


func _runner() -> Node:
	return _autoload("ChapterRunner")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(node_name))
	return get_node_or_null(NodePath("/root/%s" % node_name))


func _on_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _dialogue_manager()
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_dialogue_ended)
	_talking = false
	if not _pardoned:
		grant_pardon()
	elif court_day < _court_days():
		rest_day2()
	elif not _accepted:
		accept_marriages()


func _try_balloon(resource: Resource, cue: String) -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var dm := _dialogue_manager()
	if dm and dm.has_method("show_dialogue_balloon_scene") and ResourceLoader.exists(BALLOON_PATH):
		if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)
		dm.show_dialogue_balloon_scene(BALLOON_PATH, resource, cue, [self])
		return true
	return false


func _walk_lines(resource: Resource, cue: String) -> void:
	last_dialogue_speakers = PackedStringArray()
	last_dialogue_keys = PackedStringArray()
	var dm := _dialogue_manager()
	if dm == null or not dm.has_method("get_next_dialogue_line"):
		return
	var line: Variant = await dm.get_next_dialogue_line(resource, cue)
	while line != null:
		_record_dialogue_line(line)
		var next_id := ""
		if typeof(line) == TYPE_OBJECT and "next_id" in line:
			next_id = str(line.next_id)
		if next_id.is_empty() or next_id == "end":
			break
		line = await dm.get_next_dialogue_line(resource, next_id)


func _record_dialogue_line(line: Variant) -> void:
	if typeof(line) != TYPE_OBJECT:
		return
	if "character" in line:
		last_dialogue_speakers.append(str(line.character))
	if "text" in line:
		last_dialogue_keys.append(str(line.text))


func _load_dialogue() -> Resource:
	if ResourceLoader.exists(DIALOGUE_PATH):
		var loaded: Variant = load(DIALOGUE_PATH)
		if loaded is Resource and loaded.has_method("get_next_dialogue_line"):
			return loaded
	if not FileAccess.file_exists(DIALOGUE_PATH):
		return null
	var text := FileAccess.get_file_as_string(DIALOGUE_PATH)
	if text.is_empty():
		return null
	var compiler: Script = load("res://addons/dialogue_manager/compiler/compiler.gd") as Script
	if compiler == null:
		return null
	var result: Variant = compiler.call("compile_string", text, DIALOGUE_PATH)
	if result == null:
		return null
	if "errors" in result and result.errors.size() > 0:
		return null
	var resource_script: Script = load("res://addons/dialogue_manager/dialogue_resource.gd") as Script
	if resource_script == null:
		return null
	var resource: Resource = resource_script.new()
	if "using_states" in result:
		resource.set("using_states", result.using_states)
	if "cues" in result:
		resource.set("cues", result.cues)
	if "first_cue" in result:
		resource.set("first_cue", result.first_cue)
	if "character_names" in result:
		resource.set("character_names", result.character_names)
	if "lines" in result:
		resource.set("lines", result.lines)
	return resource


func _dialogue_manager() -> Object:
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DialogueManager")
