extends StaticBody3D
## Greybox Jimena. Interact starts the three-week rest.

func _ready() -> void:
	add_to_group("interactable")


func interact_prompt_key() -> String:
	return "hud.interact_verb"


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("rest_three_weeks"):
		host.rest_three_weeks()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("rest_three_weeks") and node.has_method("wait_done"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
