extends SceneTree
## Headless a1_alcocer occupy / wait / dawn sortie test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a1_alcocer.gd

const WORLD := "res://content/chapters/a1_alcocer/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const WIN_KEY := "a1_alcocer.sortie_win"
const DAWN_KEY := "a1_alcocer.dawn"

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
		failures.append_array(_check_horse_and_cavalry())
		failures.append_array(_check_fariz_galve_from_json())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_no_booty_ui())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_thinner_refuse_wedge())
	failures.append_array(_check_occupy_does_not_win())
	failures.append_array(_check_wait_uses_clock_not_plazo())
	failures.append_array(_check_sortie_win_travels_to_embassy())
	failures.append_array(_check_hub_lock_still_blocks_cardena())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_alcocer/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_alcocer world did not instantiate")
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
	if _world.get_node_or_null("OccupyZone") == null:
		failures.append("world missing OccupyZone")
	if _world.get_node_or_null("WaitZone") == null:
		failures.append("world missing WaitZone")
	if _world.get_node_or_null("WaitCamp") == null:
		failures.append("world missing WaitCamp")
	if _world.get_node_or_null("Garrison") == null:
		failures.append("world missing Garrison")
	if _world.get_node_or_null("Host") == null:
		failures.append("world missing Host")
	if _world.get_node_or_null("Host/Fariz") == null:
		failures.append("world missing Fariz capsule")
	if _world.get_node_or_null("Host/Galve") == null:
		failures.append("world missing Galve capsule")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("Keep") == null:
		failures.append("world missing Keep greybox")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_alcocer HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a1_alcocer HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a1_alcocer HUD")
	if _world.find_child("KeepOrSell", true, false) != null:
		failures.append("keep-or-sell must not ship on Alcocer combat PR")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a1_alcocer":
		failures.append("ChapterRunner.current_id want a1_alcocer got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden after Navapalos")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_alcocer must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_alcocer has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a1_alcocer greybox missing town CSG")
	var keeps := _world.find_children("*", "CSGCombiner3D", true, false)
	if keeps.size() < 1:
		failures.append("a1_alcocer greybox missing keep CSGCombiner")
	var towers := _world.find_children("*", "CSGCylinder3D", true, false)
	if towers.size() < 1:
		failures.append("a1_alcocer greybox missing tower/camp CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a1_alcocer sdfgi must be off")
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


func _check_fariz_galve_from_json() -> PackedStringArray:
	var failures: PackedStringArray = []
	var fariz_member: MesnadaMember = MesnadaMember.from_id(&"fariz")
	var galve_member: MesnadaMember = MesnadaMember.from_id(&"galve")
	if fariz_member == null:
		failures.append("fariz.json failed to load")
		return failures
	if galve_member == null:
		failures.append("galve.json failed to load")
		return failures
	if fariz_member.unkillable:
		failures.append("Fáriz is an enemy captain, not unkillable Alfonso")
	if galve_member.unkillable:
		failures.append("Galve is an enemy captain, not unkillable Alfonso")
	if fariz_member.combat <= 0.0:
		failures.append("Fáriz combat must come from JSON and be > 0")
	if galve_member.combat <= 0.0:
		failures.append("Galve combat must come from JSON and be > 0")
	var fariz: Node = _world.get_node_or_null("Host/Fariz")
	var galve: Node = _world.get_node_or_null("Host/Galve")
	if fariz == null or galve == null:
		failures.append("Fariz/Galve capsules missing")
		return failures
	if "unkillable" in fariz and bool(fariz.get("unkillable")):
		failures.append("Fariz node must not be unkillable")
	if "unkillable" in galve and bool(galve.get("unkillable")):
		failures.append("Galve node must not be unkillable")
	var fariz_hurt: Node = fariz.get_node_or_null("HurtBox")
	var galve_hurt: Node = galve.get_node_or_null("HurtBox")
	if fariz_hurt == null:
		failures.append("Fariz missing HurtBox")
	elif "max_hp" in fariz_hurt and not is_equal_approx(float(fariz_hurt.max_hp), fariz_member.combat):
		failures.append("Fariz hp want combat %s got %s" % [fariz_member.combat, fariz_hurt.max_hp])
	if galve_hurt == null:
		failures.append("Galve missing HurtBox")
	elif "max_hp" in galve_hurt and not is_equal_approx(float(galve_hurt.max_hp), galve_member.combat):
		failures.append("Galve hp want combat %s got %s" % [galve_member.combat, galve_hurt.max_hp])
	if fariz_hurt and "unkillable" in fariz_hurt and bool(fariz_hurt.get("unkillable")):
		failures.append("Fariz HurtBox must be killable")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var dawn := str(_loc.call("text", DAWN_KEY))
	if dawn == DAWN_KEY or dawn.is_empty():
		failures.append("Loc did not resolve a1_alcocer.dawn")
	var dawn_l := dawn.to_lower()
	if not dawn_l.contains("alba") and not dawn_l.contains("fáriz") and not dawn_l.contains("fariz"):
		failures.append("dawn line Spanish missing alba/Fáriz, got %s" % dawn)
	var win := str(_loc.call("text", WIN_KEY))
	if win == WIN_KEY or win.is_empty():
		failures.append("Loc did not resolve a1_alcocer.sortie_win")
	if not win.to_lower().contains("alcocer") and not win.to_lower().contains("fáriz") and not win.to_lower().contains("fariz"):
		failures.append("win copy must name Alcocer or Fáriz, got %s" % win)
	return failures


