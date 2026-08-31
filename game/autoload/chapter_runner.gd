extends Node
# Autoload singleton. Do not add class_name — Godot 4 hides the Node behind the named class.
# Preload resources: class_name types are not in scope when autoloads parse.

const GRAPH_SCRIPT := preload("res://game/chapters/chapter_graph.gd")
const DIRECTOR_SCRIPT := preload("res://game/chapters/beat_director.gd")

var graph: Resource
var current_id: StringName = &"a1_vivar"
var flags: PackedStringArray = PackedStringArray()
var director: Node


func _ready() -> void:
	_ensure_loaded()


func _ensure_loaded() -> void:
	if graph == null:
		graph = GRAPH_SCRIPT.from_file()
	if director == null:
		director = DIRECTOR_SCRIPT.new()
		director.name = "BeatDirector"
		if director.get_parent() == null:
			add_child(director)


func reset() -> void:
	current_id = &"a1_vivar"
	flags = PackedStringArray()


func can_travel(from_id: StringName, to_id: StringName, travel_flags: PackedStringArray) -> bool:
	_ensure_loaded()
	if graph == null or not graph.has_method("can_travel"):
		return false
	return bool(graph.can_travel(from_id, to_id, travel_flags))


func add_flag(flag: String) -> void:
	if flag.is_empty() or flag in flags:
		return
	flags.append(flag)


func complete_current() -> void:
	_ensure_loaded()
	if graph == null or not graph.has_method("complete"):
		return
	flags = graph.complete(current_id, flags)
	var bus := _bus()
	if bus:
		bus.beat_completed.emit(current_id)


func travel(to_id: StringName) -> bool:
	_ensure_loaded()
	if graph == null or not graph.has_method("can_travel"):
		return false
	if not graph.can_travel(current_id, to_id, flags):
		return false
	var edge: Resource = null
	if graph.has_method("find_open_edge"):
		edge = graph.find_open_edge(current_id, to_id, flags)
	if edge != null and "set_flags" in edge:
		for flag in edge.set_flags:
			add_flag(String(flag))
	current_id = to_id
	var bus := _bus()
	if bus:
		bus.beat_started.emit(current_id)
	if director != null and director.has_method("start"):
		director.start(current_id)
	return true


func _bus() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath("EventBus"))
