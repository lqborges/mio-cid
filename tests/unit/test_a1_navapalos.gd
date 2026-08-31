extends SceneTree
## Headless a1_navapalos sleep / Gabriel dream test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a1_navapalos.gd

const WORLD := "res://content/chapters/a1_navapalos/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const DREAM := "a1_navapalos.gabriel_dream"

var _honor: Variant
var _treasury: Variant
var _clock: Variant
var _runner: Variant
var _loc: Variant
var _bus: Variant
var _world: Node = null
var _fails: PackedStringArray = PackedStringArray()


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
		failures.append_array(_check_gabriel_not_combatant())
		failures.append_array(_check_spanish_dream_copy())
		failures.append_array(await _check_sleep_not_on_spawn())
		failures.append_array(await _check_sleep_completes_plazo())
		_world.free()
		_world = null
	failures.append_array(_check_complete_dream_hides_plazo())
	failures.append_array(_check_hub_lock_and_castejon_travel())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_navapalos/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_navapalos world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	var cid_scene: Resource = load(CID)
	if cid_scene == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Gabriel") == null:
		failures.append("world missing Gabriel")
	if _world.get_node_or_null("CloakBed") == null:
		failures.append("world missing CloakBed")
	if _world.get_node_or_null("SleepZone") == null:
		failures.append("world missing SleepZone")
	if _world.get_node_or_null("TentA") == null:
		failures.append("world missing TentA")
	if _world.get_node_or_null("FigTree") == null:
		failures.append("world missing FigTree")
	if _world.get_node_or_null("DreamCamera") == null:
		failures.append("world missing DreamCamera")
	if _world.get_node_or_null("SleepCinematic") == null:
		failures.append("world missing SleepCinematic")
	if _world.find_child("PlazoBar", true, false) == null:
		failures.append("plazo bar missing from a1_navapalos HUD")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_navapalos HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a1_navapalos HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a1_navapalos":
		failures.append("ChapterRunner.current_id want a1_navapalos got %s" % _runner.current_id)
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_navapalos must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_navapalos has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a1_navapalos greybox missing camp CSG")
	var tents := _world.find_children("*", "CSGCombiner3D", true, false)
	if tents.size() < 1:
		failures.append("a1_navapalos greybox missing tent CSGCombiner")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 1:
		failures.append("a1_navapalos greybox missing fig CSG")
	var players := _world.find_children("*", "AnimationPlayer", true, false)
	if players.size() < 1:
		failures.append("a1_navapalos missing sleep AnimationPlayer")
	return failures


func _check_gabriel_not_combatant() -> PackedStringArray:
	var failures: PackedStringArray = []
	var gabriel: Node = _world.get_node_or_null("Gabriel")
	if gabriel == null:
		failures.append("Gabriel missing")
		return failures
	var gid := str(gabriel.get("character_id")) if "character_id" in gabriel else ""
	if gid != "gabriel":
		failures.append("Gabriel character_id want gabriel got %s" % gid)
	if gabriel.find_children("*", "Area3D", true, false).size() != 0:
		failures.append("Gabriel must not have Area3D / HurtBox")
	if gabriel.get_node_or_null("CidCombat") != null:
		failures.append("Gabriel must not have CidCombat")
	if gabriel.has_method("slam") or gabriel.has_method("leap"):
		failures.append("Gabriel must not be a combatant")
	return failures


func _check_spanish_dream_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var line := str(_loc.call("text", DREAM))
	if line == DREAM or line.is_empty():
		failures.append("Loc did not resolve a1_navapalos.gabriel_dream")
	var lowered := line.to_lower()
	if not lowered.contains("viv") and not lowered.contains("éxito") and not lowered.contains("hará"):
		failures.append("dream line Spanish missing live/succeed sense, got %s" % line)
	return failures


func _check_sleep_not_on_spawn() -> PackedStringArray:
	var failures: PackedStringArray = []
	for _i in range(4):
		await physics_frame
	if bool(_world.get("_slept")):
		failures.append("sleep fired on spawn physics frames")
	if bool(_world.get("_dreamed")):
		failures.append("dream completed on spawn physics frames")
	if _clock and int(_clock.plazo_days_left) != 9:
		failures.append("plazo must not complete on spawn, got %s" % _clock.plazo_days_left)
	return failures


