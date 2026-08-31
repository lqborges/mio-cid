extends Node
# Autoload singleton. Do not add class_name — Godot 4 hides the Node behind the named class.
# Preload resources: class_name types are not in scope when autoloads parse.

const GRAPH_SCRIPT := preload("res://game/chapters/chapter_graph.gd")
const DIRECTOR_SCRIPT := preload("res://game/chapters/beat_director.gd")

const VIVAR_SCENE := "res://content/chapters/a1_vivar/world.tscn"
const BURGOS_SCENE := "res://content/chapters/a1_burgos/world.tscn"
const ARCAS_SCENE := "res://content/chapters/a1_arcas/world.tscn"
const CARDENA_SCENE := "res://content/chapters/a1_cardena/world.tscn"
const NAVAPALOS_SCENE := "res://content/chapters/a1_navapalos/world.tscn"
const CASTJON_SCENE := "res://content/chapters/a1_castejon/world.tscn"
const ALCOCER_SCENE := "res://content/chapters/a1_alcocer/world.tscn"
const EMBASSY1_SCENE := "res://content/chapters/a1_embassy1/world.tscn"
const POYO_SCENE := "res://content/chapters/a1_poyo/world.tscn"
const TEVAR_SCENE := "res://content/chapters/a1_tevar/world.tscn"

var graph: Resource
var current_id: StringName = &"a1_vivar"
var flags: PackedStringArray = PackedStringArray()
var director: Node


func _ready() -> void:
	_ensure_loaded()
	_start_director()


func _ensure_loaded() -> void:
	if graph == null:
		graph = GRAPH_SCRIPT.from_file()
	if director == null:
		director = DIRECTOR_SCRIPT.new()
		director.name = "BeatDirector"
		if director.get_parent() == null:
			add_child(director)


func reset() -> void:
	restore(&"a1_vivar", PackedStringArray())


func restore(chapter_id: StringName, new_flags: PackedStringArray) -> void:
	_ensure_loaded()
	var text := String(chapter_id)
	current_id = chapter_id if not text.is_empty() else &"a1_vivar"
	flags = new_flags.duplicate()
	_start_director()


func can_travel(from_id: StringName, to_id: StringName, travel_flags: PackedStringArray) -> bool:
	_ensure_loaded()
	if graph == null or not graph.has_method("can_travel"):
		return false
	return bool(graph.can_travel(from_id, to_id, travel_flags))


func can_skip_travel(from_id: StringName, to_id: StringName, travel_flags: PackedStringArray) -> bool:
	if not can_travel(from_id, to_id, travel_flags):
		return false
	return _visited(to_id, travel_flags)


func skip_travel(to_id: StringName) -> bool:
	if not can_skip_travel(current_id, to_id, flags):
		return false
	return travel(to_id)


func has_flag(flag_id: StringName) -> bool:
	return String(flag_id) in flags


func add_flag(flag: String) -> void:
	if flag.is_empty() or flag in flags:
		return
	flags.append(flag)


func set_flag(flag_id: StringName) -> void:
	add_flag(String(flag_id))


func complete_current() -> void:
	_ensure_loaded()
	if graph != null and graph.has_method("complete"):
		flags = graph.complete(current_id, flags)
	_emit_completed(current_id)


func travel(to_id: StringName) -> bool:
	_ensure_loaded()
	if graph == null or not graph.has_method("can_travel"):
		return false
	if not graph.can_travel(current_id, to_id, flags):
		return false
	var edge: Resource = null
	if graph.has_method("find_open_edge"):
		edge = graph.find_open_edge(current_id, to_id, flags)
	var from_id := current_id
	if edge != null and "set_flags" in edge:
		for flag in edge.set_flags:
			add_flag(String(flag))
	_emit_completed(from_id)
	current_id = to_id
	_start_director()
	return true


func goto(beat_id: StringName) -> void:
	current_id = beat_id
	var path := _scene_path(beat_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).change_scene_to_file(path)


func _scene_path(beat_id: StringName) -> String:
	if beat_id == &"a1_vivar":
		return VIVAR_SCENE
	if beat_id == &"a1_burgos":
		return BURGOS_SCENE
	if beat_id == &"a1_arcas":
		return ARCAS_SCENE
	if beat_id == &"a1_cardena":
		return CARDENA_SCENE
	if beat_id == &"a1_navapalos":
		return NAVAPALOS_SCENE
	if beat_id == &"a1_castejon":
		return CASTJON_SCENE
	if beat_id == &"a1_alcocer":
		return ALCOCER_SCENE
	if beat_id == &"a1_embassy1":
		return EMBASSY1_SCENE
	if beat_id == &"a1_poyo":
		return POYO_SCENE
	if beat_id == &"a1_tevar":
		return TEVAR_SCENE
	_ensure_loaded()
	if graph != null and graph.has_method("get_chapter"):
		var node: Resource = graph.get_chapter(beat_id)
		if node != null and "scene" in node:
			return String(node.scene)
	return ""


func _visited(to_id: StringName, travel_flags: PackedStringArray) -> bool:
	var dest := String(to_id)
	var cut := dest.find("_")
	var short := dest.substr(cut + 1) if cut >= 0 else dest
	if "%s_named" % short in travel_flags:
		return true
	if "%s_seen" % short in travel_flags:
		return true
	return false


func _start_director() -> void:
	_ensure_loaded()
	if director != null and director.has_method("start"):
		director.start(current_id)
	var bus := _bus()
	if bus:
		bus.beat_started.emit(current_id)


func _emit_completed(beat_id: StringName) -> void:
	var bus := _bus()
	if bus:
		bus.beat_completed.emit(beat_id)


func _bus() -> Node:
	var root := _scene_root()
	if root == null:
		return null
	return root.get_node_or_null(NodePath("EventBus"))


func _scene_root() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return get_parent()
