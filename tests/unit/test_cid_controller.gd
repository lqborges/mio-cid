extends SceneTree
## Headless isometric controller smoke test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_cid_controller.gd

var _failures: PackedStringArray = []
var _leap_cid: CharacterBody3D = null
var _leap_queued: bool = false


func _initialize() -> void:
	_failures.append_array(_check_cid_scene())
	_failures.append_array(_check_arena_scene())
	_failures.append_array(_check_desktop_lmb_walks())
	call_deferred("_begin_input_routing_checks")


func _check_cid_scene() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("cid.tscn failed to load")
		return failures
	var node: Node = (packed as PackedScene).instantiate()
	if not (node is CharacterBody3D):
		failures.append("Cid root is not CharacterBody3D")
		node.free()
		return failures
	var cid := node as CharacterBody3D
	if cid.get_script() == null:
		failures.append("Cid missing controller script")
	if cid.get_node_or_null("CameraRig/Camera3D") == null:
		failures.append("Cid missing locked Camera3D")
	if cid.get_node_or_null("CidCombat") == null:
		failures.append("Cid missing CidCombat stub")
	if cid.get_node_or_null("Visual") == null:
		failures.append("Cid missing Visual mesh root")
	if cid.has_method("roll"):
		failures.append("CidController still exposes roll (Souls identity)")
	if not cid.has_method("facing_dir") or not cid.has_method("is_dodging"):
		failures.append("CidController missing facing_dir / is_dodging")
	var combat: Node = cid.get_node_or_null("CidCombat")
	if combat:
		for method in ["slam", "leap", "shout", "weapon_swap"]:
			if not combat.has_method(method):
				failures.append("CidCombat missing %s" % method)
	cid.free()
	return failures


