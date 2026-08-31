extends Node3D
## a3_leon: Valencia hall. Cid asleep, men ring him, lion returned. Infantes hide.

const BEAT_ID := &"a3_leon"
const DEST := &"a3_bucar"
const HUB_LOCK := &"hub_lock_cardena"
const MESURA_EVENT := &"lion_mesura"
const RAGE_EVENT := &"lion_rage"
const ASLEEP_KEY := "a3_leon.asleep"
const JOKE_KEY := "a3_leon.joke"
const MESURA_KEY := "a3_leon.mesura_done"
const RAGE_KEY := "a3_leon.rage_done"
const RETURNED_KEY := "a3_leon.returned"
const NO_KILL_KEY := "a3_leon.no_kill"
const PLACE_KEY := "a3_leon.place_name"
const DIALOGUE_PATH := "res://content/chapters/a3_leon/leon.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const BUCAR_SCENE := "res://content/chapters/a3_bucar/world.tscn"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const SPAWN_IDLE_FRAMES := 2

var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var intro_played: bool = false
var _talking: bool = false
var _asleep: bool = true
var _joke_played: bool = false
var _path: StringName = &""
var _honor_applied: bool = false
var _returned: bool = false
var _left: bool = false
var _cid_walk: float = 4.5
var _cid_run: float = 7.0
var _spawn_idle_done: bool = false
var _idle_frames: int = 0


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if ChapterRunner and ChapterRunner.has_method("add_flag"):
		if ChapterRunner.has_method("has_flag") and not bool(ChapterRunner.has_flag(HUB_LOCK)):
			ChapterRunner.add_flag(String(HUB_LOCK))
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_ensure_roster()
	_bind_mesnada()
	_hide_plazo_bar()
	_open_cage()
	_place_infantes_hiding()
	_lay_cid_asleep()
	_hold_mesnada_ring()
	_connect_cage_zone()
	_connect_hall_zone()
	_bind_mesura()
	_show_place_name()
	_label_infantes()
	_name_horse()
	_panic_horse()
	_whisper(ASLEEP_KEY)
	intro_played = true
	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)
	_arm_spawn_idle()


func _arm_spawn_idle() -> void:
	var tree := get_tree()
	if tree == null:
		_spawn_idle_done = true
		return
	for _i in range(SPAWN_IDLE_FRAMES):
		await tree.physics_frame
	_spawn_idle_done = true
	set_process(false)
	set_physics_process(false)


func _process(_delta: float) -> void:
	_tick_spawn_idle()


func _physics_process(_delta: float) -> void:
	_tick_spawn_idle()


func _tick_spawn_idle() -> void:
	if _spawn_idle_done:
		set_process(false)
		set_physics_process(false)
		return
	_idle_frames += 1
	if _idle_frames >= SPAWN_IDLE_FRAMES:
		_spawn_idle_done = true
		set_process(false)
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or event is InputEventMouseMotion or event is InputEventJoypadMotion:
		return
	on_sleep_input()


func on_sleep_input() -> void:
	if not _spawn_idle_done or _returned:
		return
	if _asleep or not _joke_played:
		_wake_and_joke()


func _wake_and_joke() -> void:
	if _returned:
		return
	if _asleep:
		wake_cid()
	if not _joke_played and not _talking:
		start_joke()


func start_cue(cue: String) -> void:
	if cue == "wake" or cue == "sleep":
		wake_cid()
	elif cue == "joke":
		start_joke()
	elif cue == "mesura":
		choose_mesura()
	elif cue == "rage" or cue == "dump":
		choose_rage()
	elif cue == "return" or cue == "cage":
		return_lion()


func wake_cid() -> void:
	if not _asleep:
		return
	_asleep = false
	_stand_cid()
	_whisper("a3_leon.wake")


func start_joke(_cue: String = "joke") -> void:
	if _returned or _talking:
		return
	if _asleep:
		wake_cid()
	if _joke_played:
		if _path.is_empty():
			_show_choice()
		return
	_talking = true
	_whisper_joke()
	var resource := _load_dialogue()
	if resource == null:
		_finish_joke()
		return
	if _try_balloon(resource, "joke"):
		return
	await _walk_lines(resource, "joke")
	_finish_joke()


