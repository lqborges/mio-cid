extends StaticBody3D
## Greybox Jimena / Elvira / Sol / Sisebuto. Interact is the farewell, not a fight.

@export var character_id: StringName = &""
@export var cue: String = "farewell"


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_farewell"):
		host.start_farewell()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_farewell") and node.has_method("give_monastery_gift"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
