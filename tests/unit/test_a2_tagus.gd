extends SceneTree
## Headless Tagus three-day court (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a2_tagus.gd

const WORLD := "res://content/chapters/a2_tagus/world.tscn"
const BODAS := "res://content/chapters/a2_bodas/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const EMBASSY3 := "res://content/chapters/a2_embassy3/world.tscn"
const REPAY := "res://content/chapters/a2_repay_raquel/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const PLACE_KEY := "a2_tagus.place_name"
const PARDON_KEY := "a2_tagus.pardon"
const YES_KEY := "a2_tagus.yes"

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
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(await _check_pardon_then_forced_yes())
	failures.append_array(await _check_refuse_cannot_break())
	failures.append_array(_check_graph_and_join())
	failures.append_array(_check_later_beats())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_tagus/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_tagus world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("Alfonso") == null:
		failures.append("world missing Alfonso")
	if _world.get_node_or_null("FerranGonzalez") == null:
		failures.append("world missing FerranGonzalez")
	if _world.get_node_or_null("DiegoGonzalez") == null:
		failures.append("world missing DiegoGonzalez")
	if _world.get_node_or_null("Pavilion") == null:
		failures.append("world missing Pavilion")
	if _world.get_node_or_null("CourtZone") == null:
		failures.append("world missing CourtZone")
	if _world.get_node_or_null("RestZone") == null:
		failures.append("world missing RestZone")
	if _world.get_node_or_null("BodasExit") == null:
		failures.append("world missing BodasExit")
	if _world.find_child("ChoiceUI", true, false) != null:
		failures.append("forced yes; ChoiceUI must not ship")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_tagus HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_tagus HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_tagus HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_tagus":
		failures.append("ChapterRunner.current_id want a2_tagus got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden at Tagus")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a2_tagus must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_tagus has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a2_tagus greybox missing court CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a2_tagus sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a2_tagus has GPUParticles3D")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var pardon := str(_loc.call("text", PARDON_KEY))
	if pardon == PARDON_KEY or pardon.is_empty():
		failures.append("Loc did not resolve a2_tagus.pardon")
	if not pardon.to_lower().contains("perdono"):
		failures.append("pardon line Spanish missing perdono, got %s" % pardon)
	var yes := str(_loc.call("text", YES_KEY))
	if yes == YES_KEY or yes.is_empty():
		failures.append("Loc did not resolve a2_tagus.yes")
	var yes_low := yes.to_lower()
	if not yes_low.contains("rey"):
		failures.append("yes line must name the king, got %s" % yes)
	var ask := str(_loc.call("text", "a2_tagus.ask"))
	if not ask.contains("Elvira") or not ask.contains("Sol"):
		failures.append("ask line must name Elvira and Sol, got %s" % ask)
	var place := str(_loc.call("text", PLACE_KEY))
	if place != "Tajo":
		failures.append("place name must be Spanish first, got %s" % place)
	if _world.has_method("place_name_text") and str(_world.place_name_text()) != "Tajo":
		failures.append("PlaceName want Tajo got %s" % _world.place_name_text())
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	for path in ["CourtZone", "RestZone", "BodasExit"]:
		var zone: Area3D = _world.get_node_or_null(path) as Area3D
		if zone == null:
			failures.append("%s missing" % path)
			continue
		if (zone.collision_mask & 130) != 130:
			failures.append("%s must listen for player and horse, mask %s" % [path, zone.collision_mask])
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_pardoned")):
		failures.append("pardon completed on spawn physics frames")
	if bool(_world.get("_accepted")):
		failures.append("marriages accepted on spawn physics frames")
	if bool(_world.get("_left")):
		failures.append("court left on spawn physics frames")
	if int(_world.get("court_day")) != 1:
		failures.append("court must start on day 1, got %s" % _world.get("court_day"))
	return failures


