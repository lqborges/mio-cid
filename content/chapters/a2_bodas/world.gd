extends Node3D
## a2_bodas: Valencia hub. Infantes join. Train will not improve enough.

const BEAT_ID := &"a2_bodas"
const DEST := &"a3_leon"
const DEST_SCENE := "res://content/chapters/a3_leon/world.tscn"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const NAMED_FLAG := &"babieca_named"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_bodas.horse_name"
const JOIN_FLAG := &"infantes_joined"
const FERRAN_ID := &"ferran_gonzalez"
const DIEGO_ID := &"diego_gonzalez"
const ARRIVE_KEY := "a2_bodas.arrive"
const PLACE_KEY := "a2_bodas.place_name"
const CAGE_KEY := "a2_bodas.cage_locked"
const DIALOGUE_PATH := "res://content/chapters/a2_bodas/bodas.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DATA_PATH := "res://data/honor_events/bodas.json"

var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var intro_played: bool = false
var _talking: bool = false
var _joined: bool = false
var _trained: bool = false
var _gifted: bool = false
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
	_connect_train_zone()
	_connect_gift_zone()
	_connect_cage_zone()
	_connect_leon_exit()
	_show_place_name()
	_name_horse()
	_label_npcs()
	join_infantes()
	_whisper(ARRIVE_KEY)
	intro_played = true


func start_cue(cue: String) -> void:
	if cue == "train":
		start_train()
	elif cue == "gift":
		start_gift()
	elif cue == "cage":
		try_open_cage()
	elif cue == "leave" or cue == "leon":
		travel_to_leon()
	elif cue == "arrive" or cue == "join":
		join_infantes()


func start_train(_cue: String = "train") -> void:
	if _talking:
		return
	join_infantes()
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		train_infantes()
		return
	if _try_balloon(resource, "train"):
		return
	await _walk_lines(resource, "train")
	_talking = false
	train_infantes()


func run_train() -> void:
	join_infantes()
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "train")
	_talking = false
	train_infantes()


func train_infantes() -> void:
	join_infantes()
	_trained = true
	var cap := float(_tunable_int("train_combat_cap"))
	var roster: Variant = _roster()
	if roster == null or not roster.has_method("member"):
		_whisper("a2_bodas.train_done")
		return
	for character_id in [FERRAN_ID, DIEGO_ID]:
		var member: Variant = roster.member(character_id)
		if member == null:
			continue
		if "combat" in member:
			member.combat = minf(float(member.combat) + 1.0, cap)
	_whisper("a2_bodas.train_done")


func start_gift(_cue: String = "gift") -> void:
	if _talking:
		return
	join_infantes()
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		gift_infantes()
		return
	if _try_balloon(resource, "gift"):
		return
	await _walk_lines(resource, "gift")
	_talking = false
	gift_infantes()


func run_gift() -> void:
	join_infantes()
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "gift")
	_talking = false
	gift_infantes()


func gift_infantes() -> bool:
	if _gifted:
		return false
	join_infantes()
	_gifted = true
	var cost := _tunable_int("gift_marks")
	var roster: Variant = _roster()
	if roster and roster.has_method("gift_to"):
		roster.gift_to(FERRAN_ID, float(cost), true)
		roster.gift_to(DIEGO_ID, float(cost), true)
	if TreasuryService and TreasuryService.state:
		TreasuryService.state.marks = maxi(0, int(TreasuryService.state.marks) - cost)
	_whisper("a2_bodas.gift")
	return true


func join_infantes() -> void:
	if _joined:
		return
	var roster: Variant = _roster()
	if roster == null or not roster.has_method("add_member"):
		return
	for character_id in [FERRAN_ID, DIEGO_ID]:
		if roster.has_method("member") and roster.member(character_id) != null:
			continue
		var member := MesnadaMember.from_id(character_id)
		if member:
			roster.add_member(member)
	_joined = true
	_set_flag(JOIN_FLAG)
	_set_flag(&"bodas_done")


func try_open_cage() -> bool:
	_whisper(CAGE_KEY)
	return false


func is_cage_closed() -> bool:
	var gate: Node = get_node_or_null("LionCage/CageGate")
	if gate and "visible" in gate and not bool(gate.visible):
		return false
	return not _has_flag(&"lion_escaped")


func is_lion_escaped() -> bool:
	return false


func travel_to_leon() -> bool:
	if not ResourceLoader.exists(DEST_SCENE):
		_whisper("a2_bodas.leon_wait")
		return false
	return _travel(DEST)


func can_leave_to_leon() -> bool:
	if not ResourceLoader.exists(DEST_SCENE):
		return false
	return _can_travel(DEST)


func infante_combat(character_id: StringName) -> float:
	var roster: Variant = _roster()
	if roster == null or not roster.has_method("member"):
		return 0.0
	var member: Variant = roster.member(character_id)
	if member == null or not ("combat" in member):
		return 0.0
	return float(member.combat)


func infante_mesura_max(character_id: StringName) -> float:
	var roster: Variant = _roster()
	if roster == null or not roster.has_method("member"):
		return 0.0
	var member: Variant = roster.member(character_id)
	if member == null or not ("mesura_max" in member):
		return 0.0
	return float(member.mesura_max)


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func horse_display_name() -> String:
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("display_name"):
		return str(horse.call("display_name"))
	return _loc(HORSE_KEY)


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
	var ferran: Label3D = get_node_or_null("FerranGonzalez/Name") as Label3D
	if ferran:
		ferran.text = _loc("char.ferran_gonzalez")
	var diego: Label3D = get_node_or_null("DiegoGonzalez/Name") as Label3D
	if diego:
		diego.text = _loc("char.diego_gonzalez")
	var elvira: Label3D = get_node_or_null("Elvira/Name") as Label3D
	if elvira:
		elvira.text = _loc("char.elvira")
	var sol: Label3D = get_node_or_null("Sol/Name") as Label3D
	if sol:
		sol.text = _loc("char.sol")


func _connect_train_zone() -> void:
	var zone: Area3D = get_node_or_null("TrainZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_train_entered):
		zone.body_entered.connect(_on_train_entered)


func _on_train_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_train()


func _connect_gift_zone() -> void:
	var zone: Area3D = get_node_or_null("GiftZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_gift_entered):
		zone.body_entered.connect(_on_gift_entered)


func _on_gift_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_gift()


func _connect_cage_zone() -> void:
	var zone: Area3D = get_node_or_null("CageZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_cage_entered):
		zone.body_entered.connect(_on_cage_entered)


func _on_cage_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		try_open_cage()


func _connect_leon_exit() -> void:
	var zone: Area3D = get_node_or_null("LeonExit") as Area3D
	if zone and not zone.body_entered.is_connected(_on_leon_entered):
		zone.body_entered.connect(_on_leon_entered)


func _on_leon_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		travel_to_leon()


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
	for path in PackedStringArray([DATA_PATH, "res://content/chapters/a2_bodas/beats.json"]):
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
	if not ResourceLoader.exists(DEST_SCENE):
		_whisper("a2_bodas.leon_wait")
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
	if not _trained:
		train_infantes()
	elif not _gifted:
		gift_infantes()


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
