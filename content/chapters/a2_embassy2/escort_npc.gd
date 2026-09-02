extends StaticBody3D
## Greybox Jimena / Elvira / Sol on the Medinaceli road. Interact is talk, not a fight.

@export var character_id: StringName = &""
@export var cue: String = "escort"


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host == null:
		return
	if cue == "recruit" and host.has_method("start_recruit"):
		host.start_recruit()
		return
	if host.has_method("start_cue"):
		host.start_cue(cue)


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("recruit_avengalvon") and node.has_method("complete_escort"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
