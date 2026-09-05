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
@export var interact_range: float = 5.0
@export var camera_height: float = 11.0
@export var camera_offset: float = 8.0
@export var camera_look_y: float = 1.0
@export var camera_fov: float = 34.0

const CidCombatScript := preload("res://game/actors/player/cid_combat.gd")
const HorseCompanionScript := preload("res://game/actors/player/horse_companion.gd")
const TouchHudScript := preload("res://game/ui/touch_hud.gd")
const Glyphs := preload("res://game/systems/input/input_glyphs.gd")
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
var _slam_buffer: float = 0.0
var _queued_dodge: bool = false
var _queued_slam: bool = false
var _queued_leap: bool = false
var _queued_shout: bool = false
var _queued_swap: bool = false
var _queued_interact: bool = false
var _queued_dump: bool = false
var _leap_airborne: bool = false
var _block_click_move: bool = false
var _click_move_from_hud: bool = false
var _prompt_layer: CanvasLayer = null
var _prompt_host: Control = null
var _prompt_label: Label = null
var _prompt_chip: ColorRect = null
var _prompt_world: Label3D = null
var _target_ring: MeshInstance3D = null
var _occluders: Array[GeometryInstance3D] = []
var _nudge: Vector3 = Vector3.ZERO
var _nudge_left: float = 0.0
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
	_ensure_target_ring()
	_ensure_interact_prompt()
	var looks := get_tree().root.get_node_or_null("HumanoidLooks") if is_inside_tree() else null
	if looks and looks.has_method("ensure"):
		looks.call("ensure", self)
	tree_exiting.connect(_on_tree_exiting)


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


func _input(event: InputEvent) -> void:
	if chapter_asleep or chapter_locked:
		return
	if not _is_click_move_press(event):
		return
	var pos := _event_screen_pos(event)
	if not _world_click_blocked() and not _point_over_hud(pos):
		return
	_click_move_from_hud = true
	_click_target = null
	_queued_click_pos = null
	# Leave the event for GUI buttons (ChoiceUI / KeepOrSell). Walk is already blocked.


func _unhandled_input(event: InputEvent) -> void:
	Glyphs.note_event(event)
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
	if _modal_ui_open():
		# Balloon / chapter choice owns click / E / accept. Do not walk, talk-again, or dodge-on-Space.
		if _is_world_walk_tap(event) or event.is_action_pressed("click_move"):
			_click_target = null
			_queued_click_pos = null
		_queued_interact = false
		return
	# World taps walk / talk. Slam stays on the key / pad / touch button.
	if _pointer_event_blocked(event):
		var tap_pos := _event_screen_pos(event)
		if _is_world_walk_tap(event) and not _world_click_blocked() and not _point_over_hud(tap_pos):
			_queued_click_pos = tap_pos
		_mark_handled()
		return
	if _is_pointer_event(event) and (_world_click_blocked() or _point_over_hud(_event_screen_pos(event))):
		_mark_handled()
		return
	if _is_world_walk_tap(event) or event.is_action_pressed("click_move"):
		var pos := _event_screen_pos(event)
		if _world_click_blocked() or _click_move_from_hud or _point_over_hud(pos):
			_click_move_from_hud = true
			_click_target = null
			_queued_click_pos = null
			_mark_handled()
			return
		if _is_world_walk_tap(event):
			_queued_click_pos = _event_screen_pos(event)
		else:
			_queued_click_pos = get_viewport().get_mouse_position()
		_mark_handled()
		return
	if event.is_action_pressed("dodge"):
		_queued_dodge = true
		_mark_handled()
	elif event.is_action_pressed("slam"):
		_queued_slam = true
		_slam_buffer = _input_buffer_sec()
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


