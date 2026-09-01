extends Node3D
## a3_carrion: spectator lists. Cid does not fight.

const BEAT_ID := &"a3_carrion"
const DEST := &"a3_pentecost"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const PLACE_KEY := "a3_carrion.place_name"
const TABLE_KEY := "a3_carrion.table"
const WIN_KEY := "a3_carrion.win_all"
const STAIN_KEY := "a3_carrion.lose_any"
const WAIT_KEY := "a3_carrion.pentecost_wait"
const DEST_SCENE := "res://content/chapters/a3_pentecost/world.tscn"
const LAYER_SPECTATOR := 64

var _shouts: Array = [&"shout_silence", &"shout_silence", &"shout_silence"]
var _duel_index: int = 0
var _results: Array = []
var _resolved: bool = false
var _left: bool = false
var _failed: bool = false


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if ChapterRunner and ChapterRunner.has_method("add_flag"):
		ChapterRunner.add_flag(HORSE_FLAG)
		ChapterRunner.add_flag("duel_spectator")
		if ChapterRunner.has_method("has_flag") and not bool(ChapterRunner.has_flag(HUB_LOCK)):
			ChapterRunner.add_flag(String(HUB_LOCK))
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_ensure_roster()
	_bind_mesnada()
	_hide_plazo_bar()
	_hold_mesnada()
	_make_cid_spectator()
	_connect_zones()
	_show_place_name()
	_name_horse()
	_label_people()
	_whisper(TABLE_KEY)


func start_cue(cue: String) -> void:
	match cue:
		"shout_silence":
			set_shout(&"shout_silence")
		"shout_once":
			set_shout(&"shout_once")
		"shout_too_much":
			set_shout(&"shout_too_much")
		"next_duel":
			advance_duel()
		"resolve", "lists":
			resolve_lists()


func set_shout(shout_id: StringName) -> void:
	if _resolved or _duel_index < 0 or _duel_index > 2:
		return
	_shouts[_duel_index] = shout_id


func advance_duel() -> void:
	if _duel_index < 2:
		_duel_index += 1


func resolve_lists() -> void:
	if _resolved:
		return
	_resolved = true
	var resolver := DuelResolver.new()
	var roster: MesnadaRoster = _roster() as MesnadaRoster
	var honor: HonorState = null
	if GameState and GameState.has_method("honor"):
		var raw: Variant = GameState.honor()
		if raw is HonorState:
			honor = raw
	var swords := {}
	if GameState and GameState.has_method("swords"):
		swords = GameState.swords()
	var flags := PackedStringArray()
	if ChapterRunner and "flags" in ChapterRunner:
		flags = ChapterRunner.flags
	var seed := 1
	if GameState and GameState.has_method("ensure_lists_seed"):
		seed = int(GameState.ensure_lists_seed())
	_results = resolver.resolve_all(roster, honor, swords, flags, _shouts, seed)
	var wins := 0
	for row in _results:
		if row is Dictionary and bool(row.get("won", false)):
			wins += 1
	if EventBus and EventBus.has_signal("lists_finished"):
		EventBus.lists_finished.emit(_results)
	if wins <= 0:
		_failed = true
		_set_flag(&"lists_lost_all")
		if EventBus and EventBus.has_signal("hard_fail"):
			EventBus.hard_fail.emit(&"name_empty")
		return
	if wins < 3:
		_apply_honor(&"lists_lose_any")
		_set_flag(&"lists_lose_any")
		_whisper(STAIN_KEY)
	else:
		_apply_honor(&"lists_win_all")
		_set_flag(&"lists_won")
		_whisper(WIN_KEY)
	_set_flag(&"lists_done")
	_finish_beat()


func try_travel_pentecost() -> bool:
	if not _resolved or _failed:
		return false
	if not _dest_ready():
		_whisper(WAIT_KEY)
		return false
	return _travel(DEST)


func lists_resolved() -> bool:
	return _resolved


func lists_results() -> Array:
	return _results


func cid_is_spectator() -> bool:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return false
	if "spectator_mode" in cid and not bool(cid.spectator_mode):
		return false
	if int(cid.collision_layer) != LAYER_SPECTATOR:
		return false
	return cid.get_node_or_null("HurtBox") == null


func possess_cid_denied() -> bool:
	var cid: Node = get_node_or_null("Cid")
	if cid == null or not cid.has_method("possess_pawn"):
		return true
	return not bool(cid.call("possess_pawn", cid))


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func _make_cid_spectator() -> void:
	var cid: Node = get_node_or_null("Cid")
	if cid and cid.has_method("set_spectator_mode"):
		cid.call("set_spectator_mode", true)
	elif cid:
		cid.collision_layer = LAYER_SPECTATOR
		var hurt: Node = cid.get_node_or_null("HurtBox")
		if hurt:
			hurt.queue_free()


func _finish_beat() -> void:
	if _left or _failed:
		return
	if not _dest_ready() or not _travel(DEST):
		if not _dest_ready():
			_whisper(WAIT_KEY)
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_checkpoint()


func _dest_ready() -> bool:
	return ResourceLoader.exists(DEST_SCENE)


func _connect_zones() -> void:
	_connect_zone("ListZone", _on_list_entered)


func _connect_zone(node_name: String, cb: Callable) -> void:
	var zone: Area3D = get_node_or_null(node_name) as Area3D
	if zone and not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)


func _on_list_entered(body: Node) -> void:
	if body == null or _resolved:
		return
	if not (body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")):
		return
	resolve_lists()


func _hold_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"hold")


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
	_set_label("Alfonso/Name", "char.alfonso")
	_set_label("PeroBermudez/Name", "char.pero_bermudez")
	_set_label("MartinAntolinez/Name", "char.martin_antolinez")
	_set_label("MunoGustioz/Name", "char.muno_gustioz")


func _set_label(path: String, key: String) -> void:
	var label: Label3D = get_node_or_null(path) as Label3D
	if label:
		label.text = _loc(key)


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)


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


func _set_flag(flag_id: StringName) -> void:
	var runner := _runner()
	if runner and runner.has_method("add_flag"):
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
