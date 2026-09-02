extends Control
## Cheat vs refuse. Spanish labels; English loc keys.

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal_choice")
	add_to_group("hud_click_sink")
	_apply_copy()
	var cheat: Button = get_node_or_null("Panel/Cheat") as Button
	var refuse: Button = get_node_or_null("Panel/Refuse") as Button
	if cheat and not cheat.pressed.is_connected(_on_cheat):
		cheat.pressed.connect(_on_cheat)
	if refuse and not refuse.pressed.is_connected(_on_refuse):
		refuse.pressed.connect(_on_refuse)


func present() -> void:
	_apply_copy()
	visible = true


func dismiss() -> void:
	visible = false


func _apply_copy() -> void:
	var prompt: Label = get_node_or_null("Panel/Prompt") as Label
	var cheat: Button = get_node_or_null("Panel/Cheat") as Button
	var refuse: Button = get_node_or_null("Panel/Refuse") as Button
	if prompt:
		prompt.text = _loc("a1_arcas.prompt")
	if cheat:
		cheat.text = _loc("a1_arcas.choice_cheat")
	if refuse:
		refuse.text = _loc("a1_arcas.choice_refuse")


func _on_cheat() -> void:
	var host := _chapter()
	if host and host.has_method("choose_cheat"):
		host.choose_cheat()


func _on_refuse() -> void:
	var host := _chapter()
	if host and host.has_method("choose_refuse"):
		host.choose_refuse()


func _loc(key: String) -> String:
	return Loc.text(key) if Loc else key


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("choose_cheat") and node.has_method("choose_refuse"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
