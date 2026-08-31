extends Node
# Autoload HonorService extends this script. Do not add class_name (collides with the singleton).

const EVENTS_PATH := "res://data/honor_events/core.json"
const COMBAT_TAGS := PackedStringArray(["battle", "raid", "combat"])

var state: HonorState = HonorState.new()
var roster: Variant = null
var catalog: Dictionary = {}

var _applied_once: Dictionary = {}
var _uncurable_honra: bool = false


func _ready() -> void:
	_load_catalog()


func reset_state() -> void:
	state = HonorState.new()
	_applied_once.clear()
	_uncurable_honra = false


func event_by_id(id: StringName) -> HonorEvent:
	if catalog.is_empty():
		_load_catalog()
	var found: Variant = catalog.get(String(id))
	return found if found is HonorEvent else null


func apply_id(id: StringName) -> Dictionary:
	var event := event_by_id(id)
	if event == null:
		push_warning("HonorService: unknown event %s" % String(id))
		return {}
	return apply(event)


func apply(event: HonorEvent) -> Dictionary:
	if event == null:
		return {}
	if catalog.is_empty():
		_load_catalog()
	if event.once and _applied_once.has(String(event.id)):
		return {}
	if _blocks_combat_honra(event):
		return {}
	var result := state.apply(event)
	if event.once:
		_applied_once[String(event.id)] = true
	if event.has_tag(&"uncurable_by_combat"):
		_uncurable_honra = true
	if event.has_tag(&"speech"):
		_uncurable_honra = false
	_apply_flags(event)
	EventBus.honor_logged.emit(event)
	# Distinct EventBus signals; never fold one into the other.
	if result.has("soft_warn") and result["soft_warn"] != &"":
		EventBus.soft_warn.emit(result["soft_warn"])
	if result.has("hard_fail") and result["hard_fail"] != &"":
		EventBus.hard_fail.emit(result["hard_fail"])
	return result


func _blocks_combat_honra(event: HonorEvent) -> bool:
	if not _uncurable_honra:
		return false
	if event.delta_for(&"honra") <= 0.0:
		return false
	for tag in COMBAT_TAGS:
		if event.has_tag(StringName(tag)):
			return true
	return false


func _apply_flags(event: HonorEvent) -> void:
	if event.flags_set.is_empty():
		return
	if ChapterRunner == null or not ("flags" in ChapterRunner):
		return
	var flags: PackedStringArray = ChapterRunner.flags
	for flag in event.flags_set:
		if flag not in flags:
			flags.append(flag)
	ChapterRunner.flags = flags


func _load_catalog() -> void:
	catalog.clear()
	if not FileAccess.file_exists(EVENTS_PATH):
		push_warning("HonorService: missing %s" % EVENTS_PATH)
		return
	var text := FileAccess.get_file_as_string(EVENTS_PATH)
	if text.is_empty():
		push_warning("HonorService: empty %s" % EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	var items: Array = []
	if parsed is Array:
		items = parsed
	elif parsed is Dictionary and parsed.has("events"):
		var raw: Variant = parsed["events"]
		if raw is Array:
			items = raw
	for item in items:
		if not item is Dictionary:
			continue
		var ev := HonorEvent.from_dict(item)
		if String(ev.id).is_empty():
			continue
		catalog[String(ev.id)] = ev
