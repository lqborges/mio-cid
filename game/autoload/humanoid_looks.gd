extends Node
## Builds Cantar portraits on person-sized capsules. Horse stays a horse.

const LookScript := preload("res://game/actors/look/humanoid_look.gd")
const KitScript := preload("res://game/systems/art/chapter_kit.gd")


func _ready() -> void:
	var tree := get_tree()
	if tree and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	_walk(tree.root if tree else self)


func ensure(node: Node) -> void:
	if node:
		_walk(node)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	# Never call_deferred a Node. Freeing a1_vivar left ~118 typed-arg convert errors.
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	_consider_deferred.call_deferred(node.get_instance_id())


func _consider_deferred(id: int) -> void:
	if id == 0 or not is_instance_id_valid(id):
		return
	var obj: Object = instance_from_id(id)
	if obj == null or not is_instance_valid(obj):
		return
	# Never assign Object → Node. Scene-change frees left convert errors.
	var node := obj as Node
	if node == null or node.is_queued_for_deletion() or not node.is_inside_tree():
		return
	_consider(node)


func _walk(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_consider(node)
	for child in node.get_children():
		_walk(child)


func _consider(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is WorldEnvironment:
		KitScript.apply_to(node.get_parent())
	if node is Label3D and String(node.name) == "Name":
		fit_nameplate(node as Label3D)
	if _should_attach(node):
		_attach(node)
	var visual := node.get_node_or_null("Visual")
	if visual and _should_attach(visual):
		_attach(visual)
	var nameplate := node.get_node_or_null("Name")
	if nameplate is Label3D:
		fit_nameplate(nameplate as Label3D)


## Billboard sized to a person: ~0.14 m letters (~16 px at the isometric camera).
static func fit_nameplate(label: Label3D) -> void:
	if label == null or not is_instance_valid(label):
		return
	if label.has_meta("nameplate_fit"):
		return
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.pixel_size = 0.005
	label.font_size = 28
	label.outline_size = maxi(label.outline_size, 6)
	label.no_depth_test = true
	label.render_priority = 2
	label.set_meta("nameplate_fit", true)


func _should_attach(host: Node) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	if host.get_node_or_null("Humanoid") != null:
		return false
	if host.get_node_or_null("Body") is CSGPrimitive3D:
		return false
	var probe: Node = host
	while probe:
		if probe.is_in_group("horse_companion") or String(probe.name) == "Horse":
			return false
		probe = probe.get_parent()
	for child in host.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh := (child as MeshInstance3D).mesh
		if mesh is CapsuleMesh:
			var cap := mesh as CapsuleMesh
			if cap.height >= 1.2 and cap.height <= 2.2 and cap.radius <= 0.55:
				return true
	return false


func _attach(host: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	if host.get_node_or_null("Humanoid") != null:
		return
	var look: Node = LookScript.new()
	look.name = "Humanoid"
	host.add_child(look)
	if look.has_method("build_for"):
		look.call("build_for", host)
