extends Node3D
## a3_valencia_wait: three weeks while champions ride. Jimena rest. No combat.

const BEAT_ID := &"a3_valencia_wait"
const DEST := &"a3_carrion"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const PLACE_KEY := "a3_valencia_wait.place_name"
const TABLE_KEY := "a3_valencia_wait.table"
const REST_KEY := "a3_valencia_wait.rested"
const WAIT_KEY := "a3_valencia_wait.carrion_wait"
const DEST_SCENE := "res://content/chapters/a3_carrion/world.tscn"
const WAIT_DAYS := 21
const DIALOGUE_PATH := "res://content/chapters/a3_valencia_wait/wait.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"

var _rested: bool = false
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
	_set_lists_wait()
	_connect_zones()
	_show_place_name()
	_name_horse()
	_label_people()
	_whisper(TABLE_KEY)


func start_cue(cue: String) -> void:
	match cue:
		"rest", "wait", "lists_wait":
			rest_three_weeks()


func rest_three_weeks(_cue: String = "rest") -> bool:
	if _rested:
		return try_travel_carrion()
	var clock := _clock()
	if clock:
		if clock.has_method("set_segment_name"):
			clock.set_segment_name("lists_wait")
		elif "segment" in clock:
			clock.segment = 4
		var before_marks := _marks()
		var before_unfed := int(clock.unfed_streak) if "unfed_streak" in clock else 0
		if clock.has_method("advance_calendar"):
			clock.advance_calendar(WAIT_DAYS)
		if _marks() != before_marks:
			push_error("lists_wait must not spend marks")
		if "unfed_streak" in clock and int(clock.unfed_streak) != before_unfed:
			push_error("lists_wait must not increment unfed_streak")
	_rested = true
	_set_flag(&"lists_wait_done")
	_whisper(REST_KEY)
	_checkpoint()
	if _try_wait_balloon():
		return true
	return try_travel_carrion()


func try_travel_carrion() -> bool:
	if not _rested:
		return false
	if not _dest_ready():
		_whisper(WAIT_KEY)
		return false
	return _travel(DEST)


func can_leave_to_carrion() -> bool:
	if not _rested:
		return false
	return _can_travel(DEST)


func wait_done() -> bool:
	return _rested


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func _set_lists_wait() -> void:
	var clock := _clock()
	if clock == null:
		return
	if clock.has_method("set_segment_name"):
		clock.set_segment_name("lists_wait")
	elif "segment" in clock:
		clock.segment = 4


func _connect_zones() -> void:
	_connect_zone("RestZone", _on_rest_entered)
	_connect_zone("JimenaZone", _on_rest_entered)


func _connect_zone(node_name: String, cb: Callable) -> void:
	var zone: Area3D = get_node_or_null(node_name) as Area3D
	if zone and not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)


func _on_rest_entered(body: Node) -> void:
	if body == null or _rested:
		return
	if not (body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")):
		return
	rest_three_weeks()


func _try_wait_balloon() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return false
	if not ResourceLoader.exists(DIALOGUE_PATH) or not ResourceLoader.exists(BALLOON_PATH):
		return false
	var dm := _autoload("DialogueManager")
	if dm == null or not dm.has_method("show_dialogue_balloon_scene"):
		return false
	var resource: Resource = load(DIALOGUE_PATH)
	if resource == null:
		return false
	if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(_on_wait_dialogue_ended):
		dm.dialogue_ended.connect(_on_wait_dialogue_ended)
	dm.show_dialogue_balloon_scene(BALLOON_PATH, resource, "rest", [self])
	return true


func _on_wait_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _autoload("DialogueManager")
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_wait_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_wait_dialogue_ended)
	try_travel_carrion()


func _dest_ready() -> bool:
	return ResourceLoader.exists(DEST_SCENE)


func _finish_if_rested() -> void:
	if not _rested or _left:
		return
	if not _dest_ready() or not _travel(DEST):
		if not _dest_ready():
			_whisper(WAIT_KEY)
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_checkpoint()


func _hold_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"hold")
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()


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


func _clock() -> Node:
	if GameState and GameState.has_method("clock"):
		var found: Variant = GameState.clock()
		if found is Node:
			return found
	return _autoload("CampaignClock")


func _marks() -> float:
	if GameState and GameState.has_method("treasury"):
		var treasury: Variant = GameState.treasury()
		if treasury != null and "marks" in treasury:
			return float(treasury.marks)
	return 0.0


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


func _set_flag(flag_id: StringName) -> void:
	var runner := _runner()
	if runner == null:
		return
	if runner.has_method("add_flag"):
		runner.add_flag(String(flag_id))


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
