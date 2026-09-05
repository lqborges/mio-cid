extends SceneTree
## Headless combat v1 test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_combat.gd

const COMBAT := preload("res://game/actors/player/cid_combat.gd")
const HIT := preload("res://game/combat/hit_box.gd")
const HURT := preload("res://game/combat/hurt_box.gd")
const MOVESET := preload("res://game/combat/weapon_moveset.gd")
const DUMMY := preload("res://game/combat/dummy_enemy.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_moveset_cap())
	failures.append_array(_test_three_hit_combo())
	failures.append_array(_test_unkillable_refused())
	failures.append_array(_test_alfonso_parent_refused())
	failures.append_array(_test_ignite_swap())
	failures.append_array(_test_hitbox_strike_once())
	failures.append_array(_test_you_fell_death())
	failures.append_array(_test_cid_scene_sword_and_boxes())
	failures.append_array(_test_arena_eight_dummies())
	failures.append_array(_test_attack_switch_cancels_pending())
	failures.append_array(await _test_real_cid_integrations())
	_finish(failures)


func _test_moveset_cap() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ms: WeaponMoveset = MOVESET.from_json_path("res://data/combat/sword.json")
	if ms.max_combo != 3:
		failures.append("sword max_combo want 3 got %s" % ms.max_combo)
	if ms.combo_cap() != 3:
		failures.append("combo_cap want 3 got %s" % ms.combo_cap())
	if ms.combo.size() != 3 or ms.combo[0] != "slash" or ms.combo[1] != "thrust" or ms.combo[2] != "bash":
		failures.append("combo must be slash/thrust/bash")
	return failures


func _test_three_hit_combo() -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: CidCombat = COMBAT.new()
	combat.slam()
	if combat.last_move != &"slash" or combat.combo_step != 1:
		failures.append("first slam must be slash")
	combat.slam()
	if combat.last_move != &"thrust" or combat.combo_step != 2:
		failures.append("second slam must be thrust")
	combat.slam()
	if combat.last_move != &"bash" or combat.combo_step != 3:
		failures.append("third slam must be bash")
	var stam: float = combat.stamina
	combat.slam()
	if combat.combo_step != 3:
		failures.append("fourth slam must not extend combo")
	if not is_equal_approx(combat.stamina, stam):
		failures.append("fourth slam must not spend stamina")
	combat.free()
	return failures


func _test_unkillable_refused() -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: CidCombat = COMBAT.new()
	var hurt: HurtBox = HURT.new()
	hurt.unkillable = true
	hurt.hp = 9.0
	hurt.max_hp = 9.0
	if hurt.apply_hit(4.0, &"slash", 0.1, combat):
		failures.append("unkillable HurtBox must refuse apply_hit")
	if not is_equal_approx(hurt.hp, 9.0):
		failures.append("unkillable hp must stay 9, got %s" % hurt.hp)
	if combat.can_hit(hurt):
		failures.append("CidCombat must refuse unkillable hurtbox")
	var spec: HurtBox = HURT.new()
	spec.spectator = true
	spec.hp = 9.0
	spec.max_hp = 9.0
	if spec.apply_hit(4.0, &"slash", 0.0, combat):
		failures.append("spectator HurtBox must refuse apply_hit")
	if combat.can_hit(spec):
		failures.append("CidCombat must refuse spectator hurtbox")
	hurt.free()
	spec.free()
	combat.free()
	return failures


func _test_alfonso_parent_refused() -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: CidCombat = COMBAT.new()
	var dummy: DummyEnemy = DUMMY.new()
	dummy.unkillable = true
	var hurt: HurtBox = HURT.new()
	hurt.hp = 8.0
	hurt.max_hp = 8.0
	dummy.add_child(hurt)
	if combat.can_hit(hurt):
		failures.append("Alfonso-class unkillable parent must not be a valid hurtbox")
	dummy.free()
	combat.free()
	return failures


func _test_ignite_swap() -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: CidCombat = COMBAT.new()
	if combat.damage_type_for(&"slash") != &"slash":
		failures.append("steel slash type should be slash")
	combat.weapon_swap()
	if combat.weapon_index != 1:
		failures.append("weapon_swap must toggle ignite")
	if combat.damage_type_for(&"slash") != &"ignite":
		failures.append("ignite swap must change damage type")
	combat.weapon_swap()
	if combat.damage_type_for(&"thrust") != &"thrust":
		failures.append("swap back must restore steel type")
	combat.free()
	return failures


func _test_hitbox_strike_once() -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: CidCombat = COMBAT.new()
	var box: HitBox = HIT.new()
	box.monitoring = true
	box.damage = 12.0
	box.damage_type = &"slash"
	box.stagger = 0.16
	box.source = combat
	var hurt: HurtBox = HURT.new()
	hurt.hp = 38.0
	hurt.max_hp = 38.0
	if not box.strike(hurt):
		failures.append("first strike should land")
	if not is_equal_approx(hurt.hp, 26.0):
		failures.append("slash 12 of 38 should leave 26, got %s" % hurt.hp)
	if box.strike(hurt):
		failures.append("same swing must not double-hit")
	if not is_equal_approx(hurt.hp, 26.0):
		failures.append("double-hit changed hp")
	hurt.free()
	box.free()
	combat.free()
	return failures


func _test_you_fell_death() -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: CidCombat = COMBAT.new()
	combat.allow_death_reload = false
	var hurt: HurtBox = HURT.new()
	combat.bind_hurt(hurt)
	if hurt.hp <= 0.0:
		failures.append("bind_hurt must set player hp from tunables")
		combat.free()
		hurt.free()
		return failures
	var got: Array = []
	var bus := _event_bus()
	var cb := func(reason: StringName) -> void:
		got.append(reason)
	if bus != null and bus.has_signal("hard_fail"):
		bus.hard_fail.connect(cb)
	if not hurt.apply_hit(hurt.hp, &"slash", 0.0, null):
		failures.append("lethal hit should apply")
	if not combat.is_dead():
		failures.append("hp 0 must mark Cid dead")
	if bus != null:
		bus.hard_fail.disconnect(cb)
		if got.is_empty() or got[0] != &"you_fell":
			failures.append("death must emit hard_fail you_fell")
	combat.free()
	hurt.free()
	return failures


func _test_cid_scene_sword_and_boxes() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("cid.tscn failed to load")
		return failures
	var node: Node = (packed as PackedScene).instantiate()
	if node.get_node_or_null("Visual/HitBox") == null:
		failures.append("Cid missing HitBox")
	if node.get_node_or_null("HurtBox") == null:
		failures.append("Cid missing HurtBox")
	if node.get_node_or_null("ShoutRing") == null:
		failures.append("Cid missing ShoutRing")
	if node.get_node_or_null("Visual/Sword") == null:
		failures.append("Cid missing placeholder sword")
	if node.get_node_or_null("CameraRig/Camera3D") == null:
		failures.append("Cid missing locked Camera3D")
	if node.find_children("*", "SpringArm3D", true, false).size() != 0:
		failures.append("Cid gained a SpringArm3D")
	if node.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("Cid has GPUParticles3D")
	var combat: Node = node.get_node_or_null("CidCombat")
	if combat == null or not combat.has_method("slam") or not combat.has_method("leap") or not combat.has_method("shout") or not combat.has_method("weapon_swap"):
		failures.append("CidCombat missing kit methods")
	node.free()
	return failures


func _test_arena_eight_dummies() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/chapters/_dev/arena.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("arena.tscn failed to load")
		return failures
	var arena: Node = (packed as PackedScene).instantiate()
	var dummies: Node = arena.get_node_or_null("Dummies")
	if dummies == null or dummies.get_child_count() != 8:
		failures.append("arena must instance 8 dummies")
	if arena.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("arena has GPUParticles3D")
	if arena.find_children("*", "CPUParticles3D", true, false).size() != 0:
		failures.append("arena has CPUParticles3D")
	var lights := arena.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("arena must keep exactly 1 DirectionalLight3D")
	if arena.find_children("*", "OmniLight3D", true, false).size() != 0:
		failures.append("arena gained OmniLight3D")
	if dummies != null:
		for child in dummies.get_children():
			var mesh: MeshInstance3D = child.get_node_or_null("Visual/MeshInstance3D")
			if mesh == null:
				failures.append("%s missing capsule mesh" % child.name)
			elif mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				failures.append("%s fodder still casts shadows" % child.name)
			if child.get_node_or_null("HurtBox") == null:
				failures.append("%s missing HurtBox" % child.name)
	arena.free()
	return failures


func _test_attack_switch_cancels_pending() -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: CidCombat = COMBAT.new()
	var hit: HitBox = HIT.new()
	var ring: HitBox = HIT.new()
	combat.hit_box = hit
	combat.shout_ring = ring
	combat.slam()
	combat.shout()
	combat._tick_attack(0.06)
	if hit.monitoring:
		failures.append("shout after slam must not rearm the slash volume")
	if str(combat.get("_pending_id")) == "slash":
		failures.append("shout must clear the pending slash phase")
	if combat.last_move != &"shout":
		failures.append("shout must remain the current move after cancel")
	if not ring.monitoring:
		failures.append("shout volume should be live after the switch")
	combat.lower_weapon()
	combat.stamina = combat.max_stamina
	combat.slam()
	combat._tick_attack(0.06)
	if not hit.monitoring:
		failures.append("slash should arm after windup before leap")
	combat.leap()
	if hit.monitoring:
		failures.append("leap must disarm the live slash volume during windup")
	if combat.last_move != &"leap":
		failures.append("leap must replace slash as the current move")
	combat.stamina = combat.max_stamina
	combat.slam()
	if combat.last_move != &"slash" or combat.combo_step != 1:
		failures.append("combo slam after cancel must still start at slash")
	combat.slam()
	if combat.last_move != &"thrust" or combat.combo_step != 2:
		failures.append("second slam must still combo into thrust")
	hit.free()
	ring.free()
	combat.free()
	return failures


func _test_real_cid_integrations() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("real Cid: cid.tscn failed to load")
		return failures
	var cid := (packed as PackedScene).instantiate() as CharacterBody3D
	if cid == null:
		failures.append("real Cid: root is not CharacterBody3D")
		return failures
	get_root().add_child(cid)
	var wall := CSGBox3D.new()
	wall.name = "OccluderWall"
	wall.use_collision = true
	wall.size = Vector3(2.4, 2.4, 2.4)
	wall.position = Vector3(4.0, 6.0, 4.0)
	get_root().add_child(wall)
	await process_frame
	await process_frame
	await physics_frame
	failures.append_array(_probe_foot_camera_and_wall(cid, wall))
	failures.append_array(_probe_real_cid_flash(cid))
	failures.append_array(_probe_real_cid_attack_switch(cid))
	wall.free()
	cid.free()
	return failures


func _probe_foot_camera_and_wall(cid: CharacterBody3D, wall: CSGBox3D) -> PackedStringArray:
	var failures: PackedStringArray = []
	var camera: Camera3D = cid.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if camera == null:
		failures.append("real Cid: Camera3D missing")
		return failures
	var rest := Vector3(float(cid.get("camera_offset")), float(cid.get("camera_height")), float(cid.get("camera_offset")))
	cid.set("chapter_asleep", false)
	cid.set("chapter_locked", false)
	cid.call("apply_camera_nudge", Vector3(0.0, 0.0, 0.4), 0.25)
	cid._physics_process(0.016)
	if camera.position.distance_to(rest + Vector3(0.0, 0.0, 0.4)) > 0.05:
		failures.append("ordinary foot tick left camera un-nudged, pos=%s" % camera.position)
	var faded := wall.material_override as StandardMaterial3D
	if faded == null or faded.albedo_color.a > 0.35:
		failures.append("ordinary foot tick must fade the wall occluder, a=%s" % (faded.albedo_color.a if faded else "none"))
	cid.set("_nudge_left", 0.0)
	cid.set("_nudge", Vector3.ZERO)
	wall.use_collision = false
	cid._physics_process(0.016)
	if camera.position.distance_to(rest) > 0.05:
		failures.append("foot tick must restore the locked camera, pos=%s" % camera.position)
	var restored := wall.material_override as StandardMaterial3D
	if restored != null and restored.albedo_color.a <= 0.35:
		failures.append("clearing the wall collider must restore occluder fade")
	return failures


func _probe_real_cid_flash(cid: CharacterBody3D) -> PackedStringArray:
	var failures: PackedStringArray = []
	var cap := cid.get_node_or_null("Visual/MeshInstance3D") as MeshInstance3D
	var torso := cid.get_node_or_null("Visual/Humanoid/Torso") as MeshInstance3D
	var hurt := cid.get_node_or_null("HurtBox") as HurtBox
	if cap == null or hurt == null:
		failures.append("real Cid: capsule or HurtBox missing")
		return failures
	if torso == null:
		failures.append("real Cid: HumanoidLooks did not build Visual/Humanoid/Torso")
		return failures
	if cap.visible:
		failures.append("real Cid: placeholder capsule should be hidden")
	var before := torso.get_active_material(0)
	CombatFeel.note_hit(hurt, 2.0, cid)
	if cap.get_surface_override_material(0) != null:
		failures.append("real Cid: flash painted the hidden capsule")
	var flashed := torso.get_surface_override_material(0) as StandardMaterial3D
	if flashed == null:
		failures.append("real Cid: flash did not override the visible torso")
	elif before is StandardMaterial3D and flashed.albedo_color.is_equal_approx((before as StandardMaterial3D).albedo_color):
		failures.append("real Cid: torso albedo unchanged after flash")
	return failures


func _probe_real_cid_attack_switch(cid: CharacterBody3D) -> PackedStringArray:
	var failures: PackedStringArray = []
	var combat: Node = cid.get_node_or_null("CidCombat")
	var hit: HitBox = cid.get_node_or_null("Visual/HitBox") as HitBox
	var ring: HitBox = cid.get_node_or_null("ShoutRing") as HitBox
	if combat == null or hit == null or ring == null:
		failures.append("real Cid: combat volumes missing")
		return failures
	if combat.has_method("lower_weapon"):
		combat.call("lower_weapon")
	combat.set("stamina", combat.get("max_stamina"))
	cid.set("_slam_cd", 0.0)
	cid.set("_leap_cd", 0.0)
	cid.set("_shout_cd", 0.0)
	cid.set("_queued_slam", true)
	cid.set("_queued_shout", true)
	cid._physics_process(0.016)
	if combat.has_method("_tick_attack"):
		combat.call("_tick_attack", 0.06)
	if hit.monitoring:
		failures.append("same-tick slam+shout rearmed the slash volume")
	if str(combat.get("_pending_id")) == "slash":
		failures.append("same-tick shout left pending slash live")
	if combat.get("last_move") != &"shout":
		failures.append("same-tick slam+shout must finish on shout")
	if not ring.monitoring:
		failures.append("same-tick shout volume should be active")
	if combat.has_method("lower_weapon"):
		combat.call("lower_weapon")
	combat.set("stamina", combat.get("max_stamina"))
	cid.set("_slam_cd", 0.0)
	cid.set("_leap_cd", 0.0)
	cid.set("_queued_slam", true)
	cid._physics_process(0.016)
	if combat.has_method("_tick_attack"):
		combat.call("_tick_attack", 0.06)
	if not hit.monitoring:
		failures.append("real Cid slash should arm after windup")
	cid.set("_queued_leap", true)
	cid._physics_process(0.016)
	if hit.monitoring:
		failures.append("real Cid leap must disarm slash during leap windup")
	if combat.get("last_move") != &"leap":
		failures.append("real Cid leap must replace slash")
	return failures


func _event_bus() -> Node:
	return root.get_node_or_null("EventBus")


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_combat: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_combat: %s" % failure)
	quit(1)
