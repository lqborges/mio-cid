extends Node3D
## a2_yusuf day 2: Jimena-wall cinematic, one player couch, resolve. Not a second encounter.

const BEAT_ID := &"a2_yusuf"
const DEST := &"a2_embassy3"
const EMBASSY3_SCENE := "res://content/chapters/a2_embassy3/world.tscn"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const NAMED_FLAG := &"babieca_named"
const DAY1_FLAG := "yusuf_day1_done"
const DAY2_FLAG := "yusuf_day2_done"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const YUSUF_ID := &"yusuf"
const WIN_EVENT := &"yusuf_day2"
const WATCH_KEY := "a2_yusuf.day2_watch"
const CHARGE_KEY := "a2_yusuf.day2_charge"
const WIN_KEY := "a2_yusuf.day2_win"
const WALL_KEY := "a2_yusuf.wall_refused"
const PLACE_KEY := "a2_yusuf.place_name"

var _cinematic_done: bool = false
var _charged: bool = false
var _couches: int = 0
var _resolved: bool = false
var _wall_refused: bool = false
var _left: bool = false


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if ChapterRunner and ChapterRunner.has_method("add_flag"):
		ChapterRunner.add_flag(HORSE_FLAG)
		ChapterRunner.add_flag(DAY1_FLAG)
		if ChapterRunner.has_method("has_flag") and not bool(ChapterRunner.has_flag(HUB_LOCK)):
			ChapterRunner.add_flag(String(HUB_LOCK))
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_hide_plazo_bar()
	_name_horse()
	_label_jimena()
	_bind_yusuf()
	_connect_yusuf()
	_connect_charge_zone()
	_connect_climb_zone()
	_show_place_name()
	play_cinematic()


func play_cinematic() -> bool:
	if _cinematic_done:
		return true
	_cinematic_done = true
	look_from_wall()
	_whisper(WATCH_KEY)
	var player: AnimationPlayer = get_node_or_null("Day2Cinematic") as AnimationPlayer
	if player and player.has_animation("watch"):
		if not player.animation_finished.is_connected(_on_watch_finished):
			player.animation_finished.connect(_on_watch_finished)
		_set_cid_frozen(true)
		player.play("watch")
	return true


func _on_watch_finished(_anim: StringName = &"") -> void:
	return_to_cid_camera()


func start_charge(_cue: String = "charge") -> void:
	if _charged or _resolved:
		return
	_charged = true
	play_cinematic()
	_whisper(CHARGE_KEY)
	return_to_cid_camera()
	_couch_once()


func run_charge() -> void:
	# Headless: cinematic + one couch + resolve. Not a field-battle director.
	play_cinematic()
	start_charge()
	complete_resolve()


func start_cue(cue: String) -> void:
	if cue == "watch" or cue == "cinematic" or cue == "look":
		play_cinematic()
	elif cue == "charge" or cue == "couch":
		start_charge()
	elif cue == "win" or cue == "resolve":
		complete_resolve()
	elif cue == "wall" or cue == "storm" or cue == "climb":
		try_storm_wall()


func complete_resolve() -> void:
	if _resolved:
		return
	_charged = true
	_resolved = true
	_apply_honor(WIN_EVENT)
	_set_flag(DAY2_FLAG)
	_whisper(WIN_KEY)
	_set_zone_monitoring("ChargeZone", false)
	_leave_for_embassy3()


func can_storm_wall() -> bool:
	return false


func try_storm_wall() -> void:
	_wall_refused = true
	_whisper(WALL_KEY)


func look_from_wall() -> bool:
	var cam := _jimena_camera()
	if cam == null:
		return false
	cam.current = true
	return true


func return_to_cid_camera() -> void:
	_set_cid_frozen(false)
	var player: AnimationPlayer = get_node_or_null("Day2Cinematic") as AnimationPlayer
	if player:
		if player.animation_finished.is_connected(_on_watch_finished):
			player.animation_finished.disconnect(_on_watch_finished)
		if player.is_playing():
			player.stop()
	var cid_cam: Camera3D = get_node_or_null("Cid/CameraRig/Camera3D") as Camera3D
	if cid_cam:
		cid_cam.current = true
	var wall := _jimena_camera()
	if wall and wall != cid_cam:
		wall.current = false


func jimena_on_wall() -> bool:
	var jimena: Node3D = get_node_or_null("Jimena") as Node3D
	var walk: Node3D = get_node_or_null("WallWalk") as Node3D
	if jimena == null or walk == null:
		return false
	return jimena.global_position.y >= walk.global_position.y - 0.2


func is_scripted_day2() -> bool:
	return true


func charge_count() -> int:
	return _couches


func can_leave_to_embassy3() -> bool:
	if not _resolved:
		return false
	return _can_travel(DEST)


func travel_to_embassy3() -> bool:
	if not _resolved:
		return false
	return _leave_for_embassy3()


