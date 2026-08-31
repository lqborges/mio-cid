extends Node3D
## a1_poyo: place-name camp. First arrival names the hill; later visits skip it.

const BEAT_ID := &"a1_poyo"
const NAMED_FLAG := &"poyo_named"
const TEVAR_ID := &"a1_tevar"
const CARDENA_ID := &"a1_cardena"
const RAID_ID := &"a1_poyo_raid"

var intro_played: bool = false
var intro_skipped: bool = false
var _booted: bool = false


func _enter_tree() -> void:
	_boot()


func _ready() -> void:
	_boot()
	_connect_zones()


func _boot() -> void:
	if _booted:
		return
	_booted = true
	_bind_chapter()
	apply_arrival()
	_set_camp_night()


func apply_arrival() -> void:
	_show_place_name()
	if intro_played:
		return
	if _has_flag(NAMED_FLAG):
		intro_skipped = true
		return
	play_intro()


func play_intro() -> void:
	intro_played = true
	intro_skipped = false
	_set_flag(NAMED_FLAG)
	_whisper("a1_poyo.arrive")


func rest_camp() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada != null:
		var banner: Node = mesnada.get_node_or_null("Banner")
		# WHY: Banner is a child; look_at requires it already inside the tree.
		if banner != null and banner.is_inside_tree() and mesnada.has_method("plant_banner_at_leader"):
			mesnada.call("plant_banner_at_leader")
		elif "formation" in mesnada:
			mesnada.formation = &"wedge"
	var clock := _clock()
	if clock != null and clock.has_method("rest_camp"):
		clock.call("rest_camp")


func travel_to_tevar() -> bool:
	return _travel(TEVAR_ID)


func try_travel_cardena() -> bool:
	return _travel(CARDENA_ID)


func try_travel_raid() -> bool:
	return _travel(RAID_ID)


func can_leave_to_tevar() -> bool:
	return _can_travel(TEVAR_ID)


func can_return_to_cardena() -> bool:
	return _can_travel(CARDENA_ID)


func raid_open() -> bool:
	return _can_travel(RAID_ID)


func place_name_text() -> String:
	return _loc("a1_poyo.place_name")


func skip_travel_prompt() -> String:
	return _loc("a1_poyo.skip_travel")


func _bind_chapter() -> void:
	var runner := _runner()
	if runner != null and "current_id" in runner:
		runner.current_id = BEAT_ID


func _set_camp_night() -> void:
	var clock := _clock()
	if clock != null and "segment" in clock:
		clock.segment = 1


func _connect_zones() -> void:
	var rest: Area3D = get_node_or_null("RestZone") as Area3D
	if rest != null and not rest.body_entered.is_connected(_on_rest_entered):
		rest.body_entered.connect(_on_rest_entered)
	var exit_zone: Area3D = get_node_or_null("TevarExit") as Area3D
	if exit_zone != null and not exit_zone.body_entered.is_connected(_on_tevar_entered):
		exit_zone.body_entered.connect(_on_tevar_entered)


func _on_rest_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		rest_camp()


func _on_tevar_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		travel_to_tevar()


func _show_place_name() -> void:
	var label: Label3D = get_node_or_null("PlaceName") as Label3D
	if label == null:
		return
	label.text = place_name_text()
	label.visible = true


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper != null and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper != null and whisper.has_method("_show"):
		whisper.call("_show", _loc(key))


func _travel(to_id: StringName) -> bool:
	var runner := _runner()
	if runner == null or not runner.has_method("travel"):
		return false
	if "current_id" in runner:
		runner.current_id = BEAT_ID
	return bool(runner.travel(to_id))


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


func _clock() -> Node:
	return _autoload("CampaignClock")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(node_name))
	return get_node_or_null(NodePath("/root/%s" % node_name))