func _check_arena_scene() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/chapters/_dev/arena.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("arena.tscn failed to load")
		return failures
	var arena: Node = (packed as PackedScene).instantiate()
	var lights := arena.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("arena must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := arena.find_children("*", "OmniLight3D", true, false)
	extras.append_array(arena.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("arena has extra local lights")
	var cid: Node = arena.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("arena missing instanced Cid")
	var boxes := arena.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 4:
		failures.append("arena greybox missing floor/boxes")
	arena.free()
	return failures


func _check_desktop_lmb_walks() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("desktop LMB: cid.tscn failed to load")
		return failures
	var cid := (packed as PackedScene).instantiate() as CharacterBody3D
	if cid == null:
		failures.append("desktop LMB: Cid is not CharacterBody3D")
		return failures
	get_root().add_child(cid)
	var hud_script: Script = load("res://game/ui/touch_hud.gd") as Script
	if hud_script:
		hud_script.set("pointer_blocked", false)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	lmb.position = Vector2(640, 360)
	cid._unhandled_input(lmb)
	if bool(cid.get("_queued_slam")):
		failures.append("desktop LMB must not slam; it is click-to-move")
	if cid.get("_queued_click_pos") == null:
		failures.append("desktop LMB must queue click-to-move")
	cid.free()
	return failures


func _check_hud_input_does_not_eat_buttons() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("hud input: cid.tscn failed to load")
		return failures
	var cid := (packed as PackedScene).instantiate() as CharacterBody3D
	if cid == null:
		failures.append("hud input: Cid is not CharacterBody3D")
		return failures
	get_root().add_child(cid)
	var sink := Control.new()
	sink.name = "FakeChoice"
	sink.visible = true
	sink.set_anchors_preset(Control.PRESET_FULL_RECT)
	sink.mouse_filter = Control.MOUSE_FILTER_STOP
	sink.add_to_group("modal_choice")
	sink.add_to_group("hud_click_sink")
	get_root().add_child(sink)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	lmb.position = Vector2(640, 360)
	cid._input(lmb)
	var vp := cid.get_viewport()
	if vp and vp.is_input_handled():
		failures.append("Cid _input must not eat modal ChoiceUI / KeepOrSell button clicks")
	if cid.has_method("_modal_ui_open") and not bool(cid.call("_modal_ui_open")):
		failures.append("visible modal_choice must count as modal UI")
	sink.free()
	cid.free()
	return failures


func _check_dialogue_does_not_queue_interact() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("dialogue interact: cid.tscn failed to load")
		return failures
	var cid := (packed as PackedScene).instantiate() as CharacterBody3D
	get_root().add_child(cid)
	var layer := CanvasLayer.new()
	layer.name = "FakeBalloon"
	layer.visible = true
	get_root().add_child(layer)
	layer.add_to_group("talk_balloon")
	if cid.has_method("_dialogue_open") and not bool(cid.call("_dialogue_open")):
		failures.append("talk_balloon group must count as dialogue open")
	var key := InputEventAction.new()
	key.action = &"interact"
	key.pressed = true
	cid._unhandled_input(key)
	if bool(cid.get("_queued_interact")):
		failures.append("E during talk balloon must not queue another interact")
	layer.free()
	cid.free()
	return failures


func _check_false_interact_does_not_block_walk() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("false interact: cid.tscn failed to load")
		return failures
	var cid := (packed as PackedScene).instantiate() as CharacterBody3D
	get_root().add_child(cid)
	var body := StaticBody3D.new()
	body.name = "NoTalk"
	var script := GDScript.new()
	script.source_code = "extends StaticBody3D\nfunc interact() -> bool:\n\treturn false\n"
	script.reload()
	body.set_script(script)
	get_root().add_child(body)
	if cid.has_method("_try_interact_node") and bool(cid.call("_try_interact_node", body)):
		failures.append("interact() false must not count as a talk hit")
	body.free()
	cid.free()
	return failures


func _begin_input_routing_checks() -> void:
	_failures.append_array(_check_hud_input_does_not_eat_buttons())
	_failures.append_array(_check_dialogue_does_not_queue_interact())
	_failures.append_array(_check_false_interact_does_not_block_walk())
	_failures.append_array(_check_interact_chip_follows_npc())
	_begin_leap_tick()


func _check_interact_chip_follows_npc() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("interact chip: cid.tscn failed to load")
		return failures
	var cid := (packed as PackedScene).instantiate() as CharacterBody3D
	get_root().add_child(cid)
	var npc := StaticBody3D.new()
	npc.name = "AlvarStandin"
	npc.position = Vector3(2.0, 0.0, -1.5)
	npc.add_to_group("interactable")
	var script := GDScript.new()
	script.source_code = (
		"extends StaticBody3D\n"
		+ "func interact() -> void:\n"
		+ "\tpass\n"
		+ "func interact_prompt_key() -> String:\n"
		+ "\treturn \"hud.interact_verb\"\n"
	)
	script.reload()
	npc.set_script(script)
	get_root().add_child(npc)
	if cid.has_method("_update_interact_prompt"):
		cid.call("_update_interact_prompt")
	var ring: Node3D = cid.get_node_or_null("SelectedTarget") as Node3D
	if ring == null:
		failures.append("gold ring SelectedTarget missing")
	elif not ring.visible:
		failures.append("gold ring should show under the selected NPC")
	elif ring.global_position.distance_to(npc.global_position) > 0.8:
		failures.append("gold ring must sit under the NPC, not the HUD")
	var chip: Label3D = cid.find_child("InteractChip", true, false) as Label3D
	if chip == null:
		failures.append("InteractChip Label3D missing — E must ride the selected NPC")
	elif not chip.visible:
		failures.append("InteractChip should be visible while an NPC is selected")
	elif chip.get_parent() != ring:
		failures.append("InteractChip must be parented to the gold ring")
	var hint: Label = cid.get("_prompt_label") as Label
	if hint != null and hint.visible and hint.position.y > 600.0:
		failures.append("E chip stayed on the HUD bottom edge at y=%s" % hint.position.y)
	var layer: Node = get_root().get_node_or_null("InteractPrompt")
	if layer != null and layer.get_parent() == cid:
		failures.append("InteractPrompt CanvasLayer must not be a child of Cid")
	npc.free()
	cid.free()
	if layer != null and is_instance_valid(layer):
		layer.free()
	return failures


func _begin_leap_tick() -> void:
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		_failures.append("leap tick: cid.tscn failed to load")
		_finish(_failures)
		return
	_leap_cid = (packed as PackedScene).instantiate() as CharacterBody3D
	if _leap_cid == null:
		_failures.append("leap tick: Cid root is not CharacterBody3D")
		_finish(_failures)
		return
	get_root().add_child(_leap_cid)
	physics_frame.connect(_on_leap_physics_frame)


func _on_leap_physics_frame() -> void:
	if _leap_cid == null or not _leap_cid.is_inside_tree():
		return
	if not _leap_queued:
		# Zero stick: do not press move. Leap XZ must follow facing for this tick.
		_leap_cid.set("_queued_leap", true)
		_leap_queued = true
		return
	physics_frame.disconnect(_on_leap_physics_frame)
	_failures.append_array(_assert_leap_xz(_leap_cid))
	_leap_cid.free()
	_leap_cid = null
	_finish(_failures)


func _assert_leap_xz(cid: CharacterBody3D) -> PackedStringArray:
	var failures: PackedStringArray = []
	var facing: Vector3 = cid.call("facing_dir")
	facing.y = 0.0
	var combat: Node = cid.get_node_or_null("CidCombat")
	var leap_speed: float = 8.0
	if combat != null:
		leap_speed = float(combat.get("leap_speed"))
	if facing.length_squared() < 0.0001:
		failures.append("leap tick: facing xz is zero")
	else:
		facing = facing.normalized()
		var expected := Vector3(facing.x, 0.0, facing.z) * leap_speed
		var got := Vector3(cid.velocity.x, 0.0, cid.velocity.z)
		if got.distance_to(expected) > 0.05:
			failures.append("leap tick: velocity.xz %s != facing * leap_speed %s" % [got, expected])
	if cid.velocity.y <= 0.1:
		failures.append("leap tick: expected hop Y, got %s" % cid.velocity.y)
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_cid_controller: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_cid_controller: %s" % failure)
	quit(1)
