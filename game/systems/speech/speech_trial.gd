class_name SpeechTrial
extends Node
## Court speech runtime. Not an autoload — each hall owns its own node.

signal ask_resolved(index: int, tags: PackedStringArray)
signal ask_retry(index: int)
signal trial_won
signal trial_failed
signal skip_blocked
signal steel_drawn_fail

const STEEL_FAIL := &"steel_in_cortes"

@export var asks: Array[SpeechAsk] = []
@export var win_threshold: float = 12.0
var _index: int = 0
var legal_score: float = 0.0
var mesura_score: float = 0.0
var ira_score: float = 0.0
var third_ask_allowed: bool = true
var _steel_failed: bool = false


func submit_line(ask_index: int, line_id: StringName) -> void:
	if _steel_failed:
		return
	# Locked order: jumping ahead is a ruled fail, never an assert.
	if ask_index != _index or ask_index < 0 or ask_index >= asks.size():
		skip_blocked.emit()
		return
	var ask := asks[ask_index]
	if ask == null:
		skip_blocked.emit()
		return
	if not third_ask_allowed and ask_index == 2:
		skip_blocked.emit()
		return
	var line := ask.get_line(line_id)
	if line == null:
		skip_blocked.emit()
		return
	if line.has_tag(&"draw_steel"):
		_fail_steel()
		return
	if line.has_tag(&"skip_to_riepto"):
		third_ask_allowed = false
		skip_blocked.emit()
		return
	var net := line.legal - line.ira
	if net < 0.0:
		ask_retry.emit(_index)  # do not commit; retries must not stack
		return
	if ask.counts_toward_win:
		legal_score += net
		mesura_score += line.mesura
		ira_score += line.ira
	ask_resolved.emit(ask_index, line.tags)
	_index += 1
	if _index >= asks.size():
		if legal_score >= win_threshold:
			trial_won.emit()
		else:
			trial_failed.emit()
			_index = asks.size() - 1  # retry last ask
	elif _index == 2 and not third_ask_allowed:
		trial_failed.emit()


func current_ask() -> SpeechAsk:
	if _index < 0 or _index >= asks.size():
		return null
	return asks[_index]


func current_index() -> int:
	return _index


func steel_failed() -> bool:
	return _steel_failed


func _fail_steel() -> void:
	_steel_failed = true
	steel_drawn_fail.emit()
	trial_failed.emit()
	var bus := _event_bus()
	if bus != null and bus.has_signal("hard_fail"):
		bus.hard_fail.emit(STEEL_FAIL)


func _event_bus() -> Object:
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree():
		return get_tree().root.get_node_or_null("EventBus")
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null
