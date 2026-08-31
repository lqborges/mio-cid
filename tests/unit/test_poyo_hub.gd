extends SceneTree
## Headless El Poyo camp hub test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_poyo_hub.gd

const GRAPH := preload("res://game/chapters/chapter_graph.gd")
const WORLD_PATH := "res://content/chapters/a1_poyo/world.tscn"

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
	failures.append_array(_test_scene_loads())
	failures.append_array(_test_second_visit_skips_intro())
	failures.append_array(_test_cannot_return_to_cardena())
	failures.append_array(_test_cannot_skip_tevar())
	failures.append_array(_test_extra_raid_closed())
	failures.append_array(_test_skip_repeatable_travel())
	failures.append_array(_test_mesnada_can_camp())
	_finish(failures)


func _can_travel(from_id: StringName, to_id: StringName, flags: PackedStringArray) -> bool:
	if _runner != null and _runner.has_method("can_travel"):
		return bool(_runner.can_travel(from_id, to_id, flags))
	return bool(_graph.can_travel(from_id, to_id, flags))


func _test_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load(WORLD_PATH)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_poyo/world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	if world.find_children("*", "DirectionalLight3D", true, false).size() != 1:
		failures.append("poyo must keep exactly 1 DirectionalLight3D")
	if world.find_children("*", "OmniLight3D", true, false).size() != 0:
		failures.append("poyo gained OmniLight3D")
	if world.find_children("*", "SpotLight3D", true, false).size() != 0:
		failures.append("poyo gained SpotLight3D")
	if world.get_node_or_null("Mesnada") == null:
		failures.append("poyo missing Mesnada")
	if world.get_node_or_null("Cid") == null:
		failures.append("poyo missing Cid")
	if world.get_node_or_null("PoyoHill") == null:
		failures.append("poyo missing the namesake hill")
	if world.get_node_or_null("NavigationRegion3D") == null:
		failures.append("poyo missing NavigationRegion3D")
	if world.find_children("*", "GPUParticles3D", true, false).size() != 0:
		failures.append("poyo has GPUParticles3D")
	root.add_child(world)
	if world.has_method("place_name_text"):
		var name_text := str(world.call("place_name_text"))
		if name_text != "El Poyo del Cid":
			failures.append("place name must be Spanish first, got %s" % name_text)
	world.free()
	return failures


func _test_second_visit_skips_intro() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("restore"):
		failures.append("ChapterRunner.restore missing")
		return failures
	_runner.restore(&"a1_poyo", PackedStringArray())
	var packed: Resource = load(WORLD_PATH)
	var first: Node = (packed as PackedScene).instantiate()
	root.add_child(first)
	if first.has_method("apply_arrival"):
		first.apply_arrival()
	if not bool(first.get("intro_played")):
		failures.append("first Poyo visit must play the arrival beat")
	if bool(first.get("intro_skipped")):
		failures.append("first Poyo visit must not skip the arrival beat")
	if _runner.has_method("has_flag") and not bool(_runner.has_flag(&"poyo_named")):
		failures.append("first arrival must set poyo_named")
	elif "poyo_named" not in _runner.flags:
		failures.append("first arrival must set poyo_named")
	first.free()
	_runner.restore(&"a1_poyo", PackedStringArray(["poyo_named", "hub_lock_cardena"]))
	if _runner.director != null and int(_runner.director.step_index) < 1:
		failures.append("BeatDirector must skip the named arrival on a return visit")
	var second: Node = (packed as PackedScene).instantiate()
	root.add_child(second)
	if second.has_method("apply_arrival"):
		second.apply_arrival()
	if not bool(second.get("intro_skipped")):
		failures.append("second Poyo visit must skip the first-arrival beat")
	if bool(second.get("intro_played")):
		failures.append("second Poyo visit must not replay the first-arrival beat")
	second.free()
	return failures


func _test_cannot_return_to_cardena() -> PackedStringArray:
	var failures: PackedStringArray = []
	var locked := PackedStringArray(["hub_lock_cardena", "poyo_named"])
	if _can_travel(&"a1_poyo", &"a1_cardena", locked):
		failures.append("Poyo must not open a return to Cardeña")
	if _can_travel(&"a1_arcas", &"a1_cardena", PackedStringArray(["hub_lock_cardena"])):
		failures.append("hub_lock_cardena must forbid travel to a1_cardena")
	if not _can_travel(&"a1_arcas", &"a1_cardena", PackedStringArray()):
		failures.append("Cardeña must stay open from Arcas before the hub lock")
	if _runner.has_method("restore"):
		_runner.restore(&"a1_poyo", locked)
		var packed: Resource = load(WORLD_PATH)
		var world: Node = (packed as PackedScene).instantiate()
		root.add_child(world)
		if world.has_method("apply_arrival"):
			world.apply_arrival()
		if bool(world.call("can_return_to_cardena")):
			failures.append("world.can_return_to_cardena must be false")
		if bool(world.call("try_travel_cardena")):
			failures.append("try_travel_cardena must fail")
		if String(_runner.current_id) == "a1_cardena":
			failures.append("travel must not land on Cardeña")
		world.free()
	return failures


