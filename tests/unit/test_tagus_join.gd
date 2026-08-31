extends SceneTree
## Headless Tagus AND-join fixture (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_tagus_join.gd
## Autoload identifiers are not visible to a -s MainLoop script; look them up.

const GRAPH := preload("res://game/chapters/chapter_graph.gd")

var _runner: Node
var _graph: Resource
var _bus: Node


func _initialize() -> void:
	var failures: PackedStringArray = []
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_bus = get_root().get_node_or_null(NodePath("EventBus"))
	if _runner == null:
		failures.append("ChapterRunner autoload missing")
		_finish(failures)
		return
	if "graph" in _runner and _runner.graph != null:
		_graph = _runner.graph
	else:
		_graph = GRAPH.from_file()
	if _graph == null:
		failures.append("ChapterGraph failed to load")
		_finish(failures)
		return
	failures.append_array(_test_cheated_save_blocks_tagus())
	failures.append_array(_test_repay_opens_tagus())
	failures.append_array(_test_honest_path_skips_repay())
	failures.append_array(_test_act_i_stays_locked())
	failures.append_array(_test_cinematic_set_flags())
	failures.append_array(_test_travel_completes_source())
	failures.append_array(_test_reset_starts_director())
	failures.append_array(_test_advance_retries_failed_travel())
	failures.append_array(_test_runner_has_no_class_name_collision())
	_finish(failures)


func _can_travel(from_id: StringName, to_id: StringName, flags: PackedStringArray) -> bool:
	if _runner != null and _runner.has_method("can_travel"):
		return bool(_runner.can_travel(from_id, to_id, flags))
	return bool(_graph.can_travel(from_id, to_id, flags))


func _test_cheated_save_blocks_tagus() -> PackedStringArray:
	var failures: PackedStringArray = []
	var flags := PackedStringArray(["arcas_cheated", "embassy3_done"])
	if _can_travel(&"a2_embassy3", &"a2_tagus", flags):
		failures.append("cheated save must not open Tagus without repay_done")
	if not _can_travel(&"a2_embassy3", &"a2_repay_raquel", flags):
		failures.append("cheated save should open a2_repay_raquel")
	if _can_travel(&"a2_repay_raquel", &"a2_tagus", flags):
		failures.append("repay beat must not open Tagus before repay_done")
	return failures


func _test_repay_opens_tagus() -> PackedStringArray:
	var failures: PackedStringArray = []
	var flags := PackedStringArray(["arcas_cheated", "embassy3_done", "repay_done"])
	if not _can_travel(&"a2_repay_raquel", &"a2_tagus", flags):
		failures.append("repay_done must open Tagus from a2_repay_raquel")
	if _can_travel(&"a2_embassy3", &"a2_tagus", flags):
		failures.append("forbid arcas_cheated must still close embassy3 -> Tagus")
	return failures


func _test_honest_path_skips_repay() -> PackedStringArray:
	var failures: PackedStringArray = []
	var flags := PackedStringArray(["embassy3_done"])
	if not _can_travel(&"a2_embassy3", &"a2_tagus", flags):
		failures.append("honest embassy3_done must open Tagus")
	if _can_travel(&"a2_embassy3", &"a2_repay_raquel", flags):
		failures.append("a2_repay_raquel must be unreachable without arcas_cheated")
	if _can_travel(&"a2_yusuf", &"a2_repay_raquel", flags):
		failures.append("a2_repay_raquel must have no extra incoming edges")
	return failures


func _test_act_i_stays_locked() -> PackedStringArray:
	var failures: PackedStringArray = []
	var flags := PackedStringArray(["vivar_seen", "burgos_shutters_seen"])
	if not _can_travel(&"a1_vivar", &"a1_burgos", PackedStringArray(["vivar_seen"])):
		failures.append("vivar_seen should open Burgos")
	if _can_travel(&"a1_vivar", &"a1_burgos", PackedStringArray()):
		failures.append("Burgos must stay closed without vivar_seen")
	if _can_travel(&"a1_vivar", &"a1_arcas", flags):
		failures.append("Act I must not skip Burgos")
	if _can_travel(&"a1_poyo", &"a1_poyo_raid", PackedStringArray()):
		failures.append("poyo extra raids must stay v1-cut / flag off")
	if not _can_travel(&"a1_poyo_raid", &"a1_poyo", PackedStringArray()):
		failures.append("v1-cut raid must rejoin a1_poyo")
	return failures