func _check_no_booty_ui() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _world.find_child("KeepOrSell", true, false) != null:
		failures.append("KeepOrSell UI must not ship on combat-only Alcocer")
	if _world.find_child("BootyDivide", true, false) != null:
		failures.append("BootyDivide UI must not ship on combat-only Alcocer")
	if ResourceLoader.exists("res://game/ui/booty_divide.tscn"):
		failures.append("PR-16 must not ship booty_divide.tscn")
	if ResourceLoader.exists("res://content/chapters/a1_embassy1/world.tscn"):
		failures.append("PR-16 must not ship a1_embassy1/world.tscn")
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_raid_started")):
		failures.append("occupy started on spawn physics frames")
	if bool(_world.get("_occupied")):
		failures.append("occupy completed on spawn physics frames")
	if bool(_world.get("_waited")):
		failures.append("wait completed on spawn physics frames")
	if bool(_world.get("_won")):
		failures.append("sortie resolved on spawn physics frames")
	var host: Node = _world.get_node_or_null("Host")
	if host and bool(host.visible):
		failures.append("Host must stay hidden until dawn sortie")
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
	world.free()
	return failures


func _check_occupy_does_not_win() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("occupy: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	if not world.has_method("run_occupy"):
		failures.append("world missing run_occupy")
		world.free()
		return failures
	var onores_before := 0.0
	if _honor:
		onores_before = float(_honor.state.onores)
	world.run_occupy()
	if not bool(world.get("_occupied")):
		failures.append("run_occupy must occupy Alcocer")
	if bool(world.get("_waited")):
		failures.append("occupy must not skip to wait")
	if bool(world.get("_won")):
		failures.append("occupy must not apply the sortie win")
	if "alcocer_sortie_win" in _logged:
		failures.append("occupy must not apply alcocer_sortie_win")
	if "alcocer_sell" in _logged:
		failures.append("occupy must not sell")
	if _honor and not is_equal_approx(float(_honor.state.onores), onores_before):
		failures.append("occupy must not change onores, got %s" % _honor.state.onores)
	var holding: Variant = world.get("holding")
	if holding and "held" in holding and not bool(holding.held):
		failures.append("occupy must mark the town held")
	world.free()
	return failures


func _check_wait_uses_clock_not_plazo() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	var days_before := 0
	var plazo_before := 0
	if _clock:
		days_before = int(_clock.days_elapsed)
		plazo_before = int(_clock.plazo_days_left)
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("wait: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	world.run_wait()
	if not bool(world.get("_waited")):
		failures.append("run_wait must wait after occupy")
	if not bool(world.get("_occupied")):
		failures.append("wait must occupy first")
	if bool(world.get("_won")):
		failures.append("wait must not win the sortie")
	if "alcocer_sortie_win" in _logged:
		failures.append("wait must not apply alcocer_sortie_win")
	if _clock:
		if int(_clock.days_elapsed) != days_before + 1:
			failures.append("wait must rest_camp, days_elapsed want %s got %s" % [days_before + 1, _clock.days_elapsed])
		if int(_clock.plazo_days_left) != plazo_before:
			failures.append("wait must not touch plazo, want %s got %s" % [plazo_before, _clock.plazo_days_left])
	if &"plazo_expired" in _fails:
		failures.append("Alcocer wait must not fire plazo_expired")
	var plazo: Node = world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden during Alcocer wait")
	var host: Node = world.get_node_or_null("Host")
	if host == null or not bool(host.visible):
		failures.append("dawn sortie host must appear after wait")
	if not bool(world.get("_sortie_started")):
		failures.append("wait until dawn must start the sortie")
	world.free()
	return failures


func _check_sortie_win_travels_to_embassy() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("sortie: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_fails.clear()
	_logged.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	world.run_wait()
	_logged.clear()
	_completed.clear()
	var onores_before := 0.0
	if _honor:
		onores_before = float(_honor.state.onores)
	world.run_sortie()
	if current_scene != scene_before:
		failures.append("sortie must not change_scene when current_scene != world (embassy is later)")
	if "alcocer_sortie_win" not in _logged:
		failures.append("win must apply alcocer_sortie_win, logged %s" % str(_logged))
	if "alcocer_sell" in _logged:
		failures.append("combat PR must not apply alcocer_sell")
	if "alcocer_keep" in _logged:
		failures.append("combat PR must not apply alcocer_keep")
	if not _fails.is_empty():
		failures.append("sortie win must not hard_fail: %s" % ", ".join(_fails))
	if not bool(world.get("_won")):
		failures.append("run_sortie must resolve the beat")
	if _honor:
		var event: HonorEvent = _honor.event_by_id(&"alcocer_sortie_win")
		var want := onores_before
		if event:
			want += event.delta_for(&"onores")
		if not is_equal_approx(float(_honor.state.onores), want):
			failures.append("alcocer_sortie_win onores want %s got %s" % [want, _honor.state.onores])
	if _completed.count("a1_alcocer") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _runner:
		if String(_runner.current_id) != "a1_embassy1":
			failures.append("win travel must land on a1_embassy1, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if _runner.has_method("can_travel"):
			if bool(_runner.can_travel(&"a1_alcocer", &"a1_cardena", flags)):
				failures.append("hub_lock_cardena still blocks cardena")
			if bool(_runner.can_travel(&"a1_embassy1", &"a1_cardena", flags)):
				failures.append("hub_lock_cardena still blocks cardena from embassy")
		if _runner.has_method("goto"):
			_runner.goto(&"a1_embassy1")
			if current_scene != scene_before:
				failures.append("goto a1_embassy1 must no-op missing scene")
	if ResourceLoader.exists("res://content/chapters/a1_embassy1/world.tscn"):
		failures.append("PR-16 must not ship a1_embassy1/world.tscn")
	world.free()
	return failures


func _check_hub_lock_still_blocks_cardena() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	if _runner.has_method("restore"):
		_runner.restore(&"a1_alcocer", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
	else:
		_runner.current_id = &"a1_alcocer"
		_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion"])
	var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
	if _runner.has_method("can_travel"):
		if not bool(_runner.can_travel(&"a1_alcocer", &"a1_embassy1", flags)):
			failures.append("can_travel alcocer -> embassy1 should be true")
		if bool(_runner.can_travel(&"a1_alcocer", &"a1_cardena", flags)):
			failures.append("can_travel alcocer -> cardena must be false after hub lock")
		if bool(_runner.can_travel(&"a1_alcocer", &"a1_castejon", flags)):
			failures.append("can_travel alcocer -> castejon must be false")
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
			_runner.restore(&"a1_alcocer", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion"])
			if "current_id" in _runner:
				_runner.current_id = &"a1_alcocer"
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
		print("test_a1_alcocer: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_alcocer: %s" % failure)
	quit(1)
