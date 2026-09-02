extends StaticBody3D
## Greybox Martín / Raquel / Vidas. Interact opens the sand-chest offer.

@export var character_id: StringName = &""


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_offer"):
		host.start_offer()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("choose_cheat") and node.has_method("choose_refuse"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
