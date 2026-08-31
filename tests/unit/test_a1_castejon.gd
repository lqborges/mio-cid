extends SceneTree
## Headless a1_castejon dawn take / keep-or-sell test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a1_castejon.gd

const WORLD := "res://content/chapters/a1_castejon/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const ALVAR_KEY := "a1_castejon.alvar_henares"
const KEEP_KEY := "a1_castejon.keep_fail"

var _honor: Variant
var _treasury: Variant
var _clock: Variant
var _runner: Variant
var _loc: Variant
var _bus: Variant
var _world: Node = null
var _fails: PackedStringArray = PackedStringArray()
var _logged: PackedStringArray = PackedStringArray()


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
		failures.append_array(_check_horse_and_cavalry())
		failures.append_array(_check_alvar_off_map())
		failures.append_array(_check_spanish_copy())
		failures.append_array(await _check_spawn_does_not_auto_take())
		_world.free()
		_world = null
	failures.append_array(_check_thinner_refuse_wedge())
	failures.append_array(_check_keep_is_hard_fail())
	failures.append_array(_check_sell_advances_to_alcocer())
	failures.append_array(_check_hub_lock_still_blocks_cardena())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_castejon/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_castejon world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	var cid_scene: Resource = load(CID)
	if cid_scene == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("TakeZone") == null:
		failures.append("world missing TakeZone")
	if _world.get_node_or_null("Garrison") == null:
		failures.append("world missing Garrison")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("Keep") == null:
		failures.append("world missing Keep greybox")
	if _world.get_node_or_null("River") == null:
		failures.append("world missing Henares river")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_castejon HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a1_castejon HUD")
	if _world.find_child("KeepOrSell", true, false) == null:
		failures.append("keep-or-sell missing from a1_castejon HUD")
	if _world.find_child("AlvarReport", true, false) == null:
		failures.append("AlvarReport missing (Henares is off-map, not a second map)")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a1_castejon HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a1_castejon":
		failures.append("ChapterRunner.current_id want a1_castejon got %s" % _runner.current_id)
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_castejon must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_castejon has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a1_castejon greybox missing town CSG")
	var keeps := _world.find_children("*", "CSGCombiner3D", true, false)
	if keeps.size() < 1:
		failures.append("a1_castejon greybox missing keep CSGCombiner")
	var towers := _world.find_children("*", "CSGCylinder3D", true, false)
	if towers.size() < 1:
		failures.append("a1_castejon greybox missing tower CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a1_castejon sdfgi must be off")
	return failures


func _check_horse_and_cavalry() -> PackedStringArray:
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
		failures.append("destierro horse must stay unnamed")
	var packed: Resource = load(HORSE)
	if packed == null:
		failures.append("horse.tscn failed to load")
	return failures


func _check_alvar_off_map() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _world.get_node_or_null("Mesnada/AlvarFanez") != null:
		failures.append("Álvar must be off-map at Castejón, not a second playable body")
	var mesnada: Node = _world.get_node_or_null("Mesnada")
	if mesnada:
		for child in mesnada.get_children():
			if str(child.get("member_id")) == "alvar_fanez":
				failures.append("Álvar Fáñez body must not stand in the Castejón wedge")
	if ResourceLoader.exists("res://content/chapters/a1_henares/world.tscn"):
		failures.append("Henares must not be a second playable map")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var dawn := str(_loc.call("text", "a1_castejon.dawn"))
	if dawn == "a1_castejon.dawn" or dawn.is_empty():
		failures.append("Loc did not resolve a1_castejon.dawn")
	if not dawn.to_lower().contains("alba") and not dawn.to_lower().contains("castej"):
		failures.append("dawn line Spanish missing alba/Castejón, got %s" % dawn)
	var keep := str(_loc.call("text", KEEP_KEY))
	if not keep.to_lower().contains("alfonso"):
		failures.append("keep fail copy must name Alfonso, got %s" % keep)
	return failures


func _check_spawn_does_not_auto_take() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_raid_started")):
		failures.append("raid started on spawn physics frames")
	if bool(_world.get("_taken")):
		failures.append("take completed on spawn physics frames")
	if bool(_world.get("_resolved")):
		failures.append("keep/sell resolved on spawn physics frames")
	var ui: Node = _world.find_child("KeepOrSell", true, false)
	if ui and bool(ui.visible):
		failures.append("keep-or-sell must stay hidden until take")
	return failures


func _check_thinner_refuse_wedge() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _honor:
		_honor.roster = MesnadaRoster.from_starting_seed()
		_honor.roster.lanzas = 6
	if _clock:
		_clock.unfed_streak = 2
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
	if n > 6:
		failures.append("refuse wedge must not fake 12 lanzas, got %s bodies" % n)
	if n != 6:
		failures.append("refuse lanzas want 6 bodies, got %s" % n)
	if world.get_node_or_null("Mesnada/AlvarFanez") != null:
		failures.append("refuse branch must still keep Álvar off-map")
	world.free()
	return failures


