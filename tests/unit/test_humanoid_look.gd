extends SceneTree
## Run: godot --headless --path . -s res://tests/unit/test_humanoid_look.gd


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_cid())
	failures.append_array(_check_named_hosts())
	failures.append_array(_check_nameplate_fit())
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