func _physics_process(delta: float) -> void:
	# Yaw on the body would orbit the child camera — keep rotation on Visual only.
	rotation = Vector3.ZERO
	_tick_cooldowns(delta)
	_tick_nudge(delta)
	if chapter_asleep:
		# _orient_visual look_at stands the capsule; dodge/leap ignore walk_speed.
		_clear_action_queues()
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		_apply_sleep_pose()
		move_and_slide()
		_lock_isometric_camera()
		_update_interact_prompt()
		return
	if chapter_locked:
		_clear_action_queues()
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_lock_isometric_camera()
		_update_interact_prompt()
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
	if wish.length_squared() > 0.0001:
		var guide := get_node_or_null("/root/PlayerGuide")
		if guide != null and guide.has_method("note_moved"):
			guide.call("note_moved")
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
	_lock_isometric_camera()
	_update_interact_prompt()


func _consume_queues(wish: Vector3) -> void:
	if _queued_dodge and _dodge_cd <= 0.0:
		_start_dodge(wish)
	_queued_dodge = false
	# Dodge owns the step it starts on; slam/leap must not mutate velocity too.
	if _dodge_left > 0.0:
		_queued_slam = false
		_queued_leap = false
	if _is_waiting():
		if _queued_slam or _queued_leap or _queued_shout:
			_note_blocked("combat.blocked.mesura")
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
			_queued_slam = false
		elif _queued_slam and _slam_buffer <= 0.0:
			_queued_slam = false
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
	var screen: Vector2 = _queued_click_pos
	_queued_click_pos = null
	if _world_click_blocked():
		return
	var pick := _pick_from_screen(screen)
	var collider := pick.get("collider") as Node
	if _try_interact_node(collider):
		_click_target = null
		_block_click_move = true
		return
	if pick.has("position"):
		_click_target = pick.position


func _movement_wish() -> Vector3:
	var stick := _stick()
	if stick.length() > 0.12:
		_click_target = null
		_block_click_move = false
		return _camera_aligned(stick)
	if not Input.is_action_pressed("click_move"):
		_block_click_move = false
		_click_move_from_hud = false
	if (
		Input.is_action_pressed("click_move")
		and not _block_click_move
		and not _click_move_from_hud
		and not _world_click_blocked()
	):
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
	if _touch_hud_blocks_pointer() or _gui_blocks_pointer() or _mouse_over_hud():
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
	_block_click_move = false
	_click_move_from_hud = false
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
	var mouse: Vector2 = screen_pos if screen_pos is Vector2 else get_viewport().get_mouse_position()
	var pick := _pick_from_screen(mouse)
	if pick.has("position"):
		return pick.position
	return global_position + _facing


func _pick_from_screen(screen_pos: Vector2) -> Dictionary:
	var fallback := {"position": global_position + _facing}
	if camera == null:
		return fallback
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 400.0)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit
	var plane := Plane(Vector3.UP, global_position.y)
	var pt: Variant = plane.intersects_ray(origin, dir)
	if pt != null:
		return {"position": pt}
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
	if _nudge_left > 0.0 and not _nudge.is_zero_approx():
		camera.position += _nudge
	_fade_occluders()


func apply_camera_nudge(offset: Vector3, seconds: float) -> void:
	var guide := get_node_or_null("/root/PlayerGuide")
	if guide != null and guide.has_method("shake_enabled") and not bool(guide.call("shake_enabled")):
		return
	_nudge = offset
	_nudge_left = maxf(seconds, 0.0)


func _tick_nudge(delta: float) -> void:
	if _nudge_left <= 0.0:
		_nudge = Vector3.ZERO
		return
	_nudge_left = maxf(_nudge_left - delta, 0.0)
	if _nudge_left <= 0.0:
		_nudge = Vector3.ZERO


