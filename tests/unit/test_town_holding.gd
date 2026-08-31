extends SceneTree
## Headless keep-or-sell tests (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_town_holding.gd

var _treasury: Variant
var _honor: Variant
var _bus: Variant
var _clock: Variant


func _initialize() -> void:
	var failures: PackedStringArray = []
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_bus = get_root().get_node_or_null(NodePath("EventBus"))
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	if _treasury == null or _honor == null or _bus == null:
		failures.append("required autoload missing")
		_finish(failures)
		return
	if _honor.has_method("_load_catalog"):
		_honor._load_catalog()
	failures.append_array(_test_keep_castejon_hard_fails_alfonso_host())
	failures.append_array(_test_sell_divides_horses_and_marks_not_onores())
	failures.append_array(_test_alcocer_deadline_keep_then_host())
	failures.append_array(_test_alcocer_keep_before_deadline_is_safe())
	failures.append_array(_test_ui_spanish_labels_and_720p())
	_reset()
	_finish(failures)


func _test_keep_castejon_hard_fails_alfonso_host() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	var failed: Array[StringName] = []
	var on_fail := func(reason: StringName) -> void:
		failed.append(reason)
	_bus.hard_fail.connect(on_fail)
	var holding := TownHolding.from_id(&"castejon")
	if String(holding.location_id) != "castejon":
		failures.append("castejon json did not load")
	if not holding.alfonso_protectorate:
		failures.append("castejon must be Alfonso protectorate")
	if holding.sell_deadline_days != 0:
		failures.append("castejon sell_deadline_days want 0 from JSON")
	var marks_before: int = int(_treasury.state.marks)
	var onores_before: float = float(_honor.state.onores)
	var result: Dictionary = holding.keep()
	if result.get("hard_fail", &"") != &"alfonso_host":
		failures.append("keep Castejón want hard_fail alfonso_host, got %s" % str(result.get("hard_fail", &"")))
	if &"alfonso_host" not in failed:
		failures.append("keep Castejón did not emit alfonso_host, got %s" % str(failed))
	if holding.held:
		failures.append("keep Castejón must not remain held")
	if int(_treasury.state.marks) != marks_before:
		failures.append("keep Castejón must not divide booty")
	if not is_equal_approx(float(_honor.state.onores), onores_before):
		failures.append("keep Castejón must not treat marks as onores")
	_bus.hard_fail.disconnect(on_fail)
	return failures


func _test_sell_divides_horses_and_marks_not_onores() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	_honor.roster = MesnadaRoster.from_starting_seed()
	var holding := TownHolding.from_id(&"castejon")
	if int(holding.booty.get("marks", 0)) != 800 or int(holding.booty.get("horses", 0)) != 40:
		failures.append("castejon booty want 800 marks / 40 horses from JSON")
	var result: Dictionary = holding.sell()
	var split: Dictionary = result.get("split", {})
	if int(split.get("quinto_marks", 0)) != 160 or int(split.get("mesnada_marks", 0)) != 320:
		failures.append("sell marks split want 160/320/320, got %s" % str(split))
	if int(split.get("treasury_marks", 0)) != 320:
		failures.append("sell treasury marks want 320, got %s" % str(split))
	if int(split.get("quinto_horses", 0)) != 8 or int(split.get("mesnada_horses", 0)) != 16:
		failures.append("sell horses must follow fractions, got %s" % str(split))
	if int(split.get("treasury_horses", 0)) != 16:
		failures.append("sell treasury horses want 16, got %s" % str(split))
	if int(_treasury.state.marks) != 320:
		failures.append("after sell treasury marks want 320 got %s" % _treasury.state.marks)
	if int(_treasury.state.horses) != 18:
		failures.append("after sell horses want 18 (2+16) got %s" % _treasury.state.horses)
	if int(_treasury.state.royal_escrow_marks) != 160:
		failures.append("quinto escrow marks want 160 got %s" % _treasury.state.royal_escrow_marks)
	if int(_treasury.state.royal_escrow_horses) != 8:
		failures.append("quinto escrow horses want 8 got %s" % _treasury.state.royal_escrow_horses)
	if not is_equal_approx(float(_honor.state.onores), 18.0):
		failures.append("castejon_sell onores want 18 (8+10), not marks; got %s" % _honor.state.onores)
	if not is_equal_approx(float(_honor.state.honor), 15.0):
		failures.append("sell must not spend onores from marks; honor want 15 got %s" % _honor.state.honor)
	if result.get("hard_fail", &"") != &"":
		failures.append("sell must not hard_fail")
	if not holding.sold or holding.held:
		failures.append("sell must mark sold and not held")
	return failures


