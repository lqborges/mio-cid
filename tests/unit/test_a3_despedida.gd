extends SceneTree
## Headless a3_despedida departure / swords gifted / Avengalvón road test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a3_despedida.gd

const WORLD := "res://content/chapters/a3_despedida/world.tscn"
const BUCAR := "res://content/chapters/a3_bucar/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const EMBASSY2 := "res://content/chapters/a2_embassy2/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const HORSE := "res://content/art/characters/horse/horse.tscn"
const CORPES := "res://content/chapters/a3_corpes/world.tscn"
const PROMPT_KEY := "a3_despedida.prompt"
const PLACE_KEY := "a3_despedida.place_name"
const FAIL_KEY := "fail.avengalvon_dead"

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
var _sword_phases: PackedStringArray = PackedStringArray()


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
		failures.append_array(_check_avengalvon_from_json())
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_spanish_copy())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_agree_gifts_swords())
	failures.append_array(await _check_depart_line_gifts_swords())
	failures.append_array(_check_ambush_lets_him_go())
	failures.append_array(_check_dead_avengalvon_reloads())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a3_despedida/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a3_despedida world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	for path in [
		"Horse",
		"GiftZone",
		"AmbushZone",
		"Hall",
		"GiftTable",
		"Avengalvon",
		"Jimena",
		"Elvira",
		"Sol",
		"Infantes",
		"Infantes/Ferran",
		"Infantes/Diego",
		"Mesnada",
		"PlaceName",
	]:
		if _world.get_node_or_null(path) == null:
			failures.append("world missing %s" % path)
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a3_despedida HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a3_despedida HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a3_despedida HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a3_despedida":
		failures.append("ChapterRunner.current_id want a3_despedida got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	if ResourceLoader.exists(CORPES):
		failures.append("a3_corpes must not ship in this PR")
	if not ResourceLoader.exists(BUCAR):
		failures.append("a3_bucar world must keep shipping")
	if not ResourceLoader.exists(LEON):
		failures.append("a3_leon world must keep shipping")
	if not ResourceLoader.exists(EMBASSY2):
		failures.append("a2_embassy2 world must keep shipping")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a3_despedida must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a3_despedida has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a3_despedida greybox missing hall/road CSG")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 2:
		failures.append("a3_despedida greybox missing road trees")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a3_despedida sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a3_despedida has GPUParticles3D")
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
			failures.append("hall arrival must keep babieca_named")
	return failures


func _check_avengalvon_from_json() -> PackedStringArray:
	var failures: PackedStringArray = []
	var member: MesnadaMember = MesnadaMember.from_id(&"avengalvon")
	if member == null:
		failures.append("avengalvon.json failed to load")
		return failures
	if not member.essential:
		failures.append("Avengalvón must be essential")
	if String(member.must_survive_until) != "a3_despedida":
		failures.append("Avengalvón must_survive_until want a3_despedida got %s" % member.must_survive_until)
	var roster: Variant = _honor.roster if _honor else null
	if roster and roster.has_method("member"):
		var kept: Variant = roster.member(&"avengalvon")
		if kept == null:
			failures.append("chapter must restore Avengalvón to the roster")
		elif not bool(kept.alive):
			failures.append("restored Avengalvón must start alive")
		elif not bool(kept.essential):
			failures.append("restored Avengalvón must stay essential")
	var body: Node = _world.get_node_or_null("Avengalvon")
	if body == null:
		failures.append("Avengalvón capsule missing")
		return failures
	if not bool(body.visible):
		failures.append("Avengalvón must stay visible")
	var hurt: Node = body.get_node_or_null("HurtBox")
	if hurt == null:
		failures.append("Avengalvón missing HurtBox")
	elif "spectator" in hurt and bool(hurt.get("spectator")):
		failures.append("Avengalvón HurtBox must not be spectator")
	if body is CollisionObject3D and int((body as CollisionObject3D).collision_layer) == 0:
		failures.append("Avengalvón must be collidable at start")
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	for path in ["GiftZone", "AmbushZone"]:
		var zone: Area3D = _world.get_node_or_null(path) as Area3D
		if zone == null:
			failures.append("%s missing" % path)
			continue
		if (zone.collision_mask & 130) != 130:
			failures.append("%s must listen for player and horse, mask %s" % [path, zone.collision_mask])
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var prompt := str(_loc.call("text", PROMPT_KEY))
	if prompt == PROMPT_KEY or prompt.is_empty():
		failures.append("Loc did not resolve a3_despedida.prompt")
	if not prompt.to_lower().contains("elvira") and not prompt.to_lower().contains("sol"):
		failures.append("departure prompt must name the daughters, got %s" % prompt)
	var swords := str(_loc.call("text", "a3_despedida.swords"))
	if not swords.contains("Colada") or not swords.contains("Tizona"):
		failures.append("gift copy must name both swords, got %s" % swords)
	var lets := str(_loc.call("text", "a3_despedida.lets_go"))
	if not lets.to_lower().contains("avengalv"):
		failures.append("lets-go copy must keep Avengalvón, got %s" % lets)
	var fail := str(_loc.call("text", FAIL_KEY))
	if fail == FAIL_KEY or fail.is_empty():
		failures.append("Loc did not resolve fail.avengalvon_dead")
	if fail.to_lower() == "the name is empty":
		failures.append("Avengalvón fail copy must not be the English stub")
	if not fail.contains("Avengalvón"):
		failures.append("Avengalvón fail copy must be Spanish, got %s" % fail)
	var place := str(_loc.call("text", PLACE_KEY))
	if not place.to_lower().contains("valencia"):
		failures.append("place name must be Valencia, got %s" % place)
	var shown := ""
	var label: Label3D = _world.get_node_or_null("PlaceName") as Label3D
	if label:
		shown = label.text
	if shown != place and shown != "":
		failures.append("PlaceName want %s got %s" % [place, shown])
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	var tree := self
	for _i in range(3):
		await tree.physics_frame
	if bool(_world.get("_agreed")) or bool(_world.get("_gifted")):
		failures.append("spawn must not auto-gift the swords")
	if bool(_world.get("_ambush_started")) or bool(_world.get("_let_go")):
		failures.append("spawn must not auto-run the road ambush")
	if bool(_world.get("_failed")):
		failures.append("living Avengalvón must not fail-copy on spawn")
	var colada: SwordItem = _colada()
	var tizona: SwordItem = _tizona()
	if colada and colada.phase != SwordItem.Phase.IN_HAND:
		failures.append("Colada must stay IN_HAND until the gift, got %s" % colada.phase_name())
	if tizona and tizona.phase != SwordItem.Phase.IN_HAND:
		failures.append("Tizona must stay IN_HAND until the gift, got %s" % tizona.phase_name())
	return failures


func _check_agree_gifts_swords() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("gift: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_completed.clear()
	_sword_phases.clear()
	var scene_before: Node = current_scene
	if not world.has_method("run_departure"):
		failures.append("world missing run_departure")
		world.free()
		return failures
	world.run_departure()
	if not bool(world.get("_agreed")):
		failures.append("run_departure must agree to the leaving")
	if not bool(world.get("_gifted")):
		failures.append("agreeing must gift the swords")
	if not bool(world.call("swords_gifted")):
		failures.append("swords_gifted() must be true after the gift")
	var colada: SwordItem = world.get("colada") as SwordItem
	if colada == null:
		colada = _colada()
	var tizona: SwordItem = world.get("tizona") as SwordItem
	if tizona == null:
		tizona = _tizona()
	for item in [colada, tizona]:
		if item == null:
			failures.append("SwordItem missing after the gift")
			continue
		if item.phase != SwordItem.Phase.GIFTED_TO_INFANTES:
			failures.append("%s phase want GIFTED_TO_INFANTES got %s" % [item.id, item.phase_name()])
		if item.lootable():
			failures.append("%s must not become loot" % item.id)
		if item.can_player_wield():
			failures.append("%s GIFTED_TO_INFANTES must not be wieldable" % item.id)
	if _honor and (_honor.catalog.has("colada") or _honor.catalog.has("tizona")):
		failures.append("plot swords must not be honor events")
	if current_scene != scene_before:
		failures.append("gift must not change_scene when current_scene != world")
	if bool(world.get("_let_go")):
		failures.append("gift must not skip to the road let-go")
	if bool(world.get("_left")):
		failures.append("gift must not travel to missing Corpes")
	var elvira: Node = world.get_node_or_null("Elvira")
	if elvira:
		if elvira.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("Elvira must PROCESS_MODE_DISABLED after leaving")
		if elvira is CollisionObject3D and int((elvira as CollisionObject3D).collision_layer) != 0:
			failures.append("Elvira collision_layer must be 0 after leaving")
		if elvira is Node3D and bool((elvira as Node3D).visible):
			failures.append("Elvira must hide after leaving")
	var jimena: Node = world.get_node_or_null("Jimena")
	if jimena == null or not bool(jimena.visible):
		failures.append("Jimena must stay in Valencia")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "swords_gifted" not in flags:
			failures.append("gift must set swords_gifted")
		if "daughters_left" not in flags:
			failures.append("gift must set daughters_left")
		if String(_runner.current_id) == "a3_corpes":
			failures.append("gift must not travel to Corpes")
	if _completed.count("a3_despedida") > 0:
		failures.append("gift must not complete the beat, got %s" % str(_completed))
	world.free()
	return failures


func _check_depart_line_gifts_swords() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("depart line: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	if not world.has_method("start_departure"):
		failures.append("world missing start_departure")
		world.free()
		return failures
	await world.start_departure()
	if not bool(world.get("_agreed")):
		world.run_departure()
	var speakers: PackedStringArray = world.get("last_dialogue_speakers")
	var keys: PackedStringArray = world.get("last_dialogue_keys")
	var has_cid := false
	for speaker in speakers:
		if str(speaker).to_lower().contains("cid"):
			has_cid = true
	if speakers.size() > 0 and not has_cid:
		failures.append("depart cue must speak as Cid, speakers %s" % str(speakers))
	if keys.size() > 0 and "a3_despedida.agree" not in keys and "a3_despedida.prompt" not in keys:
		failures.append("depart cue must play departure keys, keys %s" % str(keys))
	var item: SwordItem = _colada()
	if item == null or item.phase != SwordItem.Phase.GIFTED_TO_INFANTES:
		failures.append("Colada GIFTED_TO_INFANTES must follow the agree line")
	world.free()
	return failures


func _check_ambush_lets_him_go() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("ambush: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_fails.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	world.run_ambush()
	if not bool(world.get("_ambush_started")):
		failures.append("run_ambush must start the murder attempt")
	if not bool(world.get("_let_go")):
		failures.append("run_ambush must let Avengalvón go")
	if bool(world.get("_failed")):
		failures.append("Avengalvón must survive the road")
	if not bool(world.call("avengalvon_survived")):
		failures.append("avengalvon_survived() must be true after let-go")
	if not _fails.is_empty():
		failures.append("let-go must not hard_fail: %s" % ", ".join(_fails))
	var body: Node = world.get_node_or_null("Avengalvon")
	if body == null or not bool(body.visible):
		failures.append("Avengalvón capsule must stay after he lets them go")
	if body is CollisionObject3D and int((body as CollisionObject3D).collision_layer) == 0:
		failures.append("living Avengalvón must stay collidable")
	var ferran: Node = world.get_node_or_null("Infantes/Ferran")
	if ferran:
		if ferran.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("Ferran must PROCESS_MODE_DISABLED after let-go")
		if ferran is CollisionObject3D and int((ferran as CollisionObject3D).collision_layer) != 0:
			failures.append("Ferran collision_layer must be 0 after let-go")
	var roster: Variant = _honor.roster if _honor else null
	if roster and roster.has_method("member"):
		var member: Variant = roster.member(&"avengalvon")
		if member == null or not bool(member.alive):
			failures.append("roster Avengalvón must stay alive")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "avengalvon_alive_despedida" not in flags:
			failures.append("let-go must set avengalvon_alive_despedida")
		if "swords_gifted" not in flags:
			failures.append("ambush path must still gift the swords")
		if String(_runner.current_id) == "a3_corpes":
			failures.append("must not travel into missing a3_corpes")
	if bool(world.get("_left")):
		failures.append("must not _left into missing a3_corpes")
	if current_scene != scene_before:
		failures.append("let-go must not change_scene when current_scene != world")
	if _completed.count("a3_despedida") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _completed.count("a3_despedida") < 1:
		failures.append("missing dest must still complete a3_despedida once")
	var cid: Node = world.get_node_or_null("Cid")
	var mesura: Node = cid.get_node_or_null("Mesura") if cid else null
	if mesura and mesura.has_method("has_trait") and not bool(mesura.call("has_trait", &"keep_avengalvon")):
		failures.append("keep_avengalvon trait must unlock when he lives")
	world.free()
	return failures


func _check_dead_avengalvon_reloads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _honor and _honor.roster:
		var member := MesnadaMember.from_id(&"avengalvon")
		if member:
			member.alive = false
			_honor.roster.add_member(member)
			var kept: Variant = _honor.roster.member(&"avengalvon")
			if kept:
				kept.alive = false
	_fails.clear()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("dead: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	if not bool(world.get("_failed")):
		failures.append("dead Avengalvón at start must fail-copy")
	if &"avengalvon_dead" not in _fails and "avengalvon_dead" not in _fails:
		failures.append("dead Avengalvón must emit hard_fail avengalvon_dead, got %s" % str(_fails))
	var last := _fail_copy_reason()
	if last != &"avengalvon_dead":
		failures.append("FailCopy.last_reason want avengalvon_dead got %s" % last)
	if _loc:
		var copy := str(_loc.call("text", FAIL_KEY))
		if copy.to_lower() == "the name is empty" or copy == FAIL_KEY:
			failures.append("fail copy must use Loc Spanish, got %s" % copy)
	if world.has_method("run_departure"):
		world.run_departure()
	var colada: SwordItem = _colada()
	if colada and colada.phase == SwordItem.Phase.GIFTED_TO_INFANTES:
		failures.append("dead Avengalvón must block the gift")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "colada_acquired", "lion_returned"])
	if bool(_runner.can_travel(&"a3_bucar", &"a3_despedida", flags)):
		failures.append("bucar -> despedida must wait for tizona_acquired")
	flags.append("tizona_acquired")
	if not bool(_runner.can_travel(&"a3_bucar", &"a3_despedida", flags)):
		failures.append("bucar -> despedida must stay open after tizona_acquired")
	if bool(_runner.can_travel(&"a3_leon", &"a3_despedida", flags)):
		failures.append("leon must not skip Búcar")
	if bool(_runner.can_travel(&"a3_bucar", &"a3_corpes", flags)):
		failures.append("bucar must not skip to Corpes")
	if not bool(_runner.can_travel(&"a3_despedida", &"a3_corpes", flags)):
		failures.append("despedida -> corpes must stay open")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if ResourceLoader.exists(CORPES):
		failures.append("a3_corpes must not ship in this PR")
	if not ResourceLoader.exists(WORLD):
		failures.append("a3_despedida world must exist")
	if not ResourceLoader.exists(BUCAR):
		failures.append("a3_bucar world must keep shipping")
	if not ResourceLoader.exists(LEON):
		failures.append("a3_leon world must keep shipping")
	if not ResourceLoader.exists(EMBASSY2):
		failures.append("a2_embassy2 world must keep shipping")
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _on_sword_phase(item_id: StringName, phase: int) -> void:
	_sword_phases.append("%s:%s" % [item_id, phase])


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
	var colada: SwordItem = _colada()
	if colada:
		colada.phase = SwordItem.Phase.IN_HAND
	var tizona: SwordItem = _tizona()
	if tizona:
		tizona.phase = SwordItem.Phase.IN_HAND
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(
				&"a3_despedida",
				PackedStringArray(
					[
						"hub_lock_cardena",
						"horse_companion",
						"colada_acquired",
						"lion_returned",
						"tizona_acquired",
						"babieca_named",
						"avengalvon_recruited",
					]
				)
			)
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(
					[
						"hub_lock_cardena",
						"horse_companion",
						"colada_acquired",
						"lion_returned",
						"tizona_acquired",
						"babieca_named",
						"avengalvon_recruited",
					]
				)
			if "current_id" in _runner:
				_runner.current_id = &"a3_despedida"
	if _bus:
		if _bus.has_signal("hard_fail") and not _bus.hard_fail.is_connected(_on_hard_fail):
			_bus.hard_fail.connect(_on_hard_fail)
		if _bus.has_signal("honor_logged") and not _bus.honor_logged.is_connected(_on_honor_logged):
			_bus.honor_logged.connect(_on_honor_logged)
		if _bus.has_signal("beat_completed") and not _bus.beat_completed.is_connected(_on_beat_completed):
			_bus.beat_completed.connect(_on_beat_completed)
		if _bus.has_signal("sword_phase_changed") and not _bus.sword_phase_changed.is_connected(_on_sword_phase):
			_bus.sword_phase_changed.connect(_on_sword_phase)
	_fails.clear()
	_logged.clear()
	_completed.clear()
	_sword_phases.clear()


func _colada() -> SwordItem:
	if _state and _state.has_method("sword"):
		return _state.sword(&"colada") as SwordItem
	return null


func _tizona() -> SwordItem:
	if _state and _state.has_method("sword"):
		return _state.sword(&"tizona") as SwordItem
	return null


func _fail_copy_reason() -> StringName:
	var script: Script = load("res://game/ui/fail_copy.gd") as Script
	if script and "last_reason" in script:
		return script.last_reason
	return &""


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a3_despedida: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_despedida: %s" % failure)
	quit(1)
