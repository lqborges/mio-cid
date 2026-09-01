extends Node3D
## a3_querella: Valencia hall. Dictate the complaint. Mesura is law.

const BEAT_ID := &"a3_querella"
const DEST := &"a3_toledo"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const FILE_EVENT := &"querella_filed"
const RIDE_EVENT := &"ride_host_to_carrion"
const PLACE_KEY := "a3_querella.place_name"
const TABLE_KEY := "a3_querella.table"
const SENT_KEY := "a3_querella.sent"
const RIDE_KEY := "a3_querella.ride_host"
const WAIT_KEY := "a3_querella.toledo_wait"
const TRIAL_PATH := "res://data/speech/querella.json"
const DEST_SCENE := "res://content/chapters/a3_toledo/world.tscn"
const WIN_FLAGS := ["querella_filed", "querella_done"]

var _started: bool = false
var _filed: bool = false
var _host_ridden: bool = false
var _left: bool = false


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
	_load_querella()
	_connect_trial()
	_connect_zones()
	_show_place_name()
	_name_horse()
	_label_people()
	_whisper(TABLE_KEY)


func start_cue(cue: String) -> void:
	if cue == "dictate" or cue == "querella":
		start_dictate()
	elif cue == "legal":
		run_legal()
	elif cue == "mesura":
		run_mesura()
	elif cue == "ira":
		run_ira()
	elif cue == "ride_host" or cue == "host":
		run_ride_host()


func start_dictate(_cue: String = "dictate") -> void:
	if _started or _filed or _host_ridden:
		return
	_started = true
	_freeze_cid(true)
	_bind_ui()
	_whisper(TABLE_KEY)


func run_legal() -> void:
	_submit(&"legal")


func run_mesura() -> void:
	_submit(&"mesura")


func run_ira() -> void:
	_submit(&"ira")


func run_ride_host() -> void:
	_submit(&"ride_host")


func try_travel_toledo() -> bool:
	if not _filed and not _host_ridden:
		return false
	if not _dest_ready():
		_whisper(WAIT_KEY)
		return false
	return _travel(DEST)


func can_leave_to_toledo() -> bool:
	if not _filed or _host_ridden:
		return false
	return _can_travel(DEST)


func querella_filed() -> bool:
	return _filed


func host_ridden() -> bool:
	return _host_ridden


func trial() -> SpeechTrial:
	return get_node_or_null("SpeechTrial") as SpeechTrial


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func _submit(line_id: StringName) -> void:
	start_dictate()
	var node := trial()
	if node == null:
		return
	node.submit_line(node.current_index(), line_id)


func _load_querella() -> void:
	var node := trial()
	if node == null:
		node = SpeechTrial.new()
		node.name = "SpeechTrial"
		add_child(node)
	if not FileAccess.file_exists(TRIAL_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRIAL_PATH))
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	node.win_threshold = float(data.get("win_threshold", 6.0))
	var asks: Array[SpeechAsk] = []
	var raw_asks: Variant = data.get("asks", [])
	if raw_asks is Array:
		for item in raw_asks:
			if item is Dictionary:
				asks.append(_ask_from_dict(item))
	node.asks = asks


func _ask_from_dict(data: Dictionary) -> SpeechAsk:
	var ask := SpeechAsk.new()
	ask.id = StringName(str(data.get("id", "")))
	ask.prompt_key = StringName(str(data.get("prompt_key", "")))
	ask.counts_toward_win = bool(data.get("counts_toward_win", true))
	var lines: Array[SpeechLine] = []
	var raw_lines: Variant = data.get("lines", [])
	if raw_lines is Array:
		for item in raw_lines:
			if item is Dictionary:
				lines.append(_line_from_dict(item))
	ask.lines = lines
	return ask


func _line_from_dict(data: Dictionary) -> SpeechLine:
	var line := SpeechLine.new()
	line.id = StringName(str(data.get("id", "")))
	line.text_key = StringName(str(data.get("text_key", "")))
	line.legal = float(data.get("legal", 0.0))
	line.mesura = float(data.get("mesura", 0.0))
	line.ira = float(data.get("ira", 0.0))
	line.vo_id = StringName(str(data.get("vo_id", "")))
	var tags := PackedStringArray()
	var raw_tags: Variant = data.get("tags", [])
	if raw_tags is Array:
		for tag in raw_tags:
			tags.append(str(tag))
	line.tags = tags
	return line


func _connect_trial() -> void:
	var node := trial()
	if node == null:
		return
	if not node.ask_resolved.is_connected(_on_ask_resolved):
		node.ask_resolved.connect(_on_ask_resolved)
	if not node.trial_won.is_connected(_on_trial_won):
		node.trial_won.connect(_on_trial_won)
	if not node.trial_failed.is_connected(_on_trial_failed):
		node.trial_failed.connect(_on_trial_failed)


func _bind_ui() -> void:
	var ui: Node = find_child("SpeechTrialUI", true, false)
	var node := trial()
	if ui and ui.has_method("bind") and node:
		ui.call("bind", node)


func _hide_trial_ui() -> void:
	var ui: Node = find_child("SpeechTrialUI", true, false)
	if ui == null:
		return
	if ui.has_method("bind"):
		ui.call("bind", null)
	ui.visible = false


func _on_ask_resolved(_index: int, tags: PackedStringArray) -> void:
	if "ride_host" in tags:
		_apply_ride_host()


func _on_trial_won() -> void:
	if _host_ridden:
		_finish_beat()
		return
	_file_querella()
	_finish_beat()


func _on_trial_failed() -> void:
	if _host_ridden:
		_finish_beat()


func _file_querella() -> void:
	if _filed:
		return
	_filed = true
	for flag in WIN_FLAGS:
		_set_flag(StringName(flag))
	_apply_honor(FILE_EVENT)
	if EventBus and EventBus.has_signal("querella_sent"):
		EventBus.querella_sent.emit()
	_whisper(SENT_KEY)
	_send_muno()


func _apply_ride_host() -> void:
	if _host_ridden:
		return
	_host_ridden = true
	_set_flag(&"ride_host")
	_apply_honor(RIDE_EVENT)
	_whisper(RIDE_KEY)


func _send_muno() -> void:
	_set_body_active(get_node_or_null("MunoGustioz"), false)


func _finish_beat() -> void:
	_freeze_cid(false)
	_hide_trial_ui()
	if _left:
		return
	# ChapterRunner.travel emits beat_completed; only emit here if travel does not run.
	if not _dest_ready() or not _travel(DEST):
		if not _dest_ready():
			_whisper(WAIT_KEY)
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_checkpoint()


func _dest_ready() -> bool:
	return ResourceLoader.exists(DEST_SCENE)


func _connect_zones() -> void:
	_connect_zone("DictateZone", _on_dictate_entered)


func _connect_zone(node_name: String, cb: Callable) -> void:
	var zone: Area3D = get_node_or_null(node_name) as Area3D
	if zone and not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)


func _on_dictate_entered(body: Node) -> void:
	if body == null or _started:
		return
	if not (body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")):
		return
	start_dictate()


func _freeze_cid(on: bool) -> void:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return
	if cid.has_method("set_chapter_locked"):
		cid.call("set_chapter_locked", on)
	elif "chapter_locked" in cid:
		cid.chapter_locked = on


func _hold_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"hold")
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()


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
	_set_label("MunoGustioz/Name", "char.muno_gustioz")


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
	if _host_ridden:
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