func _check_keep_is_hard_fail() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("keep: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_fails.clear()
	_logged.clear()
	var scene_before: Node = current_scene
	if not world.has_method("run_take") or not world.has_method("choose_keep"):
		failures.append("world missing run_take/choose_keep")
		world.free()
		return failures
	world.run_take()
	if not bool(world.get("_taken")):
		failures.append("run_take must occupy Castejón")
	var report: Node = world.find_child("AlvarReport", true, false)
	var report_line := ""
	if report:
		var label: Label = report.get_node_or_null("Line") as Label
		if label:
			report_line = label.text
		if not bool(report.visible):
			failures.append("Álvar Henares report UI must show after take")
	if report_line.is_empty() or not report_line.to_lower().contains("henares"):
		failures.append("Álvar report must name the Henares, got %s" % report_line)
	if "castejon_take" not in _logged:
		failures.append("take must apply castejon_take, logged %s" % str(_logged))
	world.choose_keep()
	if current_scene != scene_before:
		failures.append("headless keep must not change_scene when current_scene != world")
	if "castejon_keep" not in _logged:
		failures.append("keep must apply castejon_keep, not a flavor line. logged %s" % str(_logged))
	if &"alfonso_wrath" not in _fails and &"alfonso_host" not in _fails:
		failures.append("keep must hard_fail, got %s" % str(_fails))
	if &"alfonso_wrath" not in _fails:
		failures.append("keep fail_copy want alfonso_wrath, got %s" % str(_fails))
	var last := _fail_copy_reason()
	if last != &"alfonso_wrath" and last != &"alfonso_host" and last != &"":
		failures.append("fail copy reason want alfonso wrath/host, got %s" % last)
	if _honor and not is_equal_approx(float(_honor.state.honor), 0.0):
		failures.append("castejon_keep honor want 0 (15-40 clamp) got %s" % _honor.state.honor)
	if not bool(world.get("_resolved")):
		failures.append("keep must resolve the beat")
	if _runner and _runner.has_method("can_travel"):
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if bool(_runner.can_travel(&"a1_castejon", &"a1_cardena", flags)):
			failures.append("hub_lock_cardena still blocks cardena after keep")
	world.free()
	return failures


func _check_sell_advances_to_alcocer() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("sell: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_fails.clear()
	_logged.clear()
	var scene_before: Node = current_scene
	world.run_take()
	world.choose_sell()
	if current_scene != scene_before:
		failures.append("sell must not change_scene when current_scene != world (Alcocer is later)")
	if "castejon_sell" not in _logged:
		failures.append("sell must apply castejon_sell, logged %s" % str(_logged))
	if not _fails.is_empty():
		failures.append("sell must not hard_fail: %s" % ", ".join(_fails))
	if _runner:
		if String(_runner.current_id) != "a1_alcocer":
			failures.append("sell travel must land on a1_alcocer, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if _runner.has_method("can_travel"):
			if not bool(_runner.can_travel(&"a1_castejon", &"a1_alcocer", flags)) and String(_runner.current_id) != "a1_alcocer":
				failures.append("can_travel castejon -> alcocer must be true after sell")
			if bool(_runner.can_travel(&"a1_alcocer", &"a1_cardena", flags)):
				failures.append("hub_lock_cardena still blocks cardena")
			if bool(_runner.can_travel(&"a1_castejon", &"a1_cardena", flags)):
				failures.append("hub_lock_cardena still blocks cardena from castejon")
		if _runner.has_method("goto"):
			_runner.goto(&"a1_alcocer")
			if current_scene != scene_before:
				failures.append("goto a1_alcocer must no-op missing scene")
	if ResourceLoader.exists("res://content/chapters/a1_alcocer/world.tscn"):
		failures.append("PR-15 must not ship a1_alcocer/world.tscn")
	world.free()
	return failures


func _check_hub_lock_still_blocks_cardena() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	if _runner.has_method("restore"):
		_runner.restore(&"a1_castejon", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
	else:
		_runner.current_id = &"a1_castejon"
		_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion"])
	var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
	if _runner.has_method("can_travel"):
		if not bool(_runner.can_travel(&"a1_castejon", &"a1_alcocer", flags)):
			failures.append("can_travel castejon -> alcocer should be true")
		if bool(_runner.can_travel(&"a1_castejon", &"a1_cardena", flags)):
			failures.append("can_travel castejon -> cardena must be false after hub lock")
		if bool(_runner.can_travel(&"a1_castejon", &"a1_navapalos", flags)):
			failures.append("can_travel castejon -> navapalos must be false")
	return failures


func _fail_copy_reason() -> StringName:
	var script: Script = load("res://game/ui/fail_copy.gd") as Script
	if script and "last_reason" in script:
		return script.last_reason
	return &""


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


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
			_runner.restore(&"a1_castejon", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion"])
			if "current_id" in _runner:
				_runner.current_id = &"a1_castejon"
	if _bus:
		if _bus.has_signal("hard_fail") and not _bus.hard_fail.is_connected(_on_hard_fail):
			_bus.hard_fail.connect(_on_hard_fail)
		if _bus.has_signal("honor_logged") and not _bus.honor_logged.is_connected(_on_honor_logged):
			_bus.honor_logged.connect(_on_honor_logged)
	_fails.clear()
	_logged.clear()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a1_castejon: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_castejon: %s" % failure)
	quit(1)