func run_joke() -> void:
	# Headless: wake, walk the hall joke, then present mesura vs rage.
	if _asleep:
		wake_cid()
	_talking = true
	_whisper_joke()
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "joke")
	_finish_joke()


func choose_mesura() -> void:
	if _returned:
		return
	if not _joke_played:
		start_joke()
		return
	if _talking:
		return
	_path = &"mesura"
	_hide_choice()
	_hold_cid_mesura(true)
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		return_lion()
		return
	if _try_balloon(resource, "mesura"):
		return
	await _walk_lines(resource, "mesura")
	_talking = false
	return_lion()


func choose_rage() -> void:
	if _returned:
		return
	if not _joke_played:
		start_joke()
		return
	if _talking:
		return
	_path = &"rage"
	_hide_choice()
	_hold_cid_mesura(false)
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		return_lion()
		return
	if _try_balloon(resource, "rage"):
		return
	await _walk_lines(resource, "rage")
	_talking = false
	return_lion()


func run_mesura() -> void:
	# Headless: skip-cinematic mesura return. Joke still recorded as played.
	if _asleep:
		wake_cid()
	_joke_played = true
	_path = &"mesura"
	_hide_choice()
	_hold_cid_mesura(true)
	_whisper(MESURA_KEY)
	return_lion()


func run_rage() -> void:
	# Headless: skip-cinematic rage dump. Returning the lion is still the win.
	if _asleep:
		wake_cid()
	_joke_played = true
	_path = &"rage"
	_hide_choice()
	_hold_cid_mesura(false)
	_whisper(RAGE_KEY)
	return_lion()


func return_lion() -> bool:
	if _returned:
		return true
	if _asleep:
		wake_cid()
	_place_lion_in_cage()
	_close_cage()
	_returned = true
	if _path.is_empty():
		_path = &"mesura" if _cid_is_holding() else &"rage"
		if not _cid_is_holding() and not _cid_dumped_ira():
			_path = &"mesura"
	_apply_return_honor()
	_set_flag(&"lion_returned")
	_clear_flag(&"lion_escaped")
	_whisper(RETURNED_KEY)
	_hold_cid_mesura(false)
	_finish_beat()
	return true


func try_kill_lion() -> bool:
	_whisper(NO_KILL_KEY)
	return false


func is_cage_closed() -> bool:
	var gate: Node = get_node_or_null("LionCage/CageGate")
	if gate and "visible" in gate:
		return bool(gate.visible)
	return _returned


func is_lion_escaped() -> bool:
	return not _returned


func is_cid_asleep() -> bool:
	return _asleep


func is_ferran_hiding() -> bool:
	return _has_flag(&"ferran_hid_leon")


func is_diego_hiding() -> bool:
	return _has_flag(&"diego_hid_leon")


func infantes_hid() -> bool:
	return _has_flag(&"infantes_hid_leon")


func lion_returned() -> bool:
	return _returned


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func try_travel_bucar() -> bool:
	if not _returned and not _has_flag(&"lion_returned"):
		return false
	if not _dest_ready():
		return false
	return _travel(DEST)


func can_leave_to_bucar() -> bool:
	if not _returned and not _has_flag(&"lion_returned"):
		return false
	return _can_travel(DEST)


func _finish_joke() -> void:
	_talking = false
	_joke_played = true
	_set_flag(&"infantes_hid_leon")
	_set_flag(&"ferran_hid_leon")
	_set_flag(&"diego_hid_leon")
	_set_flag(&"infantes_cowardice_leon")
	if not _returned and _path.is_empty():
		_show_choice()


func _apply_return_honor() -> void:
	if _honor_applied:
		return
	_honor_applied = true
	if _path == &"rage":
		_apply_honor(RAGE_EVENT)
	else:
		_apply_honor(MESURA_EVENT)


