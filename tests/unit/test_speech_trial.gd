extends SceneTree
## Headless SpeechTrial tests (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_speech_trial.gd


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_retry_does_not_stack())
	failures.append_array(_test_ask_order_locked())
	failures.append_array(_test_skip_blocked_no_assert())
	failures.append_array(_test_garcia_is_separate_trial())
	failures.append_array(_test_steel_in_hall_fails())
	failures.append_array(_test_win_threshold_on_trial())
	failures.append_array(_test_ui_has_spanish_and_english())
	failures.append_array(_test_press_line_does_not_free_emitter())
	_finish(failures)


func _test_retry_does_not_stack() -> PackedStringArray:
	var failures: PackedStringArray = []
	var trial := _three_ask_trial()
	var retries: Array = []
	trial.ask_retry.connect(func(index: int) -> void:
		retries.append(index)
	)
	trial.submit_line(0, &"ira")
	trial.submit_line(0, &"ira")
	if trial.legal_score != 0.0 or trial.mesura_score != 0.0 or trial.ira_score != 0.0:
		failures.append("retry committed a negative net delta")
	if trial.current_index() != 0:
		failures.append("retry advanced the ask index")
	if retries.size() != 2:
		failures.append("retry should emit ask_retry twice, got %s" % retries.size())
	trial.submit_line(0, &"ok")
	if not is_equal_approx(trial.legal_score, 5.0):
		failures.append("after retries, legal_score want 5 got %s" % trial.legal_score)
	if trial.current_index() != 1:
		failures.append("good line should advance to ask 1")
	if not is_equal_approx(trial.ira_score, 1.0):
		failures.append("committed ira should be the good line only, got %s" % trial.ira_score)
	trial.free()
	return failures


func _test_ask_order_locked() -> PackedStringArray:
	var failures: PackedStringArray = []
	var trial := _three_ask_trial()
	var blocked: Array = []
	trial.skip_blocked.connect(func() -> void:
		blocked.append(true)
	)
	trial.submit_line(2, &"ok")
	trial.submit_line(1, &"ok")
	if trial.current_index() != 0:
		failures.append("out-of-order submit must not advance _index")
	if trial.legal_score != 0.0:
		failures.append("out-of-order submit must not commit legal")
	if blocked.size() != 2:
		failures.append("locked order should emit skip_blocked, got %s" % blocked.size())
	trial.submit_line(0, &"ok")
	if trial.current_index() != 1:
		failures.append("current ask must still be submittable in order")
	blocked.clear()
	trial.submit_line(0, &"ok")
	if blocked.size() != 1:
		failures.append("going backward should skip_block")
	if trial.current_index() != 1:
		failures.append("going backward must not rewind _index")
	trial.free()
	return failures


func _test_skip_blocked_no_assert() -> PackedStringArray:
	var failures: PackedStringArray = []
	var trial := _three_ask_trial()
	var blocked: Array = []
	var failed: Array = []
	trial.skip_blocked.connect(func() -> void:
		blocked.append(true)
	)
	trial.trial_failed.connect(func() -> void:
		failed.append(true)
	)
	trial.submit_line(0, &"skip")
	if trial.third_ask_allowed:
		failures.append("skip_to_riepto must set third_ask_allowed false")
	if trial.current_index() != 0:
		failures.append("skip_to_riepto must stay on the current ask")
	if trial.legal_score != 0.0:
		failures.append("skip_to_riepto must not commit a delta")
	if blocked.size() != 1:
		failures.append("skip_to_riepto should emit skip_blocked once")
	if failed.size() != 0:
		failures.append("skip_to_riepto on ask 0 is not yet trial_failed")
	trial.submit_line(0, &"ok")
	trial.submit_line(1, &"ok")
	if failed.size() != 1:
		failures.append("reaching the third ask after skip_to_riepto should trial_failed")
	if trial.current_index() != 2:
		failures.append("mesura-fail should leave index on the blocked third ask")
	blocked.clear()
	trial.submit_line(2, &"ok")
	if blocked.size() != 1:
		failures.append("third ask after skip_to_riepto stays skip_blocked")
	trial.free()
	return failures


