extends SceneTree
## Headless a2_yusuf day-1 field battle test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a2_yusuf.gd

const WORLD := "res://content/chapters/a2_yusuf/world.tscn"
const DAY1 := "res://content/chapters/a2_yusuf/day1.tscn"
const DAY2 := "res://content/chapters/a2_yusuf/day2.tscn"
const EMBASSY3 := "res://content/chapters/a2_embassy3/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const FIELD_KEY := "a2_yusuf.field"
const WIN_KEY := "a2_yusuf.win"
const WALL_KEY := "a2_yusuf.wall_refused"
const PLACE_KEY := "a2_yusuf.place_name"
const HORSE_KEY := "a2_jeronimo.horse_name"

var _honor: Variant
var _treasury: Variant
var _clock: Variant
var _runner: Variant
var _loc: Variant
var _bus: Variant
var _world: Node = null
var _fails: PackedStringArray = PackedStringArray()
var _logged: PackedStringArray = PackedStringArray()
var _completed: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_loc = get_root().get_node_or_null(NodePath("Loc"))
	_bus = get_root().get_node_or_null(NodePath("EventBus"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_scene_loads())
	if _world:
		failures.append_array(_check_greybox_lights())
		failures.append_array(_check_horse_named())
		failures.append_array(_check_jimena_on_wall())
		failures.append_array(_check_field_not_climb())
		failures.append_array(_check_host_active())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_spanish_copy())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_thinner_refuse_wedge())
	failures.append_array(_check_win_stays_on_yusuf())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_day2_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if not ResourceLoader.exists(DAY1):
		failures.append("a2_yusuf/day1.tscn must exist")
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_yusuf/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_yusuf world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("FieldZone") == null:
		failures.append("world missing FieldZone")
	if _world.get_node_or_null("ClimbZone") == null:
		failures.append("world missing ClimbZone")
	if _world.get_node_or_null("Host") == null:
		failures.append("world missing Host")
	if _world.get_node_or_null("Host/Yusuf") == null:
		failures.append("world missing Yusuf capsule")
	if _world.get_node_or_null("Jimena") == null:
		failures.append("world missing Jimena spectator")
	if _world.get_node_or_null("Wall") == null:
		failures.append("world missing Wall greybox")
	if _world.get_node_or_null("WallWalk") == null:
		failures.append("world missing WallWalk")
	if _world.get_node_or_null("HuertaPatch") == null:
		failures.append("world missing huerta greybox")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("PlaceName") == null:
		failures.append("world missing PlaceName")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_yusuf HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_yusuf HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_yusuf HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_yusuf":
		failures.append("ChapterRunner.current_id want a2_yusuf got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden during Yusuf day 1")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a2_yusuf must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_yusuf has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a2_yusuf greybox missing huerta/wall CSG")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 2:
		failures.append("a2_yusuf greybox missing orchard CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a2_yusuf sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a2_yusuf has GPUParticles3D")
	return failures


func _check_horse_named() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: Node = _world.get_node_or_null("Horse")
	if horse == null:
		failures.append("Horse missing")
		return failures
	if horse.get_node_or_null("CavalryCharge") == null:
		failures.append("Horse missing CavalryCharge (couch lance)")
	if not horse.is_in_group("horse_companion"):
		failures.append("Horse must be in horse_companion group")
	if not horse.has_method("debug_id") or String(horse.debug_id()) != "babieca":
		failures.append("Valencia horse debug_id want babieca got %s" % (horse.debug_id() if horse.has_method("debug_id") else "missing"))
	if horse is CollisionObject3D and int((horse as CollisionObject3D).collision_layer) != 128:
		failures.append("Horse collision_layer want 128")
	if load(HORSE) == null:
		failures.append("horse.tscn failed to load")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "babieca_named" not in flags:
			failures.append("Yusuf day 1 must keep babieca_named")
	return failures