func _fade_occluders() -> void:
	_restore_occluders()
	if camera == null or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := camera.global_position
	var to := global_position + Vector3(0.0, 1.2, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Variant = hit.get("collider")
	if not (collider is Node):
		return
	var geom := _geometry_of(collider as Node)
	if geom == null:
		return
	_occluders.append(geom)
	var mat := geom.material_override
	if mat == null:
		mat = StandardMaterial3D.new()
		if geom is CSGShape3D and (geom as CSGShape3D).material is StandardMaterial3D:
			mat = ((geom as CSGShape3D).material as StandardMaterial3D).duplicate()
		geom.material_override = mat
		geom.set_meta("kit_fade_owned", true)
	if mat is StandardMaterial3D:
		var faded := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color := faded.albedo_color
		color.a = 0.28
		faded.albedo_color = color
		geom.material_override = faded
		geom.set_meta("kit_fade_prev", mat)


func _restore_occluders() -> void:
	for geom in _occluders:
		if geom == null or not is_instance_valid(geom):
			continue
		if geom.has_meta("kit_fade_prev"):
			geom.material_override = geom.get_meta("kit_fade_prev")
			geom.remove_meta("kit_fade_prev")
		elif geom.has_meta("kit_fade_owned"):
			geom.material_override = null
			geom.remove_meta("kit_fade_owned")
	_occluders.clear()


func _geometry_of(node: Node) -> GeometryInstance3D:
	var probe: Node = node
	while probe:
		if probe is GeometryInstance3D and not (probe is MeshInstance3D and probe.get_parent() == visual):
			if probe.is_ancestor_of(self) or probe == self:
				return null
			return probe as GeometryInstance3D
		probe = probe.get_parent()
	return null


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
	_slam_buffer = maxf(_slam_buffer - delta, 0.0)


func _input_buffer_sec() -> float:
	if combat != null and "tunables" in combat:
		return float(combat.tunables.get("input_buffer_sec", 0.12))
	return 0.12


func _note_blocked(key: String) -> void:
	var guide := get_node_or_null("/root/PlayerGuide")
	if guide != null and guide.has_method("note_blocked"):
		guide.call("note_blocked", key)


func _try_interact() -> void:
	if _try_interact_node(_interact_ray_node()):
		return
	_try_interact_node(_nearest_interactable())


func _try_interact_node(node: Node) -> bool:
	var owner := _interact_owner(node)
	if owner == null:
		return false
	if owner.has_method("interact"):
		var result: Variant = owner.call("interact")
		if result is bool and result == false:
			return false
		_note_guide_interact()
		return true
	if owner.has_method("action"):
		var result: Variant = owner.call("action")
		if result is bool and result == false:
			return false
		_note_guide_interact()
		return true
	return false


func _interact_ray_node() -> Node:
	if interact_ray == null or not interact_ray.is_colliding():
		return null
	return interact_ray.get_collider() as Node


func _interact_owner(node: Node) -> Node:
	while node:
		if node.has_method("interact") or node.has_method("action"):
			return node
		node = node.get_parent()
	return null


func _is_talk_target(node: Node) -> bool:
	return node != null and node.is_in_group("interactable")


func _nearest_interactable() -> Node:
	var best: Node = null
	var best_d := interact_range
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D) or not _is_talk_target(node):
			continue
		var d := (node as Node3D).global_position.distance_to(global_position)
		if d <= best_d:
			best_d = d
			best = node
	var space := get_world_3d().direct_space_state
	if space == null:
		return best
	var sphere := SphereShape3D.new()
	sphere.radius = interact_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3(0.0, 1.0, 0.0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for hit in space.intersect_shape(query, 24):
		var owner := _interact_owner(hit.get("collider") as Node)
		if owner == null or not (owner is Node3D) or not _is_talk_target(owner):
			continue
		var d := (owner as Node3D).global_position.distance_to(global_position)
		if d <= best_d:
			best_d = d
			best = owner
	return best


func _focus_interactable() -> Node:
	var ray_owner := _interact_owner(_interact_ray_node())
	if ray_owner:
		return ray_owner
	return _nearest_interactable()


func _update_interact_prompt() -> void:
	if _modal_ui_open() or chapter_asleep or chapter_locked:
		_set_prompt_visible(false)
		_set_target_ring(null)
		return
	var target := _focus_interactable()
	_set_target_ring(target)
	if target == null:
		_set_prompt_visible(false)
		return
	var key := "hud.interact_verb"
	if target.has_method("interact_prompt_key"):
		var custom := str(target.call("interact_prompt_key"))
		if not custom.is_empty():
			key = custom
	var fallback := _loc_text("hud.interact_verb", "Hablar")
	var text := _loc_text(key, "E — Hablar")
	var guide := get_node_or_null("/root/PlayerGuide")
	if guide != null and guide.has_method("format_interact_prompt"):
		text = str(guide.call("format_interact_prompt", key, fallback))
	_set_prompt_text(text)
	_set_prompt_visible(true)
	_place_prompt_over(target as Node3D)


func _ensure_target_ring() -> void:
	if _target_ring != null or not is_inside_tree():
		return
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "SelectedTarget"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.86
	mesh.bottom_radius = 0.86
	mesh.height = 0.09
	mesh.radial_segments = 28
	_target_ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.90, 0.38, 0.95)
	_target_ring.material_override = mat
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring.visible = false
	add_child(_target_ring)
	_ensure_world_prompt()


