extends Control
## One shout per duel. Spanish labels; English loc keys.

signal chosen(shout_id: StringName)

var _duel_index: int = 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal_choice")
	add_to_group("hud_click_sink")
	_bind_buttons()
	_apply_copy()


func present(duel_index: int) -> void:
	_duel_index = duel_index
	_apply_copy()
	visible = true


func dismiss() -> void:
	visible = false


func _bind_buttons() -> void:
	_connect_btn("Panel/Silence", &"shout_silence")
	_connect_btn("Panel/Once", &"shout_once")
	_connect_btn("Panel/TooMuch", &"shout_too_much")


func _connect_btn(path: String, shout_id: StringName) -> void:
	var btn: Button = get_node_or_null(path) as Button
	if btn and not btn.pressed.is_connected(_on_pressed.bind(shout_id)):
		btn.pressed.connect(_on_pressed.bind(shout_id))


func _on_pressed(shout_id: StringName) -> void:
	var host := _chapter()
	if host and host.has_method("choose_shout"):
		host.call("choose_shout", shout_id)
		return
	chosen.emit(shout_id)


func _apply_copy() -> void:
	var prompt: Label = get_node_or_null("Panel/Prompt") as Label
	if prompt:
		prompt.text = "%s (%s/3)" % [_loc("a3_carrion.shout_prompt"), str(_duel_index + 1)]
	_set_btn("Panel/Silence", "a3_carrion.shout_silence")
	_set_btn("Panel/Once", "a3_carrion.shout_once")
	_set_btn("Panel/TooMuch", "a3_carrion.shout_too_much")


func _set_btn(path: String, key: String) -> void:
	var btn: Button = get_node_or_null(path) as Button
	if btn:
		btn.text = _loc(key)


func _loc(key: String) -> String:
	return Loc.text(key) if Loc else key


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("choose_shout"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
