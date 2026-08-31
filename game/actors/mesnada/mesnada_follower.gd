class_name MesnadaFollower
extends CharacterBody3D

## Greybox captain (named) or cheap lanza body (unnamed). Follows MesnadaAI
## slots. Uses NavigationAgent3D when a map exists; otherwise XZ steer.

@export var kind: StringName = &"captain"
@export var member_id: StringName = &""

var member: MesnadaMember
var slot_index: int = 0
var gone: bool = false
var ai
var lod: StringName = &"skinned"

var _agent: NavigationAgent3D
var _mesh_skinned: MeshInstance3D
var _mesh_capsule: MeshInstance3D
var _facing_marker: MeshInstance3D


func _ready() -> void:
	if kind == &"captain":
		add_to_group("mesnada_captain")
	else:
		add_to_group("mesnada_lanza")
	add_to_group("mesnada_follower")
	floor_snap_length = 0.25
	_mesh_skinned = get_node_or_null("Visual/MeshSkinned") as MeshInstance3D
	_mesh_capsule = get_node_or_null("Visual/MeshCapsule") as MeshInstance3D
	if _mesh_capsule == null:
		_mesh_capsule = get_node_or_null("Visual/MeshInstance3D") as MeshInstance3D
	_facing_marker = get_node_or_null("Visual/FacingMarker") as MeshInstance3D
	_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if _agent != null:
		_agent.avoidance_enabled = false
	_shadows_off()
	if kind != &"captain":
		set_lod(&"capsule")
	var parent := get_parent()
	if parent != null and parent.has_method("register_follower"):
		parent.register_follower(self)


func bind_ai(next: Node) -> void:
	ai = next
	if ai != null and _agent != null and "tunables" in ai:
		var tun: Dictionary = ai.tunables
		_agent.target_desired_distance = float(tun.get("arrive_distance", 0.0))
		_agent.path_desired_distance = float(tun.get("arrive_distance", 0.0))


func mark_gone() -> void:
	gone = true
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	set_physics_process(false)


func set_lod(level: StringName) -> void:
	lod = level
	var show_skinned := level == &"skinned" and kind == &"captain"
	var show_capsule := level == &"capsule" or (level == &"skinned" and _mesh_skinned == null)
	var show_any := level != &"hidden" and not gone
	if _mesh_skinned != null:
		_mesh_skinned.visible = show_any and show_skinned
		_mesh_skinned.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mesh_capsule != null:
		_mesh_capsule.visible = show_any and show_capsule and not show_skinned
		_mesh_capsule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _facing_marker != null:
		_facing_marker.visible = show_any and kind == &"captain" and level != &"hidden"
		_facing_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func desired_xz(from: Vector3, to: Vector3, speed: float, arrive: float, reverse: bool = false) -> Vector3:
	var delta := to - from
	delta.y = 0.0
	if reverse:
		delta = -delta
		if delta.length_squared() < 0.0001:
			return Vector3.ZERO
		return delta.normalized() * speed
	if delta.length() <= arrive:
		return Vector3.ZERO
	return delta.normalized() * speed


func _physics_process(delta: float) -> void:
	if gone:
		return
	_apply_gravity(delta)
	if ai == null:
		move_and_slide()
		return
	var wish := _wish_xz()
	velocity.x = wish.x
	velocity.z = wish.z
	if wish.length_squared() > 0.0001:
		_face(wish)
	move_and_slide()


func _wish_xz() -> Vector3:
	var arrive := float(ai.tunables.get("arrive_distance", 0.0))
	var speed: float = float(ai.speed_for(self))
	match ai.order:
		&"hold":
			return Vector3.ZERO
		&"flee":
			return _steer_to(ai.flee_slot(ai.slot_index_for(self)), speed, arrive)
		&"charge":
			return _steer_to(ai.world_slot(ai.slot_index_for(self)) + ai.formation_facing() * float(ai.tunables.get("follow_distance", 0.0)), speed, arrive)
		_:
			return _steer_to(ai.world_slot(ai.slot_index_for(self)), speed, arrive)


func _steer_to(slot: Vector3, speed: float, arrive: float) -> Vector3:
	if _nav_usable():
		_agent.target_position = slot
		if _agent.is_navigation_finished():
			return Vector3.ZERO
		var next := _agent.get_next_path_position()
		return desired_xz(global_position, next, speed, arrive, false)
	return desired_xz(global_position, slot, speed, arrive, false)


func _nav_usable() -> bool:
	if _agent == null or not is_inside_tree():
		return false
	var map := _agent.get_navigation_map()
	if map == RID():
		return false
	return NavigationServer3D.map_get_iteration_id(map) > 0


func _face(dir: Vector3) -> void:
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	var pt := global_position + flat
	if pt.distance_squared_to(global_position) < 0.0001:
		return
	visual.look_at(pt, Vector3.UP)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y <= 0.0:
			velocity.y = 0.0
		return
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	velocity.y -= g * delta


func _shadows_off() -> void:
	for mesh in [_mesh_skinned, _mesh_capsule, _facing_marker]:
		if mesh != null:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
