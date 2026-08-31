extends Node3D
## a2_siege: nine months as authored events on CampaignClock.SIEGE. No second clock.

const BEAT_ID := &"a2_siege"
const DEST := &"a2_jeronimo"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HELD_EVENT := &"valencia_held"
const CAMP_KEY := "a2_siege.camp"
const STORM_KEY := "a2_siege.storm_refused"
const PLACE_KEY := "a2_siege.place_name"
const DIALOGUE_PATH := "res://content/chapters/a2_siege/siege.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const EVENTS_PATH := "res://data/siege/valencia_events.json"

var calendar: SiegeCalendar
var _siege_start_day: int = 0
var _fired: PackedStringArray = PackedStringArray()
var _sally_open: bool = false
var _storm_refused: bool = false
var _left: bool = false
var _host_left: int = 0


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
	_load_calendar()
	_bind_clock()
	_set_host_active(false)
	_connect_storm_zone()
	_connect_rest_zone()
	_connect_host()
	_hide_storm_prompt()
	_show_place_name()
	_whisper(CAMP_KEY)
	_apply_rest_copy()


func clock() -> Node:
	return _clock()


func siege_day() -> int:
	var clock := _clock()
	if clock == null:
		return 0
	return maxi(0, int(clock.days_elapsed) - _siege_start_day)


func events_fired() -> PackedStringArray:
	return _fired.duplicate()


func can_storm_wall() -> bool:
	if calendar == null:
		return false
	return bool(calendar.wall_storm_enabled)


func try_storm_wall() -> void:
	# Offered, then refused. Álvar: this cantar is not a climb.
	_storm_refused = true
	_whisper(STORM_KEY)
	_show_storm_prompt()


func start_cue(cue: String) -> void:
	if cue == "storm":
		try_storm_wall()
	elif cue == "rest" or cue == "skip":
		rest_skip()
	elif cue == "sally":
		complete_sally()
	elif cue == "calendar":
		run_calendar()


func rest_skip() -> void:
	if _left or _sally_open:
		return
	_load_calendar()
	var clock := _clock()
	if clock == null or calendar == null:
		return
	var days := calendar.rest_skip_days()
	if days <= 0:
		return
	if clock.has_method("advance_calendar"):
		clock.advance_calendar(days)
	_fire_due()


func run_calendar() -> void:
	# Headless: rest-skip the authored events; auto-resolve sallies. Same CampaignClock.
	if _left:
		return
	_load_calendar()
	if calendar == null:
		return
	var guard := 0
	var max_skips := calendar.event_count()
	if calendar.rest_skip_min_days > 0:
		max_skips = calendar.siege_days / calendar.rest_skip_min_days + calendar.event_count()
	while _fired.size() < calendar.event_count() and guard < max_skips:
		if _sally_open:
			complete_sally()
		else:
			rest_skip()
		guard += 1
	if _sally_open:
		complete_sally()
	if _fired.size() >= calendar.event_count():
		_leave_for_jeronimo()


func complete_sally() -> void:
	if not _sally_open:
		return
	_sally_open = false
	_host_left = 0
	_set_host_active(false)
	_fire_due()
	if calendar and _fired.size() >= calendar.event_count():
		_leave_for_jeronimo()


func _bind_clock() -> void:
	var clock := _clock()
	if clock == null:
		return
	_siege_start_day = int(clock.days_elapsed)
	if clock.has_method("set_segment_name"):
		clock.set_segment_name("siege")
	elif "segment" in clock:
		clock.segment = clock.Segment.SIEGE if "Segment" in clock else clock.segment


func _load_calendar() -> void:
	if calendar != null:
		return
	calendar = SiegeCalendar.from_file(EVENTS_PATH)


func _fire_due() -> void:
	_load_calendar()
	if calendar == null:
		return
	var due: Array = calendar.due(siege_day(), _fired)
	for raw in due:
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw
		if str(row.get("type", "")) == "sally":
			if not _sally_open:
				_start_sally(row)
				if _sally_open:
					return
		_apply_event(row)
	if calendar.event_count() > 0 and _fired.size() >= calendar.event_count():
		_leave_for_jeronimo()


func _start_sally(row: Dictionary) -> void:
	_whisper(_event_key(row))
	_set_host_active(true)
	_form_wedge()
	if _host_left <= 0:
		_set_host_active(false)
		return
	_sally_open = true