func _check_jimena_on_wall() -> PackedStringArray:
	var failures: PackedStringArray = []
	var jimena: Node3D = _world.get_node_or_null("Jimena") as Node3D
	if jimena == null:
		failures.append("Jimena missing")
		return failures
	if not jimena.is_in_group("spectator"):
		failures.append("Jimena must be in spectator group")
	if jimena is CollisionObject3D:
		var layer := int((jimena as CollisionObject3D).collision_layer)
		if (layer & 64) == 0:
			failures.append("Jimena collision_layer must include spectator 64, got %s" % layer)
		if (layer & 4) != 0:
			failures.append("Jimena must not sit on killable hurtbox layer 4")
	var hurt: Area3D = jimena.get_node_or_null("HurtBox") as Area3D
	if hurt and hurt.monitorable:
		failures.append("Jimena HurtBox must not be a valid target")
	if _world.has_method("jimena_on_wall") and not bool(_world.jimena_on_wall()):
		failures.append("Jimena must stand on the wall walk")
	var walk: Node3D = _world.get_node_or_null("WallWalk") as Node3D
	if walk and jimena.global_position.y < walk.global_position.y - 0.2:
		failures.append("Jimena y want wall height, got %s vs walk %s" % [jimena.global_position.y, walk.global_position.y])
	var cam: Camera3D = _world.get_node_or_null("Jimena/JimenaCamera") as Camera3D
	if cam == null:
		cam = _world.get_node_or_null("JimenaCamera") as Camera3D
	if cam == null:
		failures.append("Jimena-on-wall camera missing")
	else:
		if cam.current:
			failures.append("JimenaCamera must not steal Cid's camera on spawn")
		if cam.global_position.y < 4.0:
			failures.append("JimenaCamera must sit on the wall, y got %s" % cam.global_position.y)
		if not _world.has_method("look_from_wall") or not bool(_world.look_from_wall()):
			failures.append("look_from_wall must make the wall camera current")
		elif not cam.current:
			failures.append("look_from_wall must set JimenaCamera.current")
		if _world.has_method("return_to_cid_camera"):
			_world.return_to_cid_camera()
	return failures


func _check_field_not_climb() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not _world.has_method("can_storm_wall"):
		failures.append("world missing can_storm_wall")
		return failures
	if bool(_world.can_storm_wall()):
		failures.append("Yusuf day 1 must not be a wall climb")
	_world.try_storm_wall()
	if bool(_world.get("_raid_started")):
		failures.append("try_storm_wall must not start the field battle")
	if bool(_world.get("_won")):
		failures.append("try_storm_wall must not win the day")
	if not bool(_world.get("_wall_refused")):
		failures.append("try_storm_wall must mark the climb refused")
	if bool(_world.can_storm_wall()):
		failures.append("can_storm_wall must stay false after the refuse")
	if _world.has_method("can_leave_to_embassy3") and bool(_world.can_leave_to_embassy3()):
		failures.append("day 1 must not open embassy3")
	return failures


func _check_host_active() -> PackedStringArray:
	var failures: PackedStringArray = []
	var host: Node = _world.get_node_or_null("Host")
	if host == null:
		failures.append("Host missing")
		return failures
	if not bool(host.visible):
		failures.append("Yusuf host must be visible in the huerta")
	for path in ["Host/Yusuf", "Host/Dummy1"]:
		var body: Node = _world.get_node_or_null(path)
		if body == null:
			failures.append("%s missing" % path)
			continue
		if body is CollisionObject3D and int((body as CollisionObject3D).collision_layer) == 0:
			failures.append("%s must be collidable in the field, layer 0" % path)
		var hurt: Area3D = body.get_node_or_null("HurtBox") as Area3D
		if hurt == null:
			failures.append("%s HurtBox missing" % path)
		elif not hurt.monitorable:
			failures.append("%s HurtBox must be monitorable in the field" % path)
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var field: Area3D = _world.get_node_or_null("FieldZone") as Area3D
	var climb: Area3D = _world.get_node_or_null("ClimbZone") as Area3D
	if field == null or climb == null:
		failures.append("FieldZone or ClimbZone missing")
		return failures
	if (field.collision_mask & 130) != 130:
		failures.append("FieldZone must listen for player and horse, mask %s" % field.collision_mask)
	if (climb.collision_mask & 130) != 130:
		failures.append("ClimbZone must listen for player and horse, mask %s" % climb.collision_mask)
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var field := str(_loc.call("text", FIELD_KEY))
	if field == FIELD_KEY or field.is_empty():
		failures.append("Loc did not resolve a2_yusuf.field")
	var field_l := field.to_lower()
	if not field_l.contains("huerta") and not field_l.contains("campo"):
		failures.append("field copy must name the huerta/campo, got %s" % field)
	if not field_l.contains("yusuf"):
		failures.append("field copy must name Yusuf, got %s" % field)
	var win := str(_loc.call("text", WIN_KEY))
	if win == WIN_KEY or win.is_empty():
		failures.append("Loc did not resolve a2_yusuf.win")
	if not win.to_lower().contains("jimena"):
		failures.append("win copy must name Jimena, got %s" % win)
	var wall := str(_loc.call("text", WALL_KEY))
	if wall == WALL_KEY or wall.is_empty():
		failures.append("Loc did not resolve a2_yusuf.wall_refused")
	var wall_l := wall.to_lower()
	if not wall_l.contains("álvar") and not wall_l.contains("alvar"):
		failures.append("wall refuse must name Álvar, got %s" % wall)
	if not wall_l.contains("huerta") and not wall_l.contains("escala"):
		failures.append("wall refuse Spanish missing huerta/escala, got %s" % wall)
	var place := str(_loc.call("text", PLACE_KEY))
	if place == PLACE_KEY or not place.to_lower().contains("valencia"):
		failures.append("place name must be Valencia huerta, got %s" % place)
	var horse := str(_loc.call("text", HORSE_KEY))
	if horse.to_lower().find("babieca") < 0:
		failures.append("horse loc want Babieca got %s" % horse)
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_raid_started")):
		failures.append("field battle started on spawn physics frames")
	if bool(_world.get("_won")):
		failures.append("day 1 resolved on spawn physics frames")
	if bool(_world.get("_held")):
		failures.append("day 1 held on spawn physics frames")
	if "yusuf_win" in _logged:
		failures.append("yusuf_win applied on spawn")
	return failures


