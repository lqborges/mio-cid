class_name CidController
extends CharacterBody3D

## High 3/4 isometric foot controller. Locked camera; WASD+mouse or click-to-move.

@export var walk_speed: float = 4.5
@export var run_speed: float = 7.0
@export var dodge_speed: float = 16.0
@export var dodge_duration: float = 0.14
@export var dodge_cooldown: float = 0.38
@export var slam_cooldown: float = 0.4
@export var leap_cooldown: float = 0.7
@export var shout_cooldown: float = 1.0
@export var click_arrive_distance: float = 0.4
@export var camera_height: float = 11.0
@export var camera_offset: float = 8.0
@export var camera_look_y: float = 1.0
@export var camera_fov: float = 34.0

const CidCombatScript := preload("res://game/actors/player/cid_combat.gd")
const HorseCompanionScript := preload("res://game/actors/player/horse_companion.gd")

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var combat: CidCombatScript = $CidCombat
@onready var interact_ray: RayCast3D = $Visual/InteractRay

var _facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var _click_target: Variant = null
var _dodge_dir: Vector3 = Vector3.ZERO
var _dodge_left: float = 0.0
var _dodge_cd: float = 0.0
var _slam_cd: float = 0.0
var _leap_cd: float = 0.0
var _shout_cd: float = 0.0
var _queued_dodge: bool = false
var _queued_slam: bool = false
var _queued_leap: bool = false
var _queued_shout: bool = false
var _queued_swap: bool = false
var _queued_interact: bool = false
var _horse: HorseCompanionScript = null


func _ready() -> void:
	# Visible cursor: mouse is aim, not an orbit pivot (TPS is void).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	floor_snap_length = 0.25
	add_to_group("player")
	_lock_isometric_camera()
	_horse = _find_horse()


func facing_dir() -> Vector3:
	return _facing


func is_dodging() -> bool:
	return _dodge_left > 0.0


func is_mounted() -> bool:
	return _horse != null and is_instance_valid(_horse) and _horse.is_mounted()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("dodge"):
		_queued_dodge = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("slam"):
		_queued_slam = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("leap"):
		_queued_leap = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("shout"):
		_queued_shout = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("weapon_swap"):
		_queued_swap = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_queued_interact = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("click_move"):
		_click_target = _ground_point_from_mouse()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# Yaw on the body would orbit the child camera — keep rotation on Visual only.
	rotation = Vector3.ZERO
	_tick_cooldowns(delta)
	if _horse == null or not is_instance_valid(_horse):
		_horse = _find_horse()
	if is_mounted():
		# Horse owns XZ; writing walk here would clobber couch/gallop.
		_consume_mounted_queues()
		velocity.x = 0.0
		velocity.z = 0.0
		_orient_visual()
		_lock_isometric_camera()
		return
	_apply_gravity(delta)
	var wish := _movement_wish()
	_update_facing(wish)
	if _dodge_left > 0.0:
		_dodge_left = maxf(_dodge_left - delta, 0.0)
		velocity.x = _dodge_dir.x * dodge_speed
		velocity.z = _dodge_dir.z * dodge_speed
		_queued_dodge = false
		_queued_slam = false
		_queued_leap = false
	elif combat != null and combat.has_method("is_staggered") and combat.is_staggered():
		velocity.x = 0.0
		velocity.z = 0.0
		_queued_dodge = false
		_queued_slam = false
		_queued_leap = false
		_queued_shout = false
		_queued_swap = false
	else:
		_consume_queues(wish)
		var speed := walk_speed
		if wish.length_squared() > 0.0001:
			if Input.is_action_pressed("run") and _can_sprint(delta):
				speed = run_speed
			velocity.x = wish.x * speed
			velocity.z = wish.z * speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	_orient_visual()
	move_and_slide()


func _consume_queues(wish: Vector3) -> void:
	if _queued_dodge and _dodge_cd <= 0.0:
		_start_dodge(wish)
	_queued_dodge = false
	if combat == null:
		_queued_slam = false
		_queued_leap = false
		_queued_shout = false
		_queued_swap = false
	else:
		if _queued_slam and _slam_cd <= 0.0:
			combat.slam()
			_slam_cd = slam_cooldown
		if _queued_leap and _leap_cd <= 0.0:
			combat.leap()
			_leap_cd = leap_cooldown
		if _queued_shout and _shout_cd <= 0.0:
			combat.shout()
			_shout_cd = shout_cooldown
		if _queued_swap:
			combat.weapon_swap()
		_queued_slam = false
		_queued_leap = false
		_queued_shout = false
		_queued_swap = false
	if _queued_interact:
		_try_interact()
	_queued_interact = false


