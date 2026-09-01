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
		failures.append_array(_check_hud_labels_and_click_sink())
		failures.append_array(_check_nameplates())
		failures.append_array(_check_companions_interactable())
		failures.append_array(_check_pause_menu())
		failures.append_array(_check_plazo_clock_bound_on_ready())
		failures.append_array(_check_talk_balloon_advances_on_click())
		failures.append_array(_check_greybox_lights())
		failures.append_array(await _check_first_names_set_seen())
		failures.append_array(_check_advance_plazo_does_not_feed())
		failures.append_array(_check_south_gate_leave())
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
	var gate: Node = _world.get_node_or_null("Gate")
	if gate == null or not gate.has_method("interact"):
		failures.append("world missing Gate leave interact")
	if gate and not gate.is_in_group("interactable"):
		failures.append("Gate must be interactable")
	if gate is CollisionObject3D and (gate as CollisionObject3D).collision_layer == 1:
		failures.append("Gate layer 1 blocks Cid (mask 5) and traps the solar")
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


func _check_hud_labels_and_click_sink() -> PackedStringArray:
	var failures: PackedStringArray = []
	var meters: Node = _world.find_child("HonorMeters", true, false)
	if meters == null or not (meters is Control):
		failures.append("HonorMeters missing")
		return failures
	var hud := meters as Control
	if hud.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("HonorMeters must STOP mouse so HUD is a click sink")
	if not hud.is_in_group("hud_click_sink"):
		failures.append("HonorMeters must join hud_click_sink")
	if hud.get_rect().size.x < 200.0:
		failures.append("HonorMeters hit rect is too small to sink clicks")
	if hud.has_method("_meter_label"):
		var onores := str(hud.call("_meter_label", &"onores"))
		if onores != "Honores":
			failures.append("onores label want Honores, got %s" % onores)
		if onores == "onores" or onores.begins_with("onores"):
			failures.append("onores label is still clipped/uncapitalized")
	var bar: Node = _world.find_child("PlazoBar", true, false)
	if bar is Control and (bar as Control).mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("PlazoBar must STOP mouse so HUD is a click sink")
	return failures


func _check_nameplates() -> PackedStringArray:
	var failures: PackedStringArray = []
	var looks: Node = get_root().get_node_or_null("HumanoidLooks")
	if looks and looks.has_method("ensure"):
		looks.call("ensure", _world)
	for path in ["Alvar/Name", "Martin/Name"]:
		var label: Label3D = _world.get_node_or_null(path) as Label3D
		if label == null:
			failures.append("missing nameplate %s" % path)
			continue
		if label.fixed_size:
			failures.append("%s nameplate must not use fixed_size (it blows up on the isometric camera)" % path)
		if label.font_size > 32:
			failures.append("%s nameplate font_size %s is too large" % [path, label.font_size])
		if label.pixel_size > 0.006:
			failures.append("%s nameplate pixel_size %s is too large" % [path, label.pixel_size])
		var world_h := float(label.font_size) * float(label.pixel_size)
		if world_h > 0.18:
			failures.append("%s nameplate world height %s is too tall" % [path, world_h])
	return failures


func _check_companions_interactable() -> PackedStringArray:
	var failures: PackedStringArray = []
	for name in ["Alvar", "Martin"]:
		var npc: Node = _world.get_node_or_null(name)
		if npc == null:
			failures.append("missing %s" % name)
			continue
		if not npc.has_method("interact"):
			failures.append("%s missing interact()" % name)
		if not npc.is_in_group("interactable"):
			failures.append("%s must be in interactable group" % name)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid and cid.has_method("_nearest_interactable"):
		var near: Variant = cid.call("_nearest_interactable")
		if near == null:
			failures.append("Cid should see a nearby interactable in the solar")
	return failures


func _check_pause_menu() -> PackedStringArray:
	var failures: PackedStringArray = []
	var pause: Node = get_root().get_node_or_null("PauseMenu")
	if pause == null:
		failures.append("PauseMenu autoload missing")
		return failures
	if not pause.has_method("open") or not pause.has_method("resume"):
		failures.append("PauseMenu missing open/resume")
		return failures
	pause.call("open")
	if not bool(pause.visible):
		failures.append("Escape pause menu did not open")
	if pause.get_node_or_null("Panel/Center/Resume") == null:
		failures.append("pause menu missing Resume")
	if pause.get_node_or_null("Panel/Center/Menu") == null:
		failures.append("pause menu missing Menu")
	if pause.get_node_or_null("Panel/Center/Quit") == null:
		failures.append("pause menu missing Quit")
	if not paused:
		failures.append("pause menu must pause the tree")
	pause.call("resume")
	if paused:
		failures.append("resume must unpause the tree")
	return failures


func _check_plazo_clock_bound_on_ready() -> PackedStringArray:
	var failures: PackedStringArray = []
	var bar: Node = _world.find_child("PlazoBar", true, false)
	if bar == null:
		failures.append("PlazoBar missing for ready bind")
		return failures
	if bar is CanvasItem and not (bar as CanvasItem).is_processing():
		failures.append("PlazoBar must start processing from _ready, not the first HUD click")
	var bus: Node = get_root().get_node_or_null("EventBus")
	if bus and bus.has_signal("beat_completed") and bar.has_method("_on_beat_completed"):
		if not bus.beat_completed.is_connected(bar._on_beat_completed):
			failures.append("PlazoBar must connect beat_completed in _ready")
	return failures


func _check_talk_balloon_advances_on_click() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://game/ui/talk_balloon.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("talk_balloon.tscn failed to load")
		return failures
	var balloon: Node = (packed as PackedScene).instantiate()
	if balloon == null:
		failures.append("talk_balloon did not instantiate")
		return failures
	get_root().add_child(balloon)
	if not balloon.has_method("_try_advance") or not balloon.has_method("_input"):
		failures.append("talk balloon must advance from _input so HUD/Cid cannot eat the click")
		balloon.free()
		return failures
	balloon.set("_waiting", true)
	balloon.set("_line", {"next_id": "end"})
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 640)
	balloon.call("_input", click)
	if bool(balloon.get("_waiting")):
		failures.append("talk balloon click must leave _waiting so the next line can show")
	balloon.free()
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


func _check_south_gate_leave() -> PackedStringArray:
	var failures: PackedStringArray = []
	_world.set("_left", false)
	var cid: Node3D = _world.get_node_or_null("Cid") as Node3D
	if cid == null:
		failures.append("Cid missing for south-gate leave")
		return failures
	cid.global_position = Vector3(0.0, 0.05, 8.4)
	if _world.has_method("_physics_process"):
		_world._physics_process(0.016)
	if not bool(_world.get("_left")):
		failures.append("Cid at the south opening must leave_solar (physics poll)")
	_world.set("_left", false)
	var gate: Node = _world.get_node_or_null("Gate")
	if gate and gate.has_method("interact"):
		gate.call("interact")
		if not bool(_world.get("_left")):
			failures.append("Gate.interact must call leave_solar")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a1_vivar: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_vivar: %s" % failure)
	quit(1)
