class_name BeatDirector
extends Node

## Interprets content/chapters/<id>/beats.json. Dialogue / speech types wait on later PRs.

const STEP_TYPES := [
	"blocking",
	"cinematic",
	"dialogue",
	"choice",
	"travel_spawn",
	"honor_event",
	"set_flags",
	"clock_segment",
	"keep_or_sell",
	"speech_trial",
	"fail_copy",
	"siege_event",
	"embassy_ledger",
	"whisper",
]

var beat_id: StringName = &""
var steps: Array = []
var step_index: int = 0


func start(id: StringName) -> void:
	beat_id = id
	step_index = 0
	steps = _load_steps(id)
	skip_repeatable()


func skip_repeatable() -> void:
	# WHY: first-arrival / corridor steps with skip_if do not replay on a return visit.
	while step_index >= 0 and step_index < steps.size():
		var raw: Variant = steps[step_index]
		if raw is Dictionary and _should_skip(raw):
			step_index += 1
			continue
		break


func advance() -> bool:
	skip_repeatable()
	if step_index < 0 or step_index >= steps.size():
		return false
	var raw: Variant = steps[step_index]
	if not raw is Dictionary:
		return false
	var source_id := beat_id
	if not run_step(raw):
		return false
	# travel() already called start() on this director; do not skip dest step 0.
	if beat_id == source_id:
		step_index += 1
	return true


func run_step(step: Dictionary) -> bool:
	var step_type := str(step.get("type", ""))
	var ok := false
	match step_type:
		"set_flags":
			ok = true
		"honor_event":
			ok = _run_honor(step)
		"travel_spawn":
			ok = _run_travel(step)
		"clock_segment":
			ok = _run_clock(step)
		"fail_copy":
			ok = _run_fail(step)
		_:
			ok = String(step_type) in STEP_TYPES
	if not ok:
		return false
	# GDD puts set_flags on cinematic/dialogue/etc., not only type set_flags.
	_apply_flags(step.get("set_flags", []))
	return true


func _load_steps(id: StringName) -> Array:
	var path := "res://content/chapters/%s/beats.json" % String(id)
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var raw: Variant = parsed.get("steps", [])
		if raw is Array:
			return raw
	elif parsed is Array:
		return parsed
	return []


func _should_skip(step: Dictionary) -> bool:
	var raw: Variant = step.get("skip_if", [])
	if not (raw is PackedStringArray or raw is Array):
		return false
	var runner := _autoload("ChapterRunner")
	var have: PackedStringArray = PackedStringArray()
	if runner != null and "flags" in runner:
		have = runner.flags
	for flag in raw:
		if str(flag) in have:
			return true
	return false


func _apply_flags(raw: Variant) -> void:
	var runner := _autoload("ChapterRunner")
	if runner == null or not runner.has_method("add_flag"):
		return
	if raw is PackedStringArray or raw is Array:
		for flag in raw:
			runner.add_flag(str(flag))


func _run_honor(step: Dictionary) -> bool:
	var honor := _autoload("HonorService")
	if honor == null or not honor.has_method("apply_id"):
		return false
	var event_id := str(step.get("id", step.get("honor_event", "")))
	if event_id.is_empty():
		return false
	honor.apply_id(StringName(event_id))
	return true


func _run_travel(step: Dictionary) -> bool:
	var runner := _autoload("ChapterRunner")
	if runner == null or not runner.has_method("travel"):
		return false
	var next_id := str(step.get("next", ""))
	if next_id.is_empty():
		return false
	return bool(runner.travel(StringName(next_id)))


func _run_clock(step: Dictionary) -> bool:
	var clock := _autoload("CampaignClock")
	if clock == null or not ("segment" in clock):
		return false
	# Integers match CampaignClock.Segment order; avoid autoload enum lookup.
	var name := str(step.get("segment", "")).to_lower()
	var value := 0
	match name:
		"camp_night":
			value = 1
		"refuse_48h":
			value = 2
		"siege":
			value = 3
		"lists_wait":
			value = 4
		_:
			value = 0
	clock.segment = value
	return true


func _run_fail(step: Dictionary) -> bool:
	var bus := _autoload("EventBus")
	if bus == null:
		return false
	var reason := str(step.get("reason", "name_empty"))
	bus.hard_fail.emit(StringName(reason))
	return true


func _autoload(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(name))
	var parent := get_parent()
	if parent == null:
		return null
	var root := parent.get_parent()
	if root:
		return root.get_node_or_null(NodePath(name))
	return parent.get_node_or_null(NodePath(name))
