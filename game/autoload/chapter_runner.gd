extends Node
# Autoload singleton. Do not add class_name — Godot 4 hides the Node behind the named class.
# PR-06 owns the graph; this PR only needs current beat + flags.

const VIVAR_SCENE := "res://content/chapters/a1_vivar/world.tscn"

var current_id: StringName = &""
var flags: PackedStringArray = PackedStringArray()


func set_flag(flag_id: StringName) -> void:
	var key := String(flag_id)
	if key.is_empty() or key in flags:
		return
	flags.append(key)


func has_flag(flag_id: StringName) -> bool:
	return String(flag_id) in flags


func goto(beat_id: StringName) -> void:
	current_id = beat_id
	var path := _scene_path(beat_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(path)


func _scene_path(beat_id: StringName) -> String:
	if beat_id == &"a1_vivar":
		return VIVAR_SCENE
	return ""
