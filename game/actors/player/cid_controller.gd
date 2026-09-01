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
const TouchHudScript := preload("res://game/ui/touch_hud.gd")
const TOUCH_HUD_SCENE := "res://content/ui/touch_hud.tscn"

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var combat: CidCombatScript = $CidCombat
@onready var mesura: Node = get_node_or_null("Mesura")
@onready var interact_ray: RayCast3D = $Visual/InteractRay

var _facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var _click_target: Variant = null
var _queued_click_pos: Variant = null
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
var _queued_dump: bool = false
var _leap_airborne: bool = false
var _horse: HorseCompanionScript = null
## Chapter sleep (lion hall). Walk_speed 0 is not enough: dodge uses dodge_speed.
var chapter_asleep: bool = false
## Pose-free halt. Do not reuse chapter_asleep — that lays Visual down.
var chapter_locked: bool = false
const LAYER_PLAYER := 2
const LAYER_SPECTATOR := 64
var spectator_mode: bool = false


func _ready() -> void:
	# Visible cursor: mouse is aim, not an orbit pivot (TPS is void).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	floor_snap_length = 0.25
	add_to_group("player")
	_lock_isometric_camera()
	_horse = _find_horse()
	_ensure_touch_hud()
	var looks := get_tree().root.get_node_or_null("HumanoidLooks") if is_inside_tree() else null
	if looks and looks.has_method("ensure"):
		looks.call("ensure", self)


func facing_dir() -> Vector3:
	return _facing


func set_facing(dir: Vector3) -> void:
	var xz := Vector3(dir.x, 0.0, dir.z)
	if xz.length_squared() < 0.0001:
		return
	_facing = xz.normalized()


func is_dodging() -> bool:
	return _dodge_left > 0.0


func is_mounted() -> bool:
	return _horse != null and is_instance_valid(_horse) and _horse.is_mounted()


func set_chapter_asleep(on: bool) -> void:
	chapter_asleep = on
	if on:
		_clear_action_queues()
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_sleep_pose()
	else:
		_clear_sleep_pose()


func set_chapter_locked(on: bool) -> void:
	chapter_locked = on
	if on:
		_clear_action_queues()
		velocity.x = 0.0
		velocity.z = 0.0


func set_spectator_mode(on: bool) -> void:
	spectator_mode = on
	if on:
		collision_layer = LAYER_SPECTATOR
	else:
		collision_layer = LAYER_PLAYER
	var hurt: Node = get_node_or_null("HurtBox")
	if hurt == null:
		return
	if on:
		if "spectator" in hurt:
			hurt.set("spectator", true)
		if hurt.has_method("_apply_collision"):
			hurt.call("_apply_collision")
		hurt.monitorable = false
		hurt.monitoring = false
		# DESIGN: Cid has no HurtBox at the lists.
		remove_child(hurt)
		hurt.free()
	else:
		if "spectator" in hurt:
			hurt.set("spectator", false)
		if hurt.has_method("_apply_collision"):
			hurt.call("_apply_collision")


func possess_pawn(target: Node) -> bool:
	# Debug-only. Compiled-out of ship builds; always denylists Cid at lists.
	if not OS.is_debug_build():
		return false
	if target == null:
		return false
	if spectator_mode:
		return false
	if target == self or target.is_in_group("player"):
		if _chapter_is_carrion():
			return false
	return false


