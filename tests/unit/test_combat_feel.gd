extends SceneTree
## Run: godot --headless --path . -s res://tests/unit/test_combat_feel.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_feel_and_roles())
	failures.append_array(_check_flash_uses_visible_look())
	failures.append_array(_check_mount_progress())
	_finish(failures)


func _check_feel_and_roles() -> PackedStringArray:
	var failures: PackedStringArray = []
	var table := CombatFeel.tunables()
	if not table.has("windup_frac") or not table.has("hit_flash_sec"):
		failures.append("combat tunables missing feel keys")
	if FileAccess.file_exists("res://data/combat/roles.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/roles.json"))
		if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("garrison"):
			failures.append("roles.json missing garrison")
	else:
		failures.append("roles.json missing")
	var hurt := HurtBox.new()
	hurt.hp = 10.0
	hurt.max_hp = 10.0
	if not hurt.apply_hit(2.0, &"slash", 0.0, null):
		failures.append("feel must not block a legal hit")
	if not is_equal_approx(hurt.hp, 8.0):
		failures.append("hit after feel want 8 got %s" % hurt.hp)
	hurt.free()
	return failures


func _check_flash_uses_visible_look() -> PackedStringArray:
	var failures: PackedStringArray = []
	var host := Node3D.new()
	host.name = "DummyHost"
	var visual := Node3D.new()
	visual.name = "Visual"
	host.add_child(visual)
	var cap := MeshInstance3D.new()
	cap.name = "MeshInstance3D"
	cap.visible = false
	cap.mesh = CapsuleMesh.new()
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.2, 0.2, 0.2)
	cap.material_override = cap_mat
	visual.add_child(cap)
	var human := Node3D.new()
	human.name = "Humanoid"
	visual.add_child(human)
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	torso.visible = true
	torso.mesh = BoxMesh.new()
	var torso_mat := StandardMaterial3D.new()
	torso_mat.albedo_color = Color(0.1, 0.2, 0.4)
	torso.material_override = torso_mat
	human.add_child(torso)
	var hurt := HurtBox.new()
	host.add_child(hurt)
	get_root().add_child(host)
	CombatFeel.note_hit(hurt, 2.0, host)
	if cap.get_surface_override_material(0) != null:
		failures.append("hit flash must not paint the hidden capsule")
	var flashed := torso.get_surface_override_material(0) as StandardMaterial3D
	if flashed == null:
		failures.append("hit flash must paint the visible Humanoid mesh")
	elif flashed.albedo_color.is_equal_approx(torso_mat.albedo_color):
		failures.append("visible torso material should change during flash")
	host.free()
	return failures


func _check_mount_progress() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse := HorseCompanion.new()
	if not horse.has_method("mount_progress"):
		failures.append("HorseCompanion.mount_progress missing")
	elif not is_equal_approx(float(horse.mount_progress()), 0.0):
		failures.append("idle mount_progress must be 0")
	horse.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_combat_feel: ok")
		quit(0)
	else:
		for line in failures:
			push_error(line)
		quit(1)
