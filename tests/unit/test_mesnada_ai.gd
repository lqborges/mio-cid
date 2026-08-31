extends SceneTree
## Headless mesnada follow/wedge test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_mesnada_ai.gd

const AI := preload("res://game/actors/mesnada/mesnada_ai.gd")
const FOLLOWER := preload("res://game/actors/mesnada/mesnada_follower.gd")
const ROSTER := preload("res://game/actors/mesnada/mesnada_roster.gd")


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_tunables_and_cap())
	failures.append_array(_test_wedge_offsets())
	failures.append_array(_test_follow_behind_cid())
	failures.append_array(_test_banner_wedge())
	failures.append_array(_test_lanzas_are_count())
	failures.append_array(_test_lod_levels())
	failures.append_array(_test_orders_and_steer())
	failures.append_array(_test_spawn_named_captains())
	failures.append_array(_test_desertion_hides_captain())
	failures.append_array(_test_loc_spanish())
	failures.append_array(_test_arena_instances())
	_finish(failures)


func _test_tunables_and_cap() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	if ai.skinned_cap() != 24:
		failures.append("skinned_cap want 24 got %s" % ai.skinned_cap())
	if ai.visible_lanza_body_cap() != 8:
		failures.append("visible_lanza_bodies want 8 got %s" % ai.visible_lanza_body_cap())
	if float(ai.tunables.get("lod_distance", 0.0)) != 25.0:
		failures.append("lod_distance must come from follow.json")
	if float(ai.tunables.get("impostor_distance", 0.0)) != 40.0:
		failures.append("impostor_distance must come from follow.json")
	ai.free()
	return failures


func _test_wedge_offsets() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	var tip: Vector3 = ai.wedge_local_offset(0)
	if not tip.is_equal_approx(Vector3.ZERO):
		failures.append("wedge tip must be origin, got %s" % tip)
	var left: Vector3 = ai.wedge_local_offset(1)
	var right: Vector3 = ai.wedge_local_offset(2)
	if not is_equal_approx(left.x, -right.x) or is_equal_approx(left.x, 0.0):
		failures.append("row 1 must be a symmetric pair, got %s / %s" % [left, right])
	if not is_equal_approx(left.z, right.z) or left.z <= 0.0:
		failures.append("row 1 must sit behind the tip")
	var row2: Vector3 = ai.wedge_local_offset(3)
	if row2.z <= left.z:
		failures.append("row 2 must sit behind row 1")
	ai.free()
	return failures


func _test_follow_behind_cid() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	var cid := CharacterBody3D.new()
	cid.position = Vector3(10.0, 0.0, 10.0)
	ai.set_leader(cid)
	ai.set_leader_facing(Vector3(0.0, 0.0, -1.0))
	var slot: Vector3 = ai.world_slot(0)
	if slot.z <= cid.position.z:
		failures.append("follow slot 0 must sit behind Cid facing -Z, got %s" % slot)
	if not is_equal_approx(slot.x, cid.position.x):
		failures.append("follow tip must stay on Cid's X, got %s" % slot)
	var dist := cid.position.distance_to(Vector3(slot.x, cid.position.y, slot.z))
	var want := float(ai.tunables.get("follow_distance", 0.0))
	if not is_equal_approx(dist, want):
		failures.append("follow distance want %s got %s" % [want, dist])
	cid.free()
	ai.free()
	return failures


func _test_banner_wedge() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	ai.plant_banner_at(Vector3(4.0, 0.0, 2.0), Vector3(0.0, 0.0, -1.0))
	if ai.formation != &"wedge":
		failures.append("plant_banner must set wedge formation")
	var tip: Vector3 = ai.world_slot(0)
	if not tip.is_equal_approx(Vector3(4.0, 0.0, 2.0)):
		failures.append("wedge tip must be the banner, got %s" % tip)
	ai.clear_banner()
	if ai.formation != &"follow":
		failures.append("clear_banner must return to follow")
	ai.free()
	return failures