func _test_garcia_is_separate_trial() -> PackedStringArray:
	var failures: PackedStringArray = []
	var garcia := _garcia_trial()
	var toledo := _three_ask_trial()
	if garcia.asks.size() != 1:
		failures.append("García must be a one-ask trial")
	if garcia.asks[0].counts_toward_win:
		failures.append("García ask must not count toward the Toledo win")
	for ask in toledo.asks:
		if String(ask.id) == "garcia_preliminary":
			failures.append("García must not sit in the three Toledo asks")
	if toledo.asks.size() != 3:
		failures.append("Toledo trial must keep three asks")
	garcia.submit_line(0, &"ok")
	if toledo.current_index() != 0 or toledo.legal_score != 0.0:
		failures.append("García trial must not share _index or legal_score with Toledo")
	if garcia.legal_score != 0.0:
		failures.append("García counts_toward_win false must not add legal")
	garcia.free()
	toledo.free()
	return failures


func _test_steel_in_hall_fails() -> PackedStringArray:
	var failures: PackedStringArray = []
	var trial := _three_ask_trial()
	var steel: Array = []
	var failed: Array = []
	var hard: Array = []
	trial.steel_drawn_fail.connect(func() -> void:
		steel.append(true)
	)
	trial.trial_failed.connect(func() -> void:
		failed.append(true)
	)
	var on_hard := func(reason: StringName) -> void:
		hard.append(reason)
	var bus := _event_bus()
	if bus != null and bus.has_signal("hard_fail"):
		bus.hard_fail.connect(on_hard)
	trial.submit_line(0, &"steel")
	if steel.size() != 1:
		failures.append("draw_steel should emit steel_drawn_fail")
	if failed.size() != 1:
		failures.append("draw_steel should fail the trial")
	if bus != null and (hard.size() != 1 or hard[0] != &"steel_in_cortes"):
		failures.append("draw_steel should hard_fail steel_in_cortes")
	if trial.legal_score != 0.0:
		failures.append("draw_steel must not commit a delta")
	if not trial.steel_failed():
		failures.append("steel_failed() should stay true")
	var before := trial.current_index()
	trial.submit_line(0, &"ok")
	if trial.current_index() != before or trial.legal_score != 0.0:
		failures.append("drawing steel must close the trial")
	if bus != null and bus.has_signal("hard_fail") and bus.hard_fail.is_connected(on_hard):
		bus.hard_fail.disconnect(on_hard)
	trial.free()
	return failures


func _test_win_threshold_on_trial() -> PackedStringArray:
	var failures: PackedStringArray = []
	var trial := _three_ask_trial()
	trial.win_threshold = 12.0
	if trial.get("win_threshold") == null:
		failures.append("win_threshold must live on the trial")
	var won: Array = []
	var failed: Array = []
	trial.trial_won.connect(func() -> void:
		won.append(true)
	)
	trial.trial_failed.connect(func() -> void:
		failed.append(true)
	)
	trial.submit_line(0, &"ok")
	trial.submit_line(1, &"ok")
	trial.submit_line(2, &"weak")
	# 5 + 5 + 1 = 11 < 12
	if won.size() != 0:
		failures.append("under-threshold trial must not win")
	if failed.size() != 1:
		failures.append("under-threshold trial should fail and retry last ask")
	if trial.current_index() != 2:
		failures.append("failed trial retries the last ask")
	trial.submit_line(2, &"ok")
	# last ask commits again: 11 + 5 = 16
	if won.size() != 1:
		failures.append("retrying last ask above threshold should win")
	trial.free()
	return failures


func _test_ui_has_spanish_and_english() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: PackedScene = load("res://game/ui/speech_trial.tscn") as PackedScene
	if packed == null:
		return PackedStringArray(["speech_trial.tscn failed to load"])
	var ui: Node = packed.instantiate()
	get_root().add_child(ui)
	if not (ui is SpeechTrialUI):
		failures.append("speech_trial.tscn root is not SpeechTrialUI")
	if ui.find_child("Timer", true, false) != null:
		failures.append("speech UI must not include a Timer")
	var loc := _loc_node()
	if loc == null or not loc.has_method("text"):
		failures.append("Loc autoload missing")
	else:
		var retry_es := str(loc.call("text", "speech.ui.retry"))
		var retry_en := str(loc.call("text_in", "speech.ui.retry", "en")) if loc.has_method("text_in") else ""
		if retry_es.find("taberna") < 0:
			failures.append("Spanish retry copy missing")
		if retry_en.find("tavern") < 0:
			failures.append("English retry subtitle missing")
	var trial := _three_ask_trial()
	get_root().add_child(trial)
	(ui as SpeechTrialUI).bind(trial)
	var prompt: Label = ui.get_node_or_null("Panel/Margin/Column/Prompt") as Label
	var prompt_en: Label = ui.get_node_or_null("Panel/Margin/Column/PromptEn") as Label
	if prompt == null or prompt_en == null:
		failures.append("speech UI missing Prompt / PromptEn labels")
	elif prompt.text.find("taberna") < 0 or prompt_en.text.find("tavern") < 0:
		failures.append("speech UI should show Spanish labels and English subtitles")
	get_root().remove_child(ui)
	ui.free()
	trial.free()
	return failures


