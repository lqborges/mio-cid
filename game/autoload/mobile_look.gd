extends Node
## Phone-only look lift. Desktop Envy stays 720p Compatibility with scene files unchanged.

const MIN_AMBIENT := 0.62
const MIN_SUN := 1.25


func _ready() -> void:
	if not OS.has_feature("mobile"):
		return
	var tree := get_tree()
	if tree:
		tree.node_added.connect(_on_node_added)
	_walk(get_tree().root if get_tree() else self)


func _on_node_added(node: Node) -> void:
	_apply(node)


func _walk(node: Node) -> void:
	_apply(node)
	for child in node.get_children():
		_walk(child)


func _apply(node: Node) -> void:
	if node is WorldEnvironment:
		_lift_environment((node as WorldEnvironment).environment)
	elif node is DirectionalLight3D:
		_lift_sun(node as DirectionalLight3D)
	elif node is MeshInstance3D:
		_smooth_capsule(node as MeshInstance3D)


func _lift_environment(env: Environment) -> void:
	if env == null:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if env.tonemap_exposure < 1.05:
		env.tonemap_exposure = 1.05
	if env.ambient_light_energy < MIN_AMBIENT:
		env.ambient_light_energy = MIN_AMBIENT
	if env.ambient_light_color.v < 0.55:
		env.ambient_light_color = env.ambient_light_color.lightened(0.12)
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false


func _lift_sun(sun: DirectionalLight3D) -> void:
	if sun.light_energy < MIN_SUN:
		sun.light_energy = MIN_SUN
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.06


func _smooth_capsule(mesh_inst: MeshInstance3D) -> void:
	var mesh := mesh_inst.mesh
	if mesh is CapsuleMesh:
		var cap := mesh as CapsuleMesh
		if cap.radial_segments < 16:
			cap.radial_segments = 16
		if cap.rings < 8:
			cap.rings = 8
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
