extends SceneTree
## Headless a3_querella one-ask SpeechTrial test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a3_querella.gd

const WORLD := "res://content/chapters/a3_querella/world.tscn"
const CORPES := "res://content/chapters/a3_corpes/world.tscn"
const DESPEDIDA := "res://content/chapters/a3_despedida/world.tscn"
const BUCAR := "res://content/chapters/a3_bucar/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const EMBASSY2 := "res://content/chapters/a2_embassy2/world.tscn"
const TOLEDO := "res://content/chapters/a3_toledo/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const PLACE_KEY := "a3_querella.place_name"
const PROMPT_KEY := "a3_querella.prompt"
const WIN_FLAGS := ["querella_filed", "querella_done"]

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
var _sent: int = 0


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
	failures.append_array(_check_legal_files_querella())
	failures.append_array(_check_mesura_files_querella())
	failures.append_array(_check_ira_does_not_commit())
	failures.append_array(_check_ride_host_blocks_toledo())
	failures.append_array(_check_missing_toledo_no_scene_change())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a3_querella/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a3_querella world did not instantiate")
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
		"Jimena",
		"MunoGustioz",
		"Mesnada",
		"DictateZone",
		"PlaceName",
		"SpeechTrial",
	]:
		if _world.get_node_or_null(path) == null:
			failures.append("world missing %s" % path)
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a3_querella HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a3_querella HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a3_querella HUD")
	if _world.find_child("SpeechTrialUI", true, false) == null:
		failures.append("speech trial UI missing from a3_querella HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a3_querella":
		failures.append("ChapterRunner.current_id want a3_querella got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	if not ResourceLoader.exists(CORPES):
		failures.append("a3_corpes world must keep shipping")
	if not ResourceLoader.exists(TOLEDO):
		failures.append("a3_toledo must keep shipping")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a3_querella must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a3_querella has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a3_querella greybox missing hall CSG")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a3_querella sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a3_querella has GPUParticles3D")
	if _world.find_child("Timer", true, false) != null:
		failures.append("a3_querella must not include a Timer")
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var zone: Area3D = _world.get_node_or_null("DictateZone") as Area3D
	if zone == null:
		failures.append("DictateZone missing")
		return failures
	if (zone.collision_mask & 130) != 130:
		failures.append("DictateZone must listen for player and horse, mask %s" % zone.collision_mask)
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
		failures.append("Loc did not resolve a3_querella.prompt")
	if not prompt.to_lower().contains("querella"):
		failures.append("prompt must name the querella, got %s" % prompt)
	if prompt.to_lower() == "the name is empty":
		failures.append("prompt must not be the English stub")
	var legal := str(_loc.call("text", "a3_querella.line_legal"))
	if not legal.to_lower().contains("hueste") and not legal.to_lower().contains("querella"):
		failures.append("legal line must be Spanish law-copy, got %s" % legal)
	var ride := str(_loc.call("text", "a3_querella.line_ride_host"))
	if not ride.to_lower().contains("hueste") and not ride.to_lower().contains("carrión") and not ride.to_lower().contains("carrion"):
		failures.append("ride_host copy must name the host, got %s" % ride)
	var place := str(_loc.call("text", PLACE_KEY))
	if not place.to_lower().contains("valencia"):
		failures.append("place name must be Valencia, got %s" % place)
	var shown := ""
	var label: Label3D = _world.get_node_or_null("PlaceName") as Label3D
	if label:
		shown = label.text
	if shown != place and shown != "":
		failures.append("PlaceName want %s got %s" % [place, shown])
	var muno := str(_loc.call("text", "char.muno_gustioz"))
	if not muno.to_lower().contains("muñ") and not muno.to_lower().contains("muno"):
		failures.append("Muño Gustioz loc missing, got %s" % muno)
	return failures


func _check_trial_shape() -> PackedStringArray:
	var failures: PackedStringArray = []
	var node: Node = _world.get_node_or_null("SpeechTrial")
	if node == null:
		failures.append("SpeechTrial node missing")
		return failures
	if not (node is SpeechTrial):
		failures.append("hall SpeechTrial node is not class_name SpeechTrial")
		return failures
	var trial := node as SpeechTrial
	if trial.asks.size() != 1:
		failures.append("querella SpeechTrial asks.size() want 1 got %s" % trial.asks.size())
	elif String(trial.asks[0].id) != "querella_dictate":
		failures.append("ask id want querella_dictate got %s" % trial.asks[0].id)
	else:
		var ids: PackedStringArray = PackedStringArray()
		for line in trial.asks[0].lines:
			if line:
				ids.append(String(line.id))
		for want in ["legal", "mesura", "ira", "ride_host"]:
			if want not in ids:
				failures.append("querella_dictate missing line %s" % want)
	return failures


func _check_spawn_does_not_auto_flow() -> PackedStringArray:
	var failures: PackedStringArray = []
	var tree := self
	for _i in range(3):
		await tree.physics_frame
	if bool(_world.get("_started")):
		failures.append("spawn must not start the querella")
	if bool(_world.get("_filed")) or bool(_world.call("querella_filed")):
		failures.append("spawn must not file the querella")
	if bool(_world.get("_host_ridden")):
		failures.append("spawn must not ride a host")
	if bool(_world.get("_left")):
		failures.append("spawn must not travel")
	if _logged.count("querella_filed") > 0:
		failures.append("spawn must not apply querella_filed")
	if _sent > 0:
		failures.append("spawn must not emit querella_sent")
	var ui: Node = _world.find_child("SpeechTrialUI", true, false)
	if ui and bool(ui.visible):
		failures.append("speech UI must stay hidden until dictate")
	failures.append_array(_check_cid_standing(_world, "spawn"))
	return failures


func _check_legal_files_querella() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("legal: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_sent = 0
	_completed.clear()
	var honra_before := 0.0
	if _honor and _honor.state:
		honra_before = float(_honor.state.honra)
	var scene_before: Node = current_scene
	world.run_legal()
	if not bool(world.call("querella_filed")):
		failures.append("legal line must file the querella")
	if bool(world.call("host_ridden")):
		failures.append("legal line must not ride a host")
	if _logged.count("querella_filed") < 1:
		failures.append("legal line must apply querella_filed, got %s" % str(_logged))
	if _logged.count("ride_host_to_carrion") > 0:
		failures.append("legal line must not apply ride_host_to_carrion")
	if _sent < 1:
		failures.append("legal line must emit querella_sent")
	if _honor and _honor.state and float(_honor.state.honra) <= honra_before:
		failures.append("querella_filed must raise honra")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		for flag in WIN_FLAGS:
			if flag not in flags:
				failures.append("legal line must set %s" % flag)
		if "ride_host" in flags:
			failures.append("legal line must not set ride_host")
		if not bool(_runner.can_travel(&"a3_querella", &"a3_toledo", flags)):
			failures.append("legal win must can_travel to Toledo")
	if not ResourceLoader.exists(TOLEDO):
		failures.append("a3_toledo must ship")
	if not bool(world.get("_left")):
		failures.append("legal must _left when a3_toledo exists")
	if _runner and String(_runner.current_id) != "a3_toledo":
		failures.append("must travel() to a3_toledo, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("legal must not change_scene when current_scene != world")
	var mesura: Node = _cid_mesura(world)
	if mesura and mesura.has_method("has_trait") and not bool(mesura.call("has_trait", &"querella_not_hueste")):
		failures.append("querella_not_hueste must unlock at querella_filed")
	world.free()
	return failures


func _check_mesura_files_querella() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("mesura: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_sent = 0
	world.run_mesura()
	if not bool(world.call("querella_filed")):
		failures.append("mesura line must file the querella")
	if _logged.count("querella_filed") < 1:
		failures.append("mesura line must apply querella_filed")
	if _sent < 1:
		failures.append("mesura line must emit querella_sent")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "querella_done" not in flags:
			failures.append("mesura line must set querella_done")
		if not bool(_runner.can_travel(&"a3_querella", &"a3_toledo", flags)):
			failures.append("mesura win must can_travel to Toledo")
	world.free()
	return failures


func _check_ira_does_not_commit() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("ira: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_sent = 0
	_completed.clear()
	world.run_ira()
	if bool(world.call("querella_filed")):
		failures.append("ira must not file the querella")
	if bool(world.call("host_ridden")):
		failures.append("ira must not ride a host")
	if _logged.count("querella_filed") > 0:
		failures.append("ira must not apply querella_filed")
	if _logged.count("ride_host_to_carrion") > 0:
		failures.append("ira must not apply ride_host_to_carrion")
	if _sent > 0:
		failures.append("ira must not emit querella_sent")
	if _completed.count("a3_querella") > 0:
		failures.append("ira retry must not complete the beat")
	var node: Node = world.get_node_or_null("SpeechTrial")
	if node is SpeechTrial:
		var trial := node as SpeechTrial
		if trial.current_index() != 0:
			failures.append("ira retry must stay on ask 0, got %s" % trial.current_index())
		if trial.legal_score != 0.0 or trial.mesura_score != 0.0 or trial.ira_score != 0.0:
			failures.append("ira retry must not commit scores")
	world.run_legal()
	if not bool(world.call("querella_filed")):
		failures.append("legal after ira retry must still file")
	if _logged.count("querella_filed") < 1:
		failures.append("legal after ira retry must apply querella_filed")
	if _sent < 1:
		failures.append("legal after ira retry must emit querella_sent")
	world.free()
	return failures


func _check_ride_host_blocks_toledo() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("ride_host: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_sent = 0
	_completed.clear()
	var honra_before := 0.0
	if _honor and _honor.state:
		honra_before = float(_honor.state.honra)
	var scene_before: Node = current_scene
	world.run_ride_host()
	if not bool(world.call("host_ridden")):
		failures.append("ride_host must mark the host ridden")
	if bool(world.call("querella_filed")):
		failures.append("ride_host must not file the querella")
	if _logged.count("ride_host_to_carrion") < 1:
		failures.append("ride_host must apply ride_host_to_carrion, got %s" % str(_logged))
	if _logged.count("querella_filed") > 0:
		failures.append("ride_host must not apply querella_filed")
	if _sent > 0:
		failures.append("ride_host must not emit querella_sent")
	if _honor and _honor.state and float(_honor.state.honra) >= honra_before:
		failures.append("ride_host_to_carrion must sink honra")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "ride_host" not in flags:
			failures.append("ride_host must set ride_host")
		if "querella_done" in flags:
			failures.append("ride_host must not set querella_done")
		if "querella_filed" in flags:
			failures.append("ride_host must not set querella_filed")
		if bool(_runner.can_travel(&"a3_querella", &"a3_toledo", flags)):
			failures.append("ride_host must not can_travel to Toledo")
		if String(_runner.current_id) == "a3_toledo":
			failures.append("ride_host must not travel to Toledo")
	if bool(world.get("_left")):
		failures.append("ride_host must not _left to Toledo")
	if current_scene != scene_before:
		failures.append("ride_host must not change_scene")
	if bool(world.call("try_travel_toledo")):
		failures.append("ride_host try_travel_toledo must fail")
	var whisper_text := _whisper_text(world)
	if whisper_text.contains("ya va") or whisper_text.contains("already rides"):
		failures.append("ride_host must not whisper WAIT_KEY, got %s" % whisper_text)
	if not whisper_text.contains("hueste") and not whisper_text.contains("host"):
		failures.append("ride_host whisper must stay on the illegal path, got %s" % whisper_text)
	world.run_legal()
	if bool(world.call("querella_filed")):
		failures.append("legal after ride_host must not file")
	if _sent > 0:
		failures.append("legal after ride_host must not emit querella_sent")
	world.free()
	return failures


func _check_missing_toledo_no_scene_change() -> PackedStringArray:
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
	world.run_legal()
	if not ResourceLoader.exists(TOLEDO):
		failures.append("a3_toledo must ship")
	if not bool(world.get("_left")):
		failures.append("legal must _left when a3_toledo exists")
	if _runner and String(_runner.current_id) != "a3_toledo":
		failures.append("must travel() to a3_toledo, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("legal must not change_scene when current_scene != world")
	if bool(world.call("try_travel_toledo")):
		failures.append("try_travel_toledo must no-op after already leaving")
	if current_scene != scene_before:
		failures.append("try_travel_toledo must not change_scene")
	if _completed.count("a3_querella") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _completed.count("a3_querella") < 1:
		failures.append("travel must complete a3_querella once")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "tizona_acquired"])
	if not bool(_runner.can_travel(&"a3_corpes", &"a3_querella", flags)):
		failures.append("corpes -> querella must stay open")
	if bool(_runner.can_travel(&"a3_querella", &"a3_toledo", flags)):
		failures.append("querella -> toledo must wait for querella_filed")
	flags.append("querella_filed")
	if not bool(_runner.can_travel(&"a3_querella", &"a3_toledo", flags)):
		failures.append("querella -> toledo must open after querella_filed")
	flags.append("ride_host")
	if bool(_runner.can_travel(&"a3_querella", &"a3_toledo", flags)):
		failures.append("ride_host must forbid Toledo")
	if bool(_runner.can_travel(&"a3_corpes", &"a3_toledo", flags)):
		failures.append("corpes must not skip querella")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ResourceLoader.exists(TOLEDO):
		failures.append("a3_toledo world must keep shipping")
	if ResourceLoader.exists("res://content/chapters/a3_valencia_wait/world.tscn"):
		failures.append("a3_valencia_wait must not ship in this beat")
	if ResourceLoader.exists("res://content/chapters/a3_carrion/world.tscn"):
		failures.append("a3_carrion must not ship in this beat")
	if not ResourceLoader.exists(WORLD):
		failures.append("a3_querella world must exist")
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
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _on_querella_sent() -> void:
	_sent += 1


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


func _whisper_text(world: Node) -> String:
	var whisper: Node = world.find_child("HallWhisper", true, false)
	if whisper == null:
		return ""
	var line: Label = whisper.get_node_or_null("Line") as Label
	if line == null:
		return ""
	return line.text.to_lower()


func _cid_mesura(world: Node) -> Node:
	var cid: Node = world.get_node_or_null("Cid")
	if cid == null:
		return null
	var found: Node = cid.get_node_or_null("Mesura")
	if found:
		return found
	return cid.find_child("Mesura", true, false)


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
				&"a3_querella",
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
						"swords_gifted",
						"avengalvon_alive_despedida",
						"babieca_named",
						"corpes_happened",
						"corpes_news",
						"elvira_alive",
						"sol_alive",
						"felez_found_them",
					]
				)
			if "current_id" in _runner:
				_runner.current_id = &"a3_querella"
	if _bus:
		if _bus.has_signal("hard_fail") and not _bus.hard_fail.is_connected(_on_hard_fail):
			_bus.hard_fail.connect(_on_hard_fail)
		if _bus.has_signal("honor_logged") and not _bus.honor_logged.is_connected(_on_honor_logged):
			_bus.honor_logged.connect(_on_honor_logged)
		if _bus.has_signal("beat_completed") and not _bus.beat_completed.is_connected(_on_beat_completed):
			_bus.beat_completed.connect(_on_beat_completed)
		if _bus.has_signal("querella_sent") and not _bus.querella_sent.is_connected(_on_querella_sent):
			_bus.querella_sent.connect(_on_querella_sent)
	_fails.clear()
	_logged.clear()
	_completed.clear()
	_sent = 0


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a3_querella: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_querella: %s" % failure)
	quit(1)
