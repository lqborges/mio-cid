extends SceneTree
## Headless a3_corpes aftermath / PEGI packet test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a3_corpes.gd

const WORLD := "res://content/chapters/a3_corpes/world.tscn"
const DESPEDIDA := "res://content/chapters/a3_despedida/world.tscn"
const BUCAR := "res://content/chapters/a3_bucar/world.tscn"
const LEON := "res://content/chapters/a3_leon/world.tscn"
const EMBASSY2 := "res://content/chapters/a2_embassy2/world.tscn"
const QUERELLA := "res://content/chapters/a3_querella/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const WARNING_KEY := "a3_corpes.warning"
const PLACE_KEY := "a3_corpes.place_name"
const NEWS_FLAGS := [
	"corpes_happened",
	"corpes_news",
	"elvira_alive",
	"sol_alive",
	"felez_found_them",
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
		failures.append_array(_check_zones_accept_horse())
		failures.append_array(_check_spanish_copy())
		failures.append_array(await _check_spawn_does_not_auto_flow())
		_world.free()
		_world = null
	failures.append_array(_check_hear_only_records_fact())
	failures.append_array(_check_default_shows_grove_same_flags())
	failures.append_array(_check_rage_dump_costs_honra())
	failures.append_array(_check_missing_querella_still_completes())
	failures.append_array(_check_graph_spine())
	failures.append_array(_check_later_beats_not_shipped())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a3_corpes/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a3_corpes world did not instantiate")
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
		"Grove",
		"Grove/Linen",
		"Grove/LeafStain",
		"Cid",
		"Horse",
		"Jimena",
		"Elvira",
		"Sol",
		"Felez",
		"DiegoTellez",
		"Mesnada",
		"ReportZone",
		"PlaceName",
	]:
		if _world.get_node_or_null(path) == null:
			failures.append("world missing %s" % path)
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a3_corpes HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a3_corpes HUD")
	if _world.find_child("MesuraHud", true, false) == null:
		failures.append("mesura hud missing from a3_corpes HUD")
	if _world.find_child("WarningUI", true, false) == null:
		failures.append("warning UI missing from a3_corpes HUD")
	if _world.find_child("ChoiceUI", true, false) == null:
		failures.append("choice UI missing from a3_corpes HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a3_corpes":
		failures.append("ChapterRunner.current_id want a3_corpes got %s" % _runner.current_id)
	var plazo: Node = _world.find_child("PlazoBar", true, false)
	if plazo and bool(plazo.visible):
		failures.append("plazo bar must stay hidden in Valencia")
	if not ResourceLoader.exists(DESPEDIDA):
		failures.append("a3_despedida world must keep shipping")
	if not ResourceLoader.exists(QUERELLA):
		failures.append("a3_querella must keep shipping")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a3_corpes must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a3_corpes has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a3_corpes greybox missing hall CSG")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 2:
		failures.append("a3_corpes greybox missing grove oaks")
	var env: WorldEnvironment = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null or env.environment == null or env.environment.sdfgi_enabled:
		failures.append("a3_corpes sdfgi must be off")
	if _world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("a3_corpes has GPUParticles3D")
	var grove: Node = _world.get_node_or_null("Grove")
	if grove and bool(grove.visible):
		failures.append("grove must start hidden")
	return failures


func _check_zones_accept_horse() -> PackedStringArray:
	var failures: PackedStringArray = []
	var zone: Area3D = _world.get_node_or_null("ReportZone") as Area3D
	if zone == null:
		failures.append("ReportZone missing")
		return failures
	if (zone.collision_mask & 130) != 130:
		failures.append("ReportZone must listen for player and horse, mask %s" % zone.collision_mask)
	return failures


func _check_spanish_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	if _loc.has_method("_reload"):
		_loc.call("_reload")
	var warning := str(_loc.call("text", WARNING_KEY))
	if warning == WARNING_KEY or warning.is_empty():
		failures.append("Loc did not resolve a3_corpes.warning")
	if not warning.to_lower().contains("crimen") and not warning.to_lower().contains("crime"):
		failures.append("warning must name a crime, got %s" % warning)
	if warning.to_lower() == "the name is empty":
		failures.append("warning must not be the English stub")
	var report := str(_loc.call("text", "a3_corpes.report"))
	if not report.to_lower().contains("félez") and not report.to_lower().contains("felez"):
		failures.append("report must name Félez, got %s" % report)
	var alive := str(_loc.call("text", "a3_corpes.alive"))
	if not alive.to_lower().contains("elvira") or not alive.to_lower().contains("sol"):
		failures.append("alive copy must name the daughters, got %s" % alive)
	var hear := str(_loc.call("text", "a3_corpes.choice_hear"))
	if not hear.to_lower().contains("oír") and not hear.to_lower().contains("oir"):
		failures.append("hear-only copy must be Spanish, got %s" % hear)
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
	if bool(_world.get("_warned")):
		failures.append("spawn must not confirm the warning")
	if bool(_world.get("_reported")) or bool(_world.get("_news_applied")):
		failures.append("spawn must not skip the warning into the report")
	if bool(_world.get("_left")):
		failures.append("spawn must not travel")
	if _logged.count("corpes_news") > 0:
		failures.append("spawn must not apply corpes_news")
	var warning: Node = _world.find_child("WarningUI", true, false)
	if warning == null or not bool(warning.visible):
		failures.append("content warning must show before either path")
	var grove: Node = _world.get_node_or_null("Grove")
	if grove and bool(grove.visible):
		failures.append("spawn must not show the grove")
	var elvira: Node = _world.get_node_or_null("Elvira")
	if elvira and bool(elvira.visible):
		failures.append("daughters must stay hidden until the report")
	var felez: Node = _world.get_node_or_null("Felez")
	if felez and bool(felez.visible):
		failures.append("Félez must enter with the report, not at spawn")
	failures.append_array(_check_cid_standing(_world, "spawn"))
	return failures


func _check_hear_only_records_fact() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("hear-only: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	_completed.clear()
	var honra_before := 0.0
	if _honor and _honor.state:
		honra_before = float(_honor.state.honra)
	if not world.has_method("run_hear_only"):
		failures.append("world missing run_hear_only")
		world.free()
		return failures
	world.run_hear_only()
	if not bool(world.get("_warned")):
		failures.append("hear-only must still pass the content warning")
	if not bool(world.call("hear_only_used")):
		failures.append("hear_only_used() must be true")
	if bool(world.call("grove_shown")):
		failures.append("hear-only must not show the grove")
	var grove: Node = world.get_node_or_null("Grove")
	if grove and bool(grove.visible):
		failures.append("hear-only grove node must stay hidden")
	var stain: Node = world.get_node_or_null("Grove/LeafStain")
	if stain and bool(stain.visible):
		failures.append("hear-only must leave distant leaf stain off")
	if not bool(world.call("fact_recorded")):
		failures.append("hear-only must still record the fact")
	if not bool(world.call("daughters_present")):
		failures.append("hear-only must still seat Elvira and Sol alive")
	var felez: Node = world.get_node_or_null("Felez")
	if felez == null or not bool(felez.visible):
		failures.append("Félez must report in the hall on hear-only")
	var lod: Node = world.get_node_or_null("Felez/Visual/MeshCapsule")
	if lod and bool(lod.visible):
		failures.append("Félez LOD MeshCapsule must stay hidden after the report")
	if bool(world.call("grove_camera_held")):
		failures.append("hear-only must skip the grove camera")
	failures.append_array(_check_cid_standing(world, "hear-only"))
	if _logged.count("corpes_news") < 1:
		failures.append("hear-only must apply corpes_news, got %s" % str(_logged))
	if _honor and _honor.state:
		if float(_honor.state.honra) >= honra_before:
			failures.append("corpes_news must sink honra")
		if not bool(_honor.state.has_stain(&"uncurable_by_combat")):
			failures.append("corpes_news must persist uncurable_by_combat")
	if _clock and int(_clock.days_elapsed) < 14:
		failures.append("San Esteban skip must advance 14 days, got %s" % _clock.days_elapsed)
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		for flag in NEWS_FLAGS:
			if flag not in flags:
				failures.append("hear-only must set %s" % flag)
	if bool(world.get("_left")):
		failures.append("report must wait for mesura/rage before leaving")
	if _completed.count("a3_corpes") > 0:
		failures.append("report must not complete the beat before mesura")
	world.free()
	return failures


func _check_default_shows_grove_same_flags() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("default: world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_logged.clear()
	world.run_default()
	if bool(world.call("hear_only_used")):
		failures.append("default path must not be hear-only")
	if not bool(world.call("grove_shown")):
		failures.append("default path must show the empty grove")
	if not bool(world.call("grove_camera_held")):
		failures.append("default path must hold the grove camera before the hall cut")
	if world.get_node_or_null("Grove/Linen") == null:
		failures.append("default path must include the linen")
	var grove: Node = world.get_node_or_null("Grove")
	if grove and bool(grove.visible):
		failures.append("grove must hide after the camera cut")
	failures.append_array(_check_cid_standing(world, "default"))
	if not bool(world.call("fact_recorded")):
		failures.append("default path must record the same fact")
	if _logged.count("corpes_news") < 1:
		failures.append("default path must apply corpes_news")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		for flag in NEWS_FLAGS:
			if flag not in flags:
				failures.append("default path must set %s" % flag)
	world.run_mesura()
	if String(world.get("_path")) != "mesura":
		failures.append("run_mesura must hold mesura, got %s" % world.get("_path"))
	if _logged.count("corpes_rage_dump") > 0:
		failures.append("mesura hold must not apply corpes_rage_dump")
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
	root.add_child(world)
	_logged.clear()
	world.run_hear_only()
	var honra_after_news := 0.0
	if _honor and _honor.state:
		honra_after_news = float(_honor.state.honra)
	world.run_rage()
	if String(world.get("_path")) != "rage":
		failures.append("run_rage must dump rage, got %s" % world.get("_path"))
	if _logged.count("corpes_rage_dump") < 1:
		failures.append("rage path must apply corpes_rage_dump, got %s" % str(_logged))
	if _honor and _honor.state and float(_honor.state.honra) >= honra_after_news:
		failures.append("corpes_rage_dump must sink honra")
	if _logged.count("ride_host_to_carrion") > 0:
		failures.append("ride_host must stay deferred")
	world.free()
	return failures


func _check_missing_querella_still_completes() -> PackedStringArray:
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
	world.run_hear_only()
	world.run_mesura()
	if not ResourceLoader.exists(QUERELLA):
		failures.append("a3_querella must ship")
	if not bool(world.get("_left")):
		failures.append("mesura must _left when a3_querella exists")
	if _runner and String(_runner.current_id) != "a3_querella":
		failures.append("must travel() to a3_querella, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("mesura must not change_scene when current_scene != world")
	if _completed.count("a3_corpes") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	if _completed.count("a3_corpes") < 1:
		failures.append("travel must complete a3_corpes once")
	world.free()
	return failures


func _check_graph_spine() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion", "tizona_acquired"])
	if not bool(_runner.can_travel(&"a3_despedida", &"a3_corpes", flags)):
		failures.append("despedida -> corpes must stay open")
	if bool(_runner.can_travel(&"a3_bucar", &"a3_corpes", flags)):
		failures.append("bucar must not skip to Corpes")
	if bool(_runner.can_travel(&"a3_leon", &"a3_corpes", flags)):
		failures.append("leon must not skip to Corpes")
	if not bool(_runner.can_travel(&"a3_corpes", &"a3_querella", flags)):
		failures.append("corpes -> querella must stay open")
	return failures


func _check_later_beats_not_shipped() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ResourceLoader.exists(QUERELLA):
		failures.append("a3_querella world must keep shipping")
	if not ResourceLoader.exists("res://content/chapters/a3_toledo/world.tscn"):
		failures.append("a3_toledo world must keep shipping")
	if not ResourceLoader.exists("res://content/chapters/a3_valencia_wait/world.tscn"):
		failures.append("a3_valencia_wait must keep shipping")
	if not ResourceLoader.exists("res://content/chapters/a3_carrion/world.tscn"):
		failures.append("a3_carrion must keep shipping")
	if not ResourceLoader.exists(WORLD):
		failures.append("a3_corpes world must exist")
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


func _check_cid_standing(world: Node, label: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var cid: Node = world.get_node_or_null("Cid")
	if cid == null:
		return failures
	if "chapter_asleep" in cid and bool(cid.chapter_asleep):
		failures.append("%s: Cid must not use chapter_asleep" % label)
	var visual: Node3D = cid.get_node_or_null("Visual") as Node3D
	if visual and not visual.rotation.is_zero_approx():
		failures.append("%s: Cid Visual.rotation must stay identity, got %s" % [label, visual.rotation])
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
				&"a3_corpes",
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
					]
				)
			if "current_id" in _runner:
				_runner.current_id = &"a3_corpes"
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
		print("test_a3_corpes: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_corpes: %s" % failure)
	quit(1)
