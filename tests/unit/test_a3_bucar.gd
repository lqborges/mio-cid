extends SceneTree
## Headless a3_bucar shore battle / Infantes flee / Tizona test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a3_bucar.gd

const WORLD := "res://content/chapters/a3_bucar/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const DESPEDIDA := "res://content/chapters/a3_despedida/world.tscn"
const CORPES := "res://content/chapters/a3_corpes/world.tscn"
const BATTLE_KEY := "a3_bucar.battle"
const PLACE_KEY := "a3_bucar.place_name"
const COWARDICE_FLAGS := ["infantes_fled_bucar", "captains_covered_bucar"]

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
		failures.append_array(_check_horse_named())
		failures.append_array(_check_bucar_from_json())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_spanish_copy())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_thinner_refuse_wedge())
	failures.append_array(_check_battle_flees_without_tizona())
	failures.append_array(_check_win_keeps_tizona_in_hand())
	failures.append_array(await _check_win_line_keeps_tizona())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a3_bucar/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a3_bucar world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	for path in [
		"Horse",
		"BattleZone",
		"Water",
		"Shore",
		"Wall",
		"PalmA",
		"Host",
		"Host/Bucar",
		"Infantes",
		"Infantes/Ferran",
		"Infantes/Diego",
		"Mesnada",
		"PlaceName",
	]:
		if _world.get_node_or_null(path) == null:
			failures.append("world missing %s" % path)
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a3_bucar HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a3_bucar HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a3_bucar HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a3_bucar":
		failures.append("ChapterRunner.current_id want a3_bucar got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	if ResourceLoader.exists(DESPEDIDA):
		failures.append("a3_despedida must not ship in this PR")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a3_bucar must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a3_bucar has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a3_bucar greybox missing shore CSG")
	var palms := _world.find_children("*", "CSGCylinder3D", true, false)
	if palms.size() < 8:
		failures.append("a3_bucar greybox missing palm CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a3_bucar sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a3_bucar has GPUParticles3D")
	return failures


func _check_horse_named() -> PackedStringArray:
	var failures: PackedStringArray = []
	var horse: Node = _world.get_node_or_null("Horse")
	if horse == null:
		failures.append("Horse missing")
		return failures
	if horse.get_node_or_null("CavalryCharge") == null:
		failures.append("Horse missing CavalryCharge (couch lance)")
	if not horse.is_in_group("horse_companion"):
		failures.append("Horse must be in horse_companion group")
	if horse.has_method("debug_id") and String(horse.debug_id()) != "babieca":
		failures.append("Valencia horse must be named Babieca, got %s" % horse.debug_id())
	var packed: Resource = load(HORSE)
	if packed == null:
		failures.append("horse.tscn failed to load")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "babieca_named" not in flags:
			failures.append("shore arrival must keep babieca_named")
	return failures


func _check_bucar_from_json() -> PackedStringArray:
	var failures: PackedStringArray = []
	var member: MesnadaMember = MesnadaMember.from_id(&"bucar")
	if member == null:
		failures.append("bucar.json failed to load")
		return failures
	if member.unkillable:
		failures.append("Búcar is a fight; bucar.json unkillable is false")
	if not is_equal_approx(member.combat, 68.0):
		failures.append("Búcar combat want 68 got %s" % member.combat)
	if String(member.role) != "taifa_king":
		failures.append("Búcar role want taifa_king got %s" % member.role)
	var bucar: Node = _world.get_node_or_null("Host/Bucar")
	if bucar == null:
		failures.append("Bucar capsule missing")
		return failures
	if "unkillable" in bucar and bool(bucar.get("unkillable")):
		failures.append("Bucar node must not be unkillable")
	var hurt: Node = bucar.get_node_or_null("HurtBox")
	if hurt == null:
		failures.append("Bucar missing HurtBox")
	elif "max_hp" in hurt and not is_equal_approx(float(hurt.max_hp), member.combat):
		failures.append("Bucar hp want combat %s got %s" % [member.combat, hurt.max_hp])
	if hurt and "unkillable" in hurt and bool(hurt.get("unkillable")):
		failures.append("Bucar HurtBox must be killable so the win can fire")
	if bucar is CollisionObject3D and int((bucar as CollisionObject3D).collision_layer) == 0:
		failures.append("Bucar must be collidable at battle start")
	if hurt is Area3D and not (hurt as Area3D).monitorable:
		failures.append("Bucar HurtBox must be monitorable at battle start")
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var battle: Area3D = _world.get_node_or_null("BattleZone") as Area3D
	if battle == null:
		failures.append("BattleZone missing")
		return failures
	if (battle.collision_mask & 130) != 130:
		failures.append("BattleZone must listen for player and horse, mask %s" % battle.collision_mask)
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var battle := str(_loc.call("text", BATTLE_KEY))
	if battle == BATTLE_KEY or battle.is_empty():
		failures.append("Loc did not resolve a3_bucar.battle")
	if not battle.to_lower().contains("búcar") and not battle.to_lower().contains("bucar"):
		failures.append("battle line Spanish missing Búcar, got %s" % battle)
	var flee := str(_loc.call("text", "a3_bucar.flee"))
	if not flee.to_lower().contains("huyen"):
		failures.append("flee line Spanish missing huyen, got %s" % flee)
	var cover := str(_loc.call("text", "a3_bucar.cover"))
	if not cover.to_lower().contains("capitanes"):
		failures.append("cover line Spanish missing capitanes, got %s" % cover)
	var kept := str(_loc.call("text", "a3_bucar.tizona_kept"))
	if not kept.contains("Tizona"):
		failures.append("Tizona keep line Spanish missing Tizona, got %s" % kept)
	var place := str(_loc.call("text", PLACE_KEY))
	if place != "Playa de Valencia":
		failures.append("place name must be Spanish first, got %s" % place)
	if _world.has_method("place_name_text") and str(_world.place_name_text()) != "Playa de Valencia":
		failures.append("PlaceName want Playa de Valencia got %s" % _world.place_name_text())
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_battle_started")):
		failures.append("battle started on spawn physics frames")
	if bool(_world.get("_fled")):
		failures.append("infantes fled on spawn physics frames")
	if bool(_world.get("_won")):
		failures.append("win fired on spawn physics frames")
	var ferran: Node = _world.get_node_or_null("Infantes/Ferran")
	if ferran is CollisionObject3D and int((ferran as CollisionObject3D).collision_layer) == 0:
		failures.append("Infantes must be collidable before they flee")
	return failures


func _check_thinner_refuse_wedge() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _honor:
		_honor.roster = MesnadaRoster.from_starting_seed()
		_honor.roster.lanzas = 6
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
		failures.append("refuse wedge must not fake a full lanza wall, got %s bodies" % n)
	if n != 6:
		failures.append("refuse lanzas want 6 bodies, got %s" % n)
	world.free()
	return failures


func _check_battle_flees_without_tizona() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("battle: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var honor_before := 0.0
	if _honor and _honor.state:
		honor_before = float(_honor.state.honor)
	if not world.has_method("run_battle"):
		failures.append("world missing run_battle")
		world.free()
		return failures
	world.run_battle()
	if not bool(world.get("_battle_started")):
		failures.append("run_battle must start the shore fight")
	if not bool(world.get("_fled")):
		failures.append("run_battle must record the Infantes fleeing")
	if not bool(world.get("_covered")):
		failures.append("run_battle must record captains covering")
	if bool(world.get("_won")):
		failures.append("battle must not skip to Tizona")
	if "bucar_win" in _logged:
		failures.append("flee must not apply bucar_win")
	if _honor and not is_equal_approx(float(_honor.state.honor), honor_before):
		failures.append("flee must not change honor, got %s" % _honor.state.honor)
	var item: SwordItem = _tizona()
	if item == null:
		failures.append("GameState missing Tizona SwordItem")
	elif item.phase != SwordItem.Phase.NOT_YET:
		failures.append("Tizona must stay NOT_YET until Búcar falls, got %s" % item.phase_name())
	elif item.lootable():
		failures.append("Tizona must never be lootable")
	if _honor and _honor.catalog.has("tizona"):
		failures.append("Tizona must not be an honor event")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		for flag in COWARDICE_FLAGS:
			if flag not in flags:
				failures.append("cowardice flag missing after battle: %s" % flag)
		if "tizona_acquired" in flags:
			failures.append("tizona_acquired must wait until the win")
		if String(_runner.current_id) == "a3_despedida":
			failures.append("battle must not travel to despedida")
	if not _fails.is_empty():
		failures.append("flee must not hard_fail: %s" % ", ".join(_fails))
	var ferran: Node = world.get_node_or_null("Infantes/Ferran")
	if ferran == null:
		failures.append("Ferran missing after flee")
	else:
		if ferran.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("Ferran must PROCESS_MODE_DISABLED after flee")
		if ferran is CollisionObject3D and int((ferran as CollisionObject3D).collision_layer) != 0:
			failures.append("Ferran collision_layer must be 0 after flee, got %s" % (ferran as CollisionObject3D).collision_layer)
		var ferran_hurt: Area3D = ferran.get_node_or_null("HurtBox") as Area3D
		if ferran_hurt == null:
			failures.append("Ferran HurtBox missing")
		elif ferran_hurt.monitorable:
			failures.append("Ferran HurtBox must not be monitorable after flee")
		elif ferran_hurt.collision_layer != 0:
			failures.append("Ferran HurtBox collision_layer must be 0 after flee")
	var diego: Node = world.get_node_or_null("Infantes/Diego")
	if diego and diego is CollisionObject3D and int((diego as CollisionObject3D).collision_layer) != 0:
		failures.append("Diego collision_layer must be 0 after flee")
	var bucar: Node = world.get_node_or_null("Host/Bucar")
	if bucar is CollisionObject3D and int((bucar as CollisionObject3D).collision_layer) == 0:
		failures.append("Bucar must stay collidable until the win")
	var pero: Node3D = world.get_node_or_null("Mesnada/PeroBermudez") as Node3D
	if pero and pero.global_position.distance_to(Vector3(-1.8, 0.05, 11.2)) > 0.8:
		failures.append("Pero Bermúdez must cover the Infantes' gap")
	world.free()
	return failures


func _check_win_keeps_tizona_in_hand() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("win: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	var honor_before := 0.0
	if _honor and _honor.state:
		honor_before = float(_honor.state.honor)
	var colada: SwordItem = _colada()
	if colada:
		colada.phase = SwordItem.Phase.IN_HAND
	world.run_battle()
	_logged.clear()
	_completed.clear()
	if not world.has_method("run_win"):
		failures.append("world missing run_win skip-cinematic path")
		world.free()
		return failures
	world.run_win()
	if current_scene != scene_before:
		failures.append("win must not change_scene when current_scene != world")
	if "bucar_win" not in _logged:
		failures.append("win must apply bucar_win, logged %s" % str(_logged))
	if "tizona" in _logged:
		failures.append("Tizona must not be an honor event, logged %s" % str(_logged))
	if not _fails.is_empty():
		failures.append("win must not hard_fail: %s" % ", ".join(_fails))
	if not bool(world.get("_won")):
		failures.append("run_win must finish the shore fight")
	if _honor:
		var event: Variant = _honor.event_by_id(&"bucar_win")
		var want := honor_before
		if event and event.has_method("delta_for"):
			want += float(event.call("delta_for", &"honor"))
		if not is_equal_approx(float(_honor.state.honor), want):
			failures.append("bucar_win honor want %s got %s" % [want, _honor.state.honor])
		if _honor.catalog.has("colada") or _honor.catalog.has("tizona"):
			failures.append("plot swords must not be honor events")
	var item: SwordItem = world.get("tizona") as SwordItem
	if item == null:
		item = _tizona()
	if item == null:
		failures.append("Tizona SwordItem missing after the shore")
	else:
		if item.phase != SwordItem.Phase.IN_HAND:
			failures.append("Tizona phase want IN_HAND got %s" % item.phase_name())
		if item.lootable():
			failures.append("Tizona must not become loot")
		if not item.can_player_wield():
			failures.append("Tizona IN_HAND must be wieldable")
		if String(item.acquired_beat) != "a3_bucar":
			failures.append("Tizona acquired_beat want a3_bucar got %s" % item.acquired_beat)
		if String(item.lists_champion) != "pero_bermudez":
			failures.append("Tizona lists champion want pero_bermudez got %s" % item.lists_champion)
	colada = _colada()
	if colada and colada.phase != SwordItem.Phase.IN_HAND:
		failures.append("Colada must stay IN_HAND at Búcar")
	if _completed.count("a3_bucar") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _runner:
		if String(_runner.current_id) != "a3_bucar":
			failures.append("win must stay on a3_bucar until despedida ships, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "tizona_acquired" not in flags:
			failures.append("win must set tizona_acquired")
		for flag in COWARDICE_FLAGS:
			if flag not in flags:
				failures.append("cowardice flag dropped after win: %s" % flag)
		if bool(world.get("_left")):
			failures.append("must not _left into missing a3_despedida")
		if _runner.has_method("can_travel") and not bool(_runner.can_travel(&"a3_bucar", &"a3_despedida", flags)):
			failures.append("bucar -> despedida must stay open")
	var bucar: Node = world.get_node_or_null("Host/Bucar")
	if bucar:
		if bucar.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("defeated Búcar must PROCESS_MODE_DISABLED")
		if bucar is CollisionObject3D and int((bucar as CollisionObject3D).collision_layer) != 0:
			failures.append("defeated Búcar collision_layer must be 0")
		var hurt: Area3D = bucar.get_node_or_null("HurtBox") as Area3D
		if hurt and hurt.monitorable:
			failures.append("defeated Búcar HurtBox must not be monitorable")
	var mesnada: Node = world.get_node_or_null("Mesnada")
	if mesnada and str(mesnada.get("order")) != "hold":
		failures.append("win must hold the mesnada, order %s" % mesnada.get("order"))
	world.free()
	return failures


func _check_win_line_keeps_tizona() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("win line: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_completed.clear()
	if not world.has_method("start_win"):
		failures.append("world missing start_win")
		world.free()
		return failures
	world.run_battle()
	await world.start_win()
	if not bool(world.get("_won")):
		world.run_win()
	var speakers: PackedStringArray = world.get("last_dialogue_speakers")
	var keys: PackedStringArray = world.get("last_dialogue_keys")
	var has_cid := false
	for speaker in speakers:
		if str(speaker).to_lower().contains("cid"):
			has_cid = true
	if speakers.size() > 0 and not has_cid:
		failures.append("win cue must speak as Cid, speakers %s" % str(speakers))
	if keys.size() > 0 and "a3_bucar.tizona_kept" not in keys:
		failures.append("win cue must play a3_bucar.tizona_kept, keys %s" % str(keys))
	if "bucar_win" not in _logged:
		failures.append("win after dialogue must apply bucar_win, logged %s" % str(_logged))
	var item: SwordItem = _tizona()
	if item == null or item.phase != SwordItem.Phase.IN_HAND:
		failures.append("Tizona IN_HAND must follow the keep line")
	var flags: PackedStringArray = _runner.flags if _runner and "flags" in _runner else PackedStringArray()
	if "tizona_acquired" not in flags:
		failures.append("tizona_acquired must follow the keep line")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "lion_returned"])
	if not bool(_runner.can_travel(&"a3_leon", &"a3_bucar", flags)):
		failures.append("leon -> bucar must stay open after lion_returned")
	if not bool(_runner.can_travel(&"a3_bucar", &"a3_despedida", flags)):
		failures.append("bucar -> despedida must stay open")
	if bool(_runner.can_travel(&"a3_leon", &"a3_despedida", flags)):
		failures.append("leon must not skip Búcar")
	if bool(_runner.can_travel(&"a3_bucar", &"a3_corpes", flags)):
		failures.append("bucar must not skip to Corpes")
	if bool(_runner.can_travel(&"a2_bodas", &"a3_bucar", flags)):
		failures.append("bodas must not skip the lion scene")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if ResourceLoader.exists(DESPEDIDA):
		failures.append("a3_despedida must not ship in this PR")
	if ResourceLoader.exists(CORPES):
		failures.append("a3_corpes must not ship in this PR")
	if not ResourceLoader.exists(LEON):
		failures.append("a3_leon world must keep shipping")
	if not ResourceLoader.exists(WORLD):
		failures.append("a3_bucar world must exist")
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
			_runner.restore(
				&"a3_bucar",
				PackedStringArray(
					["hub_lock_cardena", "horse_companion", "colada_acquired", "lion_returned", "babieca_named"]
				)
			)
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(
					["hub_lock_cardena", "horse_companion", "colada_acquired", "lion_returned", "babieca_named"]
				)
			if "current_id" in _runner:
				_runner.current_id = &"a3_bucar"
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


func _colada() -> SwordItem:
	if _state and _state.has_method("sword"):
		return _state.sword(&"colada") as SwordItem
	return null


func _tizona() -> SwordItem:
	if _state and _state.has_method("sword"):
		return _state.sword(&"tizona") as SwordItem
	return null


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a3_bucar: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_bucar: %s" % failure)
	quit(1)
