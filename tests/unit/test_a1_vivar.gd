extends SceneTree
## Headless a1_vivar prologue test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_a1_vivar.gd

const WORLD := "res://content/chapters/a1_vivar/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"

var _clock: Variant
var _treasury: Variant
var _runner: Variant
var _loc: Variant
var _world: Node = null


func _initialize() -> void:
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_loc = get_root().get_node_or_null(NodePath("Loc"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_scene_loads())
	if _world:
		failures.append_array(_check_plazo_bar_present())
		failures.append_array(_check_greybox_lights())
		failures.append_array(await _check_first_names_set_seen())
		failures.append_array(_check_advance_plazo_does_not_feed())
		_world.free()
		_world = null
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_vivar/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_vivar world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	var cid_scene: Resource = load(CID)
	if cid_scene == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Alvar") == null:
		failures.append("world missing Álvar companion")
	if _world.get_node_or_null("Martin") == null:
		failures.append("world missing Martín companion")
	if _world.find_child("Chest", true, false) != null:
		failures.append("empty solar still has a Chest")
	return failures


func _check_plazo_bar_present() -> PackedStringArray:
	var failures: PackedStringArray = []
	var bar: Node = _world.find_child("PlazoBar", true, false)
	if bar == null:
		failures.append("plazo bar missing from a1_vivar HUD")
	elif not (bar is Control):
		failures.append("plazo bar is not a Control")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_vivar must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_vivar has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 6:
		failures.append("a1_vivar greybox missing house/courtyard CSG")
	return failures


func _check_first_names_set_seen() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null:
		failures.append("ChapterRunner autoload missing")
		return failures
	if "flags" in _runner:
		_runner.flags = PackedStringArray()
	if _loc:
		var alvar := str(_loc.call("text", "a1_vivar.call_alvar"))
		if not alvar.contains("Álvar"):
			failures.append("Spanish first name Álvar missing from Loc, got %s" % alvar)
		var martin := str(_loc.call("text", "a1_vivar.call_martin"))
		if not martin.contains("Martín"):
			failures.append("Spanish first name Martín missing from Loc, got %s" % martin)
	if not _world.has_method("run_first_names"):
		failures.append("world missing run_first_names")
		return failures
	await _world.run_first_names()
	var flags: PackedStringArray = PackedStringArray()
	if "flags" in _runner:
		flags = _runner.flags
	if "vivar_seen" not in flags:
		failures.append("first-names call did not set vivar_seen, flags=%s" % str(flags))
	return failures


func _check_advance_plazo_does_not_feed() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _clock == null or _treasury == null:
		failures.append("CampaignClock or TreasuryService missing")
		return failures
	if _clock.has_method("reset"):
		_clock.reset()
	if _treasury.has_method("reset"):
		_treasury.reset()
	_treasury.state.marks = 200
	_clock.unfed_streak = 1
	_clock.days_elapsed = 3
	_clock.plazo_days_left = 9
	if not _world.has_method("leave_solar"):
		failures.append("world missing leave_solar")
		return failures
	_world.set("_left", false)
	_world.leave_solar()
	if int(_clock.plazo_days_left) != 8:
		failures.append("leave_solar should advance_plazo(1) to 8, got %s" % _clock.plazo_days_left)
	if int(_treasury.state.marks) != 200:
		failures.append("advance_plazo must not spend marks, got %s" % _treasury.state.marks)
	if int(_clock.unfed_streak) != 1:
		failures.append("advance_plazo must not touch unfed_streak")
	if int(_clock.days_elapsed) != 3:
		failures.append("advance_plazo must not advance days_elapsed")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a1_vivar: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_vivar: %s" % failure)
	quit(1)
