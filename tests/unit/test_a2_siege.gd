extends SceneTree
## Headless a2_murviedro / a2_siege calendar test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a2_siege.gd

const MURV_WORLD := "res://content/chapters/a2_murviedro/world.tscn"
const SIEGE_WORLD := "res://content/chapters/a2_siege/world.tscn"
const JERONIMO := "res://content/chapters/a2_jeronimo/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const STORM_KEY := "a2_siege.storm_refused"
const TAKE_KEY := "a2_murviedro.take_done"
const PLACE_KEY := "a2_siege.place_name"

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
	failures.append_array(_check_siege_scene_loads())
	if _world:
		failures.append_array(_check_greybox_lights())
		failures.append_array(_check_horse_unnamed())
		failures.append_array(_check_host_inactive_not_hittable())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_storm_disabled())
		failures.append_array(_check_same_campaign_clock())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_thinner_refuse_wedge())
	failures.append_array(_check_murviedro_take_travels_to_siege())
	failures.append_array(_check_calendar_eight_events_then_jeronimo())
	failures.append_array(_check_graph_spine())
	_finish(failures)


func _check_siege_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign(&"a2_siege")
	var packed: Resource = load(SIEGE_WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_siege/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_siege world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("StormZone") == null:
		failures.append("world missing StormZone")
	if _world.get_node_or_null("RestZone") == null:
		failures.append("world missing RestZone")
	if _world.get_node_or_null("Host") == null:
		failures.append("world missing Host")
	if _world.get_node_or_null("WallWest") == null:
		failures.append("world missing wall greybox")
	if _world.get_node_or_null("MarketStall") == null:
		failures.append("world missing empty market")
	if _world.get_node_or_null("ExtraA") == null:
		failures.append("world missing thin extras")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("PlaceName") == null:
		failures.append("world missing PlaceName")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_siege HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_siege HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_siege HUD")
	if _world.find_child("StormPrompt", true, false) == null:
		failures.append("storm prompt missing from a2_siege HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_siege":
		failures.append("ChapterRunner.current_id want a2_siege got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden during the siege")
	if not ResourceLoader.exists(JERONIMO):
		failures.append("a2_jeronimo world must exist after the siege")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a2_siege must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_siege has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a2_siege greybox missing wall CSG")
	var extras_csg := _world.find_children("*", "CSGCylinder3D", true, false)
	if extras_csg.size() < 2:
		failures.append("a2_siege greybox missing thin extras")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a2_siege sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a2_siege has GPUParticles3D")
	return failures


func _check_horse_unnamed() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: Node = _world.get_node_or_null("Horse")
	if horse == null:
		failures.append("Horse missing")
		return failures
	if horse.get_node_or_null("CavalryCharge") == null:
		failures.append("Horse missing CavalryCharge (couch lance)")
	if not horse.is_in_group("horse_companion"):
		failures.append("Horse must be in horse_companion group")
	if horse.has_method("debug_id") and String(horse.debug_id()) == "babieca":
		failures.append("horse must stay unnamed until the Valencia hub")
	if load(HORSE) == null:
		failures.append("horse.tscn failed to load")
	return failures


func _check_host_inactive_not_hittable() -> PackedStringArray:
	var failures: PackedStringArray = []
	var host: Node = _world.get_node_or_null("Host")
	if host == null:
		failures.append("Host missing")
		return failures
	if bool(host.visible):
		failures.append("Host must stay hidden until a sally")
	for path in ["Host/Dummy1", "Host/Dummy2"]:
		var body: Node = _world.get_node_or_null(path)
		if body == null:
			failures.append("%s missing while Host is down" % path)
			continue
		if body is CollisionObject3D and int((body as CollisionObject3D).collision_layer) != 0:
			failures.append("%s collision_layer must be 0 before sally, got %s" % [path, (body as CollisionObject3D).collision_layer])
		var hurt: Area3D = body.get_node_or_null("HurtBox") as Area3D
		if hurt == null:
			failures.append("%s HurtBox missing" % path)
		elif hurt.monitorable:
			failures.append("%s HurtBox must not be monitorable before sally" % path)
		elif hurt.collision_layer != 0:
			failures.append("%s HurtBox collision_layer must be 0 before sally" % path)
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var storm: Area3D = _world.get_node_or_null("StormZone") as Area3D
	var rest: Area3D = _world.get_node_or_null("RestZone") as Area3D
	if storm == null or rest == null:
		failures.append("StormZone or RestZone missing")
		return failures
	if (storm.collision_mask & 130) != 130:
		failures.append("StormZone must listen for player and horse, mask %s" % storm.collision_mask)
	if (rest.collision_mask & 130) != 130:
		failures.append("RestZone must listen for player and horse, mask %s" % rest.collision_mask)
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var storm := str(_loc.call("text", STORM_KEY))
	if storm == STORM_KEY or storm.is_empty():
		failures.append("Loc did not resolve a2_siege.storm_refused")
	var storm_l := storm.to_lower()
	if not storm_l.contains("álvar") and not storm_l.contains("alvar"):
		failures.append("storm refusal must name Álvar, got %s" % storm)
	if not storm_l.contains("hambre"):
		failures.append("storm refusal Spanish missing hambre, got %s" % storm)
	var take := str(_loc.call("text", TAKE_KEY))
	if take == TAKE_KEY or take.is_empty():
		failures.append("Loc did not resolve a2_murviedro.take_done")
	if not take.to_lower().contains("murviedro"):
		failures.append("take copy must name Murviedro, got %s" % take)
	var place := str(_loc.call("text", PLACE_KEY))
	if place == PLACE_KEY or not place.to_lower().contains("valencia"):
		failures.append("place name must be Valencia, got %s" % place)
	return failures


func _check_storm_disabled() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not _world.has_method("can_storm_wall"):
		failures.append("world missing can_storm_wall")
		return failures
	if bool(_world.can_storm_wall()):
		failures.append("wall-storm must stay disabled")
	var prompt: Node = _world.find_child("StormPrompt", true, false)
	if prompt and bool(prompt.visible):
		failures.append("StormPrompt must stay hidden until offered")
	_world.try_storm_wall()
	if bool(_world.get("_sally_open")):
		failures.append("try_storm_wall must not start a sally")
	if bool(_world.get("_left")):
		failures.append("try_storm_wall must not finish the siege")
	if prompt and not bool(prompt.visible):
		failures.append("try_storm_wall must show the refuse prompt")
	if not bool(_world.get("_storm_refused")):
		failures.append("try_storm_wall must mark the storm refused")
	if bool(_world.can_storm_wall()):
		failures.append("can_storm_wall must stay false after the prompt")
	return failures


func _check_same_campaign_clock() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _clock == null:
		failures.append("CampaignClock missing")
		return failures
	var world_clock: Variant = _world.clock() if _world.has_method("clock") else null
	if world_clock != _clock:
		failures.append("siege must use the CampaignClock autoload, not a second clock")
	if str(_clock.segment_id()) != "siege":
		failures.append("clock segment want siege got %s" % _clock.segment_id())
	if bool(_clock.feeds_tonight()):
		failures.append("SIEGE must not feed tonight")
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if PackedStringArray(_world.events_fired()).size() != 0:
		failures.append("siege events must not fire on spawn")
	if bool(_world.get("_sally_open")):
		failures.append("sally started on spawn physics frames")
	if bool(_world.get("_left")):
		failures.append("siege resolved on spawn physics frames")
	var host: Node = _world.get_node_or_null("Host")
	if host and bool(host.visible):
		failures.append("Host must stay hidden on spawn")
	return failures


func _check_thinner_refuse_wedge() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign(&"a2_siege")
	if _honor:
		_honor.roster = MesnadaRoster.from_starting_seed()
		_honor.roster.lanzas = 6
	if _clock:
		_clock.unfed_streak = 2
	var packed: Resource = load(SIEGE_WORLD)
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


func _check_murviedro_take_travels_to_siege() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign(&"a2_murviedro")
	var packed: Resource = load(MURV_WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("murviedro: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	var murv_lights := world.find_children("*", "DirectionalLight3D", true, false)
	if murv_lights.size() != 1:
		failures.append("a2_murviedro must have exactly 1 DirectionalLight3D, has %d" % murv_lights.size())
	if world.get_node_or_null("Sea") == null:
		failures.append("a2_murviedro missing coastal Sea CSG")
	if bool(world.can_storm_wall()):
		failures.append("Murviedro take must not be a wall climb")
	world.run_roads()
	if not bool(world.get("_roads_cut")):
		failures.append("run_roads must cut the roads")
	if bool(world.get("_taken")):
		failures.append("roads must not skip the field take")
	if "murviedro_take" in _logged:
		failures.append("roads must not apply murviedro_take")
	_logged.clear()
	world.run_take()
	if current_scene != scene_before:
		failures.append("take must not change_scene when current_scene != world")
	if "murviedro_take" not in _logged:
		failures.append("take must apply murviedro_take, logged %s" % str(_logged))
	if not bool(world.get("_taken")):
		failures.append("run_take must take Murviedro")
	if _completed.count("a2_murviedro") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _runner and String(_runner.current_id) != "a2_siege":
		failures.append("Murviedro travel must land on a2_siege, got %s" % _runner.current_id)
	if not ResourceLoader.exists(JERONIMO):
		failures.append("a2_jeronimo world must exist after Murviedro")
	world.free()
	return failures


func _check_calendar_eight_events_then_jeronimo() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign(&"a2_siege")
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	var packed: Resource = load(SIEGE_WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("calendar: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	var clock_before: Variant = _clock
	var days_before := 0
	var marks_before := 0
	var unfed_before := 0
	if _clock:
		days_before = int(_clock.days_elapsed)
		unfed_before = int(_clock.unfed_streak)
	if _treasury:
		marks_before = int(_treasury.state.marks)
	if str(_clock.segment_id()) != "siege":
		failures.append("entering a2_siege must set CampaignClock segment siege")
	world.try_storm_wall()
	if bool(world.can_storm_wall()):
		failures.append("storm remains disabled during the calendar")
	world.run_calendar()
	if world.clock() != clock_before:
		failures.append("run_calendar must keep the same CampaignClock instance")
	if str(_clock.segment_id()) != "siege":
		failures.append("calendar must stay on CampaignClock.siege")
	if bool(_clock.feeds_tonight()):
		failures.append("SIEGE calendar must not feed")
	if int(_clock.unfed_streak) != unfed_before:
		failures.append("rest-skip must not increment unfed_streak")
	if _treasury and int(_treasury.state.marks) != marks_before:
		failures.append("SIEGE rest-skip must not spend marks")
	if int(_clock.days_elapsed) <= days_before:
		failures.append("rest-skip must advance CampaignClock.days_elapsed")
	var fired: PackedStringArray = world.events_fired()
	var cal: SiegeCalendar = world.get("calendar")
	var want := 8
	if cal:
		want = cal.event_count()
	if fired.size() != want:
		failures.append("calendar must fire %s events, got %s %s" % [want, fired.size(), str(fired)])
	if "valencia_held" not in _logged:
		failures.append("last event must honor-tick valencia_held, logged %s" % str(_logged))
	if not _fails.is_empty():
		failures.append("siege must not hard_fail: %s" % ", ".join(_fails))
	if current_scene != scene_before:
		failures.append("calendar must not change_scene when current_scene != world")
	if _completed.count("a2_siege") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _runner and String(_runner.current_id) != "a2_jeronimo":
		failures.append("siege travel must land on a2_jeronimo, got %s" % _runner.current_id)
	if not ResourceLoader.exists(JERONIMO):
		failures.append("a2_jeronimo world must exist after the calendar")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired"])
	if not bool(_runner.can_travel(&"a1_tevar", &"a2_murviedro", flags)):
		failures.append("tevar -> murviedro must stay open")
	if not bool(_runner.can_travel(&"a2_murviedro", &"a2_siege", flags)):
		failures.append("murviedro -> siege must stay open")
	if not bool(_runner.can_travel(&"a2_siege", &"a2_jeronimo", flags)):
		failures.append("siege -> jeronimo must stay open")
	if bool(_runner.can_travel(&"a1_tevar", &"a2_siege", flags)):
		failures.append("tevar must not skip Murviedro")
	if bool(_runner.can_travel(&"a2_murviedro", &"a2_jeronimo", flags)):
		failures.append("murviedro must not skip the siege")
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _prep_campaign(beat_id: StringName) -> void:
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
			_runner.restore(beat_id, PackedStringArray(["hub_lock_cardena", "horse_companion"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion"])
			if "current_id" in _runner:
				_runner.current_id = beat_id
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
		print("test_a2_siege: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a2_siege: %s" % failure)
	quit(1)
