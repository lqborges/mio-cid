extends SceneTree
## Headless Tagus AND-join fixture (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_tagus_join.gd
## Autoload identifiers are not visible to a -s MainLoop script; look them up.

const GRAPH := preload("res://game/chapters/chapter_graph.gd")

var _runner: Node
var _graph: Resource


func _initialize() -> void:
	var failures: PackedStringArray = []
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
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
	return failures


func _test_runner_has_no_class_name_collision() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner.get_script() == null:
		failures.append("ChapterRunner missing script")
		return failures
	var source := ""
	if _runner.get_script() is GDScript:
		source = (_runner.get_script() as GDScript).source_code
	if source.begins_with("class_name"):
		failures.append("ChapterRunner must not declare class_name")
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
