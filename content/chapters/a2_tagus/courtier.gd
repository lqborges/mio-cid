extends StaticBody3D
## Greybox Alfonso / Infantes. Interact is court speech, not a fight.

@export var character_id: StringName = &""
@export var cue: String = "pardon"


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_court"):
		host.start_court()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_court") and node.has_method("grant_pardon"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
