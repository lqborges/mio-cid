extends StaticBody3D
## Greybox Jimena / Elvira / Sol in the Valencia hall. Interact is talk, not a fight.

@export var character_id: StringName = &""
@export var cue: String = "depart"


func interact() -> void:
	var host := _chapter()
	if host == null:
		return
	if host.has_method("start_cue"):
		host.start_cue(cue)


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_departure") and node.has_method("run_ambush"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
