extends Control
## Mesura hold vs rage dump after Félez reports. Ride-host is not offered here.

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_copy()
	var mesura: Button = get_node_or_null("Panel/Mesura") as Button
	var rage: Button = get_node_or_null("Panel/Rage") as Button
	if mesura and not mesura.pressed.is_connected(_on_mesura):
		mesura.pressed.connect(_on_mesura)
	if rage and not rage.pressed.is_connected(_on_rage):
		rage.pressed.connect(_on_rage)


func present() -> void:
	_apply_copy()
	visible = true


func dismiss() -> void:
	visible = false


func _apply_copy() -> void:
	var prompt: Label = get_node_or_null("Panel/Prompt") as Label
	var mesura: Button = get_node_or_null("Panel/Mesura") as Button
	var rage: Button = get_node_or_null("Panel/Rage") as Button
	if prompt:
		prompt.text = _loc("a3_corpes.choice_prompt")
	if mesura:
		mesura.text = _loc("a3_corpes.choice_mesura")
	if rage:
		rage.text = _loc("a3_corpes.choice_rage")


func _on_mesura() -> void:
	var host := _chapter()
	if host and host.has_method("choose_mesura"):
		host.choose_mesura()


func _on_rage() -> void:
	var host := _chapter()
	if host and host.has_method("choose_rage"):
		host.choose_rage()


func _loc(key: String) -> String:
	return Loc.text(key) if Loc else key


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("choose_mesura") and node.has_method("choose_rage"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
