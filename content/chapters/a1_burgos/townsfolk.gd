extends StaticBody3D
## Greybox child / innkeeper / burgales. Interact is talk, not a fight.

@export var cue: String = ""
@export var role: String = "burgales"


func _ready() -> void:
	if _is_talk_role():
		add_to_group("interactable")


func interact_prompt_key() -> String:
	match role:
		"child":
			return "hud.hear_verb"
		"innkeeper":
			return "hud.lodge_verb"
		_:
			return "hud.interact_verb"


func interact() -> bool:
	var host := _chapter()
	if host == null:
		return false
	match role:
		"child":
			if host.has_method("start_child_v20"):
				host.start_child_v20()
				return true
		"innkeeper":
			if host.has_method("start_inn_refusal"):
				host.start_inn_refusal()
				return true
		"camp":
			# RiverCamp Area3D owns travel. A click/E here must not skip Burgos.
			return false
		_:
			if not cue.is_empty() and host.has_method("start_cue"):
				host.start_cue(cue)
				return true
	return false


func _is_talk_role() -> bool:
	return role == "child" or role == "innkeeper" or (not cue.is_empty() and role != "camp")


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("speak_v20") and node.has_method("draw_steel_on_burgaleses"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