func _check_sleep_completes_plazo() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not _world.has_method("run_sleep"):
		failures.append("world missing run_sleep")
		return failures
	_fails.clear()
	var scene_before: Node = current_scene
	var marks_before := 0
	if _treasury and _treasury.state:
		marks_before = int(_treasury.state.marks)
	await _world.run_sleep()
	if current_scene != scene_before:
		failures.append("headless sleep must not change_scene when current_scene != world")
	if _clock and int(_clock.plazo_days_left) != 0:
		failures.append("after run_sleep plazo_days_left want 0 got %s" % _clock.plazo_days_left)
	if "plazo_expired" in _fails:
		failures.append("navapalos must not hard_fail plazo_expired")
	if not _fails.is_empty():
		failures.append("hard_fail during sleep: %s" % ", ".join(_fails))
	var bar: Node = _world.find_child("PlazoBar", true, false)
	if bar == null or bool(bar.visible):
		failures.append("plazo bar must be hidden after sleep")
	if _runner:
		var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
		if "hub_lock_cardena" not in flags:
			failures.append("hub_lock_cardena must remain after dream")
		if _runner.has_method("can_travel"):
			if not bool(_runner.can_travel(&"a1_navapalos", &"a1_castejon", flags)):
				failures.append("can_travel navapalos -> castejon must be true after beat")
			if bool(_runner.can_travel(&"a1_navapalos", &"a1_cardena", flags)):
				failures.append("hub_lock_cardena still blocks cardena")
	if _treasury and _treasury.state and int(_treasury.state.marks) != marks_before:
		failures.append("sleep must not feed / spend marks")
	var whisper: Node = _world.find_child("HallWhisper", true, false)
	var shown := ""
	if whisper:
		var label: Node = whisper.get_node_or_null("Line")
		if label and "text" in label:
			shown = str(label.get("text"))
	if shown.is_empty() or (not shown.to_lower().contains("viv") and not shown.to_lower().contains("hará")):
		failures.append("hall-whisper did not show the Gabriel line, got %s" % shown)
	return failures


func _check_complete_dream_hides_plazo() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	if _clock:
		_clock.plazo_days_left = 4
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("complete_dream: world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	get_root().add_child(_world)
	_fails.clear()
	var scene_before: Node = current_scene
	if not _world.has_method("complete_dream"):
		failures.append("world missing complete_dream")
		_world.free()
		_world = null
		return failures
	_world.complete_dream()
	if current_scene != scene_before:
		failures.append("complete_dream must not change_scene when current_scene != world")
	if _clock and int(_clock.plazo_days_left) != 0:
		failures.append("after complete_dream plazo_days_left want 0 got %s" % _clock.plazo_days_left)
	if "plazo_expired" in _fails:
		failures.append("complete_dream must not hard_fail plazo_expired")
	var bar: Node = _world.find_child("PlazoBar", true, false)
	if bar == null or bool(bar.visible):
		failures.append("plazo bar must be hidden after complete_dream")
	_world.free()
	_world = null
	return failures


func _check_hub_lock_and_castejon_travel() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	if _runner.has_method("restore"):
		_runner.restore(&"a1_navapalos", PackedStringArray(["hub_lock_cardena"]))
	else:
		_runner.current_id = &"a1_navapalos"
		_runner.flags = PackedStringArray(["hub_lock_cardena"])
	var scene_before: Node = current_scene
	var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
	if _runner.has_method("can_travel"):
		if not bool(_runner.can_travel(&"a1_navapalos", &"a1_castejon", flags)):
			failures.append("can_travel navapalos -> castejon should be true")
		if bool(_runner.can_travel(&"a1_navapalos", &"a1_cardena", flags)):
			failures.append("can_travel navapalos -> cardena must be false after hub lock")
	if not _runner.travel(&"a1_castejon"):
		failures.append("navapalos -> castejon should travel")
	if _runner.current_id != &"a1_castejon":
		failures.append("travel must land on a1_castejon, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("travel() must not change_scene; goto is the scene swap")
	if ResourceLoader.exists("res://content/chapters/a1_castejon/world.tscn"):
		failures.append("PR-10a must not ship a1_castejon/world.tscn")
	return failures


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _prep_campaign() -> void:
	if _honor:
		if _honor.has_method("reset_state"):
			_honor.reset_state()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(&"a1_navapalos", PackedStringArray(["hub_lock_cardena"]))
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray(["hub_lock_cardena"])
			if "current_id" in _runner:
				_runner.current_id = &"a1_navapalos"
	if _bus and _bus.has_signal("hard_fail"):
		if not _bus.hard_fail.is_connected(_on_hard_fail):
			_bus.hard_fail.connect(_on_hard_fail)
	_fails.clear()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a1_navapalos: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_navapalos: %s" % failure)
	quit(1)