func _chapter_is_carrion() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var runner: Node = (loop as SceneTree).root.get_node_or_null(NodePath("ChapterRunner"))
	if runner == null or not ("current_id" in runner):
		return false
	return String(runner.current_id) == "a3_carrion"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if chapter_asleep:
		if event is InputEventMouseMotion or event is InputEventJoypadMotion:
			return
		_notify_chapter_sleep_input()
		_mark_handled()
		return
	if chapter_locked:
		if event is InputEventMouseMotion or event is InputEventJoypadMotion:
			return
		_mark_handled()
		return
	# World taps emulate LMB (slam). HUD actions / keys / joy still pass.
	if _pointer_event_blocked(event):
		if _is_world_walk_tap(event):
			_queued_click_pos = _event_screen_pos(event)
		_mark_handled()
		return
	if event.is_action_pressed("dodge"):
		_queued_dodge = true
		_mark_handled()
	elif event.is_action_pressed("slam"):
		_queued_slam = true
		_mark_handled()
	elif event.is_action_pressed("leap"):
		_queued_leap = true
		_mark_handled()
	elif event.is_action_pressed("shout"):
		_queued_shout = true
		_mark_handled()
	elif event.is_action_pressed("weapon_swap"):
		_queued_swap = true
		_mark_handled()
	elif event.is_action_pressed("interact"):
		_queued_interact = true
		_mark_handled()
	elif event.is_action_pressed("rage_dump"):
		_queued_dump = true
		_mark_handled()
	elif event.is_action_pressed("click_move"):
		if _touch_hud_blocks_pointer():
			_mark_handled()
			return
		_queued_click_pos = get_viewport().get_mouse_position()
		_mark_handled()


func _physics_process(delta: float) -> void:
	# Yaw on the body would orbit the child camera — keep rotation on Visual only.
	rotation = Vector3.ZERO
	_tick_cooldowns(delta)
	if chapter_asleep:
		# _orient_visual look_at stands the capsule; dodge/leap ignore walk_speed.
		_clear_action_queues()
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		_apply_sleep_pose()
		move_and_slide()
		_lock_isometric_camera()
		return
	if chapter_locked:
		_clear_action_queues()
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_lock_isometric_camera()
		return
	_update_mesura_hold()
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
	_resolve_queued_click()
	var wish := _movement_wish()
	_update_facing(wish)
	if _dodge_left > 0.0:
		_apply_dodge_xz(delta)
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
		_queued_dump = false
	else:
		_consume_queues(wish)
		# Dodge/leap/slam own XZ this step — walk/run would clobber them.
		if _dodge_left > 0.0:
			_apply_dodge_xz(delta)
		elif _leap_airborne:
			pass
		elif _slam_cd > 0.0:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var speed := walk_speed
			if wish.length_squared() > 0.0001:
				if not _is_waiting() and Input.is_action_pressed("run") and _can_sprint(delta):
					speed = run_speed
				if _is_waiting() and mesura != null and mesura.has_method("move_mult"):
					speed *= float(mesura.move_mult())
				velocity.x = wish.x * speed
				velocity.z = wish.z * speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
	_orient_visual()
	move_and_slide()
	if _leap_airborne and is_on_floor() and velocity.y <= 0.0:
		_leap_airborne = false


func _consume_queues(wish: Vector3) -> void:
	if _queued_dodge and _dodge_cd <= 0.0:
		_start_dodge(wish)
	_queued_dodge = false
	# Dodge owns the step it starts on; slam/leap must not mutate velocity too.
	if _dodge_left > 0.0:
		_queued_slam = false
		_queued_leap = false
	if _is_waiting():
		_queued_slam = false
		_queued_leap = false
		_queued_shout = false
		_queued_dump = false
	if combat == null:
		_queued_slam = false
		_queued_leap = false
		_queued_shout = false
		_queued_swap = false
		_queued_dump = false
	else:
		if _queued_slam and _slam_cd <= 0.0:
			combat.slam()
			_slam_cd = slam_cooldown
			_leap_airborne = false
		if _queued_leap and _leap_cd <= 0.0:
			combat.leap()
			_leap_cd = leap_cooldown
			_leap_airborne = true
		if _queued_shout and _shout_cd <= 0.0:
			combat.shout()
			_shout_cd = shout_cooldown
		if _queued_swap:
			combat.weapon_swap()
		if _queued_dump and mesura != null and mesura.has_method("try_dump"):
			mesura.try_dump()
		_queued_slam = false
		_queued_leap = false
		_queued_shout = false
		_queued_swap = false
		_queued_dump = false
	if _queued_interact:
		_try_interact()
	_queued_interact = false


func _is_waiting() -> bool:
	return mesura != null and mesura.has_method("is_holding") and bool(mesura.is_holding())


