class_name MesuraComponent
extends Node

## Hold to wait / parry / rotate-in. Dump spends ira and sinks honra.

const TRAITS_PATH := "res://data/mesura_traits.json"
const HONOR_DUMP_ID := &"rage_dump"
const GROUP := &"mesura"

signal held_changed(holding: bool)
signal dumped(honra_delta: float)
signal rotate_in_requested()
signal parry_landed()

var traits: Dictionary = {}
var mesura: float = 0.0
var ira: float = 0.0
var holding: bool = false
var rotate_in_ready: bool = false
var unlocked: PackedStringArray = []

var _hold_elapsed: float = 0.0
var _strike_lock: float = 0.0
var _hold_fights: int = 0
var _hold_saw_threat: bool = false
var _speech_lines: int = 0


func _init() -> void:
	load_traits()


func _ready() -> void:
	add_to_group(String(GROUP))
	set_physics_process(true)
	var bus := _event_bus()
	if bus != null and bus.has_signal("honor_logged"):
		if not bus.honor_logged.is_connected(_on_honor_logged):
			bus.honor_logged.connect(_on_honor_logged)
	_sync_honor()


func load_traits() -> void:
	traits = _load_json(TRAITS_PATH)
	mesura = float(traits.get("mesura_start", 0.0))
	ira = float(traits.get("ira_start", 0.0))


func is_holding() -> bool:
	return holding


func is_waiting() -> bool:
	return holding


func set_holding(on: bool) -> void:
	if holding == on:
		return
	if holding and not on:
		_finish_hold()
	holding = on
	_hold_elapsed = 0.0
	_hold_saw_threat = false
	rotate_in_ready = holding
	if holding:
		rotate_in_requested.emit()
	held_changed.emit(holding)


func try_dump() -> bool:
	if holding:
		return false
	if ira + 0.0001 < float(traits.get("dump_ira_min", 0.0)):
		return false
	var event := _make_dump_event()
	var honra_delta := event.delta_for(&"honra")
	if event.delta_for(&"onores") != 0.0:
		event.deltas.erase("onores")
		event.deltas.erase(&"onores")
	var service := _honor_service()
	if service != null and service.has_method("apply"):
		service.apply(event)
	ira = 0.0
	note_strike()
	_sync_honor()
	var combat := _combat()
	if combat != null and combat.has_method("dump_strike"):
		combat.dump_strike()
	dumped.emit(honra_delta)
	return true


func try_parry() -> bool:
	if not is_parry_open():
		return false
	_hold_saw_threat = true
	var gain := float(traits.get("parry_mesura", 0.0))
	mesura = minf(_mesura_max(), mesura + gain)
	_sync_honor()
	parry_landed.emit()
	return true


func is_parry_open() -> bool:
	if not holding:
		return false
	return _hold_elapsed <= _parry_window_sec()


func note_strike() -> void:
	_strike_lock = float(traits.get("mesura_pause_after_strike_sec", 0.0))


func note_hit_taken() -> void:
	_hold_saw_threat = holding
	add_ira(float(traits.get("ira_on_hit", 0.0)))


func add_ira(amount: float) -> void:
	ira = clampf(ira + amount, 0.0, _ira_max())
	_sync_honor()


func note_mesura_speech() -> void:
	_speech_lines += 1
	_try_unlock(&"hablar_poco", "mesura_speech_lines", _speech_lines)


func grant_trait(id: StringName) -> bool:
	if has_trait(id):
		return false
	if unlocked.size() >= _trait_cap():
		return false
	if _trait_row(id).is_empty():
		return false
	unlocked.append(String(id))
	return true


func has_trait(id: StringName) -> bool:
	return String(id) in unlocked


func stamina_regen_mult() -> float:
	if not holding:
		return 1.0
	return float(traits.get("hold_stamina_regen_mult", 1.0))


func move_mult() -> float:
	if not holding:
		return 1.0
	return float(traits.get("hold_move_mult", 1.0))


func time_scale() -> float:
	if not holding:
		return 1.0
	return float(traits.get("hold_time_scale", 1.0))


func rotate_in_cooldown_mult() -> float:
	var mult := float(traits.get("rotate_in_cooldown_mult", 1.0))
	if has_trait(&"dejar_golpear"):
		var row := _trait_row(&"dejar_golpear")
		if row.has("rotate_in_cooldown_mult"):
			mult = float(row["rotate_in_cooldown_mult"])
	return mult


func dump_move() -> Dictionary:
	return {
		"damage": float(traits.get("dump_damage", 0.0)),
		"stagger": float(traits.get("dump_stagger", 0.0)),
		"duration": float(traits.get("dump_duration", 0.0)),
		"radius": float(traits.get("dump_radius", 0.0)),
		"stamina": float(traits.get("dump_stamina", 0.0)),
	}


