extends StaticBody3D
## Cloak bed. Interact is sleep, not a fight.

func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_sleep"):
		host.start_sleep()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_sleep") and node.has_method("complete_dream"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
