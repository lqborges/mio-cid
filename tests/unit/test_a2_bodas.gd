extends SceneTree
## Headless Valencia marriages / Infantes (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a2_bodas.gd

const WORLD := "res://content/chapters/a2_bodas/world.tscn"
const TAGUS := "res://content/chapters/a2_tagus/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const PLACE_KEY := "a2_bodas.place_name"
const HORSE_KEY := "a2_bodas.horse_name"
const ROOM_NAMES := [
	"Hall",
	"Forge",
	"LionCage",
	"Bishopric",
	"WallWalk",
	"Solar",
	"Treasury",
]

var _honor: Variant
var _treasury: Variant
var _clock: Variant
var _runner: Variant
var _loc: Variant
var _bus: Variant
var _state: Variant
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
	_state = get_root().get_node_or_null(NodePath("GameState"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_scene_loads())
	if _world:
		failures.append_array(_check_greybox_lights())
		failures.append_array(_check_rooms())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_cage_closed())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(await _check_infantes_join_and_train())
	failures.append_array(_check_leon_gated())
	failures.append_array(_check_graph_spine())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_bodas/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_bodas world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("FerranGonzalez") == null:
		failures.append("world missing FerranGonzalez")
	if _world.get_node_or_null("DiegoGonzalez") == null:
		failures.append("world missing DiegoGonzalez")
	if _world.get_node_or_null("Elvira") == null:
		failures.append("world missing Elvira")
	if _world.get_node_or_null("Sol") == null:
		failures.append("world missing Sol")
	if _world.get_node_or_null("TrainZone") == null:
		failures.append("world missing TrainZone")
	if _world.get_node_or_null("GiftZone") == null:
		failures.append("world missing GiftZone")
	if _world.get_node_or_null("CageZone") == null:
		failures.append("world missing CageZone")
	if _world.get_node_or_null("LeonExit") == null:
		failures.append("world missing LeonExit")
	if _world.find_child("ChoiceUI", true, false) != null:
		failures.append("ChoiceUI must not ship at the bodas")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_bodas HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_bodas HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_bodas HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_bodas":
		failures.append("ChapterRunner.current_id want a2_bodas got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a2_bodas must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_bodas has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 12:
		failures.append("a2_bodas greybox missing hub CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a2_bodas sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a2_bodas has GPUParticles3D")
	return failures


func _check_rooms() -> PackedStringArray:
	var failures: PackedStringArray = []
	for room in ROOM_NAMES:
		if _world.get_node_or_null(room) == null:
			failures.append("hub missing room %s" % room)
	if _world.get_node_or_null("LionCage/CageGate") == null:
		failures.append("LionCage missing CageGate")
	if _world.get_node_or_null("LionProp") == null:
		failures.append("hub missing LionProp")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var arrive := str(_loc.call("text", "a2_bodas.arrive"))
	if arrive == "a2_bodas.arrive" or arrive.is_empty():
		failures.append("Loc did not resolve a2_bodas.arrive")
	if not arrive.to_lower().contains("infantes"):
		failures.append("arrive line Spanish missing infantes, got %s" % arrive)
	var train := str(_loc.call("text", "a2_bodas.train"))
	if not train.to_lower().contains("entrenad"):
		failures.append("train line Spanish missing entrenad, got %s" % train)
	var place := str(_loc.call("text", PLACE_KEY))
	if place != "Valencia":
		failures.append("place name must be Spanish first, got %s" % place)
	var horse_name := str(_loc.call("text", HORSE_KEY))
	if horse_name != "Babieca":
		failures.append("horse name loc want Babieca got %s" % horse_name)
	if _world.has_method("place_name_text") and str(_world.place_name_text()) != "Valencia":
		failures.append("PlaceName want Valencia got %s" % _world.place_name_text())
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	for path in ["TrainZone", "GiftZone", "CageZone", "LeonExit"]:
		var zone: Area3D = _world.get_node_or_null(path) as Area3D
		if zone == null:
			failures.append("%s missing" % path)
			continue
		if (zone.collision_mask & 130) != 130:
			failures.append("%s must listen for player and horse, mask %s" % [path, zone.collision_mask])
	return failures


func _check_cage_closed() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _world.has_method("is_cage_closed") and not bool(_world.call("is_cage_closed")):
		failures.append("lion cage must stay locked at the bodas")
	if _world.has_method("is_lion_escaped") and bool(_world.call("is_lion_escaped")):
		failures.append("lion must not escape in a2_bodas")
	if _world.has_method("try_open_cage") and bool(_world.call("try_open_cage")):
		failures.append("cage must not open")
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_trained")):
		failures.append("training completed on spawn physics frames")
	if bool(_world.get("_gifted")):
		failures.append("gifts completed on spawn physics frames")
	if bool(_world.get("_left")):
		failures.append("hub left on spawn physics frames")
	return failures


func _check_infantes_join_and_train() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _treasury:
		_treasury.state.marks = 200
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("train: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	if not bool(world.get("_joined")):
		failures.append("Infantes must join the roster on arrival")
	var roster: Variant = null
	if _honor:
		roster = _honor.roster
	if roster == null or not roster.has_method("member"):
		failures.append("roster missing after join")
		world.free()
		return failures
	var ferran: Variant = roster.member(&"ferran_gonzalez")
	var diego: Variant = roster.member(&"diego_gonzalez")
	if ferran == null:
		failures.append("ferran_gonzalez missing from roster")
	if diego == null:
		failures.append("diego_gonzalez missing from roster")
	if ferran:
		if not is_equal_approx(float(ferran.combat), 22.0):
			failures.append("ferran combat want 22 got %s" % ferran.combat)
		if not is_equal_approx(float(ferran.birth), 92.0):
			failures.append("ferran birth want 92 got %s" % ferran.birth)
		if not is_equal_approx(float(ferran.mesura_max), 0.0):
			failures.append("ferran mesura_max want 0 got %s" % ferran.mesura_max)
	if diego:
		if not is_equal_approx(float(diego.combat), 20.0):
			failures.append("diego combat want 20 got %s" % diego.combat)
		if not is_equal_approx(float(diego.birth), 92.0):
			failures.append("diego birth want 92 got %s" % diego.birth)
		if not is_equal_approx(float(diego.mesura_max), 0.0):
			failures.append("diego mesura_max want 0 got %s" % diego.mesura_max)
	if world.has_method("run_train"):
		await world.run_train()
	if ferran and float(ferran.combat) > 22.0:
		failures.append("train must not raise ferran above cap, got %s" % ferran.combat)
	if diego and float(diego.combat) > 22.0:
		failures.append("train must not raise diego above cap, got %s" % diego.combat)
	if ferran and not is_equal_approx(float(ferran.mesura_max), 0.0):
		failures.append("train must not give ferran mesura")
	if world.has_method("run_gift"):
		await world.run_gift()
	if _treasury and int(_treasury.state.marks) != 160:
		failures.append("gift marks want 160 (200-40) got %s" % _treasury.state.marks)
	world.free()
	return failures


func _check_leon_gated() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("leon: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	var scene_before: Node = current_scene
	if ResourceLoader.exists(LEON):
		failures.append("a3_leon must not ship in this PR")
	if world.has_method("can_leave_to_leon") and bool(world.call("can_leave_to_leon")):
		failures.append("leon exit must stay closed while a3_leon is missing")
	if world.has_method("travel_to_leon") and bool(world.call("travel_to_leon")):
		failures.append("travel_to_leon must no-op when dest is missing")
	if current_scene != scene_before:
		failures.append("missing leon must not change_scene")
	if not ResourceLoader.exists(TAGUS):
		failures.append("a2_tagus must ship with bodas")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["embassy3_done", "pardon", "marriages_accepted"])
	if not bool(_runner.can_travel(&"a2_tagus", &"a2_bodas", flags)):
		failures.append("tagus -> bodas must stay open")
	if not bool(_runner.can_travel(&"a2_bodas", &"a3_leon", flags)):
		failures.append("bodas -> leon graph edge must exist")
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
	if _state and _state.has_method("reset_swords"):
		_state.reset_swords()
	var flags := PackedStringArray([
		"hub_lock_cardena",
		"horse_companion",
		"colada_acquired",
		"valencia_held",
		"embassy3_done",
		"pardon",
		"marriages_accepted",
		"tagus_done",
	])
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(&"a2_bodas", flags)
		else:
			if "flags" in _runner:
				_runner.flags = flags
			if "current_id" in _runner:
				_runner.current_id = &"a2_bodas"
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
		print("test_a2_bodas: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a2_bodas: %s" % failure)
	quit(1)