func tick(delta: float) -> void:
	if holding:
		_hold_elapsed += delta
	if _strike_lock > 0.0:
		_strike_lock = maxf(_strike_lock - delta, 0.0)
	elif not _is_striking():
		var regen := float(traits.get("mesura_regen_per_sec", 0.0))
		mesura = minf(_mesura_max(), mesura + regen * delta)
	_sync_honor()


func _physics_process(delta: float) -> void:
	tick(delta)


func _on_honor_logged(event: HonorEvent) -> void:
	if event == null:
		return
	if event.id == HONOR_DUMP_ID:
		return
	if event.has_tag(&"mesura_fail"):
		add_ira(float(traits.get("ira_on_mesura_fail", 0.0)))
	var eid := String(event.id)
	for trait_id in ["mesa_para_el_conde", "querella_not_hueste"]:
		var row := _trait_row(StringName(trait_id))
		var unlocks: Variant = row.get("unlocks_at", {})
		if unlocks is Dictionary and str((unlocks as Dictionary).get("honor_event", "")) == eid:
			grant_trait(StringName(trait_id))


func _finish_hold() -> void:
	rotate_in_ready = false
	var min_sec := float(traits.get("hold_fight_min_sec", 0.0))
	if _hold_elapsed + 0.0001 >= min_sec and _hold_saw_threat:
		_hold_fights += 1
		_try_unlock(&"dejar_golpear", "hold_fights", _hold_fights)


func _try_unlock(id: StringName, key: String, value: int) -> void:
	var row := _trait_row(id)
	var unlocks: Variant = row.get("unlocks_at", {})
	if not unlocks is Dictionary:
		return
	if int((unlocks as Dictionary).get(key, 0)) <= 0:
		return
	if value >= int((unlocks as Dictionary).get(key, 0)):
		grant_trait(id)


func _parry_window_sec() -> float:
	var ms := float(traits.get("hold_parry_window_ms", 0.0))
	var combat := _combat()
	if combat != null and "difficulty" in combat:
		ms += float(combat.difficulty.get("parry_window_ms", 0.0))
	return maxf(ms, 0.0) / 1000.0


func _make_dump_event() -> HonorEvent:
	var ev := HonorEvent.new()
	ev.id = HONOR_DUMP_ID
	ev.tags = PackedStringArray(["mesura_fail"])
	var honra := float(traits.get("dump_honra", 0.0))
	var service := _honor_service()
	if service != null and service.has_method("event_by_id"):
		var catalog: Variant = service.event_by_id(HONOR_DUMP_ID)
		if catalog is HonorEvent:
			var src: HonorEvent = catalog
			ev.id = src.id
			ev.tags = src.tags.duplicate()
			ev.beat = src.beat
			honra = src.delta_for(&"honra")
	var sinks := 1.0
	var combat := _combat()
	if combat != null and "difficulty" in combat:
		sinks = float(combat.difficulty.get("meter_sinks", 1.0))
	ev.deltas = {"honra": honra * sinks}
	return ev


func _sync_honor() -> void:
	var state := _honor_state()
	if state == null:
		return
	if "mesura" in state:
		state.mesura = mesura
	if "rage" in state:
		state.rage = ira


func _honor_state() -> HonorState:
	var service := _honor_service()
	if service != null and "state" in service and service.state is HonorState:
		return service.state
	return null


func _honor_service() -> Node:
	var tree := _scene_tree()
	if tree != null:
		var node := tree.root.get_node_or_null("HonorService")
		if node != null:
			return node
	return null


func _event_bus() -> Node:
	var tree := _scene_tree()
	if tree != null:
		return tree.root.get_node_or_null("EventBus")
	return null


func _combat() -> Node:
	var body := get_parent()
	if body == null:
		return null
	return body.get_node_or_null("CidCombat")


func _is_striking() -> bool:
	var combat := _combat()
	if combat == null:
		return false
	if combat.has_method("is_attacking"):
		return bool(combat.is_attacking())
	return false


func _mesura_max() -> float:
	return float(traits.get("mesura_max", 0.0))


func _ira_max() -> float:
	return float(traits.get("ira_max", 0.0))


func _trait_cap() -> int:
	return int(traits.get("trait_cap", 0))


func _trait_row(id: StringName) -> Dictionary:
	var rows: Variant = traits.get("traits", [])
	if not rows is Array:
		return {}
	for row in rows:
		if row is Dictionary and str((row as Dictionary).get("id", "")) == String(id):
			return row
	return {}


func _scene_tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _exit_tree() -> void:
	if holding:
		set_holding(false)
