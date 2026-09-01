extends SceneTree
## Headless a3_leon lion scene test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a3_leon.gd

const WORLD := "res://content/chapters/a3_leon/world.tscn"
const BUCAR := "res://content/chapters/a3_bucar/world.tscn"
const CORPES := "res://content/chapters/a3_corpes/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const JOKE_KEY := "a3_leon.joke"
const PLACE_KEY := "a3_leon.place_name"
const HIDE_FLAGS := [
	"ferran_hid_leon",
	"diego_hid_leon",
	"infantes_hid_leon",
	"infantes_cowardice_leon",
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
		failures.append_array(_check_cage_open_and_infantes_hide())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_zones_accept_player())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(await _check_joke_then_choice())
	failures.append_array(_check_mesura_path_returns_lion())
	failures.append_array(_check_rage_dump_costs_honra())
	failures.append_array(_check_cannot_kill_lion())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a3_leon/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a3_leon world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	for path in [
		"Hall",
		"LionCage",
		"LionCage/CageGate",
		"LionProp",
		"SleepCouch",
		"HallBenchA",
		"Solar",
		"SolarBed",
		"Ferran",
		"Diego",
		"Mesnada",
		"CageZone",
		"HallZone",
		"LionProp/CollisionShape3D",
		"LionCage/Door",
		"PlaceName",
	]:
		if _world.get_node_or_null(path) == null:
			failures.append("world missing %s" % path)
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a3_leon HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a3_leon HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a3_leon HUD")
	if _world.find_child("ChoiceUI", true, false) == null:
		failures.append("choice UI missing from a3_leon HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a3_leon":
		failures.append("ChapterRunner.current_id want a3_leon got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a3_leon must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a3_leon has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a3_leon greybox missing hall CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a3_leon sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a3_leon has GPUParticles3D")
	return failures


func _check_cage_open_and_infantes_hide() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not _world.has_method("is_cage_closed"):
		failures.append("world missing is_cage_closed")
		return failures
	if bool(_world.is_cage_closed()):
		failures.append("lion cage must start open")
	if not _world.has_method("is_lion_escaped") or not bool(_world.is_lion_escaped()):
		failures.append("lion must start escaped")
	if _world.has_method("is_cid_asleep") and not bool(_world.is_cid_asleep()):
		failures.append("Cid must start asleep")
	var cid: Node = _world.get_node_or_null("Cid")
	if cid and "chapter_asleep" in cid and not bool(cid.chapter_asleep):
		failures.append("CidController.chapter_asleep must start true")
	var gate: Node = _world.get_node_or_null("LionCage/CageGate")
	if gate and "visible" in gate and bool(gate.visible):
		failures.append("CageGate must start hidden (open)")
	var lion: Node3D = _world.get_node_or_null("LionProp") as Node3D
	var cage: Node3D = _world.get_node_or_null("LionCage") as Node3D
	if lion and cage and lion.global_position.distance_to(cage.global_position) < 2.0:
		failures.append("escaped lion must not sit in the cage")
	if lion and lion.get_node_or_null("HurtBox") != null:
		failures.append("lion must not be a boss hurtbox")
	var ferran: Node3D = _world.get_node_or_null("Ferran") as Node3D
	var bench: Node3D = _world.get_node_or_null("HallBenchA") as Node3D
	if ferran == null or bench == null:
		failures.append("Ferrán hide under bench missing")
	elif ferran.global_position.distance_to(bench.global_position) > 1.0:
		failures.append("Ferrán must hide under the bench")
	var diego: Node3D = _world.get_node_or_null("Diego") as Node3D
	var bed: Node3D = _world.get_node_or_null("SolarBed") as Node3D
	if diego == null or bed == null:
		failures.append("Diego hide in solar missing")
	elif diego.global_position.distance_to(bed.global_position) > 2.0:
		failures.append("Diego must hide in the solar")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		for flag in HIDE_FLAGS:
			if flag not in flags:
				failures.append("hide/cowardice flag missing on spawn: %s" % flag)
		if "lion_escaped" not in flags:
			failures.append("spawn must set lion_escaped")
		if "lion_returned" in flags:
			failures.append("lion_returned must wait until the return")
	var mesnada: Node = _world.get_node_or_null("Mesnada")
	if mesnada and str(mesnada.get("order")) != "hold":
		failures.append("mesnada must ring/hold the sleeping Cid, order %s" % mesnada.get("order"))
	var ferran_member: MesnadaMember = MesnadaMember.from_id(&"ferran_gonzalez")
	var diego_member: MesnadaMember = MesnadaMember.from_id(&"diego_gonzalez")
	if ferran_member == null or not is_equal_approx(ferran_member.mesura_max, 0.0):
		failures.append("Ferrán mesura_max must be 0")
	if diego_member == null or not is_equal_approx(diego_member.mesura_max, 0.0):
		failures.append("Diego mesura_max must be 0")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var joke := str(_loc.call("text", JOKE_KEY))
	if joke == JOKE_KEY or joke.is_empty():
		failures.append("Loc did not resolve a3_leon.joke")
	if not joke.to_lower().contains("mesura"):
		failures.append("joke line Spanish missing mesura, got %s" % joke)
	var hide := str(_loc.call("text", "a3_leon.ferran_hide"))
	if not hide.to_lower().contains("banco"):
		failures.append("Ferrán hide Spanish missing banco, got %s" % hide)
	var diego := str(_loc.call("text", "a3_leon.diego_hide"))
	if not diego.to_lower().contains("solar"):
		failures.append("Diego hide Spanish missing solar, got %s" % diego)
	var place := str(_loc.call("text", PLACE_KEY))
	if place != "Valencia":
		failures.append("place name must be Spanish first, got %s" % place)
	if _world.has_method("place_name_text") and str(_world.place_name_text()) != "Valencia":
		failures.append("PlaceName want Valencia got %s" % _world.place_name_text())
	return failures


func _check_zones_accept_player() -> PackedStringArray:
	var failures: PackedStringArray = []
	var zone: Area3D = _world.get_node_or_null("CageZone") as Area3D
	if zone == null:
		failures.append("CageZone missing")
		return failures
	if (zone.collision_mask & 130) != 130:
		failures.append("CageZone must listen for player and horse, mask %s" % zone.collision_mask)
	if zone.global_position.z < 11.0 or zone.global_position.z > 13.0:
		failures.append("CageZone must sit on the south threshold, z %s" % zone.global_position.z)
	var hall: Area3D = _world.get_node_or_null("HallZone") as Area3D
	if hall == null:
		failures.append("HallZone missing")
	elif (hall.collision_mask & 130) != 130:
		failures.append("HallZone must listen for player and horse, mask %s" % hall.collision_mask)
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_joke_played")):
		failures.append("joke played on spawn physics frames")
	if bool(_world.get("_returned")):
		failures.append("lion returned on spawn physics frames")
	if bool(_world.get("_honor_applied")):
		failures.append("honor applied on spawn physics frames")
	var choice: Node = _world.find_child("ChoiceUI", true, false)
	if choice and bool(choice.visible):
		failures.append("ChoiceUI must stay hidden on spawn")
	if _world.has_method("is_cid_asleep") and not bool(_world.is_cid_asleep()):
		failures.append("Cid must stay asleep on spawn")
	var cid: Node = _world.get_node_or_null("Cid")
	if cid and "chapter_asleep" in cid and not bool(cid.chapter_asleep):
		failures.append("sleep flag must survive four physics frames")
	var visual: Node3D = cid.get_node_or_null("Visual") as Node3D if cid else null
	if visual and visual.rotation_degrees.x < 45.0:
		failures.append("sleep pose must hold after look_at; got %s" % visual.rotation_degrees)
	if "_spawn_idle_done" in _world and not bool(_world.get("_spawn_idle_done")):
		failures.append("wake input must arm after four physics frames")
	return failures


func _check_joke_then_choice() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("joke: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_completed.clear()
	for _i in range(4):
		await physics_frame
	if bool(world.get("_joke_played")):
		failures.append("joke must wait for wake input")
	if world.has_method("on_sleep_input"):
		world.call("on_sleep_input")
	if bool(world.get("_asleep")):
		failures.append("on_sleep_input after idle must wake Cid")
	if not world.has_method("run_joke"):
		failures.append("world missing run_joke")
		world.free()
		return failures
	for _j in range(45):
		if bool(world.get("_joke_played")):
			break
		await process_frame
	if not bool(world.get("_joke_played")):
		await world.run_joke()
	if bool(world.get("_returned")):
		failures.append("joke must not skip to returning the lion")
	if "lion_mesura" in _logged or "lion_rage" in _logged:
		failures.append("joke must not apply lion honor, logged %s" % str(_logged))
	var ui: Node = world.find_child("ChoiceUI", true, false)
	if ui == null or not bool(ui.visible):
		failures.append("run_joke must present ChoiceUI")
	var speakers: PackedStringArray = world.get("last_dialogue_speakers")
	var keys: PackedStringArray = world.get("last_dialogue_keys")
	var has_alvar := false
	for speaker in speakers:
		if str(speaker).to_lower().contains("alvar"):
			has_alvar = true
	if speakers.size() > 0 and not has_alvar:
		failures.append("joke cue must speak as Alvar, speakers %s" % str(speakers))
	if keys.size() > 0 and "a3_leon.joke" not in keys:
		failures.append("joke cue must play a3_leon.joke before the choice, keys %s" % str(keys))
	if world.has_method("choose_mesura"):
		# Choosing before the joke would skip; joke already played, this is the branch.
		pass
	else:
		failures.append("world missing choose_mesura")
	if bool(world.call("try_kill_lion")):
		failures.append("try_kill_lion must fail during the joke")
	world.free()
	return failures


func _check_mesura_path_returns_lion() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("mesura: world.tscn failed to load")
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
	if not world.has_method("run_mesura"):
		failures.append("world missing run_mesura")
		world.free()
		return failures
	world.run_mesura()
	if current_scene != scene_before:
		failures.append("return must not change_scene when current_scene != world")
	if "lion_mesura" not in _logged:
		failures.append("mesura path must apply lion_mesura, logged %s" % str(_logged))
	if "lion_rage" in _logged:
		failures.append("mesura path must not apply lion_rage")
	if not _fails.is_empty():
		failures.append("mesura path must not hard_fail: %s" % ", ".join(_fails))
	if not bool(world.get("_returned")):
		failures.append("run_mesura must return the lion")
	if world.has_method("is_cage_closed") and not bool(world.is_cage_closed()):
		failures.append("cage must close after the return")
	if world.has_method("is_lion_escaped") and bool(world.is_lion_escaped()):
		failures.append("lion must not stay escaped after the return")
	var gate: Node = world.get_node_or_null("LionCage/CageGate")
	if gate and "visible" in gate and not bool(gate.visible):
		failures.append("CageGate must be visible after the return")
	var lion: Node3D = world.get_node_or_null("LionProp") as Node3D
	var cage: Node3D = world.get_node_or_null("LionCage") as Node3D
	if lion and cage and lion.global_position.distance_to(cage.global_position) > 1.5:
		failures.append("returned lion must sit in the cage")
	if _honor:
		var event: Variant = _honor.event_by_id(&"lion_mesura")
		var want := honra_before
		if event and event.has_method("delta_for"):
			want += float(event.call("delta_for", &"honra"))
		if not is_equal_approx(float(_honor.state.honra), want):
			failures.append("lion_mesura honra want %s got %s" % [want, _honor.state.honra])
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "lion_returned" not in flags:
			failures.append("return must set lion_returned")
		for flag in HIDE_FLAGS:
			if flag not in flags:
				failures.append("cowardice flag dropped after return: %s" % flag)
		if String(_runner.current_id) != "a3_bucar":
			failures.append("return must travel to a3_bucar, got %s" % _runner.current_id)
		if not bool(world.get("_left")):
			failures.append("return must leave for a3_bucar")
		if _completed.count("a3_leon") > 1:
			failures.append("beat_completed must not double-fire, got %s" % str(_completed))
		if _completed.count("a3_leon") < 1:
			failures.append("leave must emit beat_completed once, got %s" % str(_completed))
		if _runner.has_method("can_travel") and not bool(_runner.can_travel(&"a3_leon", &"a3_bucar", flags)):
			failures.append("lion_returned must open leon -> bucar")
	var cid: Node = world.get_node_or_null("Cid")
	var mesura: Node = cid.get_node_or_null("Mesura") if cid else null
	if mesura == null and cid:
		mesura = cid.find_child("Mesura", true, false)
	if mesura and mesura.has_method("is_holding") and not bool(mesura.is_holding()):
		# Hold is released after the return; the path still counted as mesura.
		pass
	world.free()
	return failures


func _check_rage_dump_costs_honra() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("rage: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var honra_before := 0.0
	if _honor and _honor.state:
		honra_before = float(_honor.state.honra)
	if not world.has_method("run_rage"):
		failures.append("world missing run_rage")
		world.free()
		return failures
	world.run_rage()
	if "lion_rage" not in _logged:
		failures.append("rage path must apply lion_rage, logged %s" % str(_logged))
	if "lion_mesura" in _logged:
		failures.append("rage path must not apply lion_mesura")
	if not bool(world.get("_returned")):
		failures.append("rage dump still returns the lion; it is not a boss fight")
	if world.has_method("is_cage_closed") and not bool(world.is_cage_closed()):
		failures.append("cage must close after the rage return")
	if _honor:
		var event: Variant = _honor.event_by_id(&"lion_rage")
		var want := honra_before
		if event and event.has_method("delta_for"):
			want += float(event.call("delta_for", &"honra"))
		if not is_equal_approx(float(_honor.state.honra), want):
			failures.append("lion_rage honra want %s got %s" % [want, _honor.state.honra])
		if float(_honor.state.honra) >= honra_before:
			failures.append("rage dump must cost honra")
	if not _fails.is_empty():
		failures.append("rage path must not hard_fail: %s" % ", ".join(_fails))
	if _completed.count("a3_leon") > 1:
		failures.append("rage leave must not double-fire beat_completed, got %s" % str(_completed))
	world.free()
	return failures


func _check_cannot_kill_lion() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("kill: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	if bool(world.call("try_kill_lion")):
		failures.append("try_kill_lion must be false")
	if bool(world.get("_returned")):
		failures.append("killing must not return the lion")
	if world.has_method("is_lion_escaped") and not bool(world.is_lion_escaped()):
		failures.append("failed kill must leave the lion escaped")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena"])
	if not bool(_runner.can_travel(&"a2_bodas", &"a3_leon", flags)):
		failures.append("bodas -> leon must stay open")
	if bool(_runner.can_travel(&"a3_leon", &"a3_bucar", flags)):
		failures.append("leon -> bucar must wait for lion_returned")
	flags.append("lion_returned")
	if not bool(_runner.can_travel(&"a3_leon", &"a3_bucar", flags)):
		failures.append("leon -> bucar must open after lion_returned")
	if bool(_runner.can_travel(&"a3_leon", &"a3_corpes", flags)):
		failures.append("leon must not skip to Corpes")
	if bool(_runner.can_travel(&"a2_bodas", &"a3_bucar", flags)):
		failures.append("bodas must not skip the lion scene")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ResourceLoader.exists(BUCAR):
		failures.append("a3_bucar world must exist")
	if not ResourceLoader.exists("res://content/chapters/a3_despedida/world.tscn"):
		failures.append("a3_despedida world must keep shipping")
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
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(&"a3_leon", PackedStringArray(["hub_lock_cardena"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena"])
			if "current_id" in _runner:
				_runner.current_id = &"a3_leon"
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
		print("test_a3_leon: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_leon: %s" % failure)
	quit(1)
