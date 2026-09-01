extends Node3D
## a3_pentecost: poem ending. He dies. The horse is not a bier.

const BEAT_ID := &"a3_pentecost"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const PLACE_KEY := "a3_pentecost.place_name"
const TABLE_KEY := "a3_pentecost.table"
const DEATH_KEY := "a3_pentecost.death"
const CREDITS_KEY := "a3_pentecost.credits"

var _ended: bool = false
var _credits: bool = false


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
	_forbid_corpse_horse()
	_connect_zones()
	_show_place_name()
	_name_horse()
	_label_people()
	_whisper(TABLE_KEY)
	_show_credits(false)


func start_cue(cue: String) -> void:
	match cue:
		"death", "die", "end":
			play_death()
		"credits":
			show_credits()


func play_death(_cue: String = "death") -> void:
	if _ended:
		show_credits()
		return
	_ended = true
	_set_flag(&"cid_dead")
	_set_flag(&"pentecost_done")
	_unmount_if_needed()
	_hide_cid_standing()
	_whisper(DEATH_KEY)
	if EventBus and EventBus.has_signal("beat_completed"):
		EventBus.beat_completed.emit(BEAT_ID)
	_checkpoint()
	show_credits()


func show_credits() -> void:
	_credits = true
	_show_credits(true)
	_whisper(CREDITS_KEY)


func campaign_ended() -> bool:
	return _ended


func credits_visible() -> bool:
	var panel: Node = find_child("Credits", true, false)
	return _credits and panel != null and bool(panel.visible)


func babieca_has_corpse() -> bool:
	if has_node("BabiecaCorpse") or has_node("CorpseOnBabieca"):
		return true
	var horse: Node = get_node_or_null("Horse")
	if horse == null:
		return false
	if horse.get_node_or_null("Corpse") != null:
		return true
	if horse.get_node_or_null("CidCorpse") != null:
		return true
	if "has_corpse" in horse and bool(horse.get("has_corpse")):
		return true
	return false


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func _forbid_corpse_horse() -> void:
	# The poem ends at Pentecost. Babieca is a living companion, not a bier.
	var corpse := get_node_or_null("BabiecaCorpse")
	if corpse:
		corpse.queue_free()


func _unmount_if_needed() -> void:
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("dismount"):
		horse.call("dismount")
	var cid: Node = get_node_or_null("Cid")
	if cid and cid.has_method("is_mounted") and bool(cid.call("is_mounted")):
		if "chapter_locked" in cid:
			cid.chapter_locked = true


func _hide_cid_standing() -> void:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return
	if cid.has_method("set_chapter_locked"):
		cid.call("set_chapter_locked", true)
	cid.visible = false


func _show_credits(on: bool) -> void:
	var panel: CanvasItem = find_child("Credits", true, false) as CanvasItem
	if panel:
		panel.visible = on
	var line: Label = find_child("CreditsLine", true, false) as Label
	if line:
		line.text = _loc(CREDITS_KEY)


func _connect_zones() -> void:
	_connect_zone("EpilogueZone", _on_epilogue_entered)


func _connect_zone(node_name: String, cb: Callable) -> void:
	var zone: Area3D = get_node_or_null(node_name) as Area3D
	if zone and not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)


func _on_epilogue_entered(body: Node) -> void:
	if body == null or _ended:
		return
	if not (body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")):
		return
	play_death()


func _hold_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada and mesnada.has_method("set_order"):
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


func _set_label(path: String, key: String) -> void:
	var label: Label3D = get_node_or_null(path) as Label3D
	if label:
		label.text = _loc(key)


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)


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
