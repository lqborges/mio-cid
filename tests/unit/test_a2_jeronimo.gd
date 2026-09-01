extends SceneTree
## Headless Valencia hub / Jerónimo appointment test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a2_jeronimo.gd

const WORLD := "res://content/chapters/a2_jeronimo/world.tscn"
const SIEGE := "res://content/chapters/a2_siege/world.tscn"
const TEVAR := "res://content/chapters/a1_tevar/world.tscn"
const EMBASSY2 := "res://content/chapters/a2_embassy2/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const BUCAR := "res://content/chapters/a3_bucar/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const APPOINT_KEY := "a2_jeronimo.appoint"
const CAGE_KEY := "a2_jeronimo.cage_locked"
const PLACE_KEY := "a2_jeronimo.place_name"
const HORSE_KEY := "a2_jeronimo.horse_name"
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
		failures.append_array(_check_horse_named_here())
		failures.append_array(_check_cage_closed())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_playable_layout())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_horse_unnamed_earlier())
	failures.append_array(await _check_appoint_jeronimo())
	failures.append_array(await _check_cage_walk_does_not_leave_hub())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a2_jeronimo/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a2_jeronimo world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Horse") == null:
		failures.append("world missing Horse")
	if _world.get_node_or_null("Jeronimo") == null:
		failures.append("world missing Jerónimo")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("PlaceName") == null:
		failures.append("world missing PlaceName")
	if _world.get_node_or_null("AppointZone") == null:
		failures.append("world missing AppointZone")
	if _world.get_node_or_null("CageZone") == null:
		failures.append("world missing CageZone")
	if _world.get_node_or_null("CageLock") == null:
		failures.append("world missing CageLock")
	if _world.get_node_or_null("EmbassyExit") == null:
		failures.append("world missing EmbassyExit")
	if _world.get_node_or_null("ToEmbassy") == null:
		failures.append("world missing ToEmbassy label")
	if _world.get_node_or_null("Jimena") != null:
		failures.append("Jimena must still be at Cardeña, not in this hub")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a2_jeronimo HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a2_jeronimo HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a2_jeronimo HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a2_jeronimo":
		failures.append("ChapterRunner.current_id want a2_jeronimo got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a2_jeronimo must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a2_jeronimo has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 12:
		failures.append("a2_jeronimo greybox missing hub CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a2_jeronimo sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a2_jeronimo has GPUParticles3D")
	return failures


func _check_rooms() -> PackedStringArray:
	var failures: PackedStringArray = []
	for room in ROOM_NAMES:
		if _world.get_node_or_null(NodePath(room)) == null:
			failures.append("hub missing persistent room %s" % room)
	if _world.get_node_or_null("LionCage/CageGate") == null:
		failures.append("lion cage missing closed CageGate")
	if _world.get_node_or_null("LionProp") == null:
		failures.append("hub missing LionProp")
	if _world.get_node_or_null("Altar") == null:
		failures.append("bishopric missing Altar")
	if _world.get_node_or_null("Anvil") == null:
		failures.append("forge missing Anvil")
	if _world.get_node_or_null("SolarBed") == null:
		failures.append("solar missing bed greybox")
	if _world.get_node_or_null("ChestA") == null:
		failures.append("treasury missing chest greybox")
	return failures


func _check_horse_named_here() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: Node = _world.get_node_or_null("Horse")
	if horse == null:
		failures.append("Horse missing")
		return failures
	if not horse.is_in_group("horse_companion"):
		failures.append("Horse must be in horse_companion group")
	if horse.get_node_or_null("CavalryCharge") == null:
		failures.append("Horse missing CavalryCharge (couch lance)")
	if not horse.has_method("debug_id") or String(horse.debug_id()) != "babieca":
		failures.append("Valencia horse debug_id want babieca got %s" % (horse.debug_id() if horse.has_method("debug_id") else "missing"))
	if horse.has_method("display_name") and not str(horse.display_name()).to_lower().contains("babieca"):
		failures.append("Valencia horse display_name want Babieca got %s" % horse.display_name())
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "babieca_named" not in flags:
			failures.append("hub arrival must set babieca_named")
	if load(HORSE) == null:
		failures.append("horse.tscn failed to load")
	var label: Label3D = _world.get_node_or_null("Horse/Name") as Label3D
	if label and str(label.text).to_lower().find("babieca") < 0:
		failures.append("Horse/Name label want Babieca got %s" % label.text)
	return failures


func _check_cage_closed() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not _world.has_method("is_cage_closed"):
		failures.append("world missing is_cage_closed")
		return failures
	if not bool(_world.is_cage_closed()):
		failures.append("lion cage must start closed")
	if _world.has_method("is_lion_escaped") and bool(_world.is_lion_escaped()):
		failures.append("lion must not have escaped in this beat")
	if not _world.has_method("try_open_cage"):
		failures.append("world missing try_open_cage")
		return failures
	if bool(_world.try_open_cage()):
		failures.append("try_open_cage must refuse; the lion scene is later")
	if not bool(_world.is_cage_closed()):
		failures.append("cage must stay closed after try_open_cage")
	if _world.has_method("is_lion_escaped") and bool(_world.is_lion_escaped()):
		failures.append("try_open_cage must not run the lion escape")
	var gate: Node = _world.get_node_or_null("LionCage/CageGate")
	if gate and "visible" in gate and not bool(gate.visible):
		failures.append("CageGate must stay visible")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var appoint := str(_loc.call("text", APPOINT_KEY))
	if appoint == APPOINT_KEY or appoint.is_empty():
		failures.append("Loc did not resolve a2_jeronimo.appoint")
	var appoint_l := appoint.to_lower()
	if not appoint_l.contains("jerónimo") and not appoint_l.contains("jeronimo"):
		failures.append("appoint line must name Jerónimo, got %s" % appoint)
	if not appoint_l.contains("obispado"):
		failures.append("appoint line Spanish missing obispado, got %s" % appoint)
	if appoint_l.contains("cruzada") or appoint_l.contains("reconquista"):
		failures.append("bishopric must not be a crusade, got %s" % appoint)
	var cage := str(_loc.call("text", CAGE_KEY))
	if cage == CAGE_KEY or cage.is_empty():
		failures.append("Loc did not resolve a2_jeronimo.cage_locked")
	if not cage.to_lower().contains("jaula"):
		failures.append("cage line Spanish missing jaula, got %s" % cage)
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
	for path in ["AppointZone", "CageZone", "EmbassyExit"]:
		var zone: Area3D = _world.get_node_or_null(path) as Area3D
		if zone == null:
			failures.append("%s missing" % path)
			continue
		if (zone.collision_mask & 130) != 130:
			failures.append("%s must listen for player and horse, mask %s" % [path, zone.collision_mask])
	return failures


func _check_playable_layout() -> PackedStringArray:
	var failures: PackedStringArray = []
	var cage: Node3D = _world.get_node_or_null("LionCage") as Node3D
	var zone: Area3D = _world.get_node_or_null("CageZone") as Area3D
	if cage == null or zone == null:
		failures.append("LionCage or CageZone missing for layout")
		return failures
	var cage_south := cage.global_position.z - 3.2
	if zone.global_position.z >= cage.global_position.z:
		failures.append("CageZone must sit in front of LionCage, z %s" % zone.global_position.z)
	if zone.global_position.z > cage_south:
		failures.append("CageZone must be outside the sealed cage, z %s cage_south %s" % [zone.global_position.z, cage_south])
	if _world.get_node_or_null("LionCage/Door") == null:
		failures.append("LionCage missing subtracted Door opening")
	var stairs: Node3D = _world.get_node_or_null("Stairs") as Node3D
	if stairs == null:
		failures.append("Stairs missing")
	else:
		var basis := stairs.global_transform.basis
		if basis.y.dot(Vector3.UP) > 0.99:
			failures.append("Stairs must be a ramp, not a vertical pillar")
		if stairs.global_position.x > -8.0:
			failures.append("Stairs ramp must stay west of the hall, x %s" % stairs.global_position.x)
	var exit_zone: Area3D = _world.get_node_or_null("EmbassyExit") as Area3D
	if exit_zone == null:
		failures.append("EmbassyExit missing")
	elif exit_zone.global_position.z > cage_south:
		failures.append("EmbassyExit must not sit behind the cage, z %s" % exit_zone.global_position.z)
	var exit_name: Label3D = _world.get_node_or_null("EmbassyExit/Name") as Label3D
	if exit_name and str(exit_name.text).is_empty():
		failures.append("EmbassyExit/Name must show a2_jeronimo.to_embassy")
	var lion: CollisionObject3D = _world.get_node_or_null("LionProp") as CollisionObject3D
	if lion == null:
		failures.append("LionProp missing")
	elif lion.get_node_or_null("CollisionShape3D") == null:
		failures.append("LionProp missing CollisionShape3D")
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_appointed")):
		failures.append("appointment completed on spawn physics frames")
	if bool(_world.get("_left")):
		failures.append("hub left on spawn physics frames")
	if _world.has_method("is_lion_escaped") and bool(_world.is_lion_escaped()):
		failures.append("lion escaped on spawn")
	if _world.get("_cid_in_rest") == true:
		failures.append("Cid spawn must not sit inside a rest zone")
	return failures


func _check_horse_unnamed_earlier() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign_at(&"a1_tevar", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
	failures.append_array(_assert_scene_horse_unnamed(TEVAR, "a1_tevar"))
	_prep_campaign_at(&"a2_siege", PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired"]))
	failures.append_array(_assert_scene_horse_unnamed(SIEGE, "a2_siege"))
	var packed: Resource = load(HORSE)
	if packed is PackedScene:
		var horse: Node = (packed as PackedScene).instantiate()
		if horse.has_method("debug_id") and String(horse.debug_id()) == "babieca":
			failures.append("fresh horse.tscn must stay unnamed until Valencia")
		if horse.has_method("display_name") and str(horse.display_name()).to_lower().contains("babieca"):
			failures.append("fresh horse display_name must stay unnamed")
		horse.free()
	return failures


func _assert_scene_horse_unnamed(path: String, label: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load(path)
	if packed == null or not (packed is PackedScene):
		failures.append("%s world failed to load for unnamed-horse check" % label)
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	var horse: Node = world.get_node_or_null("Horse")
	if horse == null:
		failures.append("%s missing Horse" % label)
	elif horse.has_method("debug_id") and String(horse.debug_id()) == "babieca":
		failures.append("%s horse must stay unnamed, debug_id babieca" % label)
	world.free()
	return failures


func _check_appoint_jeronimo() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("appoint: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	if _treasury:
		_treasury.state.marks = 80
	var honor_before := 0.0
	var honra_before := 0.0
	if _honor and _honor.state:
		honor_before = float(_honor.state.honor)
		honra_before = float(_honor.state.honra)
	if not world.has_method("run_appoint"):
		failures.append("world missing run_appoint")
		world.free()
		return failures
	if bool(world.call("travel_to_embassy2")):
		failures.append("embassy exit must wait for the appointment")
	await world.run_appoint()
	if current_scene != scene_before:
		failures.append("appointment must not change_scene; Valencia is the hub")
	if not bool(world.get("_appointed")):
		failures.append("run_appoint must appoint Jerónimo")
	if "jeronimo_appointed" not in _logged:
		failures.append("appointment must apply jeronimo_appointed, logged %s" % str(_logged))
	if not _fails.is_empty():
		failures.append("appointment must not hard_fail: %s" % ", ".join(_fails))
	if _honor:
		var event: Variant = _honor.event_by_id(&"jeronimo_appointed")
		var want_honor := honor_before
		var want_honra := honra_before
		if event and event.has_method("delta_for"):
			want_honor += float(event.call("delta_for", &"honor"))
			want_honra += float(event.call("delta_for", &"honra"))
		if not is_equal_approx(float(_honor.state.honor), want_honor):
			failures.append("jeronimo_appointed honor want %s got %s" % [want_honor, _honor.state.honor])
		if not is_equal_approx(float(_honor.state.honra), want_honra):
			failures.append("jeronimo_appointed honra want %s got %s" % [want_honra, _honor.state.honra])
	if _treasury and int(_treasury.state.marks) != 40:
		failures.append("chapel gift marks want 40 (80-40) got %s" % _treasury.state.marks)
	var roster: Variant = null
	if _honor:
		roster = _honor.get("roster")
	if roster == null or not roster.has_method("member"):
		failures.append("roster missing after appointment")
	else:
		var member: Variant = roster.member(&"jeronimo")
		if member == null:
			failures.append("Jerónimo must join the mesnada")
		else:
			if str(member.role) != "bishop":
				failures.append("Jerónimo role want bishop got %s" % member.role)
			if not bool(member.list_eligible):
				failures.append("Jerónimo must be list_eligible (wants a lance)")
	var speakers: PackedStringArray = world.get("last_dialogue_speakers")
	var keys: PackedStringArray = world.get("last_dialogue_keys")
	var has_bishop := false
	for speaker in speakers:
		var lowered := str(speaker).to_lower()
		if lowered.contains("jerónimo") or lowered.contains("jeronimo"):
			has_bishop = true
	if speakers.size() > 0 and not has_bishop:
		failures.append("appoint cue must speak as Jerónimo, speakers %s" % str(speakers))
	if keys.size() > 0 and "a2_jeronimo.appoint" not in keys:
		failures.append("appoint cue must play a2_jeronimo.appoint, keys %s" % str(keys))
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "jeronimo_appointed" not in flags:
			failures.append("appointment must set jeronimo_appointed")
		if "babieca_named" not in flags:
			failures.append("hub must keep babieca_named")
	if not bool(world.call("can_leave_to_embassy2")):
		failures.append("after appointment embassy2 graph exit should open")
	if not bool(world.call("travel_to_embassy2")):
		failures.append("travel_to_embassy2 must succeed after appointment")
	if _runner and String(_runner.current_id) != "a2_embassy2":
		failures.append("hub exit must land on a2_embassy2, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("goto must no-op when current_scene is not the hub")
	world.free()
	return failures


func _check_cage_walk_does_not_leave_hub() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("cage walk: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	var cid: CharacterBody3D = world.get_node_or_null("Cid") as CharacterBody3D
	var cage: Node3D = world.get_node_or_null("CageZone") as Node3D
	if cid == null or cage == null:
		failures.append("cage walk needs Cid and CageZone")
		world.free()
		return failures
	if world.has_method("run_appoint"):
		await world.run_appoint()
	if _runner:
		_runner.current_id = &"a2_jeronimo"
	var start := cid.global_position
	var dest := cage.global_position
	dest.y = start.y
	var steps := 16
	for i in range(1, steps + 1):
		cid.global_position = start.lerp(dest, float(i) / float(steps))
		cid.velocity = Vector3.ZERO
		await physics_frame
	if _runner and String(_runner.current_id) != "a2_jeronimo":
		failures.append("walking spawn to CageZone must not leave the hub, got %s" % _runner.current_id)
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "babieca_named"])
	if not bool(_runner.can_travel(&"a2_siege", &"a2_jeronimo", flags)):
		failures.append("siege -> jeronimo must stay open")
	if not bool(_runner.can_travel(&"a2_jeronimo", &"a2_embassy2", flags)):
		failures.append("jeronimo -> embassy2 must stay open")
	if bool(_runner.can_travel(&"a2_siege", &"a2_embassy2", flags)):
		failures.append("siege must not skip the Valencia hub")
	if bool(_runner.can_travel(&"a2_jeronimo", &"a2_yusuf", flags)):
		failures.append("hub must not skip embassy2 into Yusuf")
	if bool(_runner.can_travel(&"a2_jeronimo", &"a3_leon", flags)):
		failures.append("hub must not run the lion scene")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ResourceLoader.exists(EMBASSY2):
		failures.append("a2_embassy2 must ship with the hub")
	if not ResourceLoader.exists(LEON):
		failures.append("a3_leon must ship")
	if not ResourceLoader.exists(BUCAR):
		failures.append("a3_bucar must ship")
	if not ResourceLoader.exists("res://content/chapters/a3_despedida/world.tscn"):
		failures.append("a3_despedida must ship")
	if ResourceLoader.exists("res://content/chapters/a3_corpes/world.tscn"):
		failures.append("a3_corpes must not ship in this PR")
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _prep_campaign() -> void:
	_prep_campaign_at(&"a2_jeronimo", PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "valencia_held"]))


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
		print("test_a2_jeronimo: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a2_jeronimo: %s" % failure)
	quit(1)
