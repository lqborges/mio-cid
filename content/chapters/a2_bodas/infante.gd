extends StaticBody3D
## Greybox Infantes. Interact trains them; they will not improve enough.

@export var character_id: StringName = &""
@export var cue: String = "train"


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host == null:
		return
	if cue == "gift" and host.has_method("start_gift"):
		host.start_gift()
		return
	if host.has_method("start_train"):
		host.start_train()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_train") and node.has_method("join_infantes"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
