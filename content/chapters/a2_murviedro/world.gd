extends Node3D
## a2_murviedro: coastal field take, cut roads. Keep the town; no wall climb.

const BEAT_ID := &"a2_murviedro"
const DEST := &"a2_siege"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const TOWN_ID := &"murviedro"
const TAKE_EVENT := &"murviedro_take"
const ROADS_KEY := "a2_murviedro.roads"
const FIELD_KEY := "a2_murviedro.field"
const TAKE_KEY := "a2_murviedro.take_done"
const PLACE_KEY := "a2_murviedro.place_name"
const DIALOGUE_PATH := "res://content/chapters/a2_murviedro/murviedro.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"

var holding: Resource
var _roads_cut: bool = false
var _raid_started: bool = false
var _taken: bool = false
var _left: bool = false
var _garrison_left: int = 0


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
	_load_holding()
	_bind_mesnada()
	_hide_plazo_bar()
	_connect_road_zone()
	_connect_field_zone()
	_connect_garrison()
	_set_zone_monitoring("FieldZone", false)
	_show_place_name()
	_whisper(ROADS_KEY)


func start_roads(_cue: String = "roads") -> void:
	if _roads_cut or _taken or _left:
		return
	complete_roads()


func run_roads() -> void:
	# Headless: cut the roads without walking RoadCutZone.
	start_roads()


func start_take(_cue: String = "field") -> void:
	if not _roads_cut or _raid_started or _taken or _left:
		return
	_raid_started = true
	_whisper(FIELD_KEY)
	_form_wedge()


func run_take() -> void:
	# Headless: cut roads if needed, then take the town without walking FieldZone.
	if not _roads_cut:
		run_roads()
	start_take()
	_garrison_left = 0
	complete_take()


func start_cue(cue: String) -> void:
	if cue == "roads":
		start_roads()
	elif cue == "field" or cue == "take" or cue == "dawn":
		start_take()
	elif cue == "win":
		complete_take()


func complete_roads() -> void:
	if _roads_cut or _taken:
		return
	_roads_cut = true
	_whisper(ROADS_KEY)
	_set_zone_monitoring("RoadCutZone", false)
	_set_zone_monitoring("FieldZone", true)


func complete_take() -> void:
	if _taken or _left:
		return
	if not _roads_cut:
		complete_roads()
	_raid_started = true
	_taken = true
	_hold_town()
	_apply_honor(TAKE_EVENT)
	_whisper(TAKE_KEY)
	_set_zone_monitoring("FieldZone", false)
	_leave_for_siege()


func can_storm_wall() -> bool:
	# Coastal field take; Murviedro is not a climb.
	return false


func _hold_town() -> void:
	_load_holding()
	if holding == null:
		return
	# occupy() would honor-tick take_event_id; complete_take applies it once.
	holding.held = true
	holding.sold = false


func _leave_for_siege() -> void:
	if _left:
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


func _connect_road_zone() -> void:
	var zone: Area3D = get_node_or_null("RoadCutZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_road_entered):
		zone.body_entered.connect(_on_road_entered)


func _on_road_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_roads()


func _connect_field_zone() -> void:
	var zone: Area3D = get_node_or_null("FieldZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_field_entered):
		zone.body_entered.connect(_on_field_entered)


func _on_field_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_take()


func _connect_garrison() -> void:
	var garrison: Node = get_node_or_null("Garrison")
	if garrison == null:
		return
	_garrison_left = 0
	for child in garrison.get_children():
		var hurt: Node = child.get_node_or_null("HurtBox")
		if hurt == null or not hurt.has_signal("died"):
			continue
		_garrison_left += 1
		if not hurt.died.is_connected(_on_dummy_died):
			hurt.died.connect(_on_dummy_died)


func _on_dummy_died() -> void:
	_garrison_left = maxi(0, _garrison_left - 1)
	if _raid_started and _garrison_left <= 0:
		complete_take()


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


func _load_holding() -> void:
	if holding != null:
		return
	holding = TownHolding.from_id(TOWN_ID)


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