func _leave_for_embassy3() -> bool:
	if _left:
		return _already_on_dest()
	_left = true
	var travelled := false
	if ChapterRunner and ChapterRunner.has_method("can_travel"):
		var flags: PackedStringArray = ChapterRunner.flags if "flags" in ChapterRunner else PackedStringArray()
		if not bool(ChapterRunner.can_travel(BEAT_ID, DEST, flags)):
			_emit_completed()
			_checkpoint()
			return false
	if ChapterRunner and ChapterRunner.has_method("travel"):
		travelled = bool(ChapterRunner.travel(DEST))
	if not travelled:
		_emit_completed()
		if ChapterRunner and ChapterRunner.has_method("complete_current"):
			ChapterRunner.complete_current()
	_checkpoint()
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return travelled
	# travel() does not change scenes.
	if not ResourceLoader.exists(EMBASSY3_SCENE):
		return travelled
	if ChapterRunner and ChapterRunner.has_method("goto"):
		ChapterRunner.goto(DEST)
	return travelled


func _already_on_dest() -> bool:
	if ChapterRunner and "current_id" in ChapterRunner:
		return String(ChapterRunner.current_id) == String(DEST)
	return true


func _emit_completed() -> void:
	if EventBus and EventBus.has_signal("beat_completed"):
		EventBus.beat_completed.emit(BEAT_ID)


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


func _connect_charge_zone() -> void:
	var zone: Area3D = get_node_or_null("ChargeZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_charge_entered):
		zone.body_entered.connect(_on_charge_entered)


func _on_charge_entered(body: Node) -> void:
	if body == null:
		return
	if not (body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")):
		return
	start_charge()
	if _couches < 1:
		return
	complete_resolve()


func _connect_yusuf() -> void:
	var node: Node = get_node_or_null("Host/Yusuf")
	if node == null:
		return
	var hurt: Node = node.get_node_or_null("HurtBox")
	if hurt == null or not hurt.has_signal("died"):
		return
	if not hurt.died.is_connected(_on_yusuf_died):
		hurt.died.connect(_on_yusuf_died)


func _on_yusuf_died() -> void:
	start_charge()
	complete_resolve()


func _connect_climb_zone() -> void:
	var zone: Area3D = get_node_or_null("ClimbZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_climb_entered):
		zone.body_entered.connect(_on_climb_entered)


func _on_climb_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		try_storm_wall()


func _couch_once() -> void:
	if _couches > 0:
		return
	_couches += 1
	var charge := _cavalry()
	if charge == null or not charge.has_method("couch"):
		return
	charge.call("couch")


func _cavalry() -> Node:
	var horse: Node = get_node_or_null("Horse")
	if horse == null:
		return null
	var nested: Node = horse.get_node_or_null("CavalryCharge")
	if nested:
		return nested
	if "cavalry" in horse:
		var bound: Variant = horse.get("cavalry")
		if bound is Node:
			return bound
	return null


func _bind_yusuf() -> void:
	var node: Node = get_node_or_null("Host/Yusuf")
	if node == null:
		return
	if "character_id" in node:
		node.set("character_id", YUSUF_ID)


func _set_zone_monitoring(zone_name: String, on: bool) -> void:
	var zone: Area3D = get_node_or_null(zone_name) as Area3D
	if zone:
		zone.monitoring = on


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _name_horse() -> void:
	_set_flag(NAMED_FLAG)
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("apply_name"):
		horse.call("apply_name", HORSE_ID, HORSE_KEY)
	var label: Label3D = get_node_or_null("Horse/Name") as Label3D
	if label:
		label.text = _loc(HORSE_KEY)
		label.visible = true


func _label_jimena() -> void:
	var label: Label3D = get_node_or_null("Jimena/Name") as Label3D
	if label:
		label.text = _loc("char.jimena")
	var yusuf: Label3D = get_node_or_null("Host/Yusuf/Name") as Label3D
	if yusuf:
		yusuf.text = _loc("char.yusuf")


func _jimena_camera() -> Camera3D:
	var nested: Camera3D = get_node_or_null("Jimena/JimenaCamera") as Camera3D
	if nested:
		return nested
	return get_node_or_null("JimenaCamera") as Camera3D


func _honor() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath("HonorService"))
	return null


func _apply_honor(event_id: StringName) -> void:
	var honor := _honor()
	if honor == null:
		return
	if honor.has_method("apply_id"):
		honor.apply_id(event_id)
	elif honor.has_method("apply"):
		honor.call("apply", event_id)


func _set_flag(flag_id: StringName) -> void:
	if ChapterRunner == null:
		return
	if ChapterRunner.has_method("add_flag"):
		ChapterRunner.add_flag(String(flag_id))
	elif ChapterRunner.has_method("set_flag"):
		ChapterRunner.set_flag(flag_id)


func _can_travel(dest: StringName) -> bool:
	if ChapterRunner == null or not ChapterRunner.has_method("can_travel"):
		return false
	var flags: PackedStringArray = ChapterRunner.flags if "flags" in ChapterRunner else PackedStringArray()
	return bool(ChapterRunner.can_travel(BEAT_ID, dest, flags))


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


func _set_cid_frozen(frozen: bool) -> void:
	var mode := Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	for path in ["Cid", "Horse"]:
		var node: Node = get_node_or_null(path)
		if node:
			node.process_mode = mode
