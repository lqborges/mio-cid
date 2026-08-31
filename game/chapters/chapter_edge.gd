class_name ChapterEdge
extends Resource

@export var from_id: StringName
@export var to_id: StringName
@export var req_flags: PackedStringArray = []
@export var forbid_flags: PackedStringArray = []  # closed if ANY of these are set
@export var set_flags: PackedStringArray = []


static func from_dict(data: Dictionary) -> ChapterEdge:
	var edge := ChapterEdge.new()
	edge.from_id = StringName(str(data.get("from", data.get("from_id", ""))))
	edge.to_id = StringName(str(data.get("to", data.get("to_id", ""))))
	edge.req_flags = _to_packed(data.get("req_flags", []))
	edge.forbid_flags = _to_packed(data.get("forbid_flags", []))
	edge.set_flags = _to_packed(data.get("set_flags", []))
	return edge


func flags_ok(flags: PackedStringArray) -> bool:
	for flag in req_flags:
		if String(flag) not in flags:
			return false
	for flag in forbid_flags:
		if String(flag) in flags:
			return false
	return true


static func _to_packed(raw: Variant) -> PackedStringArray:
	var packed := PackedStringArray()
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for item in raw:
			if item == null:
				continue
			packed.append(str(item))
	return packed
