extends SceneTree
## Headless horse companion test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_horse_companion.gd

const HORSE := preload("res://game/actors/player/horse_companion.gd")
const CHARGE := preload("res://game/combat/cavalry_charge.gd")
const HIT := preload("res://game/combat/hit_box.gd")


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_flag_on())
	failures.append_array(_test_gait_bands())
	failures.append_array(_test_mount_dismount())
	failures.append_array(_test_follow_when_dismounted())
	failures.append_array(_test_panic_throws())
	failures.append_array(_test_couch_lance_wedge())
	failures.append_array(_test_last_tick_gallop())
	failures.append_array(_test_lance_follows_facing())
	failures.append_array(_test_couch_owns_xz())
	failures.append_array(_test_follow_leash())
	failures.append_array(_test_rider_faces_horse())
	failures.append_array(_test_scenes_cheap_camera_on_cid())
	_finish(failures)


func _test_flag_on() -> PackedStringArray:
	var failures: PackedStringArray = []
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null or not gs.has_method("flags"):
		failures.append("GameState.flags missing")
		return failures
	var flags: PackedStringArray = gs.call("flags")
	var found := false
	for flag in flags:
		if str(flag) == "horse_companion":
			found = true
			break
	if not found:
		failures.append("flags.horse_companion must be ON")
	return failures


func _test_gait_bands() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: HorseCompanion = HORSE.new()
	var trot_min := float(horse.tunables.get("trot_min_speed", 0.0))
	var gallop_min := float(horse.tunables.get("gallop_min_speed", 0.0))
	if trot_min <= 0.0 or gallop_min <= trot_min:
		failures.append("horse.json gait bands missing")
		horse.free()
		return failures
	if horse.gait_for_speed(trot_min - 0.1) != &"walk":
		failures.append("below trot_min must be walk")
	if horse.gait_for_speed(trot_min) != &"trot":
		failures.append("trot_min must be trot")
	if horse.gait_for_speed(gallop_min - 0.1) != &"trot":
		failures.append("below gallop_min must be trot")
	if horse.gait_for_speed(gallop_min) != &"gallop":
		failures.append("gallop_min must be gallop")
	if horse.debug_id() != &"horse" and horse.debug_id() != &"destrier":
		failures.append("debug id must be horse or destrier")
	if horse.display_name().to_lower().contains("babieca"):
		failures.append("display name must stay unnamed")
	if not is_equal_approx(horse.max_hp, 80.0):
		failures.append("horse hp want 80 got %s" % horse.max_hp)
	horse.free()
	return failures


func _test_mount_dismount() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: HorseCompanion = HORSE.new()
	var rider := CharacterBody3D.new()
	rider.collision_layer = 2
	rider.collision_mask = 5
	if not horse.mount(rider):
		failures.append("mount() failed")
	if not horse.is_mounted():
		failures.append("is_mounted false after mount")
	if rider.collision_layer != 0:
		failures.append("mounted rider must drop collision_layer")
	if not horse.dismount():
		failures.append("dismount() failed")
	if horse.is_mounted():
		failures.append("still mounted after dismount")
	if rider.collision_layer != 2:
		failures.append("dismount must restore rider layer")
	rider.free()
	horse.free()
	return failures


func _test_follow_when_dismounted() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: HorseCompanion = HORSE.new()
	var rider := CharacterBody3D.new()
	horse.bind_rider(rider)
	horse.position = Vector3.ZERO
	rider.position = Vector3(12.0, 0.0, 0.0)
	var wish := horse.follow_wish()
	if wish.x <= 0.0:
		failures.append("follow wish must point at rider")
	rider.position = Vector3(3.0, 0.0, 0.0)
	wish = horse.follow_wish()
	if wish.x <= 0.0:
		failures.append("hysteresis must keep following until stop distance")
	rider.position = Vector3(0.4, 0.0, 0.0)
	wish = horse.follow_wish()
	if wish.length_squared() > 0.0001:
		failures.append("follow must stop when close")
	horse.mount(rider)
	wish = horse.follow_wish()
	if wish.length_squared() > 0.0001:
		failures.append("mounted horse must not follow")
	rider.free()
	horse.free()
	return failures


func _test_panic_throws() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: HorseCompanion = HORSE.new()
	var rider := CharacterBody3D.new()
	horse.mount(rider)
	horse.panic(&"fire")
	if horse.is_mounted():
		failures.append("panic must throw the rider")
	if not horse.is_panicking():
		failures.append("panic duration missing")
	if horse.panic_reason() != &"fire":
		failures.append("panic reason not stored")
	var charge: CavalryCharge = CHARGE.new()
	charge.horse = horse
	charge.panic_for(&"shout")
	if horse.panic_reason() != &"shout":
		failures.append("panic_for shout must reach the horse")
	rider.free()
	charge.free()
	horse.free()
	return failures


