extends SceneTree
## Headless a1_burgos greybox test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_a1_burgos.gd

const WORLD := "res://content/chapters/a1_burgos/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const V20 := "poem.v20"

var _honor: Variant
var _runner: Variant
var _loc: Variant
var _world: Node = null


func _initialize() -> void:
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_loc = get_root().get_node_or_null(NodePath("Loc"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_scene_loads())
	if _world:
		failures.append_array(_check_greybox_lights())
		failures.append_array(_check_v20_line())
		failures.append_array(await _check_child_speaks_v20())
		failures.append_array(_check_shutters_seen())
		failures.append_array(_check_steel_on_burgaleses_gated())
		failures.append_array(_check_talk_npcs_not_camp_click())
		failures.append_array(_check_river_camp_reachable())
		_world.free()
		_world = null
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner and "flags" in _runner:
		_runner.flags = PackedStringArray()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_burgos/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_burgos world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	var cid_scene: Resource = load(CID)
	if cid_scene == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Child") == null:
		failures.append("world missing Child NPC")
	if _world.get_node_or_null("Inn") == null:
		failures.append("world missing Inn")
	if _world.get_node_or_null("Innkeeper") == null:
		failures.append("world missing Innkeeper")
	if _world.get_node_or_null("River") == null:
		failures.append("world missing River")
	if _world.find_child("ShutterW1", true, false) == null:
		failures.append("world missing shutters")
	if _world.get_node_or_null("RiverCamp") == null:
		failures.append("world missing river camp")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_burgos HUD")
	if _world.find_child("PlazoBar", true, false) == null:
		failures.append("plazo bar missing from a1_burgos HUD")
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_burgos must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_burgos has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a1_burgos greybox missing shutters/inn/river CSG")
	return failures


func _check_v20_line() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var line := str(_loc.call("text", V20))
	if line == V20 or line.is_empty():
		failures.append("Loc.text did not resolve poem.v20")
	if not line.contains("buen vassallo"):
		failures.append("v. 20 Spanish missing «buen vassallo», got %s" % line)
	if not line.contains("buen señor"):
		failures.append("v. 20 Spanish missing «buen señor», got %s" % line)
	if _loc.has_method("montaner_verse"):
		var verse := str(_loc.call("montaner_verse", V20))
		if verse != "20":
			failures.append("poem.v20 montaner_verse should be 20, got %s" % verse)
	return failures


func _check_child_speaks_v20() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not _world.has_method("run_child_v20"):
		failures.append("world missing run_child_v20")
		return failures
	await _world.run_child_v20()
	var whisper: Node = _world.find_child("HallWhisper", true, false)
	if whisper == null:
		failures.append("HallWhisper missing after v. 20")
		return failures
	var label: Node = whisper.get_node_or_null("Line")
	var shown := ""
	if label and "text" in label:
		shown = str(label.get("text"))
	if not shown.contains("buen vassallo"):
		failures.append("hall-whisper did not show v. 20, got %s" % shown)
	return failures


func _check_shutters_seen() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null:
		failures.append("ChapterRunner autoload missing")
		return failures
	var flags: PackedStringArray = PackedStringArray()
	if "flags" in _runner:
		flags = _runner.flags
	if "burgos_shutters_seen" not in flags:
		if _world.has_method("apply_beats"):
			_world.apply_beats()
			if "flags" in _runner:
				flags = _runner.flags
	if "burgos_shutters_seen" not in flags:
		failures.append("beats.json did not set burgos_shutters_seen, flags=%s" % str(flags))
	return failures


func _check_steel_on_burgaleses_gated() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _honor == null:
		failures.append("HonorService autoload missing")
		return failures
	if _honor.has_method("reset_state"):
		_honor.reset_state()
	if not _world.has_method("draw_steel_on_burgaleses"):
		failures.append("world missing draw_steel_on_burgaleses")
		return failures
	var honra_before := 40.0
	if "state" in _honor and _honor.state != null and "honra" in _honor.state:
		honra_before = float(_honor.state.honra)
	var delta := -12.0
	if _honor.has_method("event_by_id"):
		var ev: Variant = _honor.event_by_id(&"burgos_draw_steel")
		if ev != null and ev.has_method("delta_for"):
			delta = float(ev.delta_for(&"honra"))
	_world.draw_steel_on_burgaleses()
	_world.draw_steel_on_burgaleses()
	var honra_after := honra_before
	if "state" in _honor and _honor.state != null and "honra" in _honor.state:
		honra_after = float(_honor.state.honra)
	if not is_equal_approx(honra_after, honra_before + delta):
		failures.append("steel-on-burgaleses should apply burgos_draw_steel once, honra %s -> %s" % [honra_before, honra_after])
	if _world.has_method("can_storm_inn") and bool(_world.can_storm_inn()):
		failures.append("mesura gate must not allow storming the inn")
	if _world.get_node_or_null("Inn") == null:
		failures.append("drawing steel must not remove the inn")
	if _world.get_node_or_null("BurgalesA") == null or _world.get_node_or_null("Child") == null:
		failures.append("drawing steel must not kill burgaleses")
	if _world.has_method("inn_is_closed") and not bool(_world.inn_is_closed()):
		failures.append("inn must stay closed (no lodging)")
	return failures


func _check_talk_npcs_not_camp_click() -> PackedStringArray:
	var failures: PackedStringArray = []
	var camp: Node = _world.get_node_or_null("Camp")
	if camp and camp.has_method("interact"):
		failures.append("Camp must not implement interact(); RiverCamp Area3D owns travel")
	if camp and camp.is_in_group("interactable"):
		failures.append("Camp must not be interactable or E/click skips Burgos")
	var child: Node = _world.get_node_or_null("Child")
	if child == null or not child.is_in_group("interactable"):
		failures.append("Child must join interactable")
	if child and child.has_method("interact") and child.has_method("_is_talk_role"):
		if not bool(child.call("_is_talk_role")):
			failures.append("Child should be a talk role")
	var inn: Node = _world.get_node_or_null("Innkeeper")
	if inn == null or not inn.is_in_group("interactable"):
		failures.append("Innkeeper must join interactable")
	var burgales: Node = _world.get_node_or_null("BurgalesA")
	if burgales and burgales.is_in_group("interactable"):
		failures.append("Burgales must not steal E / click-to-move")
	var cid: Node = _world.get_node_or_null("Cid")
	if cid and cid.has_method("_nearest_interactable"):
		var near: Variant = cid.call("_nearest_interactable")
		if near != null and String((near as Node).name) == "Camp":
			failures.append("Cid must not treat Camp as the nearest talk target at spawn")
	if camp is CollisionObject3D and (camp as CollisionObject3D).collision_layer == 1:
		failures.append("Camp layer 1 blocks Cid from RiverCamp")
	return failures


func _check_river_camp_reachable() -> PackedStringArray:
	var failures: PackedStringArray = []
	_world.set("_camped", false)
	var cid: Node3D = _world.get_node_or_null("Cid") as Node3D
	if cid == null:
		failures.append("Cid missing for river-camp reach")
		return failures
	var spawn_z := cid.global_position.z
	if spawn_z >= 9.4:
		failures.append("Cid spawn must stay north of the river-camp poll")
	cid.global_position = Vector3(0.0, 0.05, 9.6)
	if _world.has_method("_physics_process"):
		_world._physics_process(0.016)
	if not bool(_world.get("_camped")):
		failures.append("Cid at the river tents must camp_on_river (physics poll)")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a1_burgos: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_burgos: %s" % failure)
	quit(1)