func _apply_event(row: Dictionary) -> void:
	var eid := str(row.get("id", ""))
	if eid.is_empty() or eid in _fired:
		return
	_fired.append(eid)
	var honor_id := str(row.get("honor_event", ""))
	if not honor_id.is_empty():
		_apply_honor(StringName(honor_id))
	_whisper(_event_key(row))


func _event_key(row: Dictionary) -> String:
	var scene := str(row.get("scene", ""))
	if scene.is_empty():
		return CAMP_KEY
	return "a2_siege.%s" % scene


func _leave_for_jeronimo() -> void:
	if _left:
		return
	if calendar and _fired.size() < calendar.event_count():
		return
	_left = true
	var travelled := false
	if ChapterRunner and ChapterRunner.has_method("can_travel"):
		var flags: PackedStringArray = ChapterRunner.flags if "flags" in ChapterRunner else PackedStringArray()
		if not bool(ChapterRunner.can_travel(BEAT_ID, DEST, flags)):
			if EventBus and EventBus.has_signal("beat_completed"):
				EventBus.beat_completed.emit(BEAT_ID)
			_checkpoint()
			return
	if ChapterRunner and ChapterRunner.has_method("travel"):
		travelled = bool(ChapterRunner.travel(DEST))
	if not travelled:
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
	_checkpoint()
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return
	if ChapterRunner and ChapterRunner.has_method("goto"):
		ChapterRunner.goto(DEST)


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


func _connect_storm_zone() -> void:
	var zone: Area3D = get_node_or_null("StormZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_storm_entered):
		zone.body_entered.connect(_on_storm_entered)


func _on_storm_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		try_storm_wall()


func _connect_rest_zone() -> void:
	var zone: Area3D = get_node_or_null("RestZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_rest_entered):
		zone.body_entered.connect(_on_rest_entered)


func _on_rest_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		rest_skip()


func _connect_host() -> void:
	var host: Node = get_node_or_null("Host")
	if host == null:
		return
	_host_left = 0
	for child in host.get_children():
		var hurt: Node = child.get_node_or_null("HurtBox")
		if hurt == null or not hurt.has_signal("died"):
			continue
		_host_left += 1
		if not hurt.died.is_connected(_on_host_died):
			hurt.died.connect(_on_host_died)


func _on_host_died() -> void:
	_host_left = maxi(0, _host_left - 1)
	if _sally_open and _host_left <= 0:
		complete_sally()


func _set_host_active(active: bool) -> void:
	var host: Node = get_node_or_null("Host")
	if host == null:
		return
	host.visible = active
	host.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_host_collision(host, active)


func _set_host_collision(node: Node, active: bool) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if not body.has_meta("host_layer"):
			body.set_meta("host_layer", body.collision_layer)
		body.collision_layer = int(body.get_meta("host_layer")) if active else 0
		if node is Area3D:
			(node as Area3D).monitorable = active
	for child in node.get_children():
		_set_host_collision(child, active)


func _show_storm_prompt() -> void:
	var ui: Node = find_child("StormPrompt", true, false)
	if ui == null:
		return
	if ui.has_method("present"):
		ui.call("present")
	else:
		ui.visible = true


func _hide_storm_prompt() -> void:
	var ui: Node = find_child("StormPrompt", true, false)
	if ui == null:
		return
	if ui.has_method("dismiss"):
		ui.call("dismiss")
	else:
		ui.visible = false


func _apply_rest_copy() -> void:
	var rest: Node = find_child("RestSkip", true, false)
	if rest == null:
		return
	var line: Label = rest.get_node_or_null("Line") as Label
	if line:
		line.text = _loc("a2_siege.rest_skip")


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _form_wedge() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"charge")


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
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath("HonorService"))
	return null


func _clock() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath("CampaignClock"))
	return null


func _apply_honor(event_id: StringName) -> void:
	var honor := _honor()
	if honor == null:
		return
	if honor.has_method("apply_id"):
		honor.apply_id(event_id)
	elif honor.has_method("apply"):
		honor.call("apply", event_id)


func _show_place_name() -> void:
	var label: Label3D = get_node_or_null("PlaceName") as Label3D
	if label == null:
		return
	label.text = _loc(PLACE_KEY)
	label.visible = true


func _loc(key: String) -> String:
	if Loc and Loc.has_method("text"):
		return str(Loc.text(key))
	return key


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))