func _test_press_line_does_not_free_emitter() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: PackedScene = load("res://game/ui/speech_trial.tscn") as PackedScene
	if packed == null:
		return PackedStringArray(["speech_trial.tscn failed to load"])
	var ui: Node = packed.instantiate()
	get_root().add_child(ui)
	var trial := _three_ask_trial()
	get_root().add_child(trial)
	(ui as SpeechTrialUI).bind(trial)
	var lines: Node = ui.get_node_or_null("Panel/Margin/Column/Lines")
	if lines == null or lines.get_child_count() < 2:
		failures.append("speech UI missing line buttons after bind")
	else:
		var ira_button: Button = lines.get_child(1) as Button
		if ira_button == null:
			failures.append("ira line is not a Button")
		else:
			ira_button.pressed.emit()
			if trial.current_index() != 0 or trial.legal_score != 0.0:
				failures.append("ira press must retry without committing")
			lines = ui.get_node_or_null("Panel/Margin/Column/Lines")
			if lines == null or lines.get_child_count() < 1:
				failures.append("retry rebuild left no line buttons")
			else:
				var ok_button: Button = lines.get_child(0) as Button
				if ok_button == null:
					failures.append("ok line is not a Button after retry")
				else:
					ok_button.pressed.emit()
					if trial.current_index() != 1:
						failures.append("ok press after retry should advance the ask")
	get_root().remove_child(ui)
	ui.queue_free()
	trial.free()
	return failures


func _three_ask_trial() -> SpeechTrial:
	var trial := SpeechTrial.new()
	trial.win_threshold = 12.0
	var asks: Array[SpeechAsk] = []
	asks.append(_ask(&"ask_0", true, [
		_line(&"ok", 6.0, 2.0, 1.0),
		_line(&"ira", 1.0, 0.0, 4.0),
		_line(&"skip", 0.0, 0.0, 0.0, PackedStringArray(["skip_to_riepto"])),
		_line(&"steel", 0.0, 0.0, 0.0, PackedStringArray(["draw_steel"])),
	]))
	asks.append(_ask(&"ask_1", true, [
		_line(&"ok", 6.0, 2.0, 1.0),
		_line(&"ira", 1.0, 0.0, 4.0),
	]))
	asks.append(_ask(&"ask_2", true, [
		_line(&"ok", 6.0, 2.0, 1.0),
		_line(&"weak", 1.0, 0.0, 0.0),
	]))
	trial.asks = asks
	return trial


func _garcia_trial() -> SpeechTrial:
	var trial := SpeechTrial.new()
	trial.win_threshold = 0.0
	var asks: Array[SpeechAsk] = []
	asks.append(_ask(&"garcia_preliminary", false, [
		_line(&"ok", 4.0, 1.0, 0.0),
	]))
	trial.asks = asks
	return trial


func _ask(id: StringName, counts: bool, lines: Array) -> SpeechAsk:
	var ask := SpeechAsk.new()
	ask.id = id
	ask.prompt_key = StringName("speech.ui.retry")
	ask.counts_toward_win = counts
	var typed: Array[SpeechLine] = []
	for item in lines:
		typed.append(item)
	ask.lines = typed
	return ask


func _event_bus() -> Object:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return get_root().get_node_or_null("EventBus")


func _loc_node() -> Object:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Loc")
	return get_root().get_node_or_null("Loc")


func _line(id: StringName, legal: float, mesura: float, ira: float, tags: PackedStringArray = PackedStringArray()) -> SpeechLine:
	var line := SpeechLine.new()
	line.id = id
	line.text_key = StringName("speech.ui.retry")
	line.legal = legal
	line.mesura = mesura
	line.ira = ira
	line.tags = tags
	line.vo_id = &""
	return line


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_speech_trial: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_speech_trial: %s" % failure)
	quit(1)
