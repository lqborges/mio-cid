extends SceneTree
## Headless a1_embassy1 GiftToKing test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_embassy1.gd

const WORLD := "res://content/chapters/a1_embassy1/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const GIFT_PATH := "res://data/gifts/embassy_1.json"
const LANDS_KEY := "a1_embassy1.lands_restored"
const BLOCKED_KEY := "ui.embassy_ledger.blocked"

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
		failures.append_array(_check_spanish_copy())
		failures.append_array(await _check_spawn_does_not_auto_gift())
		failures.append_array(_check_ledger_greys_thirty_horses())
		_world.free()
		_world = null
	failures.append_array(_check_thirty_horses_refused_below_herd())
	failures.append_array(_check_ten_horses_cheat_branch())
	failures.append_array(_check_empty_hands_refuse_branch())
	failures.append_array(_check_hub_lock_and_poyo_travel())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_embassy1/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_embassy1 world did not instantiate")
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
	if _world.get_node_or_null("AlvarFanez") == null:
		failures.append("world missing AlvarFanez")
	if _world.get_node_or_null("GiftZone") == null:
		failures.append("world missing GiftZone")
	if _world.get_node_or_null("TentA") == null:
		failures.append("world missing TentA")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("LeaveCinematic") == null:
		failures.append("world missing LeaveCinematic")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_embassy1 HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a1_embassy1 HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a1_embassy1 HUD")
	if _world.find_child("EmbassyLedger", true, false) == null:
		failures.append("embassy ledger missing from a1_embassy1 HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a1_embassy1":
		failures.append("ChapterRunner.current_id want a1_embassy1 got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden after Navapalos")
	var ledger: Node = _world.find_child("EmbassyLedger", true, false)
	if ledger and bool(ledger.visible):
		failures.append("EmbassyLedger must stay hidden until GiftZone / start_gift")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_embassy1 must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_embassy1 has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a1_embassy1 greybox missing camp CSG")
	var tents := _world.find_children("*", "CSGCombiner3D", true, false)
	if tents.size() < 1:
		failures.append("a1_embassy1 greybox missing tent CSGCombiner")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 1:
		failures.append("a1_embassy1 greybox missing camp CSG cylinder")
	var players := _world.find_children("*", "AnimationPlayer", true, false)
	if players.size() < 1:
		failures.append("a1_embassy1 missing leave AnimationPlayer")
	var horse: Node = _world.get_node_or_null("Horse")
	if horse and horse.get_node_or_null("CavalryCharge") == null:
		failures.append("embassy Horse missing CavalryCharge")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var lands := str(_loc.call("text", LANDS_KEY))
	if lands == LANDS_KEY or lands.is_empty():
		failures.append("Loc did not resolve a1_embassy1.lands_restored")
	var lowered := lands.to_lower()
	if not lowered.contains("minaya"):
		failures.append("lands whisper must name Minaya, got %s" % lands)
	if not lowered.contains("tierra") and not lowered.contains("tierras"):
		failures.append("lands whisper must restore lands, got %s" % lands)
	if not lowered.contains("perdon") and not lowered.contains("perdona"):
		failures.append("lands whisper must say Cid is not pardoned, got %s" % lands)
	var blocked := str(_loc.call("text", BLOCKED_KEY))
	if blocked == BLOCKED_KEY or blocked.is_empty():
		failures.append("Loc did not resolve blocked embassy copy")
	var thirty := str(_loc.call("text", "ui.gift.thirty_horses"))
	if not thirty.to_lower().contains("caballos"):
		failures.append("thirty_horses copy must be horses, got %s" % thirty)
	if thirty.to_lower().contains("marcos"):
		failures.append("thirty_horses copy must not be marks, got %s" % thirty)
	return failures


func _check_ledger_greys_thirty_horses() -> PackedStringArray:
	var failures: PackedStringArray = []
	var opt := _option(&"thirty_horses")
	if opt == null:
		failures.append("thirty_horses option missing from embassy_1.json")
		return failures
	if _treasury:
		_treasury.state.horses = maxi(0, int(opt.blocked_if_horses_lt) - 1)
	if _world.has_method("start_gift"):
		_world.start_gift()
	var ui: Node = _world.find_child("EmbassyLedger", true, false)
	if ui == null or not bool(ui.visible):
		failures.append("start_gift must show EmbassyLedger")
		return failures
	if ui.has_method("is_option_blocked") and not bool(ui.call("is_option_blocked", &"thirty_horses")):
		failures.append("ledger must treat thirty_horses as blocked below herd")
	if ui.has_method("select"):
		ui.call("select", &"thirty_horses")
	var btn: Button = ui.find_child("thirty_horses", true, false) as Button
	if btn == null:
		failures.append("ledger missing thirty_horses row")
	else:
		if btn.disabled:
			failures.append("blocked thirty_horses row must stay clickable")
		if btn.modulate.is_equal_approx(Color(1, 1, 1, 1)):
			failures.append("thirty_horses row must be greyed when herd is short")
	var warn: Label = ui.get_node_or_null(NodePath("Center/Warn")) as Label
	if warn == null or warn.text.is_empty():
		failures.append("selecting blocked thirty_horses must show warn copy")
	elif not warn.text.to_lower().contains("caballo"):
		failures.append("blocked thirty_horses warn must mention horses, got %s" % warn.text)
	var confirm: Button = ui.get_node_or_null(NodePath("Center/Confirm")) as Button
	if confirm and confirm.disabled:
		failures.append("Confirm must stay enabled so blocked resolve() can run")
	return failures


func _check_spawn_does_not_auto_gift() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_gifted")):
		failures.append("gift resolved on spawn physics frames")
	if bool(_world.get("_returned")):
		failures.append("Álvar returned on spawn physics frames")
	var ledger: Node = _world.find_child("EmbassyLedger", true, false)
	if ledger and bool(ledger.visible):
		failures.append("EmbassyLedger must stay hidden on spawn")
	if _honor and not is_equal_approx(float(_honor.state.honor), 15.0):
		failures.append("spawn must not apply honor, got %s" % _honor.state.honor)
	return failures


func _check_thirty_horses_refused_below_herd() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var opt := _option(&"thirty_horses")
	if opt == null:
		failures.append("thirty_horses option missing")
		return failures
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("refuse: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	var herd := maxi(0, int(opt.blocked_if_horses_lt) - 1)
	_treasury.state.horses = herd
	_treasury.state.marks = 400
	var honor_before := float(_honor.state.honor)
	var horses_before := int(_treasury.state.horses)
	if not world.has_method("attempt_gift"):
		failures.append("world.attempt_gift missing")
		world.free()
		return failures
	var ev: HonorEvent = world.call("attempt_gift", &"thirty_horses")
	if ev != null and not String(ev.id).is_empty():
		failures.append("thirty_horses must be refused below herd, event id %s" % ev.id)
	if int(_treasury.state.horses) != horses_before:
		failures.append("refused thirty_horses must not deduct horses, got %s" % _treasury.state.horses)
	if not is_equal_approx(float(_honor.state.honor), honor_before):
		failures.append("refused thirty_horses must not change honor, got %s" % _honor.state.honor)
	if bool(world.get("_gifted")):
		failures.append("refused thirty_horses must not complete the gift")
	if "embassy1_gift" in _logged:
		failures.append("refused thirty_horses must not log embassy1_gift")
	if world.has_method("run_gift"):
		var ui_ev: HonorEvent = world.call("run_gift", &"thirty_horses")
		if ui_ev != null and not String(ui_ev.id).is_empty():
			failures.append("ledger confirm must also refuse thirty_horses, id %s" % ui_ev.id)
		if int(_treasury.state.horses) != horses_before:
			failures.append("ledger refuse must not deduct horses, got %s" % _treasury.state.horses)
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "embassy1_done" in flags or "minaya_lands_restored" in flags:
			failures.append("refused gift must not restore Minaya")
		if String(_runner.current_id) == "a1_poyo":
			failures.append("refused gift must not travel to poyo")
	world.free()
	return failures


func _check_ten_horses_cheat_branch() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var opt := _option(&"ten_horses")
	if opt == null:
		failures.append("ten_horses option missing")
		return failures
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("ten_horses: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_completed.clear()
	_fails.clear()
	var scene_before: Node = current_scene
	_treasury.state.horses = 18
	_treasury.state.marks = 1144
	var honor_before := float(_honor.state.honor)
	var horses_before := int(_treasury.state.horses)
	var ev: HonorEvent = world.call("run_gift", &"ten_horses")
	if ev == null or String(ev.id) != "embassy1_gift":
		failures.append("ten_horses must apply embassy1_gift, got %s" % (ev.id if ev else "?"))
	if "embassy1_gift" not in _logged:
		failures.append("ten_horses must log embassy1_gift via HonorService, logged %s" % str(_logged))
	if "pardon" in _logged:
		failures.append("embassy 1 must not pardon the Cid")
	var want_horses := horses_before - int(opt.horses)
	if int(_treasury.state.horses) != want_horses:
		failures.append("ten_horses herd want %s got %s" % [want_horses, _treasury.state.horses])
	var want_honor := honor_before + float(opt.honor_delta)
	if not is_equal_approx(float(_honor.state.honor), want_honor):
		failures.append("ten_horses honor want %s got %s" % [want_honor, _honor.state.honor])
	if not bool(world.get("_gifted")):
		failures.append("run_gift ten_horses must complete the gift")
	if not bool(world.get("_returned")):
		failures.append("Álvar must return after the gift")
	var alvar: Node = world.get_node_or_null("AlvarFanez")
	if alvar == null or not bool(alvar.visible):
		failures.append("Álvar must be present after return")
	var whisper: Node = world.find_child("HallWhisper", true, false)
	var line := ""
	if whisper:
		var label: Label = whisper.get_node_or_null("Line") as Label
		if label:
			line = label.text
	if line.is_empty() or (not line.to_lower().contains("minaya") and not line.to_lower().contains("tierra")):
		failures.append("return whisper must restore Minaya lands, got %s" % line)
	if _runner:
		if String(_runner.current_id) != "a1_poyo":
			failures.append("gift travel must land on a1_poyo, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "embassy1_done" not in flags:
			failures.append("gift must set embassy1_done")
		if "minaya_lands_restored" not in flags:
			failures.append("gift must set minaya_lands_restored")
		if "recruitment_flood" not in flags:
			failures.append("gift must allow recruitment flood")
		if "pardon" in flags or "pardon_possible" in flags:
			failures.append("embassy 1 must not set pardon flags")
	if current_scene != scene_before:
		failures.append("gift must not change_scene when current_scene != world (poyo is later)")
	if _completed.count("a1_embassy1") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if not _fails.is_empty():
		failures.append("gift must not hard_fail: %s" % ", ".join(_fails))
	world.free()
	return failures


func _check_empty_hands_refuse_branch() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var opt := _option(&"empty_hands")
	if opt == null:
		failures.append("empty_hands option missing")
		return failures
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("empty_hands: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_treasury.state.horses = 2
	_treasury.state.marks = 0
	# After Castejón take, onores is already > 20; empty_hands must still finish the beat.
	_honor.state.onores = 55.0
	var honor_before := float(_honor.state.honor)
	var ev: HonorEvent = world.call("run_gift", &"empty_hands")
	if ev == null or String(ev.id) != "embassy1_gift":
		failures.append("empty_hands must apply embassy1_gift when herd is thin, got %s" % (ev.id if ev else "?"))
	if int(_treasury.state.horses) != 2:
		failures.append("empty_hands must not take horses, got %s" % _treasury.state.horses)
	var want_honor := clampf(honor_before + float(opt.honor_delta), 0.0, 100.0)
	if not is_equal_approx(float(_honor.state.honor), want_honor):
		failures.append("empty_hands honor want %s got %s" % [want_honor, _honor.state.honor])
	if not bool(world.get("_returned")):
		failures.append("empty_hands still sends Álvar and he returns")
	world.free()
	return failures


func _check_hub_lock_and_poyo_travel() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	if _runner.has_method("restore"):
		_runner.restore(&"a1_embassy1", PackedStringArray(["hub_lock_cardena", "horse_companion", "alcocer_booty_divided"]))
	else:
		_runner.current_id = &"a1_embassy1"
		_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion", "alcocer_booty_divided"])
	var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
	if _runner.has_method("can_travel"):
		if not bool(_runner.can_travel(&"a1_embassy1", &"a1_poyo", flags)):
			failures.append("can_travel embassy1 -> poyo should be true")
		if bool(_runner.can_travel(&"a1_embassy1", &"a1_cardena", flags)):
			failures.append("can_travel embassy1 -> cardena must be false after hub lock")
		if bool(_runner.can_travel(&"a1_embassy1", &"a1_alcocer", flags)):
			failures.append("can_travel embassy1 -> alcocer must be false")
		if bool(_runner.can_travel(&"a1_embassy1", &"a1_tevar", flags)):
			failures.append("can_travel embassy1 -> tevar must skip poyo")
	return failures


func _option(choice_id: StringName) -> GiftOption:
	var gift := GiftToKing.from_file(GIFT_PATH)
	if gift == null:
		return null
	return gift.option(choice_id)


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
			_runner.restore(&"a1_embassy1", PackedStringArray(["hub_lock_cardena", "horse_companion", "alcocer_booty_divided"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion", "alcocer_booty_divided"])
			if "current_id" in _runner:
				_runner.current_id = &"a1_embassy1"
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
		print("test_embassy1: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_embassy1: %s" % failure)
	quit(1)
