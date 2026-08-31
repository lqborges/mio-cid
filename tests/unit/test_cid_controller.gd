extends SceneTree
## Headless isometric controller smoke test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_cid_controller.gd


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_cid_scene())
	failures.append_array(_check_arena_scene())
	_finish(failures)


func _check_cid_scene() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("cid.tscn failed to load")
		return failures
	var node: Node = (packed as PackedScene).instantiate()
	if not (node is CharacterBody3D):
		failures.append("Cid root is not CharacterBody3D")
		node.free()
		return failures
	var cid := node as CharacterBody3D
	if cid.get_script() == null:
		failures.append("Cid missing controller script")
	if cid.get_node_or_null("CameraRig/Camera3D") == null:
		failures.append("Cid missing locked Camera3D")
	if cid.get_node_or_null("CidCombat") == null:
		failures.append("Cid missing CidCombat stub")
	if cid.get_node_or_null("Visual") == null:
		failures.append("Cid missing Visual mesh root")
	if cid.has_method("roll"):
		failures.append("CidController still exposes roll (Souls identity)")
	if not cid.has_method("facing_dir") or not cid.has_method("is_dodging"):
		failures.append("CidController missing facing_dir / is_dodging")
	var combat: Node = cid.get_node_or_null("CidCombat")
	if combat:
		for method in ["slam", "leap", "shout", "weapon_swap"]:
			if not combat.has_method(method):
				failures.append("CidCombat missing %s" % method)
	cid.free()
	return failures


func _check_arena_scene() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/chapters/_dev/arena.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("arena.tscn failed to load")
		return failures
	var arena: Node = (packed as PackedScene).instantiate()
	var lights := arena.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("arena must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := arena.find_children("*", "OmniLight3D", true, false)
	extras.append_array(arena.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("arena has extra local lights")
	var cid: Node = arena.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("arena missing instanced Cid")
	var boxes := arena.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 4:
		failures.append("arena greybox missing floor/boxes")
	arena.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_cid_controller: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_cid_controller: %s" % failure)
	quit(1)
