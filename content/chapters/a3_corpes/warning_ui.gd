extends Control
## Content warning. Hear-only skips images, not the fact.

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal_choice")
	add_to_group("hud_click_sink")
	_apply_copy()
	var hear: Button = get_node_or_null("Panel/Hear") as Button
	var see: Button = get_node_or_null("Panel/See") as Button
	if hear and not hear.pressed.is_connected(_on_hear):
		hear.pressed.connect(_on_hear)
	if see and not see.pressed.is_connected(_on_see):
		see.pressed.connect(_on_see)


func present() -> void:
	_apply_copy()
	visible = true


func dismiss() -> void:
	visible = false


func _apply_copy() -> void:
	var prompt: Label = get_node_or_null("Panel/Prompt") as Label
	var hear: Button = get_node_or_null("Panel/Hear") as Button
	var see: Button = get_node_or_null("Panel/See") as Button
	if prompt:
		prompt.text = _loc("a3_corpes.warning")
	if hear:
		hear.text = _loc("a3_corpes.choice_hear")
	if see:
		see.text = _loc("a3_corpes.choice_see")


func _on_hear() -> void:
	var host := _chapter()
	if host and host.has_method("choose_hear"):
		host.choose_hear()


func _on_see() -> void:
	var host := _chapter()
	if host and host.has_method("choose_see"):
		host.choose_see()


func _loc(key: String) -> String:
	return Loc.text(key) if Loc else key


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("choose_hear") and node.has_method("choose_see"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
