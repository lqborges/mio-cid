extends Control
## Wall-storm is offered and refused. Spanish labels; English loc keys.

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal_choice")
	add_to_group("hud_click_sink")
	_apply_copy()
	var storm: Button = get_node_or_null("Panel/Storm") as Button
	if storm and not storm.pressed.is_connected(_on_storm):
		storm.pressed.connect(_on_storm)
	var wait: Button = get_node_or_null("Panel/Wait") as Button
	if wait and not wait.pressed.is_connected(_on_wait):
		wait.pressed.connect(_on_wait)


func present() -> void:
	_apply_copy()
	visible = true


func dismiss() -> void:
	visible = false


func _apply_copy() -> void:
	var prompt: Label = get_node_or_null("Panel/Prompt") as Label
	var storm: Button = get_node_or_null("Panel/Storm") as Button
	var wait: Button = get_node_or_null("Panel/Wait") as Button
	if prompt:
		prompt.text = _loc("a2_siege.storm_prompt")
	if storm:
		storm.text = _loc("a2_siege.choice_storm")
	if wait:
		wait.text = _loc("a2_siege.choice_wait")


func _on_storm() -> void:
	var host := _chapter()
	if host and host.has_method("try_storm_wall"):
		host.call("try_storm_wall")


func _on_wait() -> void:
	dismiss()


func _loc(key: String) -> String:
	return Loc.text(key) if Loc else key


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("try_storm_wall"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