func _update_mesura_hold() -> void:
	if mesura == null or not mesura.has_method("set_holding"):
		return
	var want := Input.is_action_pressed("mesura")
	if combat != null and combat.has_method("is_dead") and combat.is_dead():
		want = false
	mesura.set_holding(want)


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
	_leap_airborne = false
	_facing = _dodge_dir


func _apply_dodge_xz(delta: float) -> void:
	_dodge_left = maxf(_dodge_left - delta, 0.0)
	velocity.x = _dodge_dir.x * dodge_speed
	velocity.z = _dodge_dir.z * dodge_speed


func _resolve_queued_click() -> void:
	if _queued_click_pos == null:
		return
	_click_target = _ground_point_from_mouse(_queued_click_pos)
	_queued_click_pos = null


func _movement_wish() -> Vector3:
	var stick := _stick()
	if stick.length() > 0.12:
		_click_target = null
		return _camera_aligned(stick)
	if Input.is_action_pressed("click_move") and not _touch_hud_blocks_pointer():
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
	if _touch_hud_blocks_pointer():
		if wish.length_squared() > 0.0:
			_facing = wish
		return
	var d := _ground_point_from_mouse() - global_position
	d.y = 0.0
	if d.length() > 0.08:
		_facing = d.normalized()


func _orient_visual() -> void:
	if visual == null or chapter_asleep:
		return
	var pt := global_position + Vector3(_facing.x, 0.0, _facing.z)
	if pt.distance_squared_to(global_position) < 0.0001:
		return
	visual.look_at(pt, Vector3.UP)


func _apply_sleep_pose() -> void:
	if visual == null:
		return
	visual.rotation_degrees = Vector3(90.0, 0.0, 0.0)


func _clear_sleep_pose() -> void:
	if visual == null:
		return
	visual.rotation_degrees = Vector3.ZERO


func _clear_action_queues() -> void:
	_queued_dodge = false
	_queued_slam = false
	_queued_leap = false
	_queued_shout = false
	_queued_swap = false
	_queued_dump = false
	_queued_interact = false
	_queued_click_pos = null
	_click_target = null
	_dodge_left = 0.0
	_leap_airborne = false


func _notify_chapter_sleep_input() -> void:
	var node: Node = get_parent()
	while node:
		if node.has_method("on_sleep_input"):
			node.call("on_sleep_input")
			return
		node = node.get_parent()


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


func _ground_point_from_mouse(screen_pos: Variant = null) -> Vector3:
	var fallback := global_position + _facing
	if camera == null:
		return fallback
	var mouse: Vector2 = screen_pos if screen_pos is Vector2 else get_viewport().get_mouse_position()
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
	var node := interact_ray.get_collider() as Node
	while node:
		if node.has_method("interact"):
			node.call("interact")
			return
		if node.has_method("action"):
			node.call("action")
			return
		node = node.get_parent()


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
	_queued_dump = false


func _mark_handled() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _touch_hud_blocks_pointer() -> bool:
	return bool(TouchHudScript.pointer_blocked)


func _pointer_event_blocked(event: InputEvent) -> bool:
	if not _touch_hud_blocks_pointer():
		return false
	if event is InputEventAction:
		return false
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return false
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return true
	return event.device == InputEvent.DEVICE_ID_EMULATION


func _is_world_walk_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	return false


func _event_screen_pos(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	var vp := get_viewport()
	if vp:
		return vp.get_mouse_position()
	return Vector2.ZERO


func _ensure_touch_hud() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if tree.root.find_child("TouchHud", true, false) != null:
		return
	var packed := load(TOUCH_HUD_SCENE) as PackedScene
	if packed == null:
		return
	var hud := packed.instantiate()
	hud.name = "TouchHud"
	var host: Node = tree.current_scene
	if host == null or host == self:
		host = get_parent()
	if host == null or host == self:
		host = tree.root
	host.add_child.call_deferred(hud)


func _find_horse() -> HorseCompanionScript:
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child.get_script() == HorseCompanionScript:
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
