extends SceneTree
## Run: godot --headless --path . -s res://tests/unit/test_chapter_kit.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_vivar_kit())
	failures.append_array(_check_castejon_lights())
	_finish(failures)


func _check_vivar_kit() -> PackedStringArray:
	var failures: PackedStringArray = []
	if ChapterKit.kit_id_for(&"a1_vivar") != "castile":
		failures.append("a1_vivar must use castile kit")
	var packed: Resource = load("res://content/chapters/a1_vivar/world.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("vivar world failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	ChapterKit.apply_to(world, &"a1_vivar")
	var kit_id := str(world.get_meta("chapter_kit_applied", ""))
	if kit_id != "castile":
		failures.append("Vivar kit meta want castile got %s" % kit_id)
	var floor: CSGShape3D = world.get_node_or_null("Floor") as CSGShape3D
	if floor == null or floor.material == null:
		failures.append("Vivar Floor missing kit material")
	var extras := world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("kit must not add local lights")
	var env: WorldEnvironment = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("Vivar sdfgi must stay off after kit")
	world.free()
	return failures


func _check_castejon_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/chapters/a1_castejon/world.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("castejon world failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	ChapterKit.apply_to(world, &"a1_castejon")
	var lights := world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("castejon must keep exactly 1 DirectionalLight3D, has %d" % lights.size())
	world.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_chapter_kit: ok")
		quit(0)
	else:
		for line in failures:
			push_error(line)
		quit(1)
