extends SceneTree
## Headless Valencia hall repayment (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a2_repay_raquel.gd

const WORLD := "res://content/chapters/a2_repay_raquel/world.tscn"
const EMBASSY3 := "res://content/chapters/a2_embassy3/world.tscn"
const TAGUS := "res://content/chapters/a2_tagus/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const PLACE_KEY := "a2_repay_raquel.place_name"
const HORSE_KEY := "a2_repay_raquel.horse_name"
const PAY_KEY := "a2_repay_raquel.pay"
const RAQUEL_KEY := "a2_repay_raquel.raquel"
const VIDAS_KEY := "a2_repay_raquel.vidas"

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
		failures.append_array(_check_separate_lenders())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(await _check_pay_clears_stain())
	failures.append_array(_check_refuse_cannot_open())
	failures.append_array(_check_graph_and_join())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_repay_raquel/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_repay_raquel world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("Raquel") == null:
		failures.append("world missing Raquel")
	if _world.get_node_or_null("Vidas") == null:
		failures.append("world missing Vidas")
	if _world.get_node_or_null("Hall") == null:
		failures.append("world missing Hall")
	if _world.get_node_or_null("PayZone") == null:
		failures.append("world missing PayZone")
	if _world.get_node_or_null("TagusExit") == null:
		failures.append("world missing TagusExit")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("PlaceName") == null:
		failures.append("world missing PlaceName")
	if _world.find_child("ChoiceUI", true, false) != null:
		failures.append("pay is the only option; ChoiceUI must not ship")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_repay_raquel HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_repay_raquel HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_repay_raquel HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_repay_raquel":
		failures.append("ChapterRunner.current_id want a2_repay_raquel got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a2_repay_raquel must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_repay_raquel has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a2_repay_raquel greybox missing hall CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a2_repay_raquel sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a2_repay_raquel has GPUParticles3D")
	return failures


func _check_separate_lenders() -> PackedStringArray:
	var failures: PackedStringArray = []
	var raquel: Node = _world.get_node_or_null("Raquel")
	var vidas: Node = _world.get_node_or_null("Vidas")
	if raquel == null or vidas == null:
		failures.append("Raquel and Vidas must both be in the hall")
		return failures
	var rid := str(raquel.get("character_id")) if "character_id" in raquel else ""
	var vid := str(vidas.get("character_id")) if "character_id" in vidas else ""
	if rid != "raquel":
		failures.append("Raquel character_id want raquel got %s" % rid)
	if vid != "vidas":
		failures.append("Vidas character_id want vidas got %s" % vid)
	if rid == vid:
		failures.append("Raquel and Vidas must be separate ids")
	if _world.get_node_or_null("Mesnada/AlvarFanez") == null:
		failures.append("Minaya (Álvar) must be in the hall")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var raquel := str(_loc.call("text", RAQUEL_KEY))
	if raquel == RAQUEL_KEY or raquel.is_empty():
		failures.append("Loc did not resolve a2_repay_raquel.raquel")
	if not raquel.to_lower().contains("pagad"):
		failures.append("raquel line Spanish missing pagad, got %s" % raquel)
	var vidas := str(_loc.call("text", VIDAS_KEY))
	if vidas == VIDAS_KEY or vidas.is_empty():
		failures.append("Loc did not resolve a2_repay_raquel.vidas")
	if not vidas.to_lower().contains("arena"):
		failures.append("vidas line Spanish missing arena, got %s" % vidas)
	var minaya := str(_loc.call("text", "a2_repay_raquel.minaya"))
	if not minaya.contains("Raquel") or not minaya.contains("Vidas"):
		failures.append("minaya line must name Raquel and Vidas, got %s" % minaya)
	var pay := str(_loc.call("text", PAY_KEY))
	if pay == PAY_KEY or pay.is_empty():
		failures.append("Loc did not resolve a2_repay_raquel.pay")
	if not pay.to_lower().contains("marcos"):
		failures.append("pay line Spanish missing marcos, got %s" % pay)
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
	for path in ["PayZone", "TagusExit"]:
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
	if bool(_world.get("_paid")):
		failures.append("repayment completed on spawn physics frames")
	if bool(_world.get("_left")):
		failures.append("hall left on spawn physics frames")
	return failures


