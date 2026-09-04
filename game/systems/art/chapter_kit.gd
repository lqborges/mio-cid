class_name ChapterKit
extends RefCounted
## Paints CSG + environment from data/art/kits.json. No extra lights.

const KITS_PATH := "res://data/art/kits.json"


static func from_file() -> Dictionary:
	if not FileAccess.file_exists(KITS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KITS_PATH))
	return parsed if parsed is Dictionary else {}


static func kit_id_for(chapter_id: StringName) -> String:
	var table := from_file()
	var chapters: Variant = table.get("chapters", {})
	if chapters is Dictionary and chapters.has(String(chapter_id)):
		return str(chapters[String(chapter_id)])
	return str(table.get("default", "castile"))


static func kit_for(chapter_id: StringName) -> Dictionary:
	var table := from_file()
	var kits: Variant = table.get("kits", {})
	var kid := kit_id_for(chapter_id)
	if kits is Dictionary and kits.has(kid):
		var row: Variant = kits[kid]
		return row if row is Dictionary else {}
	return {}


static func apply_to(root: Node, chapter_id: StringName = &"") -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.has_meta("chapter_kit_applied"):
		return
	var cid := chapter_id
	if cid == &"":
		cid = _guess_chapter(root)
	var kit := kit_for(cid)
	if kit.is_empty():
		return
	root.set_meta("chapter_kit_applied", String(kit.get("id", cid)))
	_paint_environment(root, kit)
	_paint_csg(root, kit)


static func _guess_chapter(root: Node) -> StringName:
	var script: Script = root.get_script()
	if script != null:
		var path := String(script.resource_path)
		var marker := "/content/chapters/"
		var at := path.find(marker)
		if at >= 0:
			var rest := path.substr(at + marker.length())
			var slash := rest.find("/")
			if slash > 0:
				return StringName(rest.substr(0, slash))
	var runner := _runner()
	if runner != null and "current_id" in runner:
		var current := StringName(str(runner.get("current_id")))
		if current != &"":
			return current
	return &"a1_vivar"


static func _paint_environment(root: Node, kit: Dictionary) -> void:
	var env_node := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		var env := env_node.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = _color(kit.get("sky", []))
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = _color(kit.get("ambient", []))
		env.ambient_light_energy = float(kit.get("ambient_energy", 0.4))
		env.sdfgi_enabled = false
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
		env.volumetric_fog_enabled = false
	for light in root.find_children("*", "DirectionalLight3D", true, false):
		if light is DirectionalLight3D:
			(light as DirectionalLight3D).light_color = _color(kit.get("sun", []))
			(light as DirectionalLight3D).light_energy = float(kit.get("sun_energy", 1.0))


static func _paint_csg(root: Node, kit: Dictionary) -> void:
	for node in root.find_children("*", "CSGPrimitive3D", true, false):
		if not (node is CSGPrimitive3D):
			continue
		var shape := node as CSGPrimitive3D
		var slot := _slot_for(String(shape.name))
		if slot.is_empty():
			continue
		shape.material = _material(_color(kit.get(slot, kit.get("stone", []))))


static func _slot_for(node_name: String) -> String:
	var n := node_name.to_lower()
	if n.contains("floor") or n.contains("earth") or n.contains("ground") or n.contains("path") or n.contains("silt"):
		return "earth"
	if n.contains("roof") or n.contains("tile"):
		return "accent"
	if n.contains("door") or n.contains("sill") or n.contains("gate") or n.contains("beam") or n.contains("timber"):
		return "wood"
	if n.contains("house") or n.contains("inner") or n.contains("outer") or n.contains("plaster"):
		return "plaster"
	if n.contains("wall") or n.contains("keep") or n.contains("tower") or n.contains("combiner") or n.contains("stone"):
		return "stone"
	if n.begins_with("csg"):
		return "stone"
	return ""


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.metallic = 0.0
	return mat


static func _color(raw: Variant) -> Color:
	if raw is Array and (raw as Array).size() >= 3:
		var a: Array = raw
		var alpha := 1.0
		if a.size() >= 4:
			alpha = float(a[3])
		return Color(float(a[0]), float(a[1]), float(a[2]), alpha)
	return Color(0.5, 0.46, 0.38)


static func _runner() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("ChapterRunner")
	return null
