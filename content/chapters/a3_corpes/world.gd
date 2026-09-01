extends Node3D
## a3_corpes: Valencia hall. Crime is off-stage. Félez reports. Fact cannot be skipped.

const BEAT_ID := &"a3_corpes"
const DEST := &"a3_querella"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const NEWS_EVENT := &"corpes_news"
const RAGE_EVENT := &"corpes_rage_dump"
const SKIP_DAYS := 14
const WARNING_KEY := "a3_corpes.warning"
const REPORT_KEY := "a3_corpes.report"
const ALIVE_KEY := "a3_corpes.alive"
const LINEN_KEY := "a3_corpes.linen"
const MESURA_KEY := "a3_corpes.mesura_done"
const RAGE_KEY := "a3_corpes.rage_done"
const TABLE_KEY := "a3_corpes.table"
const PLACE_KEY := "a3_corpes.place_name"
const GROVE_KEY := "a3_corpes.grove_name"
const DIALOGUE_PATH := "res://content/chapters/a3_corpes/corpes.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DEST_SCENE := "res://content/chapters/a3_querella/world.tscn"
const NEWS_FLAGS := ["corpes_happened", "corpes_news", "elvira_alive", "sol_alive", "felez_found_them"]
const GROVE_HOLD_SEC := 2.4

var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var _warned: bool = false
var _hear_only: bool = false
var _grove_shown: bool = false
var _reported: bool = false
var _news_applied: bool = false
var _path: StringName = &""
var _talking: bool = false
var _left: bool = false
var _skip_cinematic: bool = false
var _grove_camera_held: bool = false


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if ChapterRunner and ChapterRunner.has_method("add_flag"):
		ChapterRunner.add_flag(HORSE_FLAG)
		if ChapterRunner.has_method("has_flag") and not bool(ChapterRunner.has_flag(HUB_LOCK)):
			ChapterRunner.add_flag(String(HUB_LOCK))
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_ensure_roster()
	_bind_mesnada()
	_hide_plazo_bar()
	_hold_mesnada()
	_freeze_cid(true)
	_hide_arrivals()
	_hide_grove()
	_connect_zones()
	_show_place_name()
	_name_horse()
	_label_people()
	_whisper(TABLE_KEY)
	_present_warning()


func start_cue(cue: String) -> void:
	if cue == "warning":
		_present_warning()
	elif cue == "hear" or cue == "hear_only":
		choose_hear()
	elif cue == "see" or cue == "grove":
		choose_see()
	elif cue == "report":
		start_report()
	elif cue == "mesura":
		choose_mesura()
	elif cue == "rage" or cue == "dump":
		choose_rage()


func choose_hear() -> void:
	if _reported:
		return
	_warned = true
	_hear_only = true
	_dismiss_warning()
	_hide_grove()
	if _skip_cinematic:
		_finish_report()
		return
	start_report()


func choose_see() -> void:
	if _reported:
		return
	_warned = true
	_hear_only = false
	_dismiss_warning()
	_arm_grove_camera()
	if _skip_cinematic:
		_cut_to_hall()
		_finish_report()
		return
	await _hold_grove_then_cut()
	start_report()


func run_hear_only() -> void:
	# Headless: skip grove images. Same flags and Félez report as the default path.
	_skip_cinematic = true
	choose_hear()


func run_default() -> void:
	# Headless: mark the empty grove shown, then the same report.
	_skip_cinematic = true
	choose_see()


func start_report(_cue: String = "report") -> void:
	if _reported or _talking:
		return
	if not _warned:
		_present_warning()
		return
	_talking = true
	_show_reporter()
	_whisper(REPORT_KEY)
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_finish_report()
		return
	if _try_balloon(resource, "report"):
		return
	await _walk_lines(resource, "report")
	_talking = false
	_finish_report()


func choose_mesura() -> void:
	if not _reported or _path != &"":
		return
	_path = &"mesura"
	_hide_choice()
	_hold_cid_mesura(true)
	_whisper(MESURA_KEY)
	if _skip_cinematic:
		_finish_beat()
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_finish_beat()
		return
	if _try_balloon(resource, "mesura"):
		return
	await _walk_lines(resource, "mesura")
	_talking = false
	_finish_beat()


