extends Control
## Force the count to eat. Spanish labels; English loc keys.

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal_choice")
	add_to_group("hud_click_sink")
	_apply_copy()
	var eat: Button = get_node_or_null("Panel/Eat") as Button
	if eat and not eat.pressed.is_connected(_on_eat):
		eat.pressed.connect(_on_eat)


func present() -> void:
	_apply_copy()
	visible = true


func dismiss() -> void:
	visible = false


func _apply_copy() -> void:
	var prompt: Label = get_node_or_null("Panel/Prompt") as Label
	var eat: Button = get_node_or_null("Panel/Eat") as Button
	if prompt:
		prompt.text = _loc("a1_tevar.table_ask")
	if eat:
		eat.text = _loc("a1_tevar.choice_eat")


func _on_eat() -> void:
	var host := _chapter()
	if host and host.has_method("choose_eat"):
		host.choose_eat()


func _loc(key: String) -> String:
	return Loc.text(key) if Loc else key


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("choose_eat"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