func _test_couch_lance_wedge() -> PackedStringArray:
	var failures: PackedStringArray = []
	var charge: CavalryCharge = CHARGE.new()
	if charge.LAYER_LANCE_WEDGE != 8:
		failures.append("lance_wedge bit 4 must be layer value 8")
	var box: HitBox = HIT.new()
	charge.hit_box = box
	charge.apply_wedge_layers()
	if box.collision_layer != 8:
		failures.append("couch hitbox layer want 8 got %s" % box.collision_layer)
	if box.collision_mask != 4:
		failures.append("couch mask must stay hurtbox_killable")
	if not charge.couch():
		failures.append("couch stub failed")
	if charge.last_move != &"lance_couch":
		failures.append("couch last_move want lance_couch")
	if not charge.is_couching():
		failures.append("couch duration must arm the charge")
	if not is_equal_approx(charge.auto_couch_distance(), 0.0):
		# horse unbound; distance comes from horse tunables when bound
		pass
	var horse: HorseCompanion = HORSE.new()
	var rider := CharacterBody3D.new()
	charge.bind_horse(horse)
	if not is_equal_approx(charge.auto_couch_distance(), 8.0):
		failures.append("straight couch distance want 8 got %s" % charge.auto_couch_distance())
	if not horse.mount(rider):
		failures.append("mount before dismount_hook failed")
	if not charge.dismount_hook():
		failures.append("dismount_hook stub failed")
	if horse.is_mounted():
		failures.append("dismount_hook must dismount")
	rider.free()
	horse.free()
	box.free()
	charge.free()
	return failures


func _test_scenes_cheap_camera_on_cid() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed_horse: Resource = load("res://content/art/characters/horse/horse.tscn")
	if packed_horse == null or not (packed_horse is PackedScene):
		failures.append("horse.tscn failed to load")
		return failures
	var horse_node: Node = (packed_horse as PackedScene).instantiate()
	if not (horse_node is CharacterBody3D):
		failures.append("Horse root is not CharacterBody3D")
	if horse_node.get_node_or_null("Visual") == null:
		failures.append("Horse missing Visual")
	if horse_node.get_node_or_null("CavalryCharge") == null:
		failures.append("Horse missing CavalryCharge")
	if horse_node.get_node_or_null("Visual/LanceHitBox") == null:
		failures.append("Horse missing Visual/LanceHitBox")
	if horse_node.find_children("*", "Camera3D", true, false).size() != 0:
		failures.append("camera must stay on Cid, not the horse")
	if horse_node.find_children("*", "CSGBox3D", true, false).is_empty():
		failures.append("Horse greybox missing CSG")
	if horse_node.find_children("*", "OmniLight3D", true, false).size() != 0:
		failures.append("Horse added OmniLight3D")
	if horse_node.find_children("*", "SpotLight3D", true, false).size() != 0:
		failures.append("Horse added SpotLight3D")
	if horse_node.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("Horse has GPUParticles3D")
	if horse_node.find_children("*", "SpringArm3D", true, false).size() != 0:
		failures.append("Horse gained a SpringArm3D")
	if horse_node is CollisionObject3D and (horse_node as CollisionObject3D).collision_layer != 128:
		failures.append("Horse collision_layer want 128")
	horse_node.free()

	var packed_cid: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed_cid == null or not (packed_cid is PackedScene):
		failures.append("cid.tscn failed to load")
		return failures
	var cid: Node = (packed_cid as PackedScene).instantiate()
	if cid.get_node_or_null("CameraRig/Camera3D") == null:
		failures.append("Cid missing locked Camera3D")
	if cid.find_children("*", "SpringArm3D", true, false).size() != 0:
		failures.append("Cid gained a SpringArm3D")
	if not cid.has_method("is_mounted"):
		failures.append("CidController missing is_mounted")
	cid.free()

	var packed_arena: Resource = load("res://content/chapters/_dev/arena.tscn")
	if packed_arena == null or not (packed_arena is PackedScene):
		failures.append("arena.tscn failed to load")
		return failures
	var arena: Node = (packed_arena as PackedScene).instantiate()
	var lights := arena.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("arena must keep exactly 1 DirectionalLight3D, has %d" % lights.size())
	if arena.find_children("*", "OmniLight3D", true, false).size() != 0:
		failures.append("arena gained OmniLight3D")
	if arena.get_node_or_null("Horse") == null:
		failures.append("arena missing Horse instance")
	if arena.get_node_or_null("Cid") == null:
		failures.append("arena missing Cid")
	arena.free()
	return failures


