class_name ChapterGraph
extends Resource

const GRAPH_PATH := "res://data/chapters/graph.json"
const NODE := preload("res://game/chapters/chapter_node.gd")
const EDGE := preload("res://game/chapters/chapter_edge.gd")

@export var nodes: Array = []
@export var edges: Array = []


static func from_file(path: String = GRAPH_PATH) -> Resource:
	if not FileAccess.file_exists(path):
		push_warning("ChapterGraph: missing %s" % path)
		return _new_graph()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("ChapterGraph: empty %s" % path)
		return _new_graph()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return from_dict(parsed)
	push_warning("ChapterGraph: %s is not an object" % path)
	return _new_graph()


static func from_dict(data: Dictionary) -> Resource:
	var graph: Resource = _new_graph()
	var raw_nodes: Variant = data.get("nodes", [])
	if raw_nodes is Array:
		for item in raw_nodes:
			if item is Dictionary:
				graph.nodes.append(NODE.from_dict(item))
	var raw_edges: Variant = data.get("edges", [])
	if raw_edges is Array:
		for item in raw_edges:
			if item is Dictionary:
				graph.edges.append(EDGE.from_dict(item))
	return graph


static func _new_graph() -> Resource:
	return (load("res://game/chapters/chapter_graph.gd") as GDScript).new()


func get_chapter(id: StringName) -> Resource:
	var wanted := String(id)
	for node in nodes:
		if node != null and String(node.id) == wanted:
			return node
	return null


func can_travel(from_id: StringName, to_id: StringName, flags: PackedStringArray) -> bool:
	var dest: Resource = get_chapter(to_id)
	if dest != null and int(dest.act) == 1 and not bool(dest.reorderable):
		var src: Resource = get_chapter(from_id)
		# Reorderable Act I side-beats (v1-cut raids) rejoin through an open edge.
		if src != null and int(src.act) == 1 and bool(src.reorderable):
			return _edge_open(from_id, to_id, flags)
		return _is_next_locked(from_id, to_id, flags)
	return _edge_open(from_id, to_id, flags)


func find_open_edge(from_id: StringName, to_id: StringName, flags: PackedStringArray) -> Resource:
	for edge in edges:
		if edge == null:
			continue
		if String(edge.from_id) != String(from_id) or String(edge.to_id) != String(to_id):
			continue
		if edge.flags_ok(flags):
			return edge
	return null


func complete(beat_id: StringName, flags: PackedStringArray) -> PackedStringArray:
	var out := flags.duplicate()
	for edge in _outgoing(beat_id):
		for flag in edge.set_flags:
			var text := String(flag)
			if text not in out:
				out.append(text)
	return out


func _is_next_locked(from_id: StringName, to_id: StringName, flags: PackedStringArray) -> bool:
	var locked := _locked_act1_ids()
	var from_i := locked.find(String(from_id))
	var to_i := locked.find(String(to_id))
	if from_i < 0 or to_i != from_i + 1:
		return false
	return _edge_open(from_id, to_id, flags)


func _locked_act1_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for node in nodes:
		if node != null and int(node.act) == 1 and not bool(node.reorderable):
			ids.append(String(node.id))
	return ids


func _edge_open(from_id: StringName, to_id: StringName, flags: PackedStringArray) -> bool:
	return find_open_edge(from_id, to_id, flags) != null


func _outgoing(beat_id: StringName) -> Array:
	var out: Array = []
	var wanted := String(beat_id)
	for edge in edges:
		if edge != null and String(edge.from_id) == wanted:
			out.append(edge)
	return out