func _open_cage() -> void:
	_set_gate_closed(false)
	_set_flag(&"lion_escaped")


func _close_cage() -> void:
	_set_gate_closed(true)


func _set_gate_closed(closed: bool) -> void:
	for path in PackedStringArray(["LionCage/CageGate", "LionCage/BarA", "LionCage/BarB"]):
		var node: Node = get_node_or_null(path)
		if node and "visible" in node:
			node.visible = closed


func _place_lion_in_cage() -> void:
	var lion: Node3D = get_node_or_null("LionProp") as Node3D
	var cage: Node3D = get_node_or_null("LionCage") as Node3D
	if lion == null or cage == null:
		return
	lion.global_position = cage.global_position + Vector3(0.0, 0.0, 0.2)


func _place_infantes_hiding() -> void:
	_set_flag(&"ferran_hid_leon")
	_set_flag(&"diego_hid_leon")
	_set_flag(&"infantes_hid_leon")
	_set_flag(&"infantes_cowardice_leon")
	var ferran: Node3D = get_node_or_null("Ferran") as Node3D
	var bench: Node3D = get_node_or_null("HallBenchA") as Node3D
	if ferran and bench:
		ferran.global_position = bench.global_position + Vector3(0.0, -0.12, 0.0)
	var diego: Node3D = get_node_or_null("Diego") as Node3D
	var bed: Node3D = get_node_or_null("SolarBed") as Node3D
	if diego and bed:
		diego.global_position = bed.global_position + Vector3(0.0, 0.05, 0.35)


func _label_infantes() -> void:
	var ferran: Label3D = get_node_or_null("Ferran/Name") as Label3D
	if ferran:
		ferran.text = _loc("char.ferran_gonzalez")
	var diego: Label3D = get_node_or_null("Diego/Name") as Label3D
	if diego:
		diego.text = _loc("char.diego_gonzalez")


func _lay_cid_asleep() -> void:
	_asleep = true
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return
	if cid.has_method("set_chapter_asleep"):
		cid.call("set_chapter_asleep", true)
	elif "chapter_asleep" in cid:
		cid.chapter_asleep = true
	if "walk_speed" in cid:
		_cid_walk = float(cid.walk_speed)
		cid.walk_speed = 0.0
	if "run_speed" in cid:
		_cid_run = float(cid.run_speed)
		cid.run_speed = 0.0
	var visual: Node3D = cid.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation_degrees = Vector3(90.0, 0.0, 0.0)


func _stand_cid() -> void:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return
	if cid.has_method("set_chapter_asleep"):
		cid.call("set_chapter_asleep", false)
	elif "chapter_asleep" in cid:
		cid.chapter_asleep = false
	if "walk_speed" in cid:
		cid.walk_speed = _cid_walk
	if "run_speed" in cid:
		cid.run_speed = _cid_run
	var visual: Node3D = cid.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation_degrees = Vector3.ZERO


func _hold_mesnada_ring() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"hold")
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()


func _bind_mesura() -> void:
	var mesura := _cid_mesura()
	if mesura == null:
		return
	if mesura.has_signal("held_changed") and not mesura.held_changed.is_connected(_on_mesura_held):
		mesura.held_changed.connect(_on_mesura_held)
	if mesura.has_signal("dumped") and not mesura.dumped.is_connected(_on_mesura_dumped):
		mesura.dumped.connect(_on_mesura_dumped)


func _on_mesura_held(holding: bool) -> void:
	if not holding or _returned or not _joke_played or _talking:
		return
	_path = &"mesura"
	_hide_choice()
	return_lion()


func _on_mesura_dumped(_honra_delta: float) -> void:
	if _returned or not _joke_played:
		return
	_path = &"rage"
	_hide_choice()
	return_lion()


func _hold_cid_mesura(on: bool) -> void:
	var mesura := _cid_mesura()
	if mesura and mesura.has_method("set_holding"):
		mesura.set_holding(on)