func _check_pay_clears_stain() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _honor and _honor.has_method("apply_id"):
		_honor.apply_id(&"arcas_cheat")
	if _treasury:
		_treasury.state.marks = 800
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("pay: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	var honra_before := 0.0
	if _honor and _honor.state:
		honra_before = float(_honor.state.honra)
		if not bool(_honor.state.has_stain(&"arcas_cheat")):
			failures.append("fixture must stain arcas_cheat before pay")
	if not world.has_method("run_pay"):
		failures.append("world missing run_pay")
		world.free()
		return failures
	if bool(world.call("travel_to_tagus")):
		failures.append("tagus exit must wait for payment")
	await world.run_pay()
	if current_scene != scene_before:
		failures.append("payment must not change_scene; TagusExit owns leave")
	if not bool(world.get("_paid")):
		failures.append("run_pay must pay Raquel and Vidas")
	if "repay_raquel" not in _logged:
		failures.append("payment must apply repay_raquel, logged %s" % str(_logged))
	if not _fails.is_empty():
		failures.append("payment must not hard_fail: %s" % ", ".join(_fails))
	if _honor and _honor.state:
		if bool(_honor.state.has_stain(&"arcas_cheat")):
			failures.append("pay must clear stain arcas_cheat")
		var event: Variant = _honor.event_by_id(&"repay_raquel")
		var want_honra := honra_before
		if event and event.has_method("delta_for"):
			want_honra += float(event.call("delta_for", &"honra"))
		if not is_equal_approx(float(_honor.state.honra), want_honra):
			failures.append("repay_raquel honra want %s got %s" % [want_honra, _honor.state.honra])
		if absf(want_honra - honra_before - 8.0) > 0.01:
			failures.append("repay_raquel catalog honra delta want 8")
	if _treasury and int(_treasury.state.marks) != 200:
		failures.append("repay marks want 200 (800-600) got %s" % _treasury.state.marks)
	var speakers: PackedStringArray = world.get("last_dialogue_speakers")
	var keys: PackedStringArray = world.get("last_dialogue_keys")
	var has_raquel := false
	var has_vidas := false
	for speaker in speakers:
		var lowered := str(speaker).to_lower()
		if lowered.contains("raquel"):
			has_raquel = true
		if lowered.contains("vidas"):
			has_vidas = true
	if speakers.size() > 0 and not has_raquel:
		failures.append("pay cue must speak as Raquel, speakers %s" % str(speakers))
	if speakers.size() > 0 and not has_vidas:
		failures.append("pay cue must speak as Vidas, speakers %s" % str(speakers))
	if keys.size() > 0 and RAQUEL_KEY not in keys:
		failures.append("pay cue must play a2_repay_raquel.raquel, keys %s" % str(keys))
	if keys.size() > 0 and VIDAS_KEY not in keys:
		failures.append("pay cue must play a2_repay_raquel.vidas, keys %s" % str(keys))
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "repay_done" not in flags:
			failures.append("payment must set repay_done")
		if "arcas_cheated" not in flags:
			failures.append("cheat path must keep arcas_cheated")
	if not bool(world.call("can_leave_to_tagus")):
		failures.append("after pay Tagus exit should open")
	if not bool(world.call("travel_to_tagus")):
		failures.append("travel_to_tagus must succeed after pay")
	if _runner and String(_runner.current_id) != "a2_tagus":
		failures.append("hall exit must land on a2_tagus, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("goto must no-op unless current_scene is the hall")
	world.free()
	return failures


func _check_refuse_cannot_open() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var honest := PackedStringArray(["embassy3_done"])
	if bool(_runner.can_travel(&"a2_embassy3", &"a2_repay_raquel", honest)):
		failures.append("refuse-branch cannot open a2_repay_raquel")
	if not bool(_runner.can_travel(&"a2_embassy3", &"a2_tagus", honest)):
		failures.append("honest embassy3_done must open Tagus")
	_prep_campaign_at(&"a2_repay_raquel", PackedStringArray(["embassy3_done"]))
	if _treasury:
		_treasury.state.marks = 800
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("refuse: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	if world.has_method("pay") and bool(world.call("pay")):
		failures.append("uncheated save must not pay")
	if bool(world.get("_paid")):
		failures.append("uncheated hall must not mark paid")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "repay_done" in flags:
			failures.append("uncheated save must not set repay_done")
	world.free()
	return failures


func _check_graph_and_join() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var cheated := PackedStringArray(["arcas_cheated", "embassy3_done"])
	if not bool(_runner.can_travel(&"a2_embassy3", &"a2_repay_raquel", cheated)):
		failures.append("cheated save with embassy3_done must open a2_repay_raquel")
	if bool(_runner.can_travel(&"a2_embassy3", &"a2_tagus", cheated)):
		failures.append("cheated save must not open Tagus without repay_done")
	if bool(_runner.can_travel(&"a2_repay_raquel", &"a2_tagus", cheated)):
		failures.append("repay beat must not open Tagus before repay_done")
	var repaid := PackedStringArray(["arcas_cheated", "embassy3_done", "repay_done"])
	if not bool(_runner.can_travel(&"a2_repay_raquel", &"a2_tagus", repaid)):
		failures.append("repay_done must open Tagus from a2_repay_raquel")
	if bool(_runner.can_travel(&"a2_yusuf", &"a2_repay_raquel", cheated)):
		failures.append("a2_repay_raquel must have no extra incoming edges")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ResourceLoader.exists(EMBASSY3):
		failures.append("a2_embassy3 must ship on this diamond")
	if not ResourceLoader.exists(TAGUS):
		failures.append("a2_tagus must ship")
	if not ResourceLoader.exists("res://content/chapters/a2_bodas/world.tscn"):
		failures.append("a2_bodas must ship")
	if not ResourceLoader.exists("res://content/chapters/a3_leon/world.tscn"):
		failures.append("a3_leon must ship")
	if not ResourceLoader.exists("res://content/chapters/a3_bucar/world.tscn"):
		failures.append("a3_bucar must ship")
	if not ResourceLoader.exists("res://content/chapters/a3_despedida/world.tscn"):
		failures.append("a3_despedida must ship")
	if not ResourceLoader.exists("res://content/chapters/a3_corpes/world.tscn"):
		failures.append("a3_corpes must ship")
	if not ResourceLoader.exists("res://content/chapters/a3_querella/world.tscn"):
		failures.append("a3_querella must ship")
	if not ResourceLoader.exists("res://content/chapters/a3_toledo/world.tscn"):
		failures.append("a3_toledo must keep shipping")
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
		&"a2_repay_raquel",
		PackedStringArray([
			"hub_lock_cardena",
			"horse_companion",
			"colada_acquired",
			"valencia_held",
			"arcas_cheated",
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
		print("test_a2_repay_raquel: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a2_repay_raquel: %s" % failure)
	quit(1)
