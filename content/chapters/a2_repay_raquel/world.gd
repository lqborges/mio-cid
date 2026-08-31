extends Node3D
## a2_repay_raquel: Valencia hall. Cheat-path only. Pay is the only option.

const BEAT_ID := &"a2_repay_raquel"
const DEST := &"a2_tagus"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const NAMED_FLAG := &"babieca_named"
const CHEAT_FLAG := &"arcas_cheated"
const REPAY_FLAG := &"repay_done"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_repay_raquel.horse_name"
const REPAY_EVENT := &"repay_raquel"
const ARRIVE_KEY := "a2_repay_raquel.arrive"
const PLACE_KEY := "a2_repay_raquel.place_name"
const DIALOGUE_PATH := "res://content/chapters/a2_repay_raquel/repay.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DATA_PATH := "res://data/honor_events/repay_raquel.json"

var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var intro_played: bool = false
var _talking: bool = false
var _paid: bool = false
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
	_connect_pay_zone()
	_connect_tagus_exit()
	_show_place_name()
	_name_horse()
	_label_npcs()
	_whisper(ARRIVE_KEY)
	intro_played = true


func start_cue(cue: String) -> void:
	if cue == "pay" or cue == "repay":
		start_pay()
	elif cue == "leave" or cue == "tagus":
		travel_to_tagus()


func start_pay(_cue: String = "pay") -> void:
	if _paid or _talking:
		return
	if not _owes_repay():
		_whisper("a2_repay_raquel.not_owed")
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		pay()
		return
	if _try_balloon(resource, "pay"):
		return
	await _walk_lines(resource, "pay")
	_talking = false
	pay()


func run_pay() -> void:
	# Headless: walk Minaya / Raquel / Vidas, then pay. No refuse.
	if not _owes_repay():
		_whisper("a2_repay_raquel.not_owed")
		return
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "pay")
	_talking = false
	pay()


func pay() -> bool:
	if _paid:
		return false
	if not _owes_repay():
		_whisper("a2_repay_raquel.not_owed")
		return false
	_paid = true
	_deduct_repay_marks()
	_apply_honor(REPAY_EVENT)
	_set_flag(REPAY_FLAG)
	_whisper("a2_repay_raquel.paid")
	return true


func travel_to_tagus() -> bool:
	if not _paid and not _has_flag(REPAY_FLAG):
		_whisper("a2_repay_raquel.pay_first")
		return false
	return _travel(DEST)


func can_leave_to_tagus() -> bool:
	if not _paid and not _has_flag(REPAY_FLAG):
		return false
	return _can_travel(DEST)


func owes_repay() -> bool:
	return _owes_repay()


func is_paid() -> bool:
	return _paid or _has_flag(REPAY_FLAG)


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func horse_display_name() -> String:
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("display_name"):
		return str(horse.call("display_name"))
	return _loc(HORSE_KEY)


func _owes_repay() -> bool:
	return _has_flag(CHEAT_FLAG)


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
	var raquel: Label3D = get_node_or_null("Raquel/Name") as Label3D
	if raquel:
		raquel.text = _loc("char.raquel")
	var vidas: Label3D = get_node_or_null("Vidas/Name") as Label3D
	if vidas:
		vidas.text = _loc("char.vidas")
	var alvar: Label3D = get_node_or_null("Mesnada/AlvarFanez/Name") as Label3D
	if alvar:
		alvar.text = _loc("char.alvar_fanez")


func _deduct_repay_marks() -> void:
	if TreasuryService == null or TreasuryService.state == null:
		return
	var cost := _tunable_int("repay_marks")
	TreasuryService.state.marks = maxi(0, int(TreasuryService.state.marks) - cost)


func _connect_pay_zone() -> void:
	var zone: Area3D = get_node_or_null("PayZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_pay_entered):
		zone.body_entered.connect(_on_pay_entered)


func _on_pay_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_pay()


func _connect_tagus_exit() -> void:
	var zone: Area3D = get_node_or_null("TagusExit") as Area3D
	if zone and not zone.body_entered.is_connected(_on_tagus_entered):
		zone.body_entered.connect(_on_tagus_entered)


func _on_tagus_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		travel_to_tagus()


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
	for path in PackedStringArray([DATA_PATH, "res://content/chapters/a2_repay_raquel/beats.json"]):
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
	pay()


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
