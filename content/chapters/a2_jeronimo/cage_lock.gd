extends StaticBody3D
## Closed cage. Interact refuses; the lion scene is later.


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("try_open_cage"):
		host.try_open_cage()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("try_open_cage") and node.has_method("is_cage_closed"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