func choose_rage() -> void:
	if not _reported or _path != &"":
		return
	_path = &"rage"
	_hide_choice()
	_hold_cid_mesura(false)
	_apply_honor(RAGE_EVENT)
	_whisper(RAGE_KEY)
	if _skip_cinematic:
		_finish_beat()
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_finish_beat()
		return
	if _try_balloon(resource, "rage"):
		return
	await _walk_lines(resource, "rage")
	_talking = false
	_finish_beat()


func run_mesura() -> void:
	_skip_cinematic = true
	if not _reported:
		run_hear_only()
	choose_mesura()


func run_rage() -> void:
	_skip_cinematic = true
	if not _reported:
		run_hear_only()
	choose_rage()


func try_travel_querella() -> bool:
	if not _reported:
		return false
	if _path.is_empty():
		return false
	if not _dest_ready():
		return false
	return _travel(DEST)


func can_leave_to_querella() -> bool:
	if not _reported or _path.is_empty():
		return false
	return _can_travel(DEST)


func fact_recorded() -> bool:
	return _reported and _news_applied and _has_flag(&"corpes_news")


func hear_only_used() -> bool:
	return _hear_only


func grove_shown() -> bool:
	return _grove_shown


func grove_camera_held() -> bool:
	return _grove_camera_held


func daughters_present() -> bool:
	var elvira: Node = get_node_or_null("Elvira")
	var sol: Node = get_node_or_null("Sol")
	if elvira == null or sol == null:
		return false
	if not bool(elvira.visible) or not bool(sol.visible):
		return false
	return _has_flag(&"elvira_alive") and _has_flag(&"sol_alive")


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func _present_warning() -> void:
	_whisper(WARNING_KEY)
	var ui: Node = find_child("WarningUI", true, false)
	if ui == null:
		return
	if ui.has_method("present"):
		ui.call("present")
	else:
		ui.visible = true


func _dismiss_warning() -> void:
	var ui: Node = find_child("WarningUI", true, false)
	if ui == null:
		return
	if ui.has_method("dismiss"):
		ui.call("dismiss")
	else:
		ui.visible = false


func _arm_grove_camera() -> void:
	_grove_shown = true
	var grove: Node3D = get_node_or_null("Grove") as Node3D
	if grove:
		grove.visible = true
	var stain: Node = get_node_or_null("Grove/LeafStain")
	if stain and "visible" in stain:
		stain.visible = true
	_whisper(LINEN_KEY)
	var grove_cam: Camera3D = get_node_or_null("Grove/Camera3D") as Camera3D
	if grove_cam:
		grove_cam.current = true
		_grove_camera_held = true
	var grove_name: Label3D = get_node_or_null("Grove/PlaceName") as Label3D
	if grove_name:
		grove_name.text = _loc(GROVE_KEY)
		grove_name.visible = true


func _hold_grove_then_cut() -> void:
	var tree := get_tree()
	if tree:
		await tree.create_timer(GROVE_HOLD_SEC).timeout
	_cut_to_hall()


func _cut_to_hall() -> void:
	var grove_cam: Camera3D = get_node_or_null("Grove/Camera3D") as Camera3D
	if grove_cam:
		grove_cam.current = false
	var cid_cam: Camera3D = get_node_or_null("Cid/CameraRig/Camera3D") as Camera3D
	if cid_cam:
		cid_cam.current = true
	var grove: Node3D = get_node_or_null("Grove") as Node3D
	if grove:
		grove.visible = false


func _hide_grove() -> void:
	_grove_shown = false
	var grove: Node3D = get_node_or_null("Grove") as Node3D
	if grove:
		grove.visible = false
	var stain: Node = get_node_or_null("Grove/LeafStain")
	if stain and "visible" in stain:
		stain.visible = false
	var grove_cam: Camera3D = get_node_or_null("Grove/Camera3D") as Camera3D
	if grove_cam:
		grove_cam.current = false


func _finish_report() -> void:
	if _reported:
		return
	_reported = true
	_talking = false
	_show_reporter()
	_show_daughters()
	_apply_news()
	_skip_san_esteban()
	_whisper(ALIVE_KEY)
	_show_choice()