func _set_target_ring(target: Node) -> void:
	if _target_ring == null:
		return
	if target == null or not (target is Node3D):
		_target_ring.visible = false
		return
	var node := target as Node3D
	_target_ring.visible = true
	var world := node.global_position
	_target_ring.global_position = Vector3(world.x, world.y + 0.04, world.z)


func _note_guide_interact() -> void:
	var guide := get_node_or_null("/root/PlayerGuide")
	if guide != null and guide.has_method("note_interacted"):
		guide.call("note_interacted")


func _ensure_interact_prompt() -> void:
	if _prompt_label != null or not is_inside_tree():
		return
	_ensure_target_ring()
	_ensure_world_prompt()
	# Screen-space chip lives on the scene root. A CanvasLayer child of Cid
	# inherited the player's 3D transform and kept E pinned to the HUD edge.
	var host: Node = get_tree().root
	_prompt_layer = host.get_node_or_null("InteractPrompt") as CanvasLayer
	if _prompt_layer == null:
		_prompt_layer = CanvasLayer.new()
		_prompt_layer.name = "InteractPrompt"
		_prompt_layer.layer = 25
		host.add_child(_prompt_layer)
	_prompt_host = _prompt_layer.get_node_or_null("Root") as Control
	if _prompt_host == null:
		_prompt_host = Control.new()
		_prompt_host.name = "Root"
		_prompt_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prompt_layer.add_child(_prompt_host)
		_prompt_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_chip = _prompt_host.get_node_or_null("Chip") as ColorRect
	if _prompt_chip == null:
		_prompt_chip = ColorRect.new()
		_prompt_chip.name = "Chip"
		_prompt_chip.color = Color(0.08, 0.06, 0.04, 0.92)
		_prompt_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prompt_host.add_child(_prompt_chip)
	_prompt_label = _prompt_host.get_node_or_null("Hint") as Label
	if _prompt_label == null:
		_prompt_label = Label.new()
		_prompt_label.name = "Hint"
		_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_prompt_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80))
		_prompt_label.add_theme_font_size_override("font_size", 20)
		_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prompt_host.add_child(_prompt_label)
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_prompt_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_prompt_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_prompt_visible(false)


func _ensure_world_prompt() -> void:
	if _prompt_world != null or _target_ring == null:
		return
	_prompt_world = Label3D.new()
	_prompt_world.name = "InteractChip"
	_prompt_world.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_world.pixel_size = 0.005
	_prompt_world.font_size = 32
	_prompt_world.outline_size = 8
	_prompt_world.modulate = Color(0.97, 0.92, 0.80)
	_prompt_world.outline_modulate = Color(0.08, 0.06, 0.04, 0.95)
	_prompt_world.position = Vector3(0.0, 2.55, 0.0)
	_prompt_world.visible = false
	_target_ring.add_child(_prompt_world)


func _on_tree_exiting() -> void:
	if _prompt_layer == null or not is_instance_valid(_prompt_layer):
		return
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("player"):
			if node != self:
				return
	_prompt_layer.queue_free()
	_prompt_layer = null


func interact_prompt_text() -> String:
	if _prompt_world != null and not _prompt_world.text.is_empty():
		return _prompt_world.text
	if _prompt_label != null:
		return _prompt_label.text
	return ""


