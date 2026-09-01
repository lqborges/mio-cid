extends SceneTree
## Headless a3_toledo Cortes test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a3_toledo.gd

const WORLD := "res://content/chapters/a3_toledo/world.tscn"
const QUERELLA := "res://content/chapters/a3_querella/world.tscn"
const CORPES := "res://content/chapters/a3_corpes/world.tscn"
const DESPEDIDA := "res://content/chapters/a3_despedida/world.tscn"
const BUCAR := "res://content/chapters/a3_bucar/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const EMBASSY2 := "res://content/chapters/a2_embassy2/world.tscn"
const WAIT := "res://content/chapters/a3_valencia_wait/world.tscn"
const CARRION := "res://content/chapters/a3_carrion/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const PLACE_KEY := "a3_toledo.place_name"
const BETROTHAL := ["elvira_betrothed_navarre", "sol_betrothed_aragon"]

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
var _steel_ids: PackedStringArray = PackedStringArray()


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
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_spanish_copy())
		failures.append_array(_check_trial_shape())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_garcia_separate_then_three_asks())
	failures.append_array(_check_skip_to_riepto_does_not_skip())
	failures.append_array(_check_steel_fails())
	failures.append_array(_check_swords_court_then_champions())
	failures.append_array(_check_navarre_aragon_cutscene())
	failures.append_array(_check_dest_missing_no_scene_change())
	failures.append_array(_check_travel_does_not_change_scenes())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_isolation())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a3_toledo/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a3_toledo world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	if load(CID) == null:
		failures.append("cid.tscn failed to load")
	for path in [
		"Hall",
		"Table",
		"HallBench",
		"Cid",
		"Horse",
		"Alfonso",
		"GarciaOrdonez",
		"Elvira",
		"Sol",
		"PeroBermudez",
		"MartinAntolinez",
		"Mesnada",
		"CourtZone",
		"PlaceName",
		"GarciaTrial",
		"SpeechTrial",
	]:
		if _world.get_node_or_null(path) == null:
			failures.append("world missing %s" % path)
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a3_toledo HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a3_toledo HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a3_toledo HUD")
	if _world.find_child("SpeechTrialUI", true, false) == null:
		failures.append("speech trial UI missing from a3_toledo HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a3_toledo":
		failures.append("ChapterRunner.current_id want a3_toledo got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Toledo")
	if not ResourceLoader.exists(QUERELLA):
		failures.append("a3_querella world must keep shipping")
	if not ResourceLoader.exists(WAIT):
		failures.append("a3_valencia_wait must keep shipping")
	if not ResourceLoader.exists(CARRION):
		failures.append("a3_carrion must keep shipping")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a3_toledo must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a3_toledo has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a3_toledo greybox missing hall CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a3_toledo sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a3_toledo has GPUParticles3D")
	if _world.find_child("Timer", true, false) != null:
		failures.append("a3_toledo must not include a Timer")
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var zone: Area3D = _world.get_node_or_null("CourtZone") as Area3D
	if zone == null:
		failures.append("CourtZone missing")
		return failures
	if (zone.collision_mask & 130) != 130:
		failures.append("CourtZone must listen for player and horse, mask %s" % zone.collision_mask)
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var prompt := str(_loc.call("text", "a3_toledo.garcia_prompt"))
	if prompt == "a3_toledo.garcia_prompt" or prompt.is_empty():
		failures.append("Loc did not resolve a3_toledo.garcia_prompt")
	if not prompt.to_lower().contains("garcía") and not prompt.to_lower().contains("garcia"):
		failures.append("García prompt must name García, got %s" % prompt)
	if prompt.to_lower() == "the name is empty":
		failures.append("prompt must not be the English stub")
	var swords := str(_loc.call("text", "a3_toledo.ask1_legal"))
	if not swords.to_lower().contains("colada") or not swords.to_lower().contains("tizona"):
		failures.append("ask1 must name both swords, got %s" % swords)
	var dowry := str(_loc.call("text", "a3_toledo.ask2_prompt"))
	if not dowry.to_lower().contains("tres mil") and not dowry.to_lower().contains("marcos"):
		failures.append("ask2 must name the 3000-mark dowry, got %s" % dowry)
	var riepto := str(_loc.call("text", "a3_toledo.ask3_prompt"))
	if not riepto.to_lower().contains("riepto") and not riepto.to_lower().contains("afrenta"):
		failures.append("ask3 must name the riepto, got %s" % riepto)
	var place := str(_loc.call("text", PLACE_KEY))
	if not place.to_lower().contains("toledo"):
		failures.append("place name must be Toledo, got %s" % place)
	var shown := ""
	var label: Label3D = _world.get_node_or_null("PlaceName") as Label3D
	if label:
		shown = label.text
	if shown != place and shown != "":
		failures.append("PlaceName want %s got %s" % [place, shown])
	return failures


func _check_trial_shape() -> PackedStringArray:
	var failures: PackedStringArray = []
	var garcia_node: Node = _world.get_node_or_null("GarciaTrial")
	if garcia_node == null or not (garcia_node is SpeechTrial):
		failures.append("GarciaTrial node missing or not SpeechTrial")
		return failures
	var garcia := garcia_node as SpeechTrial
	if garcia.asks.size() != 1:
		failures.append("García SpeechTrial asks.size() want 1 got %s" % garcia.asks.size())
	elif String(garcia.asks[0].id) != "garcia_preliminary":
		failures.append("García ask id want garcia_preliminary got %s" % garcia.asks[0].id)
	elif garcia.asks[0].counts_toward_win:
		failures.append("García ask must not count toward the Toledo win")
	var node: Node = _world.get_node_or_null("SpeechTrial")
	if node == null or not (node is SpeechTrial):
		failures.append("three-ask SpeechTrial node missing")
		return failures
	var trial := node as SpeechTrial
	if trial.asks.size() != 3:
		failures.append("Toledo SpeechTrial asks.size() want 3 got %s" % trial.asks.size())
	else:
		var ids: PackedStringArray = PackedStringArray()
		for ask in trial.asks:
			if ask:
				ids.append(String(ask.id))
		if ids != PackedStringArray(["swords", "dowry", "riepto"]):
			failures.append("asks must be swords/dowry/riepto, got %s" % str(ids))
		for ask in trial.asks:
			if ask and String(ask.id) == "garcia_preliminary":
				failures.append("García must not sit in the three Toledo asks")
	if garcia.current_index() != 0 or trial.current_index() != 0:
		failures.append("trials must start at index 0")
	if garcia.legal_score != 0.0 or trial.legal_score != 0.0:
		failures.append("trials must start with legal_score 0")
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	var tree := self
	for _i in range(3):
		await tree.physics_frame
	if bool(_world.get("_garcia_started")):
		failures.append("spawn must not start García")
	if bool(_world.get("_asks_started")):
		failures.append("spawn must not start the three asks")
	if bool(_world.get("_asks_won")) or bool(_world.call("asks_won")):
		failures.append("spawn must not win the cortes")
	if bool(_world.get("_left")):
		failures.append("spawn must not travel")
	var ui: Node = _world.find_child("SpeechTrialUI", true, false)
	if ui and bool(ui.visible):
		failures.append("speech UI must stay hidden until García starts")
	failures.append_array(_check_cid_standing(_world, "spawn"))
	return failures


func _check_garcia_separate_then_three_asks() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("garcia: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	var garcia := world.get_node_or_null("GarciaTrial") as SpeechTrial
	var trial := world.get_node_or_null("SpeechTrial") as SpeechTrial
	if garcia == null or trial == null:
		failures.append("garcia: both trial nodes required")
		world.free()
		return failures
	world.run_garcia_ira()
	if bool(world.call("garcia_done")):
		failures.append("García ira must not finish the preliminary")
	if garcia.current_index() != 0 or garcia.legal_score != 0.0:
		failures.append("García ira must retry without commit")
	if trial.current_index() != 0 or trial.legal_score != 0.0:
		failures.append("García ira must not touch the three-ask trial")
	world.run_garcia_legal()
	if not bool(world.call("garcia_done")):
		failures.append("García legal must finish the preliminary")
	if trial.current_index() != 0:
		failures.append("García must not share _index with Toledo, got %s" % trial.current_index())
	if trial.legal_score != 0.0:
		failures.append("García must not share legal_score with Toledo, got %s" % trial.legal_score)
	if garcia.legal_score != 0.0:
		failures.append("García counts_toward_win false must not add legal")
	world.run_legal()
	world.run_legal()
	world.run_legal()
	if not bool(world.call("asks_won")):
		failures.append("three legal asks after García must win the cortes")
	if trial.asks.size() != 3:
		failures.append("winning must keep three asks")
	world.free()
	return failures


func _check_skip_to_riepto_does_not_skip() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("skip: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	world.run_garcia_legal()
	var trial := world.get_node_or_null("SpeechTrial") as SpeechTrial
	if trial == null:
		failures.append("skip: SpeechTrial missing")
		world.free()
		return failures
	world.run_skip_to_riepto()
	if trial.third_ask_allowed:
		failures.append("skip_to_riepto must set third_ask_allowed false")
	if trial.current_index() != 0:
		failures.append("skip_to_riepto must not skip the current ask")
	if trial.legal_score != 0.0:
		failures.append("skip_to_riepto must not commit a delta")
	world.run_legal()
	world.run_legal()
	if bool(world.call("asks_won")):
		failures.append("skip_to_riepto path must not win")
	if trial.current_index() != 2:
		failures.append("mesura-fail should land on the blocked third ask, got %s" % trial.current_index())
	var before := trial.legal_score
	world.run_riepto_legal()
	if trial.legal_score != before:
		failures.append("third ask after skip_to_riepto must stay skip_blocked")
	if bool(world.call("asks_won")):
		failures.append("blocked riepto must not win")
	world.free()
	return failures


func _check_steel_fails() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("steel: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_fails.clear()
	_steel_ids.clear()
	world.run_garcia_legal()
	var trial := world.get_node_or_null("SpeechTrial") as SpeechTrial
	world.run_draw_steel()
	if trial == null or not trial.steel_failed():
		failures.append("draw_steel must fail the three-ask trial")
	if _fails.find("steel_in_cortes") < 0 and _steel_ids.find("steel_in_cortes") < 0:
		failures.append("draw_steel must hard_fail steel_in_cortes, got %s" % str(_fails))
	if bool(world.call("asks_won")):
		failures.append("steel must not win the cortes")
	if bool(world.get("_left")):
		failures.append("steel must not travel")
	world.free()
	return failures


func _check_swords_court_then_champions() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _state and _state.has_method("reset_swords"):
		_state.reset_swords()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("swords: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	world.run_garcia_legal()
	world.run_swords_legal()
	if not bool(world.call("swords_in_court")):
		failures.append("ask1 must set swords IN_COURT")
	var tizona: SwordItem = _state.sword(&"tizona") if _state else null
	var colada: SwordItem = _state.sword(&"colada") if _state else null
	if tizona == null or tizona.phase_name() != "IN_COURT":
		failures.append("Tizona want IN_COURT got %s" % (tizona.phase_name() if tizona else "null"))
	if colada == null or colada.phase_name() != "IN_COURT":
		failures.append("Colada want IN_COURT got %s" % (colada.phase_name() if colada else "null"))
	if tizona and tizona.can_player_wield():
		failures.append("IN_COURT Tizona must not be wieldable")
	if colada and colada.can_player_wield():
		failures.append("IN_COURT Colada must not be wieldable")
	if _logged.count("toledo_ask1_swords") < 1:
		failures.append("ask1 must apply toledo_ask1_swords")
	world.run_dowry_legal()
	if _logged.count("toledo_ask2_dowry") < 1:
		failures.append("ask2 must apply toledo_ask2_dowry")
	world.run_riepto_legal()
	if _logged.count("toledo_ask3_riepto") < 1:
		failures.append("ask3 must apply toledo_ask3_riepto")
	if not bool(world.call("swords_in_champion_hand")):
		failures.append("after give, swords must be IN_CHAMPION_HAND")
	tizona = _state.sword(&"tizona") if _state else tizona
	colada = _state.sword(&"colada") if _state else colada
	if tizona == null or tizona.phase_name() != "IN_CHAMPION_HAND":
		failures.append("Tizona want IN_CHAMPION_HAND got %s" % (tizona.phase_name() if tizona else "null"))
	if colada == null or colada.phase_name() != "IN_CHAMPION_HAND":
		failures.append("Colada want IN_CHAMPION_HAND got %s" % (colada.phase_name() if colada else "null"))
	if tizona and String(tizona.lists_champion) != "pero_bermudez":
		failures.append("Tizona champion want pero_bermudez got %s" % tizona.lists_champion)
	if colada and String(colada.lists_champion) != "martin_antolinez":
		failures.append("Colada champion want martin_antolinez got %s" % colada.lists_champion)
	if tizona and tizona.can_player_wield():
		failures.append("player cannot keep Tizona")
	if colada and colada.can_player_wield():
		failures.append("player cannot keep Colada")
	world.free()
	return failures


func _check_navarre_aragon_cutscene() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("princes: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	if world.get_node_or_null("NavarreTrial") != null:
		failures.append("navarre_aragon must not be a SpeechTrial node")
	world.run_garcia_legal()
	world.run_legal()
	world.run_legal()
	world.run_legal()
	if not bool(world.call("princes_asked")):
		failures.append("three-ask win must play the Navarre/Aragón cutscene")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		for flag in BETROTHAL:
			if flag not in flags:
				failures.append("navarre_aragon must set %s" % flag)
	world.free()
	return failures


func _check_dest_missing_no_scene_change() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("leave: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_completed.clear()
	var scene_before: Node = current_scene
	world.run_garcia_legal()
	world.run_legal()
	world.run_legal()
	world.run_legal()
	if not ResourceLoader.exists(WAIT):
		failures.append("a3_valencia_wait must keep shipping")
	if not bool(world.get("_left")):
		failures.append("win must _left into a3_valencia_wait")
	if _runner and String(_runner.current_id) != "a3_valencia_wait":
		failures.append("must travel() to a3_valencia_wait, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("win must not change_scene; ChapterRunner.travel is not goto")
	if bool(world.call("try_travel_wait")):
		failures.append("try_travel_wait must no-op after already leaving")
	if current_scene != scene_before:
		failures.append("try_travel_wait must not change_scene")
	if _completed.count("a3_toledo") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	world.free()
	return failures


func _check_travel_does_not_change_scenes() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	var scene_before: Node = current_scene
	var id_before: String = String(_runner.current_id) if "current_id" in _runner else ""
	var moved := bool(_runner.travel(&"a3_valencia_wait"))
	if current_scene != scene_before:
		failures.append("travel() must not change scenes")
	if moved and current_scene != scene_before:
		failures.append("ChapterRunner.travel must not goto")
	if "current_id" in _runner and String(_runner.current_id) != id_before and current_scene != scene_before:
		failures.append("travel() changed scenes while updating current_id")
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "querella_filed"])
	if not bool(_runner.can_travel(&"a3_querella", &"a3_toledo", flags)):
		failures.append("querella -> toledo must stay open after querella_filed")
	if not bool(_runner.can_travel(&"a3_toledo", &"a3_valencia_wait", flags)):
		failures.append("toledo -> valencia_wait must stay open")
	if bool(_runner.can_travel(&"a3_querella", &"a3_valencia_wait", flags)):
		failures.append("querella must not skip Toledo")
	return failures


func _check_isolation() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ResourceLoader.exists(WORLD):
		failures.append("a3_toledo world must exist")
	if not ResourceLoader.exists(QUERELLA):
		failures.append("a3_querella world must keep shipping")
	if not ResourceLoader.exists(CORPES):
		failures.append("a3_corpes world must keep shipping")
	if not ResourceLoader.exists(DESPEDIDA):
		failures.append("a3_despedida world must keep shipping")
	if not ResourceLoader.exists(BUCAR):
		failures.append("a3_bucar world must keep shipping")
	if not ResourceLoader.exists(LEON):
		failures.append("a3_leon world must keep shipping")
	if not ResourceLoader.exists(EMBASSY2):
		failures.append("a2_embassy2 world must keep shipping")
	if not ResourceLoader.exists(WAIT):
		failures.append("a3_valencia_wait must keep shipping")
	if not ResourceLoader.exists(CARRION):
		failures.append("a3_carrion must keep shipping")
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))
	_steel_ids.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _check_cid_standing(world: Node, label: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var cid: Node = world.get_node_or_null("Cid")
	if cid == null:
		return failures
	if "chapter_asleep" in cid and bool(cid.chapter_asleep):
		failures.append("%s: Cid must not use chapter_asleep" % label)
	if "chapter_locked" in cid and bool(cid.chapter_locked):
		failures.append("%s: Cid must not start chapter_locked" % label)
	return failures


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
				&"a3_toledo",
				PackedStringArray(
					[
						"hub_lock_cardena",
						"horse_companion",
						"colada_acquired",
						"lion_returned",
						"tizona_acquired",
						"swords_gifted",
						"avengalvon_alive_despedida",
						"babieca_named",
						"corpes_happened",
						"corpes_news",
						"elvira_alive",
						"sol_alive",
						"felez_found_them",
						"querella_filed",
						"querella_done",
					]
				)
			)
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(
					[
						"hub_lock_cardena",
						"horse_companion",
						"querella_filed",
						"querella_done",
					]
				)
			if "current_id" in _runner:
				_runner.current_id = &"a3_toledo"
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
	_steel_ids.clear()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a3_toledo: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_toledo: %s" % failure)
	quit(1)
