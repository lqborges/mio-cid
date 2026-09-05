extends SceneTree
## Run: godot --headless --path . -s res://tests/unit/test_humanoid_look.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_cid())
	failures.append_array(_check_named_hosts())
	failures.append_array(_check_nameplate_fit())
	failures.append_array(await _check_deferred_free_is_safe())
	_finish(failures)


func _check_cid() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("cid.tscn failed to load")
		return failures
	var cid: Node = (packed as PackedScene).instantiate()
	get_root().add_child(cid)
	_ensure_portraits(cid)
	var visual: Node = cid.get_node_or_null("Visual")
	var human: Node = visual.get_node_or_null("Humanoid") if visual else null
	if human == null:
		failures.append("Cid Visual missing Humanoid portrait")
	else:
		for part in ["Head", "Beard", "Cloak", "PauldronL", "Torso"]:
			if human.get_node_or_null(part) == null:
				failures.append("Cid portrait missing %s" % part)
		if str(human.get("who_id")) != "cid":
			failures.append("Cid who_id should be cid, got %s" % human.get("who_id"))
	var capsule: MeshInstance3D = visual.get_node_or_null("MeshInstance3D") as MeshInstance3D if visual else null
	if capsule and capsule.visible:
		failures.append("Cid capsule should be hidden")
	cid.free()
	return failures


func _check_named_hosts() -> PackedStringArray:
	var failures: PackedStringArray = []
	failures.append_array(_expect_host("Alfonso", ["Crown", "Beard", "Robe"]))
	failures.append_array(_expect_host("Jimena", ["Veil", "Robe"]))
	failures.append_array(_expect_host("Yusuf", ["Turban", "Beard", "Robe"]))
	failures.append_array(_expect_host("Jeronimo", ["Mitre", "Robe"]))
	failures.append_array(_expect_short_child())
	failures.append_array(_expect_lanza_lod_keeps_portrait())
	return failures


func _expect_short_child() -> PackedStringArray:
	var failures: PackedStringArray = []
	var host := StaticBody3D.new()
	host.name = "Child"
	host.set("role", "child")
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var cap := CapsuleMesh.new()
	cap.height = 1.15
	cap.radius = 0.32
	mesh.mesh = cap
	host.add_child(mesh)
	get_root().add_child(host)
	_ensure_portraits(host)
	var human: Node = host.get_node_or_null("Humanoid")
	if human == null:
		failures.append("Burgos child (1.15 m) must get a Humanoid portrait")
	elif str(human.get("who_id")) != "burgos_child":
		failures.append("Child who_id want burgos_child got %s" % human.get("who_id"))
	if mesh.visible:
		failures.append("Burgos child capsule should be hidden")
	host.free()
	return failures


func _expect_lanza_lod_keeps_portrait() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/lanza/lanza.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("lanza.tscn failed to load")
		return failures
	var lanza: Node = (packed as PackedScene).instantiate()
	get_root().add_child(lanza)
	_ensure_portraits(lanza)
	if lanza.has_method("set_lod"):
		lanza.call("set_lod", &"capsule")
	var visual: Node = lanza.get_node_or_null("Visual")
	var human: Node = visual.get_node_or_null("Humanoid") if visual else null
	if human == null:
		failures.append("Lanza Visual missing Humanoid portrait")
	var capsule: MeshInstance3D = visual.get_node_or_null("MeshInstance3D") as MeshInstance3D if visual else null
	if capsule and capsule.visible:
		failures.append("Lanza LOD must not re-show the capsule under a portrait")
	lanza.free()
	return failures


func _expect_host(node_name: String, parts: PackedStringArray) -> PackedStringArray:
	var failures: PackedStringArray = []
	var host := StaticBody3D.new()
	host.name = node_name
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var cap := CapsuleMesh.new()
	cap.height = 1.7
	cap.radius = 0.38
	mesh.mesh = cap
	host.add_child(mesh)
	get_root().add_child(host)
	_ensure_portraits(host)
	var human: Node = host.get_node_or_null("Humanoid")
	if human == null:
		failures.append("%s missing Humanoid" % node_name)
	else:
		for part in parts:
			if human.get_node_or_null(part) == null:
				failures.append("%s portrait missing %s" % [node_name, part])
	host.free()
	return failures


func _check_nameplate_fit() -> PackedStringArray:
	var failures: PackedStringArray = []
	var label := Label3D.new()
	label.name = "Name"
	label.pixel_size = 0.012
	label.font_size = 42
	label.fixed_size = false
	get_root().add_child(label)
	var looks: Node = get_root().get_node_or_null("HumanoidLooks")
	if looks and looks.has_method("ensure"):
		looks.call("ensure", label)
	elif looks and looks.has_method("fit_nameplate"):
		looks.call("fit_nameplate", label)
	if label.fixed_size:
		failures.append("nameplate fit must not set fixed_size")
	if label.font_size > 32:
		failures.append("nameplate font_size stayed huge: %s" % label.font_size)
	if float(label.font_size) * float(label.pixel_size) > 0.18:
		failures.append("nameplate world height stayed huge")
	label.free()
	return failures


func _check_deferred_free_is_safe() -> PackedStringArray:
	# Main@ff8b097 deferred the Node itself. Freeing a1_vivar printed
	# ~118× "Cannot convert argument 1 from Object to Object".
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/chapters/a1_vivar/world.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("a1_vivar missing for deferred-free check")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	world.free()
	await process_frame
	await process_frame
	var looks: Node = get_root().get_node_or_null("HumanoidLooks")
	if looks == null:
		failures.append("HumanoidLooks autoload missing")
		return failures
	if not looks.has_method("_consider_deferred"):
		failures.append("HumanoidLooks must defer instance ids, not Nodes")
	var dummy := Node3D.new()
	dummy.name = "LooksProbe"
	get_root().add_child(dummy)
	var probe_id := dummy.get_instance_id()
	dummy.free()
	if looks.has_method("_consider_deferred"):
		looks.call("_consider_deferred", probe_id)
		looks.call("_consider_deferred", 0)
	var source := FileAccess.get_file_as_string("res://game/autoload/humanoid_looks.gd")
	if source.find("obj as Node") < 0:
		failures.append("HumanoidLooks must cast instance_from_id with as Node")
	if source.find("var node: Node = obj") >= 0:
		failures.append("HumanoidLooks must not assign Object to a Node typed var")
	return failures


func _ensure_portraits(node: Node) -> void:
	var looks: Node = get_root().get_node_or_null("HumanoidLooks")
	if looks and looks.has_method("ensure"):
		looks.call("ensure", node)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_humanoid_look: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_humanoid_look: %s" % failure)
	quit(1)
