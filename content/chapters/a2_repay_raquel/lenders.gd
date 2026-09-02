extends StaticBody3D
## Greybox Raquel / Vidas. Interact is repayment; pay is the only option.

@export var character_id: StringName = &""
@export var cue: String = "pay"


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	var host := _chapter()
	if host and host.has_method("start_pay"):
		host.start_pay()


func _chapter() -> Node:
	var node: Node = self
	while node:
		if node.has_method("start_pay") and node.has_method("pay"):
			return node
		node = node.get_parent()
	return get_tree().current_scene if get_tree() else null
