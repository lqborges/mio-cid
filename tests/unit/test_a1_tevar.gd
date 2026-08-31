extends SceneTree
## Headless a1_tevar battle / capture / table / Colada test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a1_tevar.gd

const WORLD := "res://content/chapters/a1_tevar/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const MURVIEDRO := "res://content/chapters/a2_murviedro/world.tscn"
const BATTLE_KEY := "a1_tevar.battle"
const EAT_KEY := "a1_tevar.eat_done"
const PLACE_KEY := "a1_tevar.place_name"

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
		failures.append_array(_check_horse_and_cavalry())
		failures.append_array(_check_ramon_from_json())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_table_hidden_until_hunger())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_thinner_refuse_wedge())
	failures.append_array(_check_battle_captures_without_colada())
	failures.append_array(_check_eat_keeps_colada_in_hand())
	failures.append_array(await _check_hunger_presents_eat_line())
	failures.append_array(_check_new_game_resets_swords())
	failures.append_array(await _check_poyo_exit_loads_tevar())
	failures.append_array(_check_cannot_skip_tevar())
	failures.append_array(_check_hub_lock_still_blocks_cardena())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_tevar/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_tevar world did not instantiate")
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
	if _world.get_node_or_null("BattleZone") == null:
		failures.append("world missing BattleZone")
	if _world.get_node_or_null("TableZone") == null:
		failures.append("world missing TableZone")
	if _world.get_node_or_null("TableCamp") == null:
		failures.append("world missing TableCamp")
	if _world.get_node_or_null("TableCamp/Table") == null:
		failures.append("world missing table greybox")
	if _world.get_node_or_null("PineA") == null:
		failures.append("world missing pine CSG")
	if _world.get_node_or_null("Host") == null:
		failures.append("world missing Host")
	if _world.get_node_or_null("Host/Ramon") == null:
		failures.append("world missing Ramón capsule")
	if _world.get_node_or_null("Mesnada") == null:
		failures.append("world missing Mesnada")
	if _world.get_node_or_null("PlaceName") == null:
		failures.append("world missing PlaceName")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_tevar HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a1_tevar HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a1_tevar HUD")
	if _world.find_child("TableChoice", true, false) == null:
		failures.append("table choice missing from a1_tevar HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a1_tevar":
		failures.append("ChapterRunner.current_id want a1_tevar got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden after Navapalos")
	if ResourceLoader.exists(MURVIEDRO):
		failures.append("a2_murviedro must not ship in this PR")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_tevar must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_tevar has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a1_tevar greybox missing pinewood CSG")
	var pines := _world.find_children("*", "CSGCylinder3D", true, false)
	if pines.size() < 8:
		failures.append("a1_tevar greybox missing pine CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a1_tevar sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a1_tevar has GPUParticles3D")
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


func _check_ramon_from_json() -> PackedStringArray:
	var failures: PackedStringArray = []
	var member: MesnadaMember = MesnadaMember.from_id(&"ramon_berenguer")
	if member == null:
		failures.append("ramon_berenguer.json failed to load")
		return failures
	if member.unkillable:
		failures.append("Ramón is capturable; ramon_berenguer.json unkillable is false")
	if member.combat <= 0.0:
		failures.append("Ramón combat must come from JSON and be > 0")
	var ramon: Node = _world.get_node_or_null("Host/Ramon")
	if ramon == null:
		failures.append("Ramon capsule missing")
		return failures
	if "unkillable" in ramon and bool(ramon.get("unkillable")):
		failures.append("Ramon node must not be unkillable")
	var hurt: Node = ramon.get_node_or_null("HurtBox")
	if hurt == null:
		failures.append("Ramon missing HurtBox")
	elif "max_hp" in hurt and not is_equal_approx(float(hurt.max_hp), member.combat):
		failures.append("Ramon hp want combat %s got %s" % [member.combat, hurt.max_hp])
	if hurt and "unkillable" in hurt and bool(hurt.get("unkillable")):
		failures.append("Ramon HurtBox must be killable so capture can fire")
	if ramon is CollisionObject3D and int((ramon as CollisionObject3D).collision_layer) == 0:
		failures.append("Ramon must be collidable at battle start")
	if hurt is Area3D and not (hurt as Area3D).monitorable:
		failures.append("Ramon HurtBox must be monitorable at battle start")
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var battle: Area3D = _world.get_node_or_null("BattleZone") as Area3D
	var table: Area3D = _world.get_node_or_null("TableZone") as Area3D
	if battle == null:
		failures.append("BattleZone missing")
		return failures
	if table == null:
		failures.append("TableZone missing")
		return failures
	if (battle.collision_mask & 130) != 130:
		failures.append("BattleZone must listen for player and horse, mask %s" % battle.collision_mask)
	if (table.collision_mask & 130) != 130:
		failures.append("TableZone must listen for player and horse, mask %s" % table.collision_mask)
	if table.monitoring:
		failures.append("TableZone must stay off until the count is captured")
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var battle := str(_loc.call("text", BATTLE_KEY))
	if battle == BATTLE_KEY or battle.is_empty():
		failures.append("Loc did not resolve a1_tevar.battle")
	if not battle.to_lower().contains("tévar") and not battle.to_lower().contains("tevar"):
		failures.append("battle line Spanish missing Tévar, got %s" % battle)
	if not battle.to_lower().contains("remont"):
		failures.append("battle line must name don Remont, got %s" % battle)
	var eat := str(_loc.call("text", EAT_KEY))
	if eat == EAT_KEY or eat.is_empty():
		failures.append("Loc did not resolve a1_tevar.eat_done")
	var place := str(_loc.call("text", PLACE_KEY))
	if place != "Pinar de Tévar":
		failures.append("place name must be Spanish first, got %s" % place)
	if _world.has_method("_loc"):
		var shown := str(_world.get_node_or_null("PlaceName").get("text")) if _world.get_node_or_null("PlaceName") else ""
		if shown != "Pinar de Tévar":
			failures.append("PlaceName label want Pinar de Tévar got %s" % shown)
	return failures


func _check_table_hidden_until_hunger() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ui: Node = _world.find_child("TableChoice", true, false)
	if ui == null:
		failures.append("TableChoice UI missing on Tévar")
	elif bool(ui.visible):
		failures.append("TableChoice must stay hidden until the hunger strike")
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_battle_started")):
		failures.append("battle started on spawn physics frames")
	if bool(_world.get("_captured")):
		failures.append("capture completed on spawn physics frames")
	if bool(_world.get("_ate")):
		failures.append("table resolved on spawn physics frames")
	var choice: Node = _world.find_child("TableChoice", true, false)
	if choice and bool(choice.visible):
		failures.append("TableChoice must stay hidden on spawn")
	var ramon: Node = _world.get_node_or_null("Host/Ramon")
	if ramon is CollisionObject3D and int((ramon as CollisionObject3D).collision_layer) == 0:
		failures.append("Ramon must stay collidable before capture")
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


func _check_battle_captures_without_colada() -> PackedStringArray:
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
	var honra_before := 0.0
	if _honor:
		honra_before = float(_honor.state.honra)
	if not world.has_method("run_battle"):
		failures.append("world missing run_battle")
		world.free()
		return failures
	world.run_battle()
	if not bool(world.get("_captured")):
		failures.append("run_battle must capture the count")
	if bool(world.get("_ate")):
		failures.append("battle must not skip to the table eat")
	if "tevar_feed_count" in _logged:
		failures.append("capture must not apply tevar_feed_count")
	if _honor and not is_equal_approx(float(_honor.state.honra), honra_before):
		failures.append("capture must not change honra, got %s" % _honor.state.honra)
	var item: SwordItem = _colada()
	if item == null:
		failures.append("GameState missing Colada SwordItem")
	elif item.phase != SwordItem.Phase.NOT_YET:
		failures.append("Colada must stay NOT_YET until the table, got %s" % item.phase_name())
	elif item.lootable():
		failures.append("Colada must never be lootable")
	if _honor and _honor.catalog.has("colada"):
		failures.append("Colada must not be an honor event")
	if _runner and String(_runner.current_id) == "a2_murviedro":
		failures.append("battle must not travel to Murviedro")
	if not _fails.is_empty():
		failures.append("capture must not hard_fail: %s" % ", ".join(_fails))
	var ramon: Node = world.get_node_or_null("Host/Ramon")
	var seat: Node3D = world.get_node_or_null("TableCamp/Seat") as Node3D
	if ramon is Node3D and seat:
		if ramon.global_position.distance_to(seat.global_position) > 0.4:
			failures.append("captured Ramón must sit at the table")
	if ramon:
		if ramon.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("captured Ramón must sit with process off")
		if ramon is CollisionObject3D and int((ramon as CollisionObject3D).collision_layer) != 0:
			failures.append("captured Ramón combat layer must be 0")
		if "unkillable" in ramon and bool(ramon.get("unkillable")):
			failures.append("Ramón must stay killable; capture is not unkillable")
		var hurt: Node = ramon.get_node_or_null("HurtBox")
		if hurt == null:
			failures.append("seated Ramón missing HurtBox")
		else:
			if "hp" in hurt and "max_hp" in hurt and not is_equal_approx(float(hurt.hp), float(hurt.max_hp)):
				failures.append("seated Ramón hp must be restored")
			if hurt is Area3D and (hurt as Area3D).monitorable:
				failures.append("seated Ramón HurtBox must not be monitorable")
		var mesh: MeshInstance3D = ramon.get_node_or_null("Visual/MeshInstance3D") as MeshInstance3D
		if mesh:
			var mat: Material = mesh.material_override
			if mat == null:
				mat = mesh.get_active_material(0)
			if mat is StandardMaterial3D:
				var c: Color = (mat as StandardMaterial3D).albedo_color
				if is_equal_approx(c.r, 0.28) and is_equal_approx(c.g, 0.26) and is_equal_approx(c.b, 0.24):
					failures.append("seated Ramón must not keep the death-grey mesh")
	var dummy: Node = world.get_node_or_null("Host/Dummy1")
	if dummy == null:
		failures.append("Dummy1 missing after capture")
	else:
		if dummy.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("Dummy1 must PROCESS_MODE_DISABLED after capture")
		if dummy is CollisionObject3D and int((dummy as CollisionObject3D).collision_layer) != 0:
			failures.append("Dummy1 collision_layer must be 0 after capture, got %s" % (dummy as CollisionObject3D).collision_layer)
		var dummy_hurt: Area3D = dummy.get_node_or_null("HurtBox") as Area3D
		if dummy_hurt == null:
			failures.append("Dummy1 HurtBox missing")
		elif dummy_hurt.monitorable:
			failures.append("Dummy1 HurtBox must not be monitorable after capture")
		elif dummy_hurt.collision_layer != 0:
			failures.append("Dummy1 HurtBox collision_layer must be 0 after capture")
	var mesnada: Node = world.get_node_or_null("Mesnada")
	if mesnada and str(mesnada.get("order")) != "hold":
		failures.append("capture must hold the mesnada, order %s" % mesnada.get("order"))
	var table: Area3D = world.get_node_or_null("TableZone") as Area3D
	if table and not table.monitoring:
		failures.append("TableZone must open after capture")
	world.free()
	return failures


func _check_eat_keeps_colada_in_hand() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("eat: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	var honra_before := 0.0
	if _honor:
		honra_before = float(_honor.state.honra)
	world.run_battle()
	_logged.clear()
	_completed.clear()
	if not world.has_method("run_eat"):
		failures.append("world missing run_eat skip-cinematic path")
		world.free()
		return failures
	world.run_eat()
	if current_scene != scene_before:
		failures.append("eat must not change_scene when current_scene != world (Murviedro is later)")
	if "tevar_feed_count" not in _logged:
		failures.append("eat must apply tevar_feed_count, logged %s" % str(_logged))
	if "colada" in _logged:
		failures.append("Colada must not be an honor event, logged %s" % str(_logged))
	if not _fails.is_empty():
		failures.append("eat must not hard_fail: %s" % ", ".join(_fails))
	if not bool(world.get("_ate")):
		failures.append("run_eat must force the count to eat")
	if _honor:
		var event: HonorEvent = _honor.event_by_id(&"tevar_feed_count")
		var want := honra_before
		if event:
			want += event.delta_for(&"honra")
		if not is_equal_approx(float(_honor.state.honra), want):
			failures.append("tevar_feed_count honra want %s got %s" % [want, _honor.state.honra])
		if _honor.catalog.has("colada") or _honor.catalog.has("tizona"):
			failures.append("plot swords must not be honor events")
	var item: SwordItem = world.get("colada") as SwordItem
	if item == null:
		item = _colada()
	if item == null:
		failures.append("Colada SwordItem missing after the table")
	else:
		if item.phase != SwordItem.Phase.IN_HAND:
			failures.append("Colada phase want IN_HAND got %s" % item.phase_name())
		if item.lootable():
			failures.append("Colada must not become loot")
		if not item.can_player_wield():
			failures.append("Colada IN_HAND must be wieldable")
		if String(item.acquired_beat) != "a1_tevar":
			failures.append("Colada acquired_beat want a1_tevar got %s" % item.acquired_beat)
	var tizona: SwordItem = _tizona()
	if tizona and tizona.phase != SwordItem.Phase.NOT_YET:
		failures.append("Tizona must stay NOT_YET at Tévar")
	if _completed.count("a1_tevar") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _runner:
		if String(_runner.current_id) != "a2_murviedro":
			failures.append("eat travel must land on a2_murviedro, got %s" % _runner.current_id)
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "colada_acquired" not in flags:
			failures.append("Tévar exit must set colada_acquired")
		if _runner.has_method("can_travel"):
			if bool(_runner.can_travel(&"a1_tevar", &"a1_cardena", flags)):
				failures.append("hub_lock_cardena still blocks cardena")
	if ResourceLoader.exists(MURVIEDRO):
		failures.append("goto must no-op because a2_murviedro is missing")
	world.free()
	return failures


func _check_hunger_presents_eat_line() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("hunger: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_completed.clear()
	if not world.has_method("run_hunger"):
		failures.append("world missing run_hunger")
		world.free()
		return failures
	await world.run_hunger()
	var ui: Node = world.find_child("TableChoice", true, false)
	if ui == null or not bool(ui.visible):
		failures.append("run_hunger must present TableChoice")
	if bool(world.get("_ate")):
		failures.append("hunger must not skip to eat")
	var item: SwordItem = _colada()
	if item and item.phase != SwordItem.Phase.NOT_YET:
		failures.append("Colada must stay NOT_YET until the eat cue")
	var flags: PackedStringArray = _runner.flags if _runner and "flags" in _runner else PackedStringArray()
	if "colada_acquired" in flags:
		failures.append("colada_acquired must wait until after Ramón eats")
	if not world.has_method("choose_eat"):
		failures.append("world missing choose_eat")
		world.free()
		return failures
	await world.choose_eat()
	var speakers: PackedStringArray = world.get("last_dialogue_speakers")
	var keys: PackedStringArray = world.get("last_dialogue_keys")
	var has_ramon := false
	for speaker in speakers:
		var lowered := str(speaker).to_lower()
		if lowered.contains("ramón") or lowered.contains("ramon"):
			has_ramon = true
	if not has_ramon:
		failures.append("eat cue must speak as Ramón before Colada, speakers %s" % str(speakers))
	if "a1_tevar.eat_done" not in keys:
		failures.append("eat cue must play a1_tevar.eat_done before colada_acquired, keys %s" % str(keys))
	if "tevar_feed_count" not in _logged:
		failures.append("eat after hunger must apply tevar_feed_count, logged %s" % str(_logged))
	item = _colada()
	if item == null or item.phase != SwordItem.Phase.IN_HAND:
		failures.append("Colada IN_HAND must follow Ramón's eat line")
	flags = _runner.flags if _runner and "flags" in _runner else PackedStringArray()
	if "colada_acquired" not in flags:
		failures.append("colada_acquired must follow Ramón's eat line")
	world.free()
	return failures


func _check_new_game_resets_swords() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var colada: SwordItem = _colada()
	var tizona: SwordItem = _tizona()
	if colada:
		colada.phase = SwordItem.Phase.IN_HAND
	if tizona:
		tizona.phase = SwordItem.Phase.IN_HAND
	var packed: Resource = load("res://game/ui/main_menu.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("main_menu.tscn failed to load")
		return failures
	var menu: Node = (packed as PackedScene).instantiate()
	root.add_child(menu)
	if not menu.has_method("_reset_campaign"):
		failures.append("main_menu missing _reset_campaign")
		menu.free()
		return failures
	menu.call("_reset_campaign")
	colada = _colada()
	tizona = _tizona()
	if colada == null or colada.phase != SwordItem.Phase.NOT_YET:
		failures.append("New Game must reset Colada to NOT_YET, got %s" % (colada.phase_name() if colada else "missing"))
	if tizona == null or tizona.phase != SwordItem.Phase.NOT_YET:
		failures.append("New Game must reset Tizona to NOT_YET, got %s" % (tizona.phase_name() if tizona else "missing"))
	menu.free()
	return failures


func _check_poyo_exit_loads_tevar() -> PackedStringArray:
	var failures: PackedStringArray = []
	await process_frame
	if _runner == null:
		failures.append("ChapterRunner missing for Poyo TevarExit")
		return failures
	if _runner.has_method("restore"):
		_runner.restore(&"a1_poyo", PackedStringArray(["poyo_named", "hub_lock_cardena", "horse_companion"]))
	var packed: Resource = load("res://content/chapters/a1_poyo/world.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("a1_poyo/world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	if not world.has_method("travel_to_tevar"):
		failures.append("poyo missing travel_to_tevar")
		world.free()
		current_scene = null
		return failures
	if not bool(world.call("travel_to_tevar")):
		failures.append("Poyo TevarExit travel_to_tevar must succeed")
		if is_instance_valid(world):
			world.free()
		current_scene = null
		return failures
	for _i in range(8):
		await process_frame
	var scene := current_scene
	var path := ""
	if scene != null:
		path = str(scene.scene_file_path)
	if path.find("a1_tevar/world.tscn") < 0:
		failures.append("Poyo TevarExit must change_scene into a1_tevar/world.tscn, got %s" % path)
	if is_instance_valid(world) and world != current_scene:
		world.queue_free()
	if current_scene != null:
		var leftover: Node = current_scene
		current_scene = null
		leftover.queue_free()
	await process_frame
	await process_frame
	return failures


func _check_cannot_skip_tevar() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "poyo_named", "horse_companion"])
	if not bool(_runner.can_travel(&"a1_poyo", &"a1_tevar", flags)):
		failures.append("Tévar must stay the forward exit from Poyo")
	if bool(_runner.can_travel(&"a1_poyo", &"a2_murviedro", flags)):
		failures.append("Poyo must not skip Tévar into Act II")
	if bool(_runner.can_travel(&"a1_embassy1", &"a1_tevar", flags)):
		failures.append("Act I must not skip Poyo into Tévar")
	if _runner.has_method("restore"):
		_runner.restore(&"a1_poyo", flags)
		if bool(_runner.travel(&"a2_murviedro")):
			failures.append("travel poyo -> murviedro must fail")
		if String(_runner.current_id) == "a2_murviedro":
			failures.append("current_id must not skip Tévar")
		if not bool(_runner.travel(&"a1_tevar")):
			failures.append("Poyo -> Tévar travel should succeed")
		if String(_runner.current_id) != "a1_tevar":
			failures.append("forward exit must land on a1_tevar")
	return failures


func _check_hub_lock_still_blocks_cardena() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	var locked := PackedStringArray(["hub_lock_cardena", "horse_companion"])
	if _runner.has_method("restore"):
		_runner.restore(&"a1_tevar", locked)
	else:
		_runner.current_id = &"a1_tevar"
		_runner.flags = locked
	var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
	if _runner.has_method("can_travel"):
		if bool(_runner.can_travel(&"a1_tevar", &"a1_cardena", flags)):
			failures.append("can_travel tevar -> cardena must be false after hub lock")
		if bool(_runner.can_travel(&"a1_tevar", &"a1_poyo", flags)):
			failures.append("can_travel tevar -> poyo must be false")
		if not bool(_runner.can_travel(&"a1_tevar", &"a2_murviedro", flags)):
			failures.append("can_travel tevar -> murviedro should be true")
	_prep_campaign()
	var packed: Resource = load(WORLD)
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	if bool(world.call("can_return_to_cardena")):
		failures.append("world.can_return_to_cardena must be false")
	if bool(world.call("try_travel_cardena")):
		failures.append("try_travel_cardena must fail")
	if String(_runner.current_id) == "a1_cardena":
		failures.append("travel must not land on Cardeña")
	world.free()
	return failures


func _colada() -> SwordItem:
	if _state and _state.has_method("sword"):
		return _state.sword(&"colada") as SwordItem
	return null


func _tizona() -> SwordItem:
	if _state and _state.has_method("sword"):
		return _state.sword(&"tizona") as SwordItem
	return null


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
			_runner.restore(&"a1_tevar", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena", "horse_companion"])
			if "current_id" in _runner:
				_runner.current_id = &"a1_tevar"
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
		print("test_a1_tevar: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_tevar: %s" % failure)
	quit(1)
