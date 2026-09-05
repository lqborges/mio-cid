extends SceneTree
## Headless PlayerGuide / pause pages.
## Run: godot --headless --path . -s res://tests/unit/test_player_guide.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_guide_autoload())
	failures.append_array(_test_pause_pages())
	failures.append_array(_test_locale_switch())
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
	if guide.has_method("set_setting"):
		guide.call("set_setting", "locale", "es")
	if not guide.has_method("current_objective"):
		failures.append("PlayerGuide.current_objective missing")
		return failures
	var obj: Variant = guide.call("current_objective")
	if typeof(obj) != TYPE_DICTIONARY or str(obj.get("id", "")) != "vivar_talk":
		failures.append("Vivar start must show first-names objective")
	if guide.has_method("_refresh_hud"):
		guide.call("_refresh_hud")
	var hud: CanvasItem = guide.get_node_or_null("ObjectiveHud") as CanvasItem
	if hud == null:
		failures.append("ObjectiveHud missing")
	elif not hud.visible:
		failures.append("ObjectiveHud stays hidden while vivar_talk is current")
	if guide.get_node_or_null("OnboardingToast") == null:
		failures.append("OnboardingToast missing")
	if guide.get("catalog") == null:
		failures.append("PlayerGuide.catalog must load without class_name ObjectiveCatalog")
	var hint: Label = guide.find_child("ControlsHint", true, false) as Label
	if hint == null:
		failures.append("ObjectiveHud ControlsHint missing")
	if guide.has_method("replay_tips"):
		guide.call("replay_tips")
	if guide.has_method("announce_travel"):
		guide.call("announce_travel", "a1_burgos")
		if guide.has_method("travel_visible") and not bool(guide.call("travel_visible")):
			failures.append("announce_travel must show the travel card")
		if guide.has_method("place_title"):
			var place := str(guide.call("place_title", "a1_burgos"))
			if place != "Burgos":
				failures.append("place_title a1_burgos want Burgos got %s" % place)
		var card: Node = guide.get_node_or_null("TravelCard")
		if card == null:
			failures.append("TravelCard missing")
		else:
			var place_label: Label = card.find_child("Place", true, false) as Label
			if place_label == null or place_label.text != "Burgos":
				failures.append("travel card must name Burgos")
			var kicker: Label = card.find_child("Kicker", true, false) as Label
			if kicker == null or kicker.text != "Llegáis a":
				failures.append("travel card kicker want Llegáis a got %s" % (kicker.text if kicker else "missing"))
		if guide.has_method("_tick_travel"):
			guide.call("_tick_travel")
			if guide.has_method("travel_visible") and not bool(guide.call("travel_visible")):
				failures.append("travel card must survive the first tick after announce")
		if guide.has_method("dismiss_travel"):
			guide.call("dismiss_travel")
	if guide.has_method("help_lines"):
		var help: PackedStringArray = guide.call("help_lines")
		if help.is_empty() or not str(help[0]).begins_with("WASD"):
			failures.append("Ayuda must list WASD before LMB click-move")
		if str(help[0]) != "WASD — Andar":
			failures.append("Ayuda first line want WASD — Andar, got %s" % help[0])
		var joined := " ".join(help)
		if not joined.contains("LMB") and not joined.contains("Clic"):
			failures.append("Ayuda must still name click-to-move")
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
	if pause.has_method("_help_text"):
		var help_body := str(pause.call("_help_text"))
		if not help_body.begins_with("WASD"):
			failures.append("Ayuda page must start with WASD, got %s" % help_body.split("\n")[0])
		if not help_body.contains("LMB") and not help_body.contains("Clic"):
			failures.append("Ayuda page must still name click-to-move")
	if pause.has_method("_open_help"):
		pause.call("_open_help")
		var body: RichTextLabel = pause.get("_page_body") as RichTextLabel
		if body == null or not str(body.text).begins_with("WASD"):
			failures.append("open Ayuda must write WASD into the page body")
		if pause.has_method("_hide_page"):
			pause.call("_hide_page")
	if pause.visible:
		pause.call("resume")
	pause.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not pause.visible:
		failures.append("Android back should open pause in-game")
	pause.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if pause.visible:
		failures.append("Android back should close an open pause menu")
	return failures


