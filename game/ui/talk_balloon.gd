class_name TalkBalloon
extends CanvasLayer
## Parchment balloon. Spoken lines are Loc CSV keys.

var dialogue_resource: Resource
var temporary_game_states: Array = []
var _line: Variant = null
var _waiting: bool = false

@onready var _character: Label = $Panel/Character
@onready var _body: Label = $Panel/Line


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


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting or event.is_echo():
		return
	var click: bool = false
	if event is InputEventMouseButton:
		click = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_waiting = false
		var next_id := str(_line.next_id) if _line != null and "next_id" in _line else ""
		await _show_cue(next_id)
