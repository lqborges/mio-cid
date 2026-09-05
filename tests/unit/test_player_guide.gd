extends SceneTree
## Headless PlayerGuide / pause pages.
## Run: godot --headless --path . -s res://tests/unit/test_player_guide.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_guide_autoload())
	failures.append_array(_test_pause_pages())
	failures.append_array(_test_glyphs())
	_finish(failures)


func _test_guide_autoload() -> PackedStringArray:
	var failures: PackedStringArray = []
	var guide: Node = get_root().get_node_or_null("PlayerGuide")
	if guide == null:
		failures.append("PlayerGuide autoload missing")
		return failures
	var runner: Node = get_root().get_node_or_null("ChapterRunner")
	if runner and "current_id" in runner:
		runner.current_id = &"a1_vivar"
		if "flags" in runner:
			runner.flags = PackedStringArray()
	if not guide.has_method("current_objective"):
		failures.append("PlayerGuide.current_objective missing")
		return failures
	var obj: Variant = guide.call("current_objective")
	if typeof(obj) != TYPE_DICTIONARY or str(obj.get("id", "")) != "vivar_talk":
		failures.append("Vivar start must show first-names objective")
	if guide.get_node_or_null("ObjectiveHud") == null:
		failures.append("ObjectiveHud missing")
	if guide.get_node_or_null("OnboardingToast") == null:
		failures.append("OnboardingToast missing")
	if guide.has_method("replay_tips"):
		guide.call("replay_tips")
	if guide.has_method("format_interact_prompt"):
		InputGlyphs.set_device(InputGlyphs.DEVICE_KEYBOARD)
		var prompt := str(guide.call("format_interact_prompt", "hud.interact_verb", "Hablar"))
		if not prompt.contains("Hablar"):
			failures.append("interact prompt must keep the Spanish verb")
		if prompt.begins_with("Toca"):
			failures.append("keyboard prompt must not use the touch glyph")
	return failures


func _test_pause_pages() -> PackedStringArray:
	var failures: PackedStringArray = []
	var pause: Node = get_root().get_node_or_null("PauseMenu")
	if pause == null:
		failures.append("PauseMenu missing")
		return failures
	if pause.get_node_or_null("Panel/Center/Resume") == null:
		failures.append("pause missing Resume")
	if pause.get_node_or_null("Panel/Center/Journal") == null:
		failures.append("pause missing Journal")
	if pause.get_node_or_null("Panel/Center/Help") == null:
		failures.append("pause missing Help")
	if pause.get_node_or_null("Panel/Center/Settings") == null:
		failures.append("pause missing Settings")
	if pause.get_node_or_null("Panel/Center/Menu") == null:
		failures.append("pause missing Menu")
	if pause.get_node_or_null("Panel/Center/Quit") == null:
		failures.append("pause missing Quit")
	if not pause.has_method("_open_help") or not pause.has_method("_open_journal"):
		failures.append("pause missing help/journal pages")
	if pause.visible:
		pause.call("resume")
	pause.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not pause.visible:
		failures.append("Android back should open pause in-game")
	pause.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if pause.visible:
		failures.append("Android back should close an open pause menu")
	return failures


func _test_glyphs() -> PackedStringArray:
	var failures: PackedStringArray = []
	InputGlyphs.set_device(InputGlyphs.DEVICE_KEYBOARD)
	var key := InputGlyphs.prompt("interact", "Hablar")
	if not key.contains("Hablar"):
		failures.append("keyboard prompt lost the verb")
	InputGlyphs.set_device(InputGlyphs.DEVICE_TOUCH)
	var tap := InputGlyphs.action_glyph("interact")
	if tap != "Toca":
		failures.append("touch interact glyph want Toca got %s" % tap)
	InputGlyphs.set_device(InputGlyphs.DEVICE_GAMEPAD)
	var pad := InputGlyphs.action_glyph("interact")
	if pad.is_empty():
		failures.append("gamepad interact glyph empty")
	InputGlyphs.set_device(InputGlyphs.DEVICE_KEYBOARD)
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_player_guide: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_player_guide: %s" % failure)
	quit(1)