func _test_cannot_skip_tevar() -> PackedStringArray:
	var failures: PackedStringArray = []
	var flags := PackedStringArray(["poyo_named", "hub_lock_cardena"])
	if not _can_travel(&"a1_poyo", &"a1_tevar", flags):
		failures.append("Tévar must stay the forward exit from Poyo")
	if _can_travel(&"a1_poyo", &"a2_murviedro", flags):
		failures.append("Poyo must not skip Tévar into Act II")
	if _can_travel(&"a1_embassy1", &"a1_tevar", flags):
		failures.append("Act I must not skip Poyo into Tévar")
	if _runner.has_method("restore"):
		_runner.restore(&"a1_poyo", flags)
		if not bool(_runner.travel(&"a1_tevar")):
			failures.append("Poyo -> Tévar travel should succeed")
		if String(_runner.current_id) != "a1_tevar":
			failures.append("forward exit must land on a1_tevar")
	return failures


func _test_extra_raid_closed() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _can_travel(&"a1_poyo", &"a1_poyo_raid", PackedStringArray()):
		failures.append("extra raid edge must stay closed without v1_extra_raids")
	if _can_travel(&"a1_poyo", &"a1_poyo_raid", PackedStringArray(["poyo_named"])):
		failures.append("poyo_named must not open the v1-cut raid")
	if not _can_travel(&"a1_poyo", &"a1_poyo_raid", PackedStringArray(["v1_extra_raids"])):
		failures.append("v1_extra_raids should still open the authored raid edge")
	if _runner.has_method("restore"):
		_runner.restore(&"a1_poyo", PackedStringArray(["poyo_named"]))
		if bool(_runner.travel(&"a1_poyo_raid")):
			failures.append("travel into a1_poyo_raid must fail while the flag is off")
		if String(_runner.current_id) == "a1_poyo_raid":
			failures.append("current_id must not become a1_poyo_raid")
	return failures


func _test_skip_repeatable_travel() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_skip_travel"):
		failures.append("ChapterRunner.can_skip_travel missing")
		return failures
	if bool(_runner.can_skip_travel(&"a1_embassy1", &"a1_poyo", PackedStringArray())):
		failures.append("cannot skip the Poyo corridor before the first arrival")
	if not bool(_runner.can_skip_travel(&"a1_embassy1", &"a1_poyo", PackedStringArray(["poyo_named"]))):
		failures.append("poyo_named must allow skipping the repeatable Poyo corridor")
	if bool(_runner.can_skip_travel(&"a1_poyo", &"a1_tevar", PackedStringArray(["poyo_named"]))):
		failures.append("Tévar corridor must not skip before it has been ridden")
	if bool(_runner.can_skip_travel(&"a1_poyo", &"a1_cardena", PackedStringArray(["poyo_named", "hub_lock_cardena"]))):
		failures.append("skip-travel must still respect hub_lock_cardena")
	return failures


func _test_mesnada_can_camp() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner != null and _runner.has_method("restore"):
		_runner.restore(&"a1_poyo", PackedStringArray(["poyo_named"]))
	var packed: Resource = load(WORLD_PATH)
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	if world.has_method("apply_arrival"):
		world.apply_arrival()
	var mesnada: Node = world.get_node_or_null("Mesnada")
	if mesnada == null or not mesnada.has_method("plant_banner_at_leader"):
		failures.append("Poyo mesnada missing follow AI")
		world.free()
		return failures
	if world.has_method("rest_camp"):
		world.rest_camp()
	if str(mesnada.get("formation")) != "wedge":
		failures.append("rest_camp should plant the banner so the mesnada can camp")
	var clock: Node = root.get_node_or_null(NodePath("CampaignClock"))
	if clock != null and "segment" in clock and int(clock.segment) != 1 and not clock.has_method("rest_camp"):
		failures.append("Poyo camp should use CampaignClock camp night")
	world.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_poyo_hub: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_poyo_hub: %s" % failure)
	quit(1)
