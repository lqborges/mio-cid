class_name TownHolding
extends Resource

## Shared keep-or-sell for Castejón / Alcocer. Numbers live in data/towns/.

const TOWNS_DIR := "res://data/towns"
const HOST_FAIL := &"alfonso_host"

@export var location_id: StringName = &""
@export var display_name_key: StringName = &""
@export var beat: StringName = &""
@export var booty: Dictionary = {}
@export var alfonso_protectorate: bool = false
@export var keep_or_sell: bool = true
@export var keep_past_deadline_fail: bool = false
@export var sell_deadline_days: int = 0
@export var take_event_id: StringName = &""
@export var sell_event_id: StringName = &""
@export var keep_event_id: StringName = &""
@export var days_held: int = 0
@export var held: bool = false
@export var sold: bool = false


static func from_id(id: StringName) -> TownHolding:
	var path := "%s/%s.json" % [TOWNS_DIR, String(id)]
	if not FileAccess.file_exists(path):
		push_warning("TownHolding: missing %s" % path)
		return TownHolding.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return from_dict(parsed)
	push_warning("TownHolding: %s is not an object" % path)
	return TownHolding.new()


static func from_dict(data: Dictionary) -> TownHolding:
	var holding := TownHolding.new()
	holding.location_id = _name(data.get("id", data.get("location_id", "")))
	holding.display_name_key = _name(data.get("display_name_key", ""))
	holding.beat = _name(data.get("beat", ""))
	holding.booty = _pile(data.get("booty", {}))
	holding.alfonso_protectorate = bool(data.get("alfonso_protectorate", false))
	holding.keep_or_sell = bool(data.get("keep_or_sell", true))
	holding.keep_past_deadline_fail = bool(data.get("keep_past_deadline_fail", false))
	holding.sell_deadline_days = maxi(0, int(data.get("sell_deadline_days", 0)))
	holding.take_event_id = _name(data.get("take_event_id", ""))
	holding.sell_event_id = _name(data.get("sell_event_id", ""))
	holding.keep_event_id = _name(data.get("keep_event_id", ""))
	return holding


func occupy() -> Dictionary:
	held = true
	sold = false
	days_held = 0
	var result := _blank()
	result["choice"] = &"occupy"
	result["held"] = true
	var honor := _autoload("HonorService")
	if take_event_id != &"" and honor and honor.has_method("apply_id"):
		result["event_id"] = take_event_id
		result["honor"] = honor.apply_id(take_event_id)
	return result


func keep() -> Dictionary:
	var result := _blank()
	result["choice"] = &"keep"
	if sold:
		return result
	held = true
	if alfonso_protectorate:
		return _fail_host(result, false)
	if _past_deadline():
		return _fail_host(result, true)
	result["held"] = true
	return result


func sell(pile: Dictionary = {}, divide_now: bool = true) -> Dictionary:
	var result := _blank()
	result["choice"] = &"sell"
	if sold:
		result["sold"] = true
		return result
	var to_split: Dictionary = pile if not pile.is_empty() else booty
	result["pile"] = to_split
	if divide_now:
		result["split"] = divide(to_split)
	held = false
	sold = true
	result["sold"] = true
	result["held"] = false
	var honor := _autoload("HonorService")
	if sell_event_id != &"" and honor and honor.has_method("apply_id"):
		result["event_id"] = sell_event_id
		result["honor"] = honor.apply_id(sell_event_id)
	return result


func tick_day() -> Dictionary:
	var result := _blank()
	result["choice"] = &"tick"
	if not held or sold:
		return result
	days_held += 1
	result["held"] = true
	if _past_deadline():
		return _fail_host(result, true)
	return result


func divide(pile: Dictionary, _treasury: Variant = null, _roster: Variant = null) -> Dictionary:
	# Fractions and mesnada gifts live on TreasuryService; do not restack onores here.
	var treasury := _autoload("TreasuryService")
	if treasury == null or not treasury.has_method("divide_booty"):
		return {}
	return treasury.divide_booty(pile)


func _past_deadline() -> bool:
	if not keep_past_deadline_fail:
		return false
	return days_held >= sell_deadline_days


func _fail_host(result: Dictionary, apply_keep_event: bool) -> Dictionary:
	held = false
	result["held"] = false
	result["hard_fail"] = HOST_FAIL
	var honor := _autoload("HonorService")
	if apply_keep_event and keep_event_id != &"" and honor and honor.has_method("apply_id"):
		result["event_id"] = keep_event_id
		result["honor"] = honor.apply_id(keep_event_id)
	var bus := _autoload("EventBus")
	if bus:
		bus.hard_fail.emit(HOST_FAIL)
	return result


func _autoload(name: String) -> Node:
	# Global-class parse happens before -s autoload names exist.
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(name))
	return null


func _blank() -> Dictionary:
	return {
		"choice": &"",
		"held": held,
		"sold": sold,
		"hard_fail": &"",
		"event_id": &"",
		"honor": {},
		"split": {},
		"pile": {},
	}


static func _name(raw: Variant) -> StringName:
	if raw == null:
		return &""
	var text := str(raw)
	return StringName(text) if not text.is_empty() else &""


static func _pile(raw: Variant) -> Dictionary:
	var src := {}
	if raw is Dictionary:
		src = raw
	return {
		"marks": maxi(0, int(src.get("marks", 0))),
		"horses": maxi(0, int(src.get("horses", 0))),
		"cloth": maxi(0, int(src.get("cloth", 0))),
		"arms": maxi(0, int(src.get("arms", 0))),
	}
