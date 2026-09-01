extends SceneTree
## Headless touch HUD smoke test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_touch_hud.gd


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_hud())
	_finish(failures)


func _check_hud() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/ui/touch_hud.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("touch_hud.tscn failed to load")
		return failures
	var node: Node = (packed as PackedScene).instantiate()
	if node == null:
		failures.append("touch_hud.tscn instantiate failed")
		return failures
	var required := PackedStringArray(["Stick", "Slam", "Leap", "Shout", "Dodge", "Interact", "Mesura"])
	for name in required:
		var found: Node = node.find_child(name, true, false)
		if found == null:
			failures.append("missing HUD node %s" % name)
	var slam := node.find_child("Slam", true, false) as Button
	var leap := node.find_child("Leap", true, false) as Button
	var shout := node.find_child("Shout", true, false) as Button
	var dodge := node.find_child("Dodge", true, false) as Button
	var interact := node.find_child("Interact", true, false) as Button
	var mesura := node.find_child("Mesura", true, false) as Button
	if slam and slam.text != "Golpe":
		failures.append("Slam label should be Golpe, got %s" % slam.text)
	if leap and leap.text != "Salto":
		failures.append("Leap label should be Salto, got %s" % leap.text)
	if shout and shout.text != "Grito":
		failures.append("Shout label should be Grito, got %s" % shout.text)
	if dodge and dodge.text != "Esquiva":
		failures.append("Dodge label should be Esquiva, got %s" % dodge.text)
	if interact and interact.text != "Hablar":
		failures.append("Interact label should be Hablar, got %s" % interact.text)
	if mesura and mesura.text != "Mesura":
		failures.append("Mesura label should be Mesura, got %s" % mesura.text)
	for btn_name in ["Slam", "Leap", "Shout", "Dodge", "Interact", "Mesura"]:
		var btn := node.find_child(btn_name, true, false) as Control
		if btn and btn.mouse_filter != Control.MOUSE_FILTER_STOP:
			failures.append("%s mouse_filter is not STOP" % btn_name)
	var stick := node.find_child("Stick", true, false) as Control
	if stick and stick.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("Stick mouse_filter is not STOP")

	if not node.has_method("force_visible") or not node.has_method("apply_form_factor"):
		failures.append("TouchHud missing force_visible / apply_form_factor")
		node.free()
		return failures

	var hud_script: Script = load("res://game/ui/touch_hud.gd") as Script
	node.call("force_visible", false)
	if node.visible:
		failures.append("force_visible(false) left HUD visible")
	if hud_script and bool(hud_script.get("pointer_blocked")):
		failures.append("force_visible(false) left pointer_blocked")
	node.call("force_visible", true)
	if not node.visible:
		failures.append("force_visible(true) did not show HUD")
	if hud_script and not bool(hud_script.get("pointer_blocked")):
		failures.append("force_visible(true) did not set pointer_blocked")

	# Phone bucket: ~411 dp short side (1080px @ 420dpi).
	node.call("apply_form_factor", Vector2(1080, 1920), 420, Rect2())
	var phone_stick := float(node.call("stick_size"))
	var phone_button := float(node.call("button_size"))
	var phone_inset := float(node.call("edge_inset"))
	if bool(node.call("is_tablet_layout")):
		failures.append("411 dp device must use phone layout")
	if phone_stick > 160.0:
		failures.append("phone stick too large: %s" % phone_stick)
	if phone_button > 80.0:
		failures.append("phone button too large: %s" % phone_button)
	if phone_inset > 32.0:
		failures.append("phone inset too large: %s" % phone_inset)
	if stick and stick.size.x + 0.5 < phone_stick:
		failures.append("phone Stick control size %s < metric %s" % [stick.size.x, phone_stick])
	if slam and slam.size.x + 0.5 < phone_button:
		failures.append("phone Slam control size %s < metric %s" % [slam.size.x, phone_button])

	# Tablet bucket: sw600dp+ (1200px @ 240dpi = 800 dp).
	node.call("apply_form_factor", Vector2(1920, 1200), 240, Rect2())
	var tablet_stick := float(node.call("stick_size"))
	var tablet_button := float(node.call("button_size"))
	var tablet_inset := float(node.call("edge_inset"))
	if not bool(node.call("is_tablet_layout")):
		failures.append("800 dp device must use tablet layout")
	if tablet_stick <= phone_stick:
		failures.append("tablet stick %s must exceed phone %s" % [tablet_stick, phone_stick])
	if tablet_button <= phone_button:
		failures.append("tablet button %s must exceed phone %s" % [tablet_button, phone_button])
	if tablet_inset <= phone_inset:
		failures.append("tablet inset %s must exceed phone %s" % [tablet_inset, phone_inset])
	if tablet_stick < 200.0:
		failures.append("tablet stick expected ~200-220, got %s" % tablet_stick)
	if tablet_button < 90.0:
		failures.append("tablet button expected ~96, got %s" % tablet_button)
	if tablet_inset < 48.0:
		failures.append("tablet inset expected ~48-64, got %s" % tablet_inset)
	if stick and stick.size.x + 0.5 < tablet_stick:
		failures.append("tablet Stick control size %s < metric %s" % [stick.size.x, tablet_stick])
	if slam and slam.size.x + 0.5 < tablet_button:
		failures.append("tablet Slam control size %s < metric %s" % [slam.size.x, tablet_button])

	# sw600dp boundary is tablet.
	node.call("apply_form_factor", Vector2(1200, 1920), 320, Rect2())
	if not bool(node.call("is_tablet_layout")):
		failures.append("exactly 600 dp must count as tablet (sw600dp)")

	var arena_packed: Resource = load("res://content/chapters/_dev/arena.tscn")
	if arena_packed is PackedScene:
		var arena: Node = (arena_packed as PackedScene).instantiate()
		var hud_in_arena: Node = arena.find_child("TouchHud", true, false)
		if hud_in_arena == null:
			failures.append("arena.tscn does not instance TouchHud")
		elif hud_in_arena.get_parent() != arena:
			failures.append("TouchHud must be a child of the arena, not cid.tscn")
		var cid_packed: Resource = load("res://content/art/characters/cid/cid.tscn")
		if cid_packed is PackedScene:
			var cid: Node = (cid_packed as PackedScene).instantiate()
			if cid.find_child("TouchHud", true, false) != null:
				failures.append("TouchHud must not live inside cid.tscn")
			cid.free()
		arena.free()

	failures.append_array(_check_pointer_blocked_vs_lmb_slam(node, hud_script))
	node.free()
	return failures


