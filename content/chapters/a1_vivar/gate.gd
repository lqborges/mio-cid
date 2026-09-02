extends StaticBody3D
## South opening. Interact or walk-through leaves the solar.


func _ready() -> void:
	# Cid mask is 5 (layers 1+3). Layer 8 is walk-through; E / group still finds us.
	collision_layer = 8
	collision_mask = 0
	add_to_group("interactable")


func interact() -> bool:
	var host := _chapter()
	if host and host.has_method("leave_solar"):
		host.leave_solar()
		return true
	return false


func interact_prompt_key() -> String:
	return "hud.leave_hint"


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("leave_solar") and node.has_method("start_first_names"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