func _check_thinner_refuse_wedge() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _honor:
		_honor.roster = MesnadaRoster.from_starting_seed()
		_honor.roster.lanzas = 6
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("thinner wedge: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	var mesnada: Node = world.get_node_or_null("Mesnada")
	if mesnada == null:
		failures.append("thinner wedge: Mesnada missing")
		world.free()
		return failures
	var bodies: Variant = mesnada.get("lanzas")
	var n := 0
	if bodies is Array:
		n = (bodies as Array).size()
	if n != 6:
		failures.append("refuse lanzas want 6 bodies, got %s" % n)
	world.free()
	return failures


func _check_win_stays_on_yusuf() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("win: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	var honor_before := 0.0
	if _honor:
		honor_before = float(_honor.state.honor)
	if bool(world.can_storm_wall()):
		failures.append("win path must not become a wall climb")
	world.run_field()
	if current_scene != scene_before:
		failures.append("day 1 win must not change_scene when current_scene != world")
	if "yusuf_win" not in _logged:
		failures.append("win must apply yusuf_win from JSON, logged %s" % str(_logged))
	if not bool(world.get("_won")):
		failures.append("run_field must win day 1")
	if not bool(world.get("_held")):
		failures.append("win must hold on a2_yusuf for day 2")
	if _honor:
		var event: HonorEvent = _honor.event_by_id(&"yusuf_win")
		var want := honor_before
		if event:
			want += event.delta_for(&"honor")
		if not is_equal_approx(float(_honor.state.honor), want):
			failures.append("yusuf_win honor want %s got %s" % [want, _honor.state.honor])
	if _completed.count("a2_yusuf") > 0:
		failures.append("day 1 must not complete the beat (day 2 later), got %s" % str(_completed))
	if _runner:
		if String(_runner.current_id) != "a2_yusuf":
			failures.append("day 1 travel must stay on a2_yusuf, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "yusuf_day1_done" not in flags:
			failures.append("win must set yusuf_day1_done, flags %s" % str(flags))
		if world.has_method("travel_to_embassy3") and bool(world.travel_to_embassy3()):
			failures.append("travel_to_embassy3 must stay closed on day 1")
		if String(_runner.current_id) == "a2_embassy3":
			failures.append("day 1 must not land on embassy3")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "babieca_named"])
	if not bool(_runner.can_travel(&"a2_embassy2", &"a2_yusuf", flags)):
		failures.append("embassy2 -> yusuf must stay open")
	if not bool(_runner.can_travel(&"a2_yusuf", &"a2_embassy3", flags)):
		failures.append("yusuf -> embassy3 must stay in the graph for day 2")
	if bool(_runner.can_travel(&"a2_jeronimo", &"a2_yusuf", flags)):
		failures.append("hub must not skip embassy2 into Yusuf")
	if bool(_runner.can_travel(&"a2_yusuf", &"a2_tagus", flags)):
		failures.append("yusuf must not skip embassy3 into Tagus")
	return failures


func _check_day2_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if ResourceLoader.exists(DAY2):
		failures.append("a2_yusuf/day2.tscn must not ship in this PR")
	if ResourceLoader.exists(EMBASSY3):
		failures.append("a2_embassy3 must not ship in this PR")
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _prep_campaign() -> void:
	if _honor:
		if _honor.has_method("reset_state"):
			_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(&"a2_yusuf", PackedStringArray(["hub_lock_cardena", "horse_companion", "babieca_named"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion", "babieca_named"])
			if "current_id" in _runner:
				_runner.current_id = &"a2_yusuf"
	if _bus:
		if _bus.has_signal("hard_fail") and not _bus.hard_fail.is_connected(_on_hard_fail):
			_bus.hard_fail.connect(_on_hard_fail)
		if _bus.has_signal("honor_logged") and not _bus.honor_logged.is_connected(_on_honor_logged):
			_bus.honor_logged.connect(_on_honor_logged)
		if _bus.has_signal("beat_completed") and not _bus.beat_completed.is_connected(_on_beat_completed):
			_bus.beat_completed.connect(_on_beat_completed)
	_fails.clear()
	_logged.clear()
	_completed.clear()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a2_yusuf: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a2_yusuf: %s" % failure)
	quit(1)