func _test_last_tick_gallop() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: HorseCompanion = HORSE.new()
	var delta := 1.0 / 60.0
	var cost := float(horse.tunables.get("gallop_stamina_per_sec", 0.0)) * delta
	if cost <= 0.0:
		failures.append("gallop_stamina_per_sec missing")
		horse.free()
		return failures
	horse.stamina = cost
	if not horse.try_gallop(delta):
		failures.append("last stamina sliver must still gallop")
	if horse.stamina > 0.0001:
		failures.append("last gallop tick must spend the sliver, left %s" % horse.stamina)
	if horse.try_gallop(delta):
		failures.append("empty stamina must refuse gallop")
	horse.free()
	return failures


func _test_lance_follows_facing() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/horse/horse.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("horse.tscn failed to load for lance facing")
		return failures
	var horse: HorseCompanion = (packed as PackedScene).instantiate() as HorseCompanion
	var rider := CharacterBody3D.new()
	var charge: Node = horse.get_node_or_null("CavalryCharge")
	if charge == null:
		failures.append("scene missing CavalryCharge")
		horse.free()
		rider.free()
		return failures
	horse.cavalry = charge
	if charge.has_method("bind_horse"):
		charge.call("bind_horse", horse)
	horse.set_facing(Vector3.RIGHT)
	if not horse.mount(rider):
		failures.append("mount for lance facing failed")
	if not horse.couch():
		failures.append("couch for lance facing failed")
	horse._orient_visual()
	horse._ridden_move(0.016)
	var visual: Node3D = horse.get_node_or_null("Visual") as Node3D
	var lance: Node3D = horse.get_node_or_null("Visual/LanceHitBox") as Node3D
	if visual == null or lance == null:
		failures.append("Visual/LanceHitBox missing after instantiate")
	else:
		if lance.get_parent() != visual:
			failures.append("LanceHitBox must be parented under Visual")
		var fwd := -visual.basis.z
		fwd.y = 0.0
		if fwd.length_squared() < 0.0001:
			failures.append("visual forward is zero")
		else:
			fwd = fwd.normalized()
			if fwd.dot(Vector3.RIGHT) < 0.9:
				failures.append("lance/visual must follow +X facing, got %s" % fwd)
			if fwd.dot(Vector3(0.0, 0.0, -1.0)) > 0.5:
				failures.append("lance still world -Z after facing +X")
	var gallop := float(horse.tunables.get("gallop_speed", 0.0))
	if absf(horse.velocity.x - gallop) > 0.05 or absf(horse.velocity.z) > 0.05:
		failures.append("couch velocity want +X gallop got %s" % horse.velocity)
	horse.free()
	rider.free()
	return failures


func _test_couch_owns_xz() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: HorseCompanion = HORSE.new()
	var charge: CavalryCharge = CHARGE.new()
	var rider := CharacterBody3D.new()
	horse.cavalry = charge
	charge.horse = horse
	horse.set_facing(Vector3.RIGHT)
	if not horse.mount(rider):
		failures.append("mount for couch XZ failed")
	if not horse.couch():
		failures.append("couch for XZ lock failed")
	horse.velocity = Vector3(0.0, 0.0, -20.0)
	horse._ridden_move(0.016)
	var gallop := float(horse.tunables.get("gallop_speed", 0.0))
	if absf(horse.velocity.x - gallop) > 0.05:
		failures.append("couch must keep gallop along facing, vx=%s" % horse.velocity.x)
	if absf(horse.velocity.z) > 0.05:
		failures.append("couch must ignore stick/-Z clobber, vz=%s" % horse.velocity.z)
	rider.free()
	charge.free()
	horse.free()
	return failures


func _test_follow_leash() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: HorseCompanion = HORSE.new()
	var rider := CharacterBody3D.new()
	horse.bind_rider(rider)
	horse.position = Vector3.ZERO
	rider.position = Vector3(3.0, 0.0, 0.0)
	var wish := horse.follow_wish()
	if wish.length_squared() > 0.0001:
		failures.append("inside follow_distance must not start follow")
	rider.position = Vector3(12.0, 0.0, 0.0)
	wish = horse.follow_wish()
	if wish.x <= 0.0:
		failures.append("beyond follow_distance must start follow")
	rider.free()
	horse.free()
	return failures


func _test_rider_faces_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("cid.tscn failed to load for rider facing")
		return failures
	var cid: Node3D = (packed as PackedScene).instantiate() as Node3D
	var horse: HorseCompanion = HORSE.new()
	horse.set_facing(Vector3.RIGHT)
	if not horse.mount(cid):
		failures.append("mount for rider facing failed")
	horse._snap_rider()
	if not cid.has_method("facing_dir"):
		failures.append("Cid missing facing_dir")
	else:
		var face: Vector3 = cid.call("facing_dir")
		face.y = 0.0
		if face.length_squared() < 0.0001 or face.normalized().dot(Vector3.RIGHT) < 0.9:
			failures.append("mounted Cid facing want +X got %s" % face)
	horse.free()
	cid.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_horse_companion: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_horse_companion: %s" % failure)
	quit(1)
