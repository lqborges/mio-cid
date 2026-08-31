extends SceneTree
## Headless a2_embassy3 GiftToKing test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_embassy3.gd

const WORLD := "res://content/chapters/a2_embassy3/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const GIFT_PATH := "res://data/gifts/embassy_3.json"
const TAGUS := "res://content/chapters/a2_tagus/world.tscn"
const REPAY := "res://content/chapters/a2_repay_raquel/world.tscn"
const PARDON_KEY := "a2_embassy3.pardon_possible"
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
	failures.append_array(_check_ten_horses_spends_escrow_first())
	failures.append_array(_check_honest_path_tagus_gated())
	failures.append_array(_check_cheated_path_repay_gated())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_embassy3/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_embassy3 world did not instantiate")
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
	if _world.get_node_or_null("ExitZone") == null:
		failures.append("world missing ExitZone")
	if _world.get_node_or_null("TentA") == null:
		failures.append("world missing TentA")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("LeaveCinematic") == null:
		failures.append("world missing LeaveCinematic")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_embassy3 HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_embassy3 HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_embassy3 HUD")
	if _world.find_child("EmbassyLedger", true, false) == null:
		failures.append("embassy ledger missing from a2_embassy3 HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_embassy3":
		failures.append("ChapterRunner.current_id want a2_embassy3 got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden after Navapalos")
	var ledger: Node = _world.find_child("EmbassyLedger", true, false)
	if ledger and bool(ledger.visible):
		failures.append("EmbassyLedger must stay hidden until GiftZone / start_gift")
	if ResourceLoader.exists(TAGUS):
		failures.append("a2_tagus must not ship in this PR")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a2_embassy3 must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_embassy3 has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a2_embassy3 greybox missing courtyard CSG")
	var tents := _world.find_children("*", "CSGCombiner3D", true, false)
	if tents.size() < 1:
		failures.append("a2_embassy3 greybox missing CSGCombiner")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 1:
		failures.append("a2_embassy3 greybox missing CSG cylinder")
	var players := _world.find_children("*", "AnimationPlayer", true, false)
	if players.size() < 1:
		failures.append("a2_embassy3 missing leave AnimationPlayer")
	var horse: Node = _world.get_node_or_null("Horse")
	if horse and horse.get_node_or_null("CavalryCharge") == null:
		failures.append("embassy Horse missing CavalryCharge")
	var gift_zone: Area3D = _world.get_node_or_null("GiftZone") as Area3D
	if gift_zone and gift_zone.collision_mask != 130:
		failures.append("GiftZone mask want 130 got %s" % gift_zone.collision_mask)
	var exit_zone: Area3D = _world.get_node_or_null("ExitZone") as Area3D
	if exit_zone and exit_zone.collision_mask != 130:
		failures.append("ExitZone mask want 130 got %s" % exit_zone.collision_mask)
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var pardon := str(_loc.call("text", PARDON_KEY))
	if pardon == PARDON_KEY or pardon.is_empty():
		failures.append("Loc did not resolve a2_embassy3.pardon_possible")
	var lowered := pardon.to_lower()
	if not lowered.contains("perdón") and not lowered.contains("perdon"):
		failures.append("pardon whisper must name perdón, got %s" % pardon)
	if not lowered.contains("posible"):
		failures.append("pardon whisper must say possible, got %s" % pardon)
	var blocked := str(_loc.call("text", BLOCKED_KEY))
	if blocked == BLOCKED_KEY or blocked.is_empty():
		failures.append("Loc did not resolve blocked embassy copy")
	var thirty := str(_loc.call("text", "ui.gift.thirty_horses"))
	if not thirty.to_lower().contains("caballos"):
		failures.append("thirty_horses copy must be horses, got %s" % thirty)
	if thirty.to_lower().contains("marcos"):
		failures.append("thirty_horses copy must not be marks, got %s" % thirty)
	var place := str(_loc.call("text", "a2_embassy3.place_name"))
	if not place.to_lower().contains("valencia"):
		failures.append("place name must be Valencia, got %s" % place)
	return failures


func _check_ledger_greys_thirty_horses() -> PackedStringArray:
	var failures: PackedStringArray = []
	var opt := _option(&"thirty_horses")
	if opt == null:
		failures.append("thirty_horses option missing from embassy_3.json")
		return failures
	if _treasury:
		_treasury.state.horses = maxi(0, int(opt.blocked_if_horses_lt) - 1)
		_treasury.state.royal_escrow_horses = 0
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
	_treasury.state.royal_escrow_horses = 0
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
	if "embassy3_gift" in _logged:
		failures.append("refused thirty_horses must not log embassy3_gift")
	_treasury.state.horses = 20
	_treasury.state.royal_escrow_horses = 8
	var thin: HonorEvent = world.call("attempt_gift", &"thirty_horses")
	if thin != null and not String(thin.id).is_empty():
		failures.append("thirty_horses must stay blocked when herd+escrow < 30")
	if world.has_method("run_gift"):
		var ui_ev: HonorEvent = world.call("run_gift", &"thirty_horses")
		if ui_ev != null and not String(ui_ev.id).is_empty():
			failures.append("ledger confirm must also refuse thirty_horses, id %s" % ui_ev.id)
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "embassy3_done" in flags:
			failures.append("refused gift must not set embassy3_done")
		if String(_runner.current_id) == "a2_tagus":
			failures.append("refused gift must not travel to Tagus")
	world.free()
	return failures


func _check_ten_horses_spends_escrow_first() -> PackedStringArray:
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
	_treasury.state.royal_escrow_horses = 8
	_treasury.state.marks = 320
	_treasury.state.royal_escrow_marks = 160
	var honor_before := float(_honor.state.honor)
	var ev: HonorEvent = world.call("run_gift", &"ten_horses")
	if ev == null or String(ev.id) != "embassy3_gift":
		failures.append("ten_horses must apply embassy3_gift, got %s" % (ev.id if ev else "?"))
	if "embassy3_gift" not in _logged:
		failures.append("ten_horses must log embassy3_gift via HonorService, logged %s" % str(_logged))
	if "pardon" in _logged:
		failures.append("embassy 3 must not grant the pardon")
	if int(_treasury.state.royal_escrow_horses) != 0:
		failures.append("ten_horses must empty escrow horses first, got %s" % _treasury.state.royal_escrow_horses)
	if int(_treasury.state.horses) != 16:
		failures.append("ten_horses remainder herd want 16 got %s" % _treasury.state.horses)
	if int(_treasury.state.royal_escrow_marks) != 160:
		failures.append("ten_horses must not spend mark escrow, got %s" % _treasury.state.royal_escrow_marks)
	var want_honor := honor_before + float(opt.honor_delta)
	if not is_equal_approx(float(_honor.state.honor), want_honor):
		failures.append("ten_horses honor want %s got %s" % [want_honor, _honor.state.honor])
	if float(opt.honor_delta) < 10.0:
		failures.append("embassy 3 ten_horses honor_delta must be at least 10")
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
	if line.is_empty() or (not line.to_lower().contains("perdón") and not line.to_lower().contains("perdon") and not line.to_lower().contains("tajo")):
		failures.append("return whisper must say pardon is possible, got %s" % line)
	if _runner:
		if String(_runner.current_id) != "a2_tagus":
			failures.append("honest gift travel must land on a2_tagus, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "embassy3_done" not in flags:
			failures.append("gift must set embassy3_done")
		if "pardon" in flags:
			failures.append("embassy 3 must not set pardon as granted")
	if current_scene != scene_before:
		failures.append("gift must not change_scene when dest is missing")
	if ResourceLoader.exists(TAGUS):
		failures.append("a2_tagus must not ship in this PR")
	if not _fails.is_empty():
		failures.append("gift must not hard_fail: %s" % ", ".join(_fails))
	world.free()
	return failures


func _check_honest_path_tagus_gated() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	_prep_campaign()
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "embassy3_done"])
	if _runner.has_method("restore"):
		_runner.restore(&"a2_embassy3", flags)
	if not bool(_runner.can_travel(&"a2_embassy3", &"a2_tagus", flags)):
		failures.append("honest embassy3_done must open Tagus")
	if bool(_runner.can_travel(&"a2_embassy3", &"a2_repay_raquel", flags)):
		failures.append("honest path must not open repay")
	if bool(_runner.can_travel(&"a2_yusuf", &"a2_tagus", flags)):
		failures.append("yusuf must not skip embassy3 into Tagus")
	if ResourceLoader.exists(TAGUS):
		failures.append("a2_tagus must not ship in this PR")
	return failures


