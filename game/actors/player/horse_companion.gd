class_name HorseCompanion
extends CharacterBody3D

## Greybox mount (debug id horse / destrier until a chapter applies a legend name).
## Gaits are speed bands (gallop ≡ DESIGN canter). Camera stays on Cid.

const TUNABLES_PATH := "res://data/combat/horse.json"
const FLAG_ID := "horse_companion"
const LAYER_HORSE := 128

var tunables: Dictionary = {}
var hp: float = 0.0
var max_hp: float = 0.0
var stamina: float = 0.0
var max_stamina: float = 0.0
var cavalry: Node = null

var _rider: Node3D = null
var _mounted: bool = false
var _gait: StringName = &"walk"
var _panic_left: float = 0.0
var _panic_reason: StringName = &""
var _panic_dir: Vector3 = Vector3(0.0, 0.0, 1.0)
var _mount_hold: float = 0.0
var _rider_layer: int = 2
var _rider_mask: int = 5
var _last_facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var _spent_stamina: bool = false
var _following: bool = false
var _named_id: StringName = &""
var _named_key: String = ""


func _init() -> void:
	load_tunables()
	# Physics tick (not idle): snap rider before Cid orients the child camera.
	process_physics_priority = -1


func _ready() -> void:
	add_to_group("horse_companion")
	process_physics_priority = -1
	floor_snap_length = 0.25
	collision_layer = LAYER_HORSE
	if collision_mask == 0:
		collision_mask = 1
	cavalry = get_node_or_null("CavalryCharge")
	if cavalry != null and cavalry.has_method("bind_horse"):
		cavalry.call("bind_horse", self)
	_bind_rider()
	set_physics_process(true)


func load_tunables() -> void:
	tunables = _load_json(TUNABLES_PATH)
	max_hp = float(tunables.get("hp", 0.0))
	hp = max_hp
	max_stamina = float(tunables.get("stamina", 0.0))
	stamina = max_stamina


func debug_id() -> StringName:
	if _named_id != &"":
		return _named_id
	return StringName(str(tunables.get("debug_id", "horse")))


func apply_name(id: StringName, display_key: String) -> void:
	# Valencia hub supplies the legend name; destierro scenes never call this.
	if id == &"":
		return
	_named_id = id
	_named_key = display_key


func is_named() -> bool:
	return _named_id != &""


func current_gait() -> StringName:
	return _gait


func facing_dir() -> Vector3:
	return _facing()


func set_facing(dir: Vector3) -> void:
	var xz := Vector3(dir.x, 0.0, dir.z)
	if xz.length_squared() < 0.0001:
		return
	_last_facing = xz.normalized()


func is_mounted() -> bool:
	return _mounted


func is_panicking() -> bool:
	return _panic_left > 0.0


func feature_enabled() -> bool:
	var flags := _flags()
	if flags.is_empty():
		return true
	for flag in flags:
		if str(flag) == FLAG_ID:
			return true
	return false


func gait_for_speed(speed: float) -> StringName:
	var abs_speed := absf(speed)
	if abs_speed < float(tunables.get("trot_min_speed", 0.0)):
		return &"walk"
	if abs_speed < float(tunables.get("gallop_min_speed", 0.0)):
		return &"trot"
	return &"gallop"


func display_name() -> String:
	var key := _named_key
	if key.is_empty():
		key = str(tunables.get("display_name_key", "horse.companion"))
	var loc := _loc()
	if loc != null and loc.has_method("text"):
		return str(loc.call("text", key))
	if not _named_key.is_empty():
		return _named_key
	return "el caballo"


func bind_rider(rider: Node3D) -> void:
	_rider = rider


func can_mount(rider: Node3D) -> bool:
	if not feature_enabled() or _mounted or is_panicking():
		return false
	if rider == null or not is_instance_valid(rider):
		return false
	var to := _world_pos(rider) - _world_pos(self)
	to.y = 0.0
	return to.length() <= float(tunables.get("mount_distance", 0.0))


func mount(rider: Node3D) -> bool:
	if rider == null or not is_instance_valid(rider):
		return false
	if not feature_enabled() or _mounted or is_panicking():
		return false
	_rider = rider
	_mounted = true
	_following = false
	_mount_hold = 0.0
	_store_rider_collision()
	_apply_rider_collision(false)
	_snap_rider()
	return true


