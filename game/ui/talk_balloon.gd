class_name TalkBalloon
extends CanvasLayer
## Parchment balloon. Spoken lines are Loc CSV keys.

var dialogue_resource: Resource
var temporary_game_states: Array = []
var _line: Variant = null
var _waiting: bool = false

@onready var _character: Label = $Panel/Character
@onready var _body: Label = $Panel/Line
@onready var _panel: Control = $Panel


func _ready() -> void:
	add_to_group("talk_balloon")
	if _panel:
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _panel.gui_input.is_connected(_on_panel_gui_input):
			_panel.gui_input.connect(_on_panel_gui_input)


func start(resource: Resource, cue: String = "", extra_game_states: Array = []) -> void:
	dialogue_resource = resource
	temporary_game_states = extra_game_states
	await _show_cue(cue)
	show()


func _show_cue(cue: String) -> void:
	if dialogue_resource == null or not dialogue_resource.has_method("get_next_dialogue_line"):
		queue_free()
		return
	_line = await dialogue_resource.get_next_dialogue_line(cue, temporary_game_states + [self])
	_apply(_line)


func _apply(line: Variant) -> void:
	if line == null:
		queue_free()
		return
	_line = line
	if _character:
		_character.text = str(line.character) if "character" in line else ""
	if _body:
		var key := str(line.text) if "text" in line else ""
		_body.text = Loc.text(key) if Loc else key
	_waiting = true


func _input(event: InputEvent) -> void:
	if _try_advance(event):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func _on_panel_gui_input(event: InputEvent) -> void:
	if _try_advance(event) and _panel:
		_panel.accept_event()


func _try_advance(event: InputEvent) -> bool:
	if not _waiting or event.is_echo():
		return false
	if not _is_advance_event(event):
		return false
	if _is_advance_click(event) and _click_on_hud_sink(event):
		return false
	_waiting = false
	var next_id := str(_line.next_id) if _line != null and "next_id" in _line else ""
	_show_cue.call_deferred(next_id)
	return true


func _is_advance_event(event: InputEvent) -> bool:
	if _is_advance_click(event):
		return true
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")


func _is_advance_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _click_on_hud_sink(event: InputEvent) -> bool:
	if not is_inside_tree():
		return false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton:
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
	else:
		var vp := get_viewport()
		pos = vp.get_mouse_position() if vp else Vector2.ZERO
	for node in get_tree().get_nodes_in_group("hud_click_sink"):
		if not (node is Control):
			continue
		var ctl := node as Control
		if ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(pos):
			return true
	return false
