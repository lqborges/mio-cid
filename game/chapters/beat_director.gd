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
]

var beat_id: StringName = &""
var steps: Array = []
var step_index: int = 0


func start(id: StringName) -> void:
	beat_id = id
	step_index = 0
	steps = _load_steps(id)


func advance() -> bool:
	if step_index < 0 or step_index >= steps.size():
		return false
	var raw: Variant = steps[step_index]
	step_index += 1
	if raw is Dictionary:
		return run_step(raw)
	return false


func run_step(step: Dictionary) -> bool:
	var step_type := str(step.get("type", ""))
	match step_type:
		"set_flags":
			_apply_flags(step.get("set_flags", []))
			return true
		"honor_event":
			return _run_honor(step)
		"travel_spawn":
			return _run_travel(step)
		"clock_segment":
			return _run_clock(step)
		"fail_copy":
			return _run_fail(step)
		_:
			return String(step_type) in STEP_TYPES


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
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(name))