func _test_lanzas_are_count() -> PackedStringArray:
	var failures: PackedStringArray = []
	var roster = ROSTER.from_starting_seed()
	roster.lanzas = 40
	var ai = AI.new()
	ai.spawn_missing_captains = false
	ai.spawn_lanza_bodies = true
	ai.bind_roster(roster)
	root.add_child(ai)
	if ai.lanza_count() != 40:
		failures.append("lanza count must stay 40, got %s" % ai.lanza_count())
	if ai.lanzas.size() != 8:
		failures.append("visible lanza bodies must cap at 8, got %s" % ai.lanzas.size())
	for body in ai.lanzas:
		if body.get("kind") != &"lanza":
			failures.append("lanza body must not be a named captain")
		if String(body.get("member_id")) != "":
			failures.append("lanza bodies must not carry unique ids")
	ai.free()
	return failures


func _test_lod_levels() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	if ai.lod_level(2.0, &"captain", 0) != &"skinned":
		failures.append("near captain under cap must be skinned")
	if ai.lod_level(2.0, &"lanza", 0) != &"capsule":
		failures.append("lanzas are never unique skinned meshes")
	if ai.lod_level(2.0, &"captain", 24) != &"capsule":
		failures.append("25th skinned slot must drop to capsule")
	if ai.lod_level(40.0, &"captain", 0) != &"hidden":
		failures.append("impostor distance must hide extras")
	if ai.lod_level(30.0, &"captain", 0) != &"capsule":
		failures.append("past lod_distance captains become capsules")
	ai.free()
	return failures


func _test_orders_and_steer() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	ai.set_order(&"hold")
	if ai.order != &"hold" or not is_equal_approx(ai.order_speed(), float(ai.tunables.get("walk_speed", 0.0))):
		failures.append("hold must keep walk speed and stop wish")
	ai.set_order(&"charge")
	if not is_equal_approx(ai.order_speed(), float(ai.tunables.get("charge_speed", 0.0))):
		failures.append("charge speed must come from follow.json")
	ai.set_order(&"flee")
	if not is_equal_approx(ai.order_speed(), float(ai.tunables.get("flee_speed", 0.0))):
		failures.append("flee speed must come from follow.json")
	var body: Node = FOLLOWER.new()
	var arrive := float(ai.tunables.get("arrive_distance", 0.0))
	var wish: Vector3 = body.desired_xz(Vector3(5.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), 4.0, arrive, false)
	if wish.x >= 0.0:
		failures.append("steer without nav must point toward the slot")
	var arrived: Vector3 = body.desired_xz(Vector3(0.1, 0.0, 0.0), Vector3.ZERO, 4.0, 0.4, false)
	if not arrived.is_equal_approx(Vector3.ZERO):
		failures.append("inside arrive_distance must stop")
	var away: Vector3 = body.desired_xz(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, 4.0, arrive, true)
	if away.x <= 0.0:
		failures.append("flee reverse must point away from origin")
	body.free()
	ai.free()
	return failures


func _test_spawn_named_captains() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	ai.spawn_missing_captains = true
	ai.spawn_lanza_bodies = false
	ai.bind_roster(ROSTER.from_starting_seed())
	root.add_child(ai)
	if ai.captains.size() != 5:
		failures.append("seed roster must spawn 5 named captains, got %s" % ai.captains.size())
	var ids: Dictionary = {}
	for body in ai.captains:
		ids[String(body.get("member_id"))] = true
		if body.get("kind") != &"captain":
			failures.append("%s is not a captain body" % body.get("member_id"))
		if not (body is CharacterBody3D):
			failures.append("%s must be CharacterBody3D" % body.get("member_id"))
	for expected in ["alvar_fanez", "martin_antolinez", "pero_bermudez", "muno_gustioz", "felez_munoz"]:
		if not ids.has(expected):
			failures.append("missing named captain %s" % expected)
	if ids.has("jaina") or ids.has("arthas") or ids.has("uther"):
		failures.append("do not invent Blizzard names")
	ai.free()
	return failures


func _test_desertion_hides_captain() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	ai.spawn_missing_captains = true
	ai.spawn_lanza_bodies = false
	ai.bind_roster(ROSTER.from_starting_seed())
	root.add_child(ai)
	var martin: Node = null
	for body in ai.captains:
		if body.get("member_id") == &"martin_antolinez":
			martin = body
			break
	if martin == null:
		failures.append("Martín missing from spawned captains")
		ai.free()
		return failures
	var bus := root.get_node_or_null("EventBus")
	if bus != null and bus.has_signal("member_deserted"):
		bus.member_deserted.emit(&"martin_antolinez")
	if not bool(martin.get("gone")):
		ai.handle_desertion(&"martin_antolinez")
	if not bool(martin.get("gone")):
		failures.append("deserted captain must hide, not stay in the wedge")
	if (martin as CollisionObject3D).collision_layer != 0:
		failures.append("deserted captain must leave collision")
	ai.free()
	return failures