func _check_cheated_path_repay_gated() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign(["hub_lock_cardena", "horse_companion", "arcas_cheated", "yusuf_day2_done"])
	var opt := _option(&"ten_horses")
	if opt == null:
		failures.append("ten_horses option missing")
		return failures
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("cheated: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	var scene_before: Node = current_scene
	_treasury.state.horses = 18
	_treasury.state.royal_escrow_horses = 8
	_treasury.state.marks = 320
	_treasury.state.royal_escrow_marks = 160
	var ev: HonorEvent = world.call("run_gift", &"ten_horses")
	if ev == null or String(ev.id) != "embassy3_gift":
		failures.append("cheated ten_horses must apply embassy3_gift, got %s" % (ev.id if ev else "?"))
	if _runner:
		if String(_runner.current_id) != "a2_repay_raquel":
			failures.append("cheated gift travel must land on a2_repay_raquel, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "embassy3_done" not in flags:
			failures.append("cheated gift must set embassy3_done")
		if bool(_runner.can_travel(&"a2_embassy3", &"a2_tagus", flags)):
			failures.append("arcas_cheated must still close embassy3 -> Tagus")
	if current_scene != scene_before:
		failures.append("goto must no-op when repay/tagus scenes are missing")
	var whisper: Node = world.find_child("HallWhisper", true, false)
	var line := ""
	if whisper:
		var label: Label = whisper.get_node_or_null("Line") as Label
		if label:
			line = label.text
	if ResourceLoader.exists(REPAY):
		# Scene may already exist from an earlier beat; still no hop unless current_scene==world.
		pass
	elif line.is_empty() or (not line.to_lower().contains("raquel") and not line.to_lower().contains("vidas") and not line.to_lower().contains("tajo")):
		# travel() runs while current_scene != world, so the wait whisper is only for a live hop.
		pass
	world.free()
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


func _prep_campaign(extra: PackedStringArray = PackedStringArray()) -> void:
	if _honor:
		if _honor.has_method("reset_state"):
			_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "yusuf_day2_done"])
	for flag in extra:
		if String(flag) not in flags:
			flags.append(flag)
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(&"a2_embassy3", flags)
		else:
			if "flags" in _runner:
				_runner.flags = flags
			if "current_id" in _runner:
				_runner.current_id = &"a2_embassy3"
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
		print("test_embassy3: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_embassy3: %s" % failure)
	quit(1)