func dismount() -> bool:
	if not _mounted:
		return false
	_mounted = false
	if _rider != null and is_instance_valid(_rider):
		var side := Vector3(
			float(tunables.get("dismount_offset_x", 0.0)),
			float(tunables.get("dismount_offset_y", 0.0)),
			float(tunables.get("dismount_offset_z", 0.0))
		)
		_set_world_pos(_rider, _world_pos(self) + side)
		if _rider is CharacterBody3D:
			(_rider as CharacterBody3D).velocity = Vector3.ZERO
	_apply_rider_collision(true)
	if cavalry != null and cavalry.has_method("disarm"):
		cavalry.call("disarm")
	return true


func panic(reason: StringName) -> void:
	_panic_reason = reason
	_panic_left = float(tunables.get("panic_duration", 0.0))
	_panic_dir = Vector3(velocity.x, 0.0, velocity.z)
	if _panic_dir.length_squared() < 0.0001 and _rider != null and is_instance_valid(_rider):
		var away := _world_pos(self) - _world_pos(_rider)
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_panic_dir = away.normalized()
	if _panic_dir.length_squared() < 0.0001:
		_panic_dir = Vector3(0.0, 0.0, 1.0)
	else:
		_panic_dir = _panic_dir.normalized()
	if _mounted:
		dismount()
	if cavalry != null and cavalry.has_method("disarm"):
		cavalry.call("disarm")


func panic_reason() -> StringName:
	return _panic_reason


func follow_wish() -> Vector3:
	if _mounted or not feature_enabled():
		return Vector3.ZERO
	if _rider == null or not is_instance_valid(_rider):
		return Vector3.ZERO
	var to := _world_pos(_rider) - _world_pos(self)
	to.y = 0.0
	var distance := to.length()
	if distance <= float(tunables.get("follow_stop_distance", 0.0)):
		_following = false
		return Vector3.ZERO
	if not _following and distance < float(tunables.get("follow_distance", 0.0)):
		return Vector3.ZERO
	if to.length_squared() < 0.0001:
		return Vector3.ZERO
	_following = true
	return to.normalized()


func couch() -> bool:
	if not _mounted or is_panicking():
		return false
	if cavalry != null and cavalry.has_method("couch"):
		return bool(cavalry.call("couch"))
	return false


func spend_stamina(cost: float) -> bool:
	if cost > stamina:
		return false
	stamina = maxf(stamina - cost, 0.0)
	_spent_stamina = true
	return true


func try_gallop(delta: float) -> bool:
	var cost := float(tunables.get("gallop_stamina_per_sec", 0.0)) * delta
	if cost <= 0.0:
		return stamina > 0.0
	return spend_stamina(cost)


func mount_progress() -> float:
	var need := float(tunables.get("mount_hold_sec", 0.0))
	if need <= 0.0:
		return 0.0
	return clampf(_mount_hold / need, 0.0, 1.0)


func interact_prompt_key() -> String:
	if _mounted:
		return str(tunables.get("dismount_prompt_key", "horse.dismount"))
	return str(tunables.get("mount_prompt_key", "horse.mount"))


func _physics_process(delta: float) -> void:
	# Body yaw stays identity: rider is a sibling snap, camera is on Cid.
	# Lance lives under Visual, which look_ats travel.
	rotation = Vector3.ZERO
	_spent_stamina = false
	_tick_panic(delta)
	_apply_gravity(delta)
	if is_panicking():
		var speed := float(tunables.get("panic_speed", 0.0))
		velocity.x = _panic_dir.x * speed
		velocity.z = _panic_dir.z * speed
	elif _mounted:
		_ridden_move(delta)
	else:
		_tick_dismounted_input(delta)
		_follow_move(delta)
	_gait = gait_for_speed(Vector3(velocity.x, 0.0, velocity.z).length())
	_orient_visual()
	move_and_slide()
	if _mounted:
		_snap_rider()
	_regen(delta)


func _ridden_move(delta: float) -> void:
	if cavalry != null and cavalry.has_method("is_couching") and bool(cavalry.call("is_couching")):
		# Charge owns XZ; walk/run must not clobber the couch.
		var dir := _facing()
		var speed := float(tunables.get("gallop_speed", 0.0))
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		return
	var stick := _stick()
	if stick.length() <= 0.12:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var wish := _camera_aligned(stick)
	if wish.length_squared() < 0.0001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var speed := float(tunables.get("walk_speed", 0.0))
	if stick.length() > 0.55:
		speed = float(tunables.get("trot_speed", 0.0))
	if Input.is_action_pressed("run") and try_gallop(delta):
		speed = float(tunables.get("gallop_speed", 0.0))
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	_last_facing = wish