func _can_sprint(delta: float) -> bool:
	if combat != null and combat.has_method("try_sprint"):
		return combat.try_sprint(delta)
	return true


func _start_dodge(wish: Vector3) -> void:
	if wish.length_squared() > 0.0001:
		_dodge_dir = wish.normalized()
	elif _facing.length_squared() > 0.0001:
		_dodge_dir = Vector3(_facing.x, 0.0, _facing.z).normalized()
	else:
		_dodge_dir = _camera_aligned(Vector2(0.0, -1.0))
	if _dodge_dir.length_squared() < 0.0001:
		_dodge_dir = Vector3(0.0, 0.0, -1.0)
	_dodge_left = dodge_duration
	_dodge_cd = dodge_cooldown
	_click_target = null
	_facing = _dodge_dir


func _movement_wish() -> Vector3:
	var stick := _stick()
	if stick.length() > 0.12:
		_click_target = null
		return _camera_aligned(stick)
	if Input.is_action_pressed("click_move"):
		_click_target = _ground_point_from_mouse()
	if _click_target != null:
		var to := (_click_target as Vector3) - global_position
		to.y = 0.0
		if to.length() <= click_arrive_distance:
			_click_target = null
			return Vector3.ZERO
		return to.normalized()
	return Vector3.ZERO


func _update_facing(wish: Vector3) -> void:
	var rs := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if rs.length() > 0.35:
		var aimed := _camera_aligned(rs)
		if aimed.length_squared() > 0.0:
			_facing = aimed
		return
	if _click_target != null and _stick().length() <= 0.12:
		if wish.length_squared() > 0.0:
			_facing = wish
		return
	var d := _ground_point_from_mouse() - global_position
	d.y = 0.0
	if d.length() > 0.08:
		_facing = d.normalized()


func _orient_visual() -> void:
	if visual == null:
		return
	var pt := global_position + Vector3(_facing.x, 0.0, _facing.z)
	if pt.distance_squared_to(global_position) < 0.0001:
		return
	visual.look_at(pt, Vector3.UP)


func _stick() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _camera_aligned(stick: Vector2) -> Vector3:
	var forward := Vector3(0.0, 0.0, -1.0)
	var right := Vector3.RIGHT
	if camera != null:
		var b := camera.global_transform.basis
		forward = -b.z
		right = b.x
		forward.y = 0.0
		right.y = 0.0
		if forward.length_squared() > 0.0001:
			forward = forward.normalized()
		if right.length_squared() > 0.0001:
			right = right.normalized()
	var wish := right * stick.x + forward * (-stick.y)
	if wish.length_squared() < 0.0001:
		return Vector3.ZERO
	return wish.normalized()


func _ground_point_from_mouse() -> Vector3:
	var fallback := global_position + _facing
	if camera == null:
		return fallback
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 400.0)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit.position
	var plane := Plane(Vector3.UP, global_position.y)
	var pt: Variant = plane.intersects_ray(origin, dir)
	if pt != null:
		return pt
	return fallback


func _lock_isometric_camera() -> void:
	if camera == null or camera_rig == null:
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = camera_fov
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	camera.position = Vector3(camera_offset, camera_height, camera_offset)
	var look := camera_rig.global_position + Vector3(0.0, camera_look_y, 0.0)
	if not camera.global_position.is_equal_approx(look):
		camera.look_at(look)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y <= 0.0:
			velocity.y = 0.0
		return
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	velocity.y -= g * delta


func _tick_cooldowns(delta: float) -> void:
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_slam_cd = maxf(_slam_cd - delta, 0.0)
	_leap_cd = maxf(_leap_cd - delta, 0.0)
	_shout_cd = maxf(_shout_cd - delta, 0.0)


func _try_interact() -> void:
	if interact_ray == null or not interact_ray.is_colliding():
		return
	# Chapter interactables (talk / gift / open) land here in later PRs.


func _consume_mounted_queues() -> void:
	if _queued_interact:
		if _horse != null and _horse.has_method("dismount"):
			_horse.dismount()
		_queued_interact = false
	if _queued_slam:
		if _horse != null and _horse.has_method("couch"):
			_horse.couch()
		_queued_slam = false
	_queued_dodge = false
	_queued_leap = false
	_queued_shout = false
	_queued_swap = false


func _find_horse() -> HorseCompanionScript:
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is HorseCompanion:
				return child as HorseCompanionScript
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("horse_companion")
	if nodes.is_empty():
		return null
	return nodes[0] as HorseCompanionScript