func _check_pardon_then_forced_yes() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("pardon: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	var honor_before := 15.0
	var honra_before := 40.0
	if _honor and _honor.state:
		honor_before = float(_honor.state.honor)
		honra_before = float(_honor.state.honra)
	var days_before := 0
	if _clock:
		days_before = int(_clock.days_elapsed)
	if world.has_method("travel_to_bodas") and bool(world.call("travel_to_bodas")):
		failures.append("bodas exit must wait for the forced yes")
	if not world.has_method("run_pardon"):
		failures.append("world missing run_pardon")
		world.free()
		return failures
	await world.run_pardon()
	if not bool(world.get("_pardoned")):
		failures.append("run_pardon must grant the pardon")
	if "pardon" not in _logged:
		failures.append("pardon must apply honor event, logged %s" % str(_logged))
	if _honor and _honor.state:
		var want_honor := honor_before + 30.0
		if not is_equal_approx(float(_honor.state.honor), want_honor):
			failures.append("pardon honor want %s got %s" % [want_honor, _honor.state.honor])
	if int(world.get("court_day")) < 2:
		failures.append("pardon must open day 2, court_day %s" % world.get("court_day"))
	if world.has_method("accept_marriages") and bool(world.call("accept_marriages")):
		failures.append("ask must wait for the three-day court")
	if world.has_method("run_day2"):
		await world.run_day2()
	if int(world.get("court_day")) < 3:
		failures.append("day 2 rest must open day 3, court_day %s" % world.get("court_day"))
	if world.has_method("run_ask"):
		await world.run_ask()
	if not bool(world.get("_accepted")):
		failures.append("run_ask must force yes")
	if "accept_marriages" not in _logged:
		failures.append("forced yes must apply accept_marriages, logged %s" % str(_logged))
	if _honor and _honor.state:
		var want_honor2 := honor_before + 30.0 + 5.0
		var want_honra := honra_before - 4.0
		if not is_equal_approx(float(_honor.state.honor), want_honor2):
			failures.append("accept_marriages honor want %s got %s" % [want_honor2, _honor.state.honor])
		if not is_equal_approx(float(_honor.state.honra), want_honra):
			failures.append("accept_marriages honra want %s got %s" % [want_honra, _honor.state.honra])
	if not _fails.is_empty():
		failures.append("court must not hard_fail: %s" % ", ".join(_fails))
	if _clock:
		if int(_clock.days_elapsed) < days_before + 2:
			failures.append("three-day court must advance calendar, days %s" % _clock.days_elapsed)
		if int(_clock.unfed_streak) != 0:
			failures.append("court days must not feed, unfed_streak %s" % _clock.unfed_streak)
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "pardon" not in flags:
			failures.append("pardon must set pardon flag")
		if "marriages_accepted" not in flags:
			failures.append("forced yes must set marriages_accepted")
	if not bool(world.call("can_leave_to_bodas")):
		failures.append("after yes BodasExit should open")
	if not bool(world.call("travel_to_bodas")):
		failures.append("travel_to_bodas must succeed after yes")
	if _runner and String(_runner.current_id) != "a2_bodas":
		failures.append("court exit must land on a2_bodas, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("goto must no-op unless current_scene is the court")
	if not ResourceLoader.exists(BODAS):
		failures.append("a2_bodas must ship with Tagus")
	world.free()
	return failures


func _check_refuse_cannot_break() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("refuse: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	if world.has_method("run_pardon"):
		await world.run_pardon()
	if world.has_method("refuse_marriages") and bool(world.call("refuse_marriages")):
		failures.append("v1 cannot refuse the marriages")
	if bool(world.get("_accepted")):
		failures.append("refuse must not accept the marriages")
	if "accept_marriages" in _logged:
		failures.append("refuse must not apply accept_marriages")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "pardon" not in flags:
			failures.append("refuse must not strip the pardon")
		if "marriages_accepted" in flags:
			failures.append("refuse must not set marriages_accepted")
	world.free()
	return failures


func _check_graph_and_join() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var honest := PackedStringArray(["embassy3_done"])
	if not bool(_runner.can_travel(&"a2_embassy3", &"a2_tagus", honest)):
		failures.append("honest embassy3_done must open Tagus")
	if bool(_runner.can_travel(&"a2_embassy3", &"a2_repay_raquel", honest)):
		failures.append("honest path must not open repay")
	var cheated := PackedStringArray(["arcas_cheated", "embassy3_done"])
	if bool(_runner.can_travel(&"a2_embassy3", &"a2_tagus", cheated)):
		failures.append("cheated save must not open Tagus without repay_done")
	if not bool(_runner.can_travel(&"a2_embassy3", &"a2_repay_raquel", cheated)):
		failures.append("cheated embassy3_done must open repay")
	var repaid := PackedStringArray(["arcas_cheated", "embassy3_done", "repay_done"])
	if not bool(_runner.can_travel(&"a2_repay_raquel", &"a2_tagus", repaid)):
		failures.append("repay_done must open Tagus")
	if bool(_runner.can_travel(&"a2_yusuf", &"a2_tagus", honest)):
		failures.append("yusuf must not skip embassy3 into Tagus")
	return failures


func _check_later_beats() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ResourceLoader.exists(EMBASSY3):
		failures.append("a2_embassy3 must remain shipped")
	if not ResourceLoader.exists(REPAY):
		failures.append("a2_repay_raquel must remain shipped")
	if not ResourceLoader.exists(BODAS):
		failures.append("a2_bodas must ship")
	if not ResourceLoader.exists(LEON):
		failures.append("a3_leon must ship")
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _prep_campaign() -> void:
	_prep_campaign_at(
		&"a2_tagus",
		PackedStringArray([
			"hub_lock_cardena",
			"horse_companion",
			"colada_acquired",
			"valencia_held",
			"embassy3_done",
		])
	)


func _prep_campaign_at(beat_id: StringName, flags: PackedStringArray) -> void:
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
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(beat_id, flags)
		else:
			if "flags" in _runner:
				_runner.flags = flags
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
		print("test_a2_tagus: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a2_tagus: %s" % failure)
	quit(1)
