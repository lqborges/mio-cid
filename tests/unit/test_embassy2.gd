extends SceneTree
## Headless a2_embassy2 escort + GiftToKing test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_embassy2.gd

const WORLD := "res://content/chapters/a2_embassy2/world.tscn"
const HUB := "res://content/chapters/a2_jeronimo/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const GIFT_PATH := "res://data/gifts/embassy_2.json"
const FAMILY_KEY := "a2_embassy2.family_arrives"
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
		failures.append_array(await _check_spawn_does_not_auto_flow())
		failures.append_array(_check_ledger_greys_thirty_horses())
		_world.free()
		_world = null
	failures.append_array(_check_thirty_horses_refused_below_herd())
	failures.append_array(_check_escrow_spent_first())
	failures.append_array(_check_ten_horses_and_return_to_hub())
	failures.append_array(_check_avengalvon_survives_save_load())
	failures.append_array(_check_family_joins_hub())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_embassy2/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_embassy2 world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("Avengalvon") == null:
		failures.append("world missing Avengalvón")
	if _world.get_node_or_null("Jimena") == null:
		failures.append("world missing Jimena")
	if _world.get_node_or_null("Elvira") == null:
		failures.append("world missing Elvira")
	if _world.get_node_or_null("Sol") == null:
		failures.append("world missing Sol")
	if _world.get_node_or_null("AlvarFanez") == null:
		failures.append("world missing AlvarFanez")
	if _world.get_node_or_null("GiftZone") == null:
		failures.append("world missing GiftZone")
	if _world.get_node_or_null("RecruitZone") == null:
		failures.append("world missing RecruitZone")
	if _world.get_node_or_null("EscortEnd") == null:
		failures.append("world missing EscortEnd")
	if _world.get_node_or_null("Keep") == null:
		failures.append("world missing Medinaceli Keep")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("LeaveCinematic") == null:
		failures.append("world missing LeaveCinematic")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_embassy2 HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_embassy2 HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_embassy2 HUD")
	if _world.find_child("EmbassyLedger", true, false) == null:
		failures.append("embassy ledger missing from a2_embassy2 HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_embassy2":
		failures.append("ChapterRunner.current_id want a2_embassy2 got %s" % _runner.current_id)
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
		failures.append("a2_embassy2 must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_embassy2 has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a2_embassy2 greybox missing road CSG")
	var keeps := _world.find_children("*", "CSGCombiner3D", true, false)
	if keeps.size() < 1:
		failures.append("a2_embassy2 greybox missing keep/tent CSGCombiner")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 1:
		failures.append("a2_embassy2 greybox missing road CSG cylinder")
	var horse: Node = _world.get_node_or_null("Horse")
	if horse and horse.get_node_or_null("CavalryCharge") == null:
		failures.append("embassy Horse missing CavalryCharge")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var family := str(_loc.call("text", FAMILY_KEY))
	if family == FAMILY_KEY or family.is_empty():
		failures.append("Loc did not resolve a2_embassy2.family_arrives")
	var lowered := family.to_lower()
	if not lowered.contains("jimena"):
		failures.append("family whisper must name Jimena, got %s" % family)
	if not lowered.contains("avengalv"):
		failures.append("family whisper must keep Avengalvón, got %s" % family)
	var kin := str(_loc.call("text", "a2_embassy2.not_creed"))
	if kin.to_lower().contains("cruzada") or kin.to_lower().contains("reconquista"):
		failures.append("not-creed copy must not be a crusade, got %s" % kin)
	var blocked := str(_loc.call("text", BLOCKED_KEY))
	if blocked == BLOCKED_KEY or blocked.is_empty():
		failures.append("Loc did not resolve blocked embassy copy")
	var thirty := str(_loc.call("text", "ui.gift.thirty_horses"))
	if not thirty.to_lower().contains("caballos"):
		failures.append("thirty_horses copy must be horses, got %s" % thirty)
	var place := str(_loc.call("text", "a2_embassy2.place_name"))
	if not place.to_lower().contains("medinaceli"):
		failures.append("place name must be Medinaceli, got %s" % place)
	return failures


func _check_ledger_greys_thirty_horses() -> PackedStringArray:
	var failures: PackedStringArray = []
	var opt := _option(&"thirty_horses")
	if opt == null:
		failures.append("thirty_horses option missing from embassy_2.json")
		return failures
	if _treasury:
		_treasury.state.horses = maxi(0, int(opt.blocked_if_horses_lt) - 1)
		_treasury.state.royal_escrow_horses = 0
	if _world.has_method("recruit_avengalvon"):
		_world.recruit_avengalvon()
	if _world.has_method("complete_escort"):
		_world.complete_escort()
	if _world.has_method("start_gift"):
		_world.start_gift()
	var ui: Node = _world.find_child("EmbassyLedger", true, false)
	if ui == null or not bool(ui.visible):
		failures.append("start_gift must show EmbassyLedger after recruit")
		return failures
	if ui.has_method("is_option_blocked") and not bool(ui.call("is_option_blocked", &"thirty_horses")):
		failures.append("ledger must treat thirty_horses as blocked below herd")
	var btn: Button = ui.find_child("thirty_horses", true, false) as Button
	if btn == null:
		failures.append("ledger missing thirty_horses row")
	else:
		if btn.disabled:
			failures.append("blocked thirty_horses row must stay clickable")
		if btn.modulate.is_equal_approx(Color(1, 1, 1, 1)):
			failures.append("thirty_horses row must be greyed when herd is short")
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_gifted")):
		failures.append("gift resolved on spawn physics frames")
	if bool(_world.get("_recruited")):
		failures.append("Avengalvón recruited on spawn physics frames")
	if bool(_world.get("_returned")):
		failures.append("embassy 2 returned on spawn physics frames")
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
	var ev: HonorEvent = world.call("attempt_gift", &"thirty_horses")
	if ev != null and not String(ev.id).is_empty():
		failures.append("thirty_horses must be refused below herd, event id %s" % ev.id)
	if int(_treasury.state.horses) != horses_before:
		failures.append("refused thirty_horses must not deduct horses, got %s" % _treasury.state.horses)
	if not is_equal_approx(float(_honor.state.honor), honor_before):
		failures.append("refused thirty_horses must not change honor, got %s" % _honor.state.honor)
	if bool(world.get("_gifted")):
		failures.append("refused thirty_horses must not complete the gift")
	if "embassy2_gift" in _logged:
		failures.append("refused thirty_horses must not log embassy2_gift")
	world.free()
	return failures


func _check_escrow_spent_first() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var opt := _option(&"thirty_horses")
	if opt == null:
		failures.append("thirty_horses option missing")
		return failures
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("escrow: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_treasury.state.horses = 10
	_treasury.state.royal_escrow_horses = 25
	_treasury.state.marks = 0
	_treasury.state.royal_escrow_marks = 0
	var honor_before := float(_honor.state.honor)
	var ev: HonorEvent = world.call("run_gift", &"thirty_horses")
	if ev == null or String(ev.id) != "embassy2_gift":
		failures.append("escrow thirty_horses must apply embassy2_gift, got %s" % (ev.id if ev else "?"))
	if int(_treasury.state.royal_escrow_horses) != 0:
		failures.append("gift must empty horse escrow first, got %s" % _treasury.state.royal_escrow_horses)
	if int(_treasury.state.horses) != 5:
		failures.append("after escrow, personal herd want 5 got %s" % _treasury.state.horses)
	var want_honor := honor_before + float(opt.honor_delta)
	if not is_equal_approx(float(_honor.state.honor), want_honor):
		failures.append("escrow thirty_horses honor want %s got %s" % [want_honor, _honor.state.honor])
	if not bool(world.call("avengalvon_kept")):
		failures.append("Avengalvón must stay recruited and essential")
	world.free()
	return failures


func _check_ten_horses_and_return_to_hub() -> PackedStringArray:
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
	_treasury.state.marks = 200
	var honor_before := float(_honor.state.honor)
	var ev: HonorEvent = world.call("run_gift", &"ten_horses")
	if ev == null or String(ev.id) != "embassy2_gift":
		failures.append("ten_horses must apply embassy2_gift, got %s" % (ev.id if ev else "?"))
	if "embassy2_gift" not in _logged:
		failures.append("ten_horses must log embassy2_gift, logged %s" % str(_logged))
	if "pardon" in _logged:
		failures.append("embassy 2 must not pardon the Cid")
	if int(_treasury.state.royal_escrow_horses) != 0:
		failures.append("ten_horses must spend escrow horses first, got %s" % _treasury.state.royal_escrow_horses)
	if int(_treasury.state.horses) != 16:
		failures.append("ten_horses personal herd want 16 (18 - 2 after 8 escrow) got %s" % _treasury.state.horses)
	var want_honor := honor_before + float(opt.honor_delta)
	if not is_equal_approx(float(_honor.state.honor), want_honor):
		failures.append("ten_horses honor want %s got %s" % [want_honor, _honor.state.honor])
	if not bool(world.get("_gifted")):
		failures.append("run_gift ten_horses must complete the gift")
	if not bool(world.get("_recruited")):
		failures.append("run_gift must recruit Avengalvón")
	if not bool(world.get("_escorted")):
		failures.append("run_gift must complete the Medinaceli escort")
	if not bool(world.get("_returned")):
		failures.append("gift must return from the road")
	if not bool(world.call("avengalvon_kept")):
		failures.append("Avengalvón must remain in the mesnada")
	var avengalvon: Node = world.get_node_or_null("Avengalvon")
	if avengalvon == null or not bool(avengalvon.visible):
		failures.append("Avengalvón capsule must stay visible")
	if _runner:
		if String(_runner.current_id) != "a2_jeronimo":
			failures.append("gift travel must land on a2_jeronimo, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "embassy2_done" not in flags:
			failures.append("gift must set embassy2_done")
		if "avengalvon_recruited" not in flags:
			failures.append("gift must set avengalvon_recruited")
		if "family_in_valencia" not in flags:
			failures.append("gift must set family_in_valencia")
		if "pardon" in flags or "pardon_possible" in flags:
			failures.append("embassy 2 must not set pardon flags")
	if current_scene != scene_before:
		failures.append("gift must not change_scene when current_scene != world")
	if not _fails.is_empty():
		failures.append("gift must not hard_fail: %s" % ", ".join(_fails))
	var roster: Variant = _honor.get("roster") if _honor else null
	if roster == null or not roster.has_method("member"):
		failures.append("roster missing after recruit")
	else:
		var member: Variant = roster.member(&"avengalvon")
		if member == null:
			failures.append("Avengalvón must join the mesnada")
		else:
			if str(member.role) != "ally_taifa":
				failures.append("Avengalvón role want ally_taifa got %s" % member.role)
			if not bool(member.essential):
				failures.append("Avengalvón must be essential")
			if String(member.must_survive_until) != "a3_despedida":
				failures.append("Avengalvón must_survive_until want a3_despedida got %s" % member.must_survive_until)
	world.free()
	return failures


func _check_avengalvon_survives_save_load() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var save: Node = get_root().get_node_or_null(NodePath("SaveService"))
	if save == null or not save.has_method("autosave") or not save.has_method("apply_payload"):
		failures.append("SaveService.autosave/apply_payload missing")
		return failures
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("save-load: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_treasury.state.horses = 18
	_treasury.state.royal_escrow_horses = 8
	if world.call("run_gift", &"ten_horses") == null:
		failures.append("save-load run_gift failed")
		world.free()
		return failures
	if save.autosave() != OK:
		failures.append("autosave after gift failed: %s" % save.last_error)
		world.free()
		return failures
	_honor.roster = MesnadaRoster.from_starting_seed()
	if _honor.roster.member(&"avengalvon") != null:
		failures.append("starting seed must not include Avengalvón")
		world.free()
		return failures
	var payload: Dictionary = save.call("_verified_payload", save.autosave_path())
	if payload.is_empty():
		failures.append("autosave payload missing after gift")
		world.free()
		return failures
	save.apply_payload(payload)
	var member: Variant = _honor.roster.member(&"avengalvon")
	if member == null:
		failures.append("Cargar must keep Avengalvón after embassy 2")
	else:
		if not bool(member.essential):
			failures.append("loaded Avengalvón must stay essential")
		if String(member.must_survive_until) != "a3_despedida":
			failures.append("loaded Avengalvón must_survive_until want a3_despedida got %s" % member.must_survive_until)
	world.free()
	return failures


func _check_family_joins_hub() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign_at(
		&"a2_jeronimo",
		PackedStringArray([
			"hub_lock_cardena",
			"horse_companion",
			"colada_acquired",
			"valencia_held",
			"jeronimo_appointed",
			"embassy2_done",
			"family_in_valencia",
			"avengalvon_recruited",
		])
	)
	var packed: Resource = load(HUB)
	if packed == null or not (packed is PackedScene):
		failures.append("hub world.tscn failed to load for family join")
		return failures
	var hub: Node = (packed as PackedScene).instantiate()
	get_root().add_child(hub)
	if hub.has_method("family_in_hub") and not bool(hub.call("family_in_hub")):
		failures.append("Jimena/Elvira/Sol must join the Valencia hub after embassy 2")
	if hub.get_node_or_null("Jimena") == null:
		failures.append("hub missing Jimena after embassy2_done")
	if hub.get_node_or_null("Elvira") == null:
		failures.append("hub missing Elvira after embassy2_done")
	if hub.get_node_or_null("Sol") == null:
		failures.append("hub missing Sol after embassy2_done")
	var hub_roster: Variant = _honor.get("roster") if _honor else null
	if hub_roster == null or hub_roster.member(&"avengalvon") == null:
		failures.append("hub must restore Avengalvón when avengalvon_recruited")
	else:
		var kept: Variant = hub_roster.member(&"avengalvon")
		if not bool(kept.essential) or String(kept.must_survive_until) != "a3_despedida":
			failures.append("hub Avengalvón must stay essential through a3_despedida")
	hub.free()
	_prep_campaign_at(&"a2_jeronimo", PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "valencia_held"]))
	packed = load(HUB)
	var empty: Node = (packed as PackedScene).instantiate()
	get_root().add_child(empty)
	if empty.get_node_or_null("Jimena") != null:
		failures.append("Jimena must stay at Cardeña until embassy 2")
	empty.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "babieca_named"])
	if not bool(_runner.can_travel(&"a2_jeronimo", &"a2_embassy2", flags)):
		failures.append("jeronimo -> embassy2 must stay open")
	if not bool(_runner.can_travel(&"a2_embassy2", &"a2_jeronimo", flags)):
		failures.append("embassy2 -> hub return must stay open")
	if bool(_runner.can_travel(&"a2_jeronimo", &"a2_yusuf", flags)):
		failures.append("hub must not skip embassy2 into Yusuf")
	if bool(_runner.can_travel(&"a2_embassy2", &"a2_embassy3", flags)):
		failures.append("embassy 2 must not skip to embassy 3")
	var after := PackedStringArray(["hub_lock_cardena", "embassy2_done"])
	if bool(_runner.can_travel(&"a2_jeronimo", &"a2_embassy2", after)):
		failures.append("hub must not repeat the escort after embassy2_done")
	if not bool(_runner.can_travel(&"a2_jeronimo", &"a2_yusuf", after)):
		failures.append("after embassy 2 the hub may open Yusuf later")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if ResourceLoader.exists("res://content/chapters/a2_yusuf/world.tscn"):
		failures.append("a2_yusuf must not ship in this PR")
	if ResourceLoader.exists("res://content/chapters/a2_embassy3/world.tscn"):
		failures.append("a2_embassy3 must not ship in this PR")
	if ResourceLoader.exists("res://data/gifts/embassy_3.json"):
		failures.append("embassy_3.json must not ship in this PR")
	if not ResourceLoader.exists("res://content/chapters/a3_leon/world.tscn"):
		failures.append("a3_leon must ship in this diamond")
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
	_prep_campaign_at(&"a2_embassy2", PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "valencia_held", "jeronimo_appointed", "babieca_named"]))


func _prep_campaign_at(beat_id: StringName, flags: PackedStringArray) -> void:
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
		print("test_embassy2: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_embassy2: %s" % failure)
	quit(1)