func _follow_move(delta: float) -> void:
	_bind_rider()
	var wish := follow_wish()
	if wish.length_squared() < 0.0001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var distance := 0.0
	if _rider != null:
		var to := _world_pos(_rider) - _world_pos(self)
		to.y = 0.0
		distance = to.length()
	var speed := float(tunables.get("walk_speed", 0.0))
	if distance >= float(tunables.get("follow_trot_distance", 0.0)):
		speed = float(tunables.get("trot_speed", 0.0))
	if distance >= float(tunables.get("follow_gallop_distance", 0.0)):
		if try_gallop(delta):
			speed = float(tunables.get("gallop_speed", 0.0))
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	_last_facing = wish


func _tick_dismounted_input(delta: float) -> void:
	_bind_rider()
	if _rider == null:
		_mount_hold = 0.0
		return
	if Input.is_action_pressed("interact") and can_mount(_rider):
		_mount_hold += delta
		if _mount_hold >= float(tunables.get("mount_hold_sec", 0.0)):
			mount(_rider)
			_mount_hold = 0.0
	else:
		_mount_hold = 0.0


func _tick_panic(delta: float) -> void:
	if _panic_left <= 0.0:
		return
	_panic_left = maxf(_panic_left - delta, 0.0)


func _snap_rider() -> void:
	if _rider == null or not is_instance_valid(_rider):
		return
	var offset := Vector3(
		float(tunables.get("saddle_offset_x", 0.0)),
		float(tunables.get("saddle_offset_y", 0.0)),
		float(tunables.get("saddle_offset_z", 0.0))
	)
	_set_world_pos(_rider, _world_pos(self) + offset)
	if _rider is CharacterBody3D:
		(_rider as CharacterBody3D).velocity = Vector3.ZERO
	if _rider.has_method("set_facing"):
		_rider.call("set_facing", _facing())
	var vis := _rider.get_node_or_null("Visual") as Node3D
	if vis != null and _rider.is_inside_tree():
		var look := _world_pos(_rider) + Vector3(_facing().x, 0.0, _facing().z)
		if not look.is_equal_approx(_world_pos(_rider)):
			vis.look_at(look, Vector3.UP)


func _store_rider_collision() -> void:
	if _rider is CollisionObject3D:
		var body := _rider as CollisionObject3D
		_rider_layer = body.collision_layer
		_rider_mask = body.collision_mask


func _apply_rider_collision(enabled: bool) -> void:
	if not (_rider is CollisionObject3D):
		return
	var body := _rider as CollisionObject3D
	if enabled:
		body.collision_layer = _rider_layer
		body.collision_mask = _rider_mask
	else:
		body.collision_layer = 0
		body.collision_mask = 1


func _bind_rider() -> void:
	if _rider != null and is_instance_valid(_rider):
		return
	var tree := _scene_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	for node in players:
		if node is Node3D:
			_rider = node as Node3D
			return


func _world_pos(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	if node.is_inside_tree():
		return node.global_position
	return node.position


func _set_world_pos(node: Node3D, pos: Vector3) -> void:
	if node == null:
		return
	if node.is_inside_tree():
		node.global_position = pos
	else:
		node.position = pos


func _facing() -> Vector3:
	if _last_facing.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return _last_facing.normalized()


func _orient_visual() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var dir := _facing()
	if dir.length_squared() < 0.0001:
		return
	visual.basis = Basis.looking_at(dir, Vector3.UP)


func _stick() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _camera_aligned(stick: Vector2) -> Vector3:
	var forward := Vector3(0.0, 0.0, -1.0)
	var right := Vector3.RIGHT
	var camera: Camera3D = null
	if _rider != null:
		camera = _rider.get_node_or_null("CameraRig/Camera3D") as Camera3D
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


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y <= 0.0:
			velocity.y = 0.0
		return
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	velocity.y -= g * delta


func _regen(delta: float) -> void:
	if _spent_stamina or is_panicking():
		return
	if cavalry != null and cavalry.has_method("is_couching") and bool(cavalry.call("is_couching")):
		return
	var rate := float(tunables.get("stamina_regen_per_sec", 0.0))
	stamina = minf(max_stamina, stamina + rate * delta)


func _flags() -> PackedStringArray:
	var tree := _scene_tree()
	if tree == null:
		return PackedStringArray()
	var gs := tree.root.get_node_or_null("GameState")
	if gs != null and gs.has_method("flags"):
		var value: Variant = gs.call("flags")
		if value is PackedStringArray:
			return value
		if value is Array:
			var packed := PackedStringArray()
			for item in value:
				packed.append(str(item))
			return packed
	return PackedStringArray()


func _loc() -> Node:
	var tree := _scene_tree()
	if tree != null:
		return tree.root.get_node_or_null("Loc")
	return null


func _scene_tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