func _test_locale_switch() -> PackedStringArray:
	var failures: PackedStringArray = []
	var loc: Node = get_root().get_node_or_null("Loc")
	var guide: Node = get_root().get_node_or_null("PlayerGuide")
	if loc == null or guide == null or not loc.has_method("set_locale"):
		failures.append("Loc.set_locale / PlayerGuide missing")
		return failures
	var saved := str(loc.get("locale"))
	guide.call("set_setting", "locale", "en")
	if str(loc.get("locale")) != "en":
		failures.append("setting locale=en did not switch Loc")
	var pause_en := str(loc.call("text", "ui.pause.title"))
	if pause_en != "Pause":
		failures.append("English ui.pause.title want Pause got %s" % pause_en)
	if loc.has_method("normalize_locale") and str(loc.call("normalize_locale", "en_US")) != "en":
		failures.append("en_US should normalize to en")
	var meters_script: Script = load("res://game/ui/honor_meters.gd")
	var plazo_script: Script = load("res://game/ui/plazo_bar.gd")
	var meters: Node = meters_script.new()
	var plazo: Node = plazo_script.new()
	get_root().add_child(meters)
	get_root().add_child(plazo)
	var en_onores := str(meters.call("_meter_label", &"onores"))
	if en_onores != "Means":
		failures.append("English onores want Means got %s" % en_onores)
	var en_tip := str(meters.call("_meter_tip", &"onores"))
	if not en_tip.to_lower().contains("means"):
		failures.append("English onores tooltip should gloss the meter")
	if str(plazo.call("_plazo_label")) != "Term":
		failures.append("English plazo want Term got %s" % plazo.call("_plazo_label"))
	if str(loc.call("text", "hud.controls_hint")) != "WASD walk · E talk":
		failures.append("English controls hint should name WASD and E")
	if str(loc.call("text", "hud.wasd")) != "WASD — Walk":
		failures.append("English hud.wasd want WASD — Walk")
	if meters.has_method("gloss_texts"):
		var en_gloss: PackedStringArray = meters.call("gloss_texts")
		if en_gloss.is_empty() or en_gloss[1] != "king":
			failures.append("English honor gloss want king, got %s" % (" / ".join(en_gloss)))
	if plazo.has_method("caption_text") and not str(plazo.call("caption_text")).begins_with("Term"):
		failures.append("English plazo caption want Term…, got %s" % plazo.call("caption_text"))
	guide.call("set_setting", "locale", "es")
	if str(loc.get("locale")) != "es":
		failures.append("setting locale=es did not restore Spanish")
	var pause_es := str(loc.call("text", "ui.pause.title"))
	if pause_es != "Pausa":
		failures.append("Spanish ui.pause.title want Pausa got %s" % pause_es)
	if str(meters.call("_meter_label", &"onores")) != "Honores":
		failures.append("Spanish onores should stay Honores after locale restore")
	if str(plazo.call("_plazo_label")) != "Plazo":
		failures.append("Spanish plazo want Plazo got %s" % plazo.call("_plazo_label"))
	if meters.has_method("gloss_texts"):
		var es_gloss: PackedStringArray = meters.call("gloss_texts")
		if es_gloss.size() < 3 or es_gloss[0] != "feudos" or es_gloss[1] != "rey" or es_gloss[2] != "nombre":
			failures.append("Spanish glosses want feudos/rey/nombre, got %s" % " / ".join(es_gloss))
	if plazo.has_method("caption_text") and not str(plazo.call("caption_text")).begins_with("Plazo"):
		failures.append("Spanish plazo caption want Plazo…, got %s" % plazo.call("caption_text"))
	meters.queue_free()
	plazo.queue_free()
	guide.call("set_setting", "locale", saved)
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