func _check_pointer_blocked_vs_lmb_slam(hud: Node, hud_script: Script) -> PackedStringArray:
	var failures: PackedStringArray = []
	get_root().add_child(hud)
	hud.call("force_visible", true)
	if hud_script and not bool(hud_script.get("pointer_blocked")):
		failures.append("HUD in tree: pointer_blocked not set")
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("pointer slam: cid.tscn failed to load")
		return failures
	var cid: CharacterBody3D = (packed as PackedScene).instantiate() as CharacterBody3D
	if cid == null:
		failures.append("pointer slam: Cid is not CharacterBody3D")
		return failures
	get_root().add_child(cid)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	lmb.device = InputEvent.DEVICE_ID_EMULATION
	cid._unhandled_input(lmb)
	if bool(cid.get("_queued_slam")):
		failures.append("emulated LMB queued slam while HUD pointer_blocked")
	if cid.get("_queued_click_pos") == null:
		failures.append("emulated LMB should queue tap-to-walk while HUD is shown")
	cid.set("_queued_click_pos", null)
	var act := InputEventAction.new()
	act.action = "slam"
	act.pressed = true
	cid._unhandled_input(act)
	if not bool(cid.get("_queued_slam")):
		failures.append("InputEventAction slam should queue while HUD is shown")
	cid.set("_queued_slam", false)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1
	key.physical_keycode = KEY_1
	cid._unhandled_input(key)
	if not bool(cid.get("_queued_slam")):
		failures.append("InputEventKey slam should queue while HUD is shown")
	hud.call("force_visible", false)
	if hud.visible:
		failures.append("force_visible(false) did not hide HUD")
	if hud_script and bool(hud_script.get("pointer_blocked")):
		failures.append("force_visible(false) left pointer_blocked after tree add")
	cid.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_touch_hud: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_touch_hud: %s" % failure)
	quit(1)
