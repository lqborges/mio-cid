extends SceneTree
## Headless isometric controller smoke test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_cid_controller.gd

var _failures: PackedStringArray = []
var _leap_cid: CharacterBody3D = null
var _leap_queued: bool = false


func _initialize() -> void:
	_failures.append_array(_check_cid_scene())
	_failures.append_array(_check_arena_scene())
	call_deferred("_begin_leap_tick")


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


func _begin_leap_tick() -> void:
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		_failures.append("leap tick: cid.tscn failed to load")
		_finish(_failures)
		return
	_leap_cid = (packed as PackedScene).instantiate() as CharacterBody3D
	if _leap_cid == null:
		_failures.append("leap tick: Cid root is not CharacterBody3D")
		_finish(_failures)
		return
	get_root().add_child(_leap_cid)
	physics_frame.connect(_on_leap_physics_frame)


func _on_leap_physics_frame() -> void:
	if _leap_cid == null or not _leap_cid.is_inside_tree():
		return
	if not _leap_queued:
		# Zero stick: do not press move. Leap XZ must follow facing for this tick.
		_leap_cid.set("_queued_leap", true)
		_leap_queued = true
		return
	physics_frame.disconnect(_on_leap_physics_frame)
	_failures.append_array(_assert_leap_xz(_leap_cid))
	_leap_cid.free()
	_leap_cid = null
	_finish(_failures)


func _assert_leap_xz(cid: CharacterBody3D) -> PackedStringArray:
	var failures: PackedStringArray = []
	var facing: Vector3 = cid.call("facing_dir")
	facing.y = 0.0
	var combat: Node = cid.get_node_or_null("CidCombat")
	var leap_speed: float = 8.0
	if combat != null:
		leap_speed = float(combat.get("leap_speed"))
	if facing.length_squared() < 0.0001:
		failures.append("leap tick: facing xz is zero")
	else:
		facing = facing.normalized()
		var expected := Vector3(facing.x, 0.0, facing.z) * leap_speed
		var got := Vector3(cid.velocity.x, 0.0, cid.velocity.z)
		if got.distance_to(expected) > 0.05:
			failures.append("leap tick: velocity.xz %s != facing * leap_speed %s" % [got, expected])
	if cid.velocity.y <= 0.1:
		failures.append("leap tick: expected hop Y, got %s" % cid.velocity.y)
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_cid_controller: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_cid_controller: %s" % failure)
	quit(1)
