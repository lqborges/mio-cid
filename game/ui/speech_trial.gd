class_name SpeechTrialUI
extends Control
## Court speech overlay. No timer (accessibility). Spanish copy + English subtitles.

const KEY_RETRY := "speech.ui.retry"
const KEY_SKIP := "speech.ui.skip_blocked"
const KEY_STEEL := "speech.ui.steel"
const KEY_WON := "speech.ui.won"
const KEY_FAILED := "speech.ui.failed"

var trial: SpeechTrial

@onready var _prompt: Label = $Panel/Margin/Column/Prompt
@onready var _prompt_en: Label = $Panel/Margin/Column/PromptEn
@onready var _lines: VBoxContainer = $Panel/Margin/Column/Lines
@onready var _status: Label = $Panel/Margin/Column/Status
@onready var _status_en: Label = $Panel/Margin/Column/StatusEn


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP


func bind(next: SpeechTrial) -> void:
	_disconnect_trial()
	trial = next
	if trial == null:
		hide()
		return
	_connect_trial()
	_set_status("", "")
	show()
	_refresh()


func _connect_trial() -> void:
	if trial == null:
		return
	if not trial.ask_resolved.is_connected(_on_ask_resolved):
		trial.ask_resolved.connect(_on_ask_resolved)
	if not trial.ask_retry.is_connected(_on_ask_retry):
		trial.ask_retry.connect(_on_ask_retry)
	if not trial.skip_blocked.is_connected(_on_skip_blocked):
		trial.skip_blocked.connect(_on_skip_blocked)
	if not trial.trial_won.is_connected(_on_trial_won):
		trial.trial_won.connect(_on_trial_won)
	if not trial.trial_failed.is_connected(_on_trial_failed):
		trial.trial_failed.connect(_on_trial_failed)
	if not trial.steel_drawn_fail.is_connected(_on_steel):
		trial.steel_drawn_fail.connect(_on_steel)


func _disconnect_trial() -> void:
	if trial == null:
		return
	if trial.ask_resolved.is_connected(_on_ask_resolved):
		trial.ask_resolved.disconnect(_on_ask_resolved)
	if trial.ask_retry.is_connected(_on_ask_retry):
		trial.ask_retry.disconnect(_on_ask_retry)
	if trial.skip_blocked.is_connected(_on_skip_blocked):
		trial.skip_blocked.disconnect(_on_skip_blocked)
	if trial.trial_won.is_connected(_on_trial_won):
		trial.trial_won.disconnect(_on_trial_won)
	if trial.trial_failed.is_connected(_on_trial_failed):
		trial.trial_failed.disconnect(_on_trial_failed)
	if trial.steel_drawn_fail.is_connected(_on_steel):
		trial.steel_drawn_fail.disconnect(_on_steel)


func _on_ask_resolved(_index: int, _tags: PackedStringArray) -> void:
	_set_status("", "")
	_refresh()


func _on_ask_retry(_index: int) -> void:
	_set_pair(KEY_RETRY)
	_refresh()


func _on_skip_blocked() -> void:
	_set_pair(KEY_SKIP)
	_refresh()


func _on_trial_won() -> void:
	_set_pair(KEY_WON)
	_refresh()


func _on_trial_failed() -> void:
	if trial != null and trial.steel_failed():
		return
	_set_pair(KEY_FAILED)
	_refresh()


func _on_steel() -> void:
	_set_pair(KEY_STEEL)
	_refresh()


func _refresh() -> void:
	_prompt = get_node_or_null("Panel/Margin/Column/Prompt") as Label
	_prompt_en = get_node_or_null("Panel/Margin/Column/PromptEn") as Label
	_lines = get_node_or_null("Panel/Margin/Column/Lines") as VBoxContainer
	_status = get_node_or_null("Panel/Margin/Column/Status") as Label
	_status_en = get_node_or_null("Panel/Margin/Column/StatusEn") as Label
	_clear_lines()
	if trial == null:
		return
	var ask := trial.current_ask()
	if ask == null:
		if _prompt:
			_prompt.text = ""
		if _prompt_en:
			_prompt_en.text = ""
		return
	if _prompt:
		_prompt.text = _loc_es(String(ask.prompt_key))
	if _prompt_en:
		_prompt_en.text = _loc_en(String(ask.prompt_key))
	var closed := trial.steel_failed()
	for line in ask.lines:
		if line == null:
			continue
		var button := Button.new()
		button.text = "%s\n%s" % [_loc_es(String(line.text_key)), _loc_en(String(line.text_key))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = closed
		button.pressed.connect(_on_line_pressed.bind(line.id))
		if _lines:
			_lines.add_child(button)
	if _lines and _lines.is_inside_tree() and _lines.get_child_count() > 0 and not closed:
		var first: Control = _lines.get_child(0)
		if first.is_inside_tree():
			first.grab_focus()


func _on_line_pressed(line_id: StringName) -> void:
	if trial == null:
		return
	trial.submit_line(trial.current_index(), line_id)


func _clear_lines() -> void:
	if _lines == null:
		return
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.free()


func _set_pair(key: String) -> void:
	_set_status(_loc_es(key), _loc_en(key))


func _set_status(es: String, en: String) -> void:
	if _status:
		_status.text = es
	if _status_en:
		_status_en.text = en


func _loc_es(key: String) -> String:
	if key.is_empty():
		return ""
	var loc := _loc_node()
	if loc == null or not loc.has_method("text"):
		return key
	return str(loc.call("text", key))


func _loc_en(key: String) -> String:
	if key.is_empty():
		return ""
	var loc := _loc_node()
	if loc == null:
		return key
	if loc.has_method("text_in"):
		return str(loc.call("text_in", key, "en"))
	if "locale" in loc and loc.has_method("text"):
		var saved: Variant = loc.get("locale")
		loc.set("locale", "en")
		var value := str(loc.call("text", key))
		loc.set("locale", saved)
		return value
	return key


func _loc_node() -> Object:
	if Engine.has_singleton("Loc"):
		return Engine.get_singleton("Loc")
	if is_inside_tree():
		return get_tree().root.get_node_or_null("Loc")
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Loc")
	return null
