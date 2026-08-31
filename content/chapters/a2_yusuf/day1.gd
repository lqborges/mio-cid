extends Node3D
## a2_yusuf day 1: huerta field battle. Jimena watches from the wall. Not a climb.

const BEAT_ID := &"a2_yusuf"
const DEST := &"a2_embassy3"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const NAMED_FLAG := &"babieca_named"
const DAY1_FLAG := "yusuf_day1_done"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const YUSUF_ID := &"yusuf"
const WIN_EVENT := &"yusuf_win"
const FIELD_KEY := "a2_yusuf.field"
const WIN_KEY := "a2_yusuf.win"
const WALL_KEY := "a2_yusuf.wall_refused"
const WATCH_KEY := "a2_yusuf.jimena_watch"
const HOLD_KEY := "a2_yusuf.day1_hold"
const PLACE_KEY := "a2_yusuf.place_name"
const DIALOGUE_PATH := "res://content/chapters/a2_yusuf/yusuf.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"

var _raid_started: bool = false
var _won: bool = false
var _held: bool = false
var _wall_refused: bool = false
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
	_name_horse()
	_label_jimena()
	_bind_yusuf()
	_connect_field_zone()
	_connect_climb_zone()
	_connect_host()
	_show_place_name()
	_whisper(WATCH_KEY)


func start_field(_cue: String = "field") -> void:
	if _raid_started or _won or _held:
		return
	_raid_started = true
	_whisper(FIELD_KEY)
	_form_wedge()
	if _host_left <= 0:
		complete_win()


func run_field() -> void:
	# Headless: win the huerta without walking FieldZone.
	start_field()
	_host_left = 0
	complete_win()


func start_cue(cue: String) -> void:
	if cue == "field" or cue == "dawn" or cue == "battle":
		start_field()
	elif cue == "win":
		complete_win()
	elif cue == "wall" or cue == "storm" or cue == "climb":
		try_storm_wall()
	elif cue == "look":
		look_from_wall()


func complete_win() -> void:
	if _won:
		return
	_raid_started = true
	_won = true
	_apply_honor(WIN_EVENT)
	_set_flag(DAY1_FLAG)
	_whisper(WIN_KEY)
	_set_zone_monitoring("FieldZone", false)
	_hold_for_day2()


func can_storm_wall() -> bool:
	# Field battle in the huerta. Jimena is already on the wall.
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


func can_leave_to_embassy3() -> bool:
	# Day 2 (PR-27b) still owns the embassy3 exit.
	return false


func travel_to_embassy3() -> bool:
	return false


func _hold_for_day2() -> void:
	if _held:
		return
	_held = true
	_whisper(HOLD_KEY)
	_checkpoint()


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


func _connect_field_zone() -> void:
	var zone: Area3D = get_node_or_null("FieldZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_field_entered):
		zone.body_entered.connect(_on_field_entered)


func _on_field_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_field()


func _connect_climb_zone() -> void:
	var zone: Area3D = get_node_or_null("ClimbZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_climb_entered):
		zone.body_entered.connect(_on_climb_entered)


func _on_climb_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		try_storm_wall()


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
	if _raid_started and _host_left <= 0:
		complete_win()


func _bind_yusuf() -> void:
	var node: Node = get_node_or_null("Host/Yusuf")
	if node == null:
		return
	var member := MesnadaMember.from_id(YUSUF_ID)
	if member == null:
		return
	if "character_id" in node:
		node.set("character_id", YUSUF_ID)
	if "unkillable" in node:
		node.set("unkillable", member.unkillable)
	var hurt: Node = node.get_node_or_null("HurtBox")
	if member.unkillable or hurt == null:
		return
	if "max_hp" in hurt:
		hurt.max_hp = member.combat
		hurt.hp = member.combat


func _set_zone_monitoring(zone_name: String, on: bool) -> void:
	var zone: Area3D = get_node_or_null(zone_name) as Area3D
	if zone:
		zone.monitoring = on


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
