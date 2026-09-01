extends StaticBody3D
## Greybox mesnada companion. Interact starts the first-names call.

@export var cue: String = "start"


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_first_names"):
		host.start_first_names(cue)


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_first_names") and node.has_method("leave_solar"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
