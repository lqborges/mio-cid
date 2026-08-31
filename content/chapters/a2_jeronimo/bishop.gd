extends StaticBody3D
## Greybox Jerónimo. Interact is the appointment, not a fight.

@export var character_id: StringName = &"jeronimo"
@export var cue: String = "appoint"


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_appoint"):
		host.start_appoint()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_appoint") and node.has_method("appoint_jeronimo"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