func _test_cinematic_set_flags() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not ("director" in _runner):
		failures.append("BeatDirector missing for cinematic set_flags")
		return failures
	if _runner.has_method("reset"):
		_runner.reset()
	_runner.flags = PackedStringArray()
	var director: Node = _runner.director
	if director == null or not director.has_method("run_step"):
		failures.append("BeatDirector.run_step missing")
		return failures
	var ok: bool = director.run_step({
		"type": "cinematic",
		"set_flags": PackedStringArray(["burgos_shutters_seen"]),
	})
	if not ok:
		failures.append("cinematic step should succeed")
	if "burgos_shutters_seen" not in _runner.flags:
		failures.append("cinematic set_flags must apply burgos_shutters_seen")
	return failures


func _test_travel_completes_source() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	var completed: Array[StringName] = []
	var on_done := func(id: StringName) -> void:
		completed.append(id)
	if _bus:
		_bus.beat_completed.connect(on_done)
	if _runner.has_method("restore"):
		_runner.restore(&"a1_cardena", PackedStringArray())
	else:
		_runner.current_id = &"a1_cardena"
		_runner.flags = PackedStringArray()
	if not _runner.travel(&"a1_navapalos"):
		failures.append("cardena -> navapalos should travel")
	if completed.is_empty() or completed[completed.size() - 1] != &"a1_cardena":
		failures.append("travel must emit beat_completed for the source beat")
	if _runner.current_id != &"a1_navapalos":
		failures.append("travel must land on a1_navapalos")
	if "hub_lock_cardena" not in _runner.flags:
		failures.append("travel must apply the taken edge set_flags")
	if _bus:
		_bus.beat_completed.disconnect(on_done)
	return failures


func _test_reset_starts_director() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("reset"):
		failures.append("ChapterRunner.reset missing")
		return failures
	_runner.reset()
	if _runner.current_id != &"a1_vivar":
		failures.append("reset must return to a1_vivar")
	if _runner.director == null:
		failures.append("reset must keep BeatDirector")
	elif "beat_id" in _runner.director and String(_runner.director.beat_id) != "a1_vivar":
		failures.append("reset must start BeatDirector on a1_vivar")
	return failures


func _test_advance_retries_failed_travel() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or _runner.director == null:
		return failures
	if _runner.has_method("restore"):
		_runner.restore(&"a1_vivar", PackedStringArray())
	var director: Node = _runner.director
	director.steps = [{"type": "travel_spawn", "next": "a1_burgos"}]
	director.step_index = 0
	if director.advance():
		failures.append("travel_spawn without vivar_seen must fail")
	if int(director.step_index) != 0:
		failures.append("failed travel_spawn must not consume the step")
	_runner.add_flag("vivar_seen")
	if not director.advance():
		failures.append("travel_spawn should succeed after vivar_seen")
	return failures


func _test_runner_has_no_class_name_collision() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner.get_script() == null:
		failures.append("ChapterRunner missing script")
		return failures
	var source := ""
	if _runner.get_script() is GDScript:
		source = (_runner.get_script() as GDScript).source_code
	for line in source.split("\n"):
		if line.strip_edges().begins_with("class_name"):
			failures.append("ChapterRunner must not declare class_name")
			break
	if "graph" not in _runner or _runner.graph == null:
		failures.append("ChapterRunner must hold ChapterGraph")
	if "director" in _runner and _runner.director == null:
		failures.append("ChapterRunner must hold BeatDirector")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_tagus_join: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_tagus_join: %s" % failure)
	quit(1)