func _apply_news() -> void:
	if _news_applied:
		return
	_news_applied = true
	for flag in NEWS_FLAGS:
		_set_flag(StringName(flag))
	_apply_honor(NEWS_EVENT)


func _skip_san_esteban() -> void:
	var clock := _autoload("CampaignClock")
	if clock and clock.has_method("advance_calendar"):
		clock.call("advance_calendar", SKIP_DAYS)


func _finish_beat() -> void:
	_hold_cid_mesura(false)
	_freeze_cid(false)
	if _left:
		return
	# ChapterRunner.travel emits beat_completed; only emit here if travel does not run.
	if not _dest_ready() or not _travel(DEST):
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_checkpoint()


func _dest_ready() -> bool:
	return ResourceLoader.exists(DEST_SCENE)


func _hide_arrivals() -> void:
	for path in ["Felez", "DiegoTellez", "Elvira", "Sol"]:
		_set_body_active(get_node_or_null(path), false)


func _show_reporter() -> void:
	_set_body_active(get_node_or_null("Felez"), true)
	_set_body_active(get_node_or_null("DiegoTellez"), true)


func _show_daughters() -> void:
	_set_body_active(get_node_or_null("Elvira"), true)
	_set_body_active(get_node_or_null("Sol"), true)
	_seat_family()


func _seat_family() -> void:
	var bench: Node3D = get_node_or_null("HallBench") as Node3D
	var origin := Vector3(-1.6, 0.05, 1.6)
	if bench:
		origin = bench.global_position
	var elvira: Node3D = get_node_or_null("Elvira") as Node3D
	var sol: Node3D = get_node_or_null("Sol") as Node3D
	if elvira:
		elvira.global_position = origin + Vector3(-0.7, 0.0, 0.1)
	if sol:
		sol.global_position = origin + Vector3(0.7, 0.0, 0.1)


func _set_body_active(node: Node, active: bool) -> void:
	if node == null:
		return
	_set_body_colliders(node, active)
	if node is Node3D:
		(node as Node3D).visible = active


func _set_body_colliders(node: Node, active: bool) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if not body.has_meta("host_layer"):
			body.set_meta("host_layer", body.collision_layer)
		body.collision_layer = int(body.get_meta("host_layer")) if active else 0
		if node is Area3D:
			(node as Area3D).monitorable = active
	for child in node.get_children():
		_set_body_colliders(child, active)


func _connect_zones() -> void:
	_connect_zone("ReportZone", _on_report_entered)


func _connect_zone(node_name: String, cb: Callable) -> void:
	var zone: Area3D = get_node_or_null(node_name) as Area3D
	if zone and not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)


func _on_report_entered(body: Node) -> void:
	if body == null or _reported:
		return
	if not (body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")):
		return
	if not _warned:
		_present_warning()


func _freeze_cid(on: bool) -> void:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return
	if cid.has_method("set_chapter_locked"):
		cid.call("set_chapter_locked", on)
	elif "chapter_locked" in cid:
		cid.chapter_locked = on


func _hold_cid_mesura(on: bool) -> void:
	var mesura := _cid_mesura()
	if mesura and mesura.has_method("set_holding"):
		mesura.set_holding(on)


func _cid_mesura() -> Node:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return null
	var found: Node = cid.get_node_or_null("Mesura")
	if found:
		return found
	return cid.find_child("Mesura", true, false)


func _hold_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"hold")
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()


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


func _name_horse() -> void:
	_set_flag(&"babieca_named")
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("apply_name"):
		horse.call("apply_name", HORSE_ID, HORSE_KEY)
	var label: Label3D = get_node_or_null("Horse/Name") as Label3D
	if label:
		label.text = _loc(HORSE_KEY)
		label.visible = true


func _label_people() -> void:
	_set_label("Jimena/Name", "char.jimena")
	_set_label("Elvira/Name", "char.elvira")
	_set_label("Sol/Name", "char.sol")
	_set_label("Felez/Name", "char.felez_munoz")
	_set_label("DiegoTellez/Name", "char.diego_tellez")


func _set_label(path: String, key: String) -> void:
	var label: Label3D = get_node_or_null(path) as Label3D
	if label:
		label.text = _loc(key)


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


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
	if not _reported:
		_finish_report()
		return
	if _path != &"":
		_finish_beat()


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
