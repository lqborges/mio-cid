extends StaticBody3D
## Greybox Alfonso / Infantes. Interact is court speech, not a fight.

@export var character_id: StringName = &""
@export var cue: String = "pardon"


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_court"):
		host.start_court()
		return
	if host and host.has_method("start_cue"):
		host.start_cue(cue)


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_court") and node.has_method("grant_pardon"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