func _cid_is_holding() -> bool:
	var mesura := _cid_mesura()
	if mesura and mesura.has_method("is_holding"):
		return bool(mesura.is_holding())
	return false


func _cid_dumped_ira() -> bool:
	var mesura := _cid_mesura()
	if mesura == null:
		return false
	if "ira" in mesura:
		return float(mesura.ira) <= 0.0001 and _path == &"rage"
	return _path == &"rage"


func _cid_mesura() -> Node:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return null
	var found: Node = cid.get_node_or_null("Mesura")
	if found:
		return found
	return cid.find_child("Mesura", true, false)


func _connect_cage_zone() -> void:
	var zone: Area3D = get_node_or_null("CageZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_cage_entered):
		zone.body_entered.connect(_on_cage_entered)


func _connect_hall_zone() -> void:
	var zone: Area3D = get_node_or_null("HallZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_hall_entered):
		zone.body_entered.connect(_on_hall_entered)


func _on_hall_entered(body: Node) -> void:
	if body == null or _returned:
		return
	if not body.is_in_group("player"):
		return
	if not _spawn_idle_done:
		return
	_wake_and_joke()


func _on_cage_entered(body: Node) -> void:
	if body == null or _returned:
		return
	if not body.is_in_group("player"):
		return
	if _asleep:
		_wake_and_joke()
		return
	if not _joke_played:
		start_joke()
		return
	if _path.is_empty():
		_show_choice()
		return
	return_lion()


func try_open_cage() -> bool:
	if _returned:
		return false
	if _joke_played and not _path.is_empty():
		return return_lion()
	_whisper("a3_leon.escaped")
	return false


func _show_choice() -> void:
	var ui: Node = find_child("ChoiceUI", true, false)
	if ui == null:
		return
	if ui.has_method("present"):
		ui.call("present")
	else:
		ui.visible = true


func _hide_choice() -> void:
	var ui: Node = find_child("ChoiceUI", true, false)
	if ui == null:
		return
	if ui.has_method("dismiss"):
		ui.call("dismiss")
	else:
		ui.visible = false


func _finish_beat() -> void:
	if _left:
		return
	# ChapterRunner.travel emits beat_completed; only emit here if travel does not run.
	if not _dest_ready() or not _travel(DEST):
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_checkpoint()


func _dest_ready() -> bool:
	return ResourceLoader.exists(BUCAR_SCENE)


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


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


func _whisper_joke() -> void:
	_whisper(JOKE_KEY)
	var ferran: MesnadaMember = MesnadaMember.from_id(&"ferran_gonzalez")
	var maxv := 0
	if ferran:
		maxv = int(ferran.mesura_max)
	var extra := _loc("a3_leon.no_mesura")
	if extra != "a3_leon.no_mesura" and extra.find(str(maxv)) >= 0:
		var whisper: Node = find_child("HallWhisper", true, false)
		if whisper and Loc and whisper.has_method("_show"):
			whisper.call("_show", "%s %s" % [_loc(JOKE_KEY), extra])


func _name_horse() -> void:
	_set_flag(&"babieca_named")
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("apply_name"):
		horse.call("apply_name", HORSE_ID, HORSE_KEY)
	var label: Label3D = get_node_or_null("Horse/Name") as Label3D
	if label:
		label.text = _loc(HORSE_KEY)
		label.visible = true


func _panic_horse() -> void:
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("panic"):
		horse.call("panic", &"lion")
	var cavalry: Node = horse.get_node_or_null("CavalryCharge") if horse else null
	if cavalry and cavalry.has_method("panic_for"):
		cavalry.call("panic_for", &"lion")


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


func _clear_flag(flag_id: StringName) -> void:
	var runner := _runner()
	if runner == null or not ("flags" in runner):
		return
	var packed: PackedStringArray = runner.flags
	var next := PackedStringArray()
	for flag in packed:
		if flag != String(flag_id):
			next.append(flag)
	runner.flags = next


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
	var was_joke := not _joke_played
	_talking = false
	if was_joke:
		_finish_joke()
		return
	if not _returned:
		return_lion()


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
