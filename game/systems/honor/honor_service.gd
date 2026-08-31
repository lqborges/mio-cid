extends Node
# Autoload HonorService extends this script. Do not add class_name (collides with the singleton).

const EVENTS_PATH := "res://data/honor_events/core.json"
const COMBAT_TAGS := ["battle", "raid", "combat"]
const STAIN_UNCURABLE := &"uncurable_by_combat"

var state: HonorState = HonorState.new()
var roster: Variant = null
var catalog: Dictionary = {}

var _applied_once: Dictionary = {}


func _ready() -> void:
	_load_catalog()


func reset_state() -> void:
	if state == null:
		state = HonorState.new()
	else:
		state.reset()
	_applied_once.clear()


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
	var to_apply := event
	if _blocks_combat_honra(event):
		to_apply = _with_honra_zeroed(event)
	var result := state.apply(to_apply)
	if event.once:
		_applied_once[String(event.id)] = true
	_apply_flags(event)
	EventBus.honor_logged.emit(to_apply)
	# Distinct EventBus signals; never fold one into the other.
	if result.has("soft_warn") and result["soft_warn"] != &"":
		EventBus.soft_warn.emit(result["soft_warn"])
	if result.has("hard_fail") and result["hard_fail"] != &"":
		EventBus.hard_fail.emit(result["hard_fail"])
	return result


func _blocks_combat_honra(event: HonorEvent) -> bool:
	if state == null or not state.has_stain(STAIN_UNCURABLE):
		return false
	if event.delta_for(&"honra") <= 0.0:
		return false
	for tag in COMBAT_TAGS:
		if event.has_tag(StringName(tag)):
			return true
	return false


func _with_honra_zeroed(event: HonorEvent) -> HonorEvent:
	# New Resource so catalog rows are not mutated.
	var copy := HonorEvent.new()
	copy.id = event.id
	copy.deltas = event.deltas.duplicate()
	copy.deltas.erase("honra")
	if copy.deltas.has(&"honra"):
		copy.deltas.erase(&"honra")
	copy.tags = event.tags.duplicate()
	copy.stain_id = event.stain_id
	copy.clear_stain = event.clear_stain
	copy.flags_set = event.flags_set.duplicate()
	copy.hard_fail = event.hard_fail
	copy.hard_fail_reason = event.hard_fail_reason
	copy.beat = event.beat
	copy.once = event.once
	copy.ui_whisper_key = event.ui_whisper_key
	return copy


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


func consider_name_empty() -> void:
	if CampaignClock == null:
		return
	var streak_hard := 3
	var captains_fail_below := 4
	if TreasuryService and TreasuryService.has_method("tunable_int"):
		streak_hard = TreasuryService.tunable_int("unfed_streak_hard", 3)
		captains_fail_below = TreasuryService.tunable_int("named_captains_fail_below", 4)
	if int(CampaignClock.unfed_streak) < streak_hard:
		return
	var living := 0
	if roster != null and roster.has_method("living_named_captains"):
		living = int(roster.living_named_captains())
	if living < captains_fail_below:
		EventBus.hard_fail.emit(&"name_empty")


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
