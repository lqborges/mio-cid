class_name ChapterNode
extends Resource

@export var id: StringName
@export var scene: String
@export var act: int
@export var reorderable: bool = false
@export var v1_cut: bool = false


static func from_dict(data: Dictionary) -> ChapterNode:
	var node := ChapterNode.new()
	node.id = StringName(str(data.get("id", "")))
	node.scene = str(data.get("scene", ""))
	node.act = int(data.get("act", 0))
	node.reorderable = bool(data.get("reorderable", false))
	node.v1_cut = bool(data.get("v1_cut", false))
	return node