func _test_alcocer_deadline_keep_then_host() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	var failed: Array[StringName] = []
	var logged: Array[StringName] = []
	var on_fail := func(reason: StringName) -> void:
		failed.append(reason)
	var on_log := func(event: HonorEvent) -> void:
		if event:
			logged.append(event.id)
	_bus.hard_fail.connect(on_fail)
	_bus.honor_logged.connect(on_log)
	var holding := TownHolding.from_id(&"alcocer")
	if holding.alfonso_protectorate:
		failures.append("alcocer must not be a protectorate")
	if holding.sell_deadline_days != 3:
		failures.append("alcocer sell_deadline_days want 3 from JSON")
	if String(holding.keep_event_id) != "alcocer_keep":
		failures.append("alcocer keep_event_id want alcocer_keep")
	var kept: Dictionary = holding.keep()
	if kept.get("hard_fail", &"") != &"":
		failures.append("alcocer keep on day 0 must not fail")
	if not holding.held:
		failures.append("alcocer keep on day 0 must remain held")
	var tick1: Dictionary = holding.tick_day()
	var tick2: Dictionary = holding.tick_day()
	if tick1.get("hard_fail", &"") != &"" or tick2.get("hard_fail", &"") != &"":
		failures.append("alcocer must not fail before deadline")
	if failed.size() != 0:
		failures.append("no host before day 3, got %s" % str(failed))
	if not is_equal_approx(float(_honor.state.honor), 15.0):
		failures.append("alcocer_keep must not fire before deadline")
	var tick3: Dictionary = holding.tick_day()
	if tick3.get("hard_fail", &"") != &"alfonso_host":
		failures.append("alcocer day 3 want alfonso_host, got %s" % str(tick3.get("hard_fail", &"")))
	if tick3.get("event_id", &"") != &"alcocer_keep":
		failures.append("deadline must fire HonorEvent alcocer_keep, got %s" % str(tick3.get("event_id", &"")))
	if &"alcocer_keep" not in logged:
		failures.append("alcocer_keep was not logged")
	if &"alfonso_host" not in failed:
		failures.append("alcocer deadline must then emit alfonso_host, got %s" % str(failed))
	if not is_equal_approx(float(_honor.state.honor), 0.0):
		failures.append("alcocer_keep honor want 0 (15-25 clamp) got %s" % _honor.state.honor)
	if holding.held:
		failures.append("deadline fail must drop the holding")
	_bus.hard_fail.disconnect(on_fail)
	_bus.honor_logged.disconnect(on_log)
	return failures


func _test_alcocer_keep_before_deadline_is_safe() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	var holding := TownHolding.from_id(&"alcocer")
	holding.keep()
	holding.tick_day()
	var sold: Dictionary = holding.sell()
	if sold.get("hard_fail", &"") != &"":
		failures.append("sell Alcocer before deadline must not fail")
	if not holding.sold:
		failures.append("alcocer sell before deadline must mark sold")
	if int(sold.get("split", {}).get("quinto_marks", 0)) != 120:
		failures.append("alcocer sell 600 marks quinto want 120, got %s" % str(sold.get("split", {})))
	if int(sold.get("split", {}).get("quinto_horses", 0)) != 6:
		failures.append("alcocer sell 30 horses quinto want 6, got %s" % str(sold.get("split", {})))
	if not is_equal_approx(float(_honor.state.onores), 18.0):
		failures.append("alcocer_sell onores want 18 (8+10) got %s" % _honor.state.onores)
	return failures


func _test_ui_spanish_labels_and_720p() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	var packed: PackedScene = load("res://game/ui/keep_or_sell.tscn")
	if packed == null:
		failures.append("keep_or_sell.tscn missing")
		return failures
	var ui := packed.instantiate() as Control
	get_root().add_child(ui)
	var castejon := TownHolding.from_id(&"castejon")
	ui.set("holding", castejon)
	if ui.has_method("_refresh"):
		ui.call("_refresh")
	if ui.get("holding") == null:
		failures.append("KeepOrSell holding stayed null after set")
	var title := ui.get_node_or_null(NodePath("Center/Title")) as Label
	var keep_btn := ui.get_node_or_null(NodePath("Center/Keep")) as Button
	var sell_btn := ui.get_node_or_null(NodePath("Center/Sell")) as Button
	var place := ui.get_node_or_null(NodePath("Center/Place")) as Label
	var warn := ui.get_node_or_null(NodePath("Center/Warn")) as Label
	var booty := ui.get_node_or_null(NodePath("Center/Booty")) as Label
	if title == null or title.text != "¿Guardar o vender?":
		failures.append("title want ¿Guardar o vender? got %s" % (title.text if title else "null"))
	if keep_btn == null or keep_btn.text != "Guardar":
		failures.append("keep button want Guardar")
	if sell_btn == null or sell_btn.text != "Vender":
		failures.append("sell button want Vender")
	if place == null or place.text != "Castejón":
		failures.append("place want Castejón got %s" % (place.text if place else "null"))
	if warn == null or not warn.text.contains("Alfonso"):
		failures.append("protectorate warn missing Alfonso")
	if booty == null or not booty.text.contains("marcos") or not booty.text.contains("caballos"):
		failures.append("booty labels must be Spanish marcos/caballos")
	if ui.anchor_right < 0.99 or ui.anchor_bottom < 0.99:
		failures.append("keep/sell UI must fill 720p viewport")
	ui.queue_free()
	var alcocer_ui := packed.instantiate() as Control
	get_root().add_child(alcocer_ui)
	alcocer_ui.set("holding", TownHolding.from_id(&"alcocer"))
	if alcocer_ui.has_method("_refresh"):
		alcocer_ui.call("_refresh")
	var alcocer_warn := alcocer_ui.get_node_or_null(NodePath("Center/Warn")) as Label
	var alcocer_place := alcocer_ui.get_node_or_null(NodePath("Center/Place")) as Label
	if alcocer_warn == null or alcocer_warn.text.is_empty() or not alcocer_warn.text.contains("host"):
		failures.append("alcocer warn should mention the king's host")
	if alcocer_place == null or alcocer_place.text != "Alcocer":
		failures.append("place want Alcocer")
	alcocer_ui.queue_free()
	return failures


func _reset() -> void:
	if _honor:
		_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _treasury:
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_town_holding: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_town_holding: %s" % failure)
	quit(1)