func _set_prompt_text(text: String) -> void:
	if _prompt_label:
		_prompt_label.text = text
	if _prompt_world:
		_prompt_world.text = text


func _set_prompt_visible(show: bool) -> void:
	if _prompt_label:
		_prompt_label.visible = show
	if _prompt_chip:
		_prompt_chip.visible = show
	if _prompt_world:
		_prompt_world.visible = show


func _place_prompt_over(target: Node3D) -> void:
	if target == null:
		return
	# World chip rides the gold ring (already on the selected person).
	if _prompt_world:
		_prompt_world.visible = true
	var cam := camera
	if cam == null or not is_instance_valid(cam) or _prompt_label == null:
		return
	var head := target.global_position + Vector3(0.0, 2.55, 0.0)
	var screen := cam.unproject_position(head)
	if cam.is_position_behind(head):
		_prompt_label.visible = false
		if _prompt_chip:
			_prompt_chip.visible = false
		return
	_prompt_label.reset_size()
	var text_size := _prompt_label.get_minimum_size()
	if text_size.x < 8.0:
		text_size = Vector2(168.0, 28.0)
	_prompt_label.size = text_size
	var top_left := screen + Vector2(-text_size.x * 0.5, -36.0)
	_prompt_label.global_position = top_left
	_prompt_label.position = top_left
	_sync_prompt_chip()


func _sync_prompt_chip() -> void:
	if _prompt_chip == null or _prompt_label == null:
		return
	_prompt_chip.visible = _prompt_label.visible
	if not _prompt_chip.visible:
		return
	var text_size := _prompt_label.size
	if text_size.x < 8.0:
		text_size = Vector2(168.0, 28.0)
	_prompt_chip.size = text_size + Vector2(20.0, 10.0)
	_prompt_chip.global_position = _prompt_label.global_position + Vector2(-10.0, -4.0)
	_prompt_chip.position = _prompt_label.position + Vector2(-10.0, -4.0)


func _loc_text(key: String, fallback: String) -> String:
	var loc := get_node_or_null("/root/Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t


func _dialogue_open() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("talk_balloon"):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			return true
		if node is Control and (node as Control).is_visible_in_tree():
			return true
	return false


func _modal_ui_open() -> bool:
	if _dialogue_open():
		return true
	if not is_inside_tree():
		return false
	var pause := get_tree().root.get_node_or_null("PauseMenu")
	if pause != null and bool(pause.visible):
		return true
	for node in get_tree().get_nodes_in_group("modal_choice"):
		if node is Control and bool((node as Control).visible):
			return true
	return false


func _gui_blocks_pointer() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var hovered := vp.gui_get_hovered_control()
	if hovered == null:
		return false
	return hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _world_click_blocked() -> bool:
	return _gui_blocks_pointer() or _mouse_over_hud() or _modal_ui_open()


func _mouse_over_hud() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	return _point_over_hud(vp.get_mouse_position())


func _point_over_hud(screen_pos: Vector2) -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("hud_click_sink"):
		if not (node is Control):
			continue
		var ctl := node as Control
		if not ctl.is_visible_in_tree():
			continue
		if _hud_hit_rect(ctl).has_point(screen_pos):
			return true
	return false


func _hud_hit_rect(ctl: Control) -> Rect2:
	var r := ctl.get_global_rect()
	var min_s := ctl.custom_minimum_size
	if r.size.x < min_s.x:
		r.size.x = min_s.x
	if r.size.y < min_s.y:
		r.size.y = min_s.y
	# Drawn meters fallback to PANEL_SIZE when the Control has not laid out yet.
	if r.size.x < 8.0:
		r.size.x = 232.0
	if r.size.y < 8.0:
		r.size.y = 36.0
	return r


func _is_pointer_event(event: InputEvent) -> bool:
	return (
		event is InputEventMouse
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
	)


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


func _is_click_move_press(event: InputEvent) -> bool:
	if _is_world_walk_tap(event):
		return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT
	return event.is_action_pressed("click_move")


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