func _test_loc_spanish() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ai = AI.new()
	var prompt := str(ai.plant_banner_prompt())
	if prompt != "Plantar pendón":
		failures.append("plant banner loc must be Spanish first, got %s" % prompt)
	var loc: Node = root.get_node_or_null("Loc")
	if loc != null:
		if str(loc.text("mesnada.wedge_form")) != "La mesnada forma la cuña":
			failures.append("wedge loc key must resolve in Spanish")
		if str(loc.text("mesnada.order_charge")) != "¡Cargad!":
			failures.append("charge loc key must resolve in Spanish")
	ai.free()
	return failures


func _test_arena_instances() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/chapters/_dev/arena.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("arena.tscn failed to load")
		return failures
	var arena: Node = (packed as PackedScene).instantiate()
	if arena.get_node_or_null("NavigationRegion3D") == null:
		failures.append("arena missing NavigationRegion3D")
	var mesnada: Node = arena.get_node_or_null("Mesnada")
	if mesnada == null or not mesnada.has_method("plant_banner_at"):
		failures.append("arena missing MesnadaAI")
	else:
		if mesnada.get_node_or_null("Banner") == null:
			failures.append("arena mesnada missing banner")
		if mesnada.get_node_or_null("AlvarFanez") == null:
			failures.append("arena missing Álvar")
		if mesnada.get_node_or_null("MartinAntolinez") == null:
			failures.append("arena missing Martín")
		if mesnada.get_node_or_null("PeroBermudez") == null:
			failures.append("arena missing Pero")
		var named := 0
		for child in mesnada.get_children():
			if child.has_method("bind_ai") and child.get("kind") == &"captain":
				named += 1
				var skinned: MeshInstance3D = child.get_node_or_null("Visual/MeshSkinned")
				if skinned == null:
					failures.append("%s missing skinned capsule" % child.name)
				elif skinned.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					failures.append("%s captain still casts shadows" % child.name)
				if child.get_node_or_null("NavigationAgent3D") == null:
					failures.append("%s missing NavigationAgent3D" % child.name)
				if child is CollisionObject3D and (child as CollisionObject3D).collision_layer != 8:
					failures.append("%s must live on lance_wedge" % child.name)
		if named != 3:
			failures.append("arena must instance a few captains (3), got %s" % named)
	var dummies: Node = arena.get_node_or_null("Dummies")
	if dummies == null or dummies.get_child_count() != 8:
		failures.append("arena must keep 8 dummies")
	if arena.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("arena has GPUParticles3D")
	if arena.find_children("*", "CPUParticles3D", true, false).size() != 0:
		failures.append("arena has CPUParticles3D")
	if arena.find_children("*", "DirectionalLight3D", true, false).size() != 1:
		failures.append("arena must keep exactly 1 DirectionalLight3D")
	if arena.find_children("*", "OmniLight3D", true, false).size() != 0:
		failures.append("arena gained OmniLight3D")
	if arena.find_children("*", "SpotLight3D", true, false).size() != 0:
		failures.append("arena gained SpotLight3D")
	root.add_child(arena)
	var region: Node = arena.get_node_or_null("NavigationRegion3D")
	if region == null or not (region is NavigationRegion3D):
		failures.append("arena nav region missing after enter tree")
	else:
		var nav: NavigationRegion3D = region as NavigationRegion3D
		if nav.navigation_mesh == null or nav.navigation_mesh.get_polygon_count() < 1:
			failures.append("arena nav region must receive a cheap plane mesh")
	var live: Node = arena.get_node_or_null("Mesnada")
	if live != null and live.get("lanzas") != null:
		var bodies: Array = live.lanzas
		if bodies.size() > int(live.visible_lanza_body_cap()):
			failures.append("arena spawned more lanza bodies than the cap")
		for lanza in bodies:
			var mesh: MeshInstance3D = lanza.get_node_or_null("Visual/MeshInstance3D")
			if mesh != null and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				failures.append("lanza fodder still casts shadows")
	arena.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_mesnada_ai: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_mesnada_ai: %s" % failure)
	quit(1)
