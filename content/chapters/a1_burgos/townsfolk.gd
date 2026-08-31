extends StaticBody3D
## Greybox child / innkeeper / burgales. Interact is talk, not a fight.

@export var cue: String = ""
@export var role: String = "burgales"


func interact() -> void:
	var host := _chapter()
	if host == null:
		return
	match role:
		"child":
			if host.has_method("start_child_v20"):
				host.start_child_v20()
		"innkeeper":
			if host.has_method("start_inn_refusal"):
				host.start_inn_refusal()
		"camp":
			if host.has_method("camp_on_river"):
				host.camp_on_river()
		_:
			if not cue.is_empty() and host.has_method("start_cue"):
				host.start_cue(cue)


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("speak_v20") and node.has_method("draw_steel_on_burgaleses"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
