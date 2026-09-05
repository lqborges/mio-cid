class_name CombatFeel
extends RefCounted
## Hit flash and camera nudge. Numbers in data/combat/tunables.json.

const TUNABLES_PATH := "res://data/combat/tunables.json"


static func tunables() -> Dictionary:
	if not FileAccess.file_exists(TUNABLES_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TUNABLES_PATH))
	return parsed if parsed is Dictionary else {}


static func flash_allowed() -> bool:
	var guide := _guide()
	if guide != null and guide.has_method("flash_enabled"):
		return bool(guide.call("flash_enabled"))
	return true


static func shake_allowed() -> bool:
	var guide := _guide()
	if guide != null and guide.has_method("shake_enabled"):
		return bool(guide.call("shake_enabled"))
	return true


static func note_hit(hurt: Node, amount: float, source: Node) -> void:
	var table := tunables()
	if flash_allowed() and hurt is Node:
		_flash_host(hurt, table)
	if shake_allowed() and amount > 0.0:
		_nudge_camera(source, table)


static func _flash_host(hurt: Node, table: Dictionary) -> void:
	var host := hurt.get_parent()
	if host == null:
		host = hurt
	var mesh := host.get_node_or_null("Visual/MeshInstance3D") as MeshInstance3D
	if mesh == null and host is MeshInstance3D:
		mesh = host as MeshInstance3D
	if mesh == null:
		return
	var mat := mesh.get_active_material(0)
	if not (mat is StandardMaterial3D):
		return
	var local := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	var flash := _color(table.get("hit_flash", [0.95, 0.88, 0.70]))
	local.albedo_color = flash
	mesh.set_surface_override_material(0, local)
	var tree := host.get_tree() if host.is_inside_tree() else null
	if tree:
		tree.create_timer(float(table.get("hit_flash_sec", 0.08))).timeout.connect(
			func() -> void:
				if is_instance_valid(mesh):
					mesh.set_surface_override_material(0, null)
		)


static func _nudge_camera(source: Node, table: Dictionary) -> void:
	var body := source
	while body != null and not body.has_method("apply_camera_nudge"):
		body = body.get_parent()
	if body == null or not body.has_method("apply_camera_nudge"):
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			var cid := (loop as SceneTree).get_first_node_in_group("player")
			if cid != null and cid.has_method("apply_camera_nudge"):
				body = cid
	if body == null:
		return
	var deg := float(table.get("camera_nudge_deg", 0.35))
	var sec := float(table.get("camera_nudge_sec", 0.08))
	body.call("apply_camera_nudge", Vector3(0.0, 0.0, deg * 0.02), sec)


static func _color(raw: Variant) -> Color:
	if raw is Array and (raw as Array).size() >= 3:
		var a: Array = raw
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color(0.95, 0.88, 0.70)


static func _guide() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("PlayerGuide")
	return null
