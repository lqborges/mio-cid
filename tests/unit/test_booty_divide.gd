extends SceneTree
## Headless booty-divide tests (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_booty_divide.gd

const PILE := {"marks": 800, "horses": 40}
const UI_SCENE := "res://game/ui/booty_divide.tscn"
const ALCOCER := "res://content/chapters/a1_alcocer/world.tscn"
const CASTJON := "res://content/chapters/a1_castejon/world.tscn"

var _treasury: Variant
var _honor: Variant
var _bus: Variant
var _clock: Variant
var _runner: Variant
var _loc: Variant
var _logged: PackedStringArray = PackedStringArray()
var _completed: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_bus = get_root().get_node_or_null(NodePath("EventBus"))
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_loc = get_root().get_node_or_null(NodePath("Loc"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	if _treasury == null or _honor == null:
		failures.append("required autoload missing")
		_finish(failures)
		return
	if _honor.has_method("_load_catalog"):
		_honor._load_catalog()
	if _bus:
		if _bus.has_signal("honor_logged") and not _bus.honor_logged.is_connected(_on_honor_logged):
			_bus.honor_logged.connect(_on_honor_logged)
		if _bus.has_signal("beat_completed") and not _bus.beat_completed.is_connected(_on_beat_completed):
			_bus.beat_completed.connect(_on_beat_completed)
	failures.append_array(_test_preview_800_40_does_not_mutate())
	failures.append_array(_test_divide_800_40_buckets())
	failures.append_array(_test_gift_to_alvar_from_mesnada())
	failures.append_array(_test_ui_spanish_and_confirm())
	failures.append_array(_test_alcocer_embassy_waits_for_divide())
	failures.append_array(_test_castejon_sell_pile_reuses_ui())
	_reset()
	_finish(failures)


func _test_preview_800_40_does_not_mutate() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	_honor.roster = MesnadaRoster.from_starting_seed()
	if not _treasury.has_method("preview_booty"):
		failures.append("TreasuryService.preview_booty missing")
		return failures
	var marks_before: int = int(_treasury.state.marks)
	var horses_before: int = int(_treasury.state.horses)
	var escrow_before: int = int(_treasury.state.royal_escrow_marks)
	var split: Dictionary = _treasury.preview_booty(PILE)
	if int(split.get("quinto_marks", 0)) != 160 or int(split.get("mesnada_marks", 0)) != 320:
		failures.append("preview marks want 160/320/320, got %s" % str(split))
	if int(split.get("treasury_marks", 0)) != 320:
		failures.append("preview treasury marks want 320, got %s" % str(split))
	if int(split.get("quinto_horses", 0)) != 8 or int(split.get("mesnada_horses", 0)) != 16:
		failures.append("preview horses want 8/16/16, got %s" % str(split))
	if int(split.get("treasury_horses", 0)) != 16:
		failures.append("preview treasury horses want 16, got %s" % str(split))
	if int(_treasury.state.marks) != marks_before:
		failures.append("preview must not add treasury marks")
	if int(_treasury.state.horses) != horses_before:
		failures.append("preview must not add horses")
	if int(_treasury.state.royal_escrow_marks) != escrow_before:
		failures.append("preview must not fill escrow")
	return failures


func _test_divide_800_40_buckets() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	_honor.roster = MesnadaRoster.from_starting_seed()
	var split: Dictionary = _treasury.divide_booty(PILE)
	if int(split.get("quinto_marks", 0)) != 160 or int(split.get("mesnada_marks", 0)) != 320:
		failures.append("divide marks want 160/320/320, got %s" % str(split))
	if int(split.get("treasury_marks", 0)) != 320:
		failures.append("divide treasury marks want 320, got %s" % str(split))
	if int(split.get("quinto_horses", 0)) != 8 or int(split.get("mesnada_horses", 0)) != 16:
		failures.append("divide horses want 8/16/16, got %s" % str(split))
	if int(split.get("treasury_horses", 0)) != 16:
		failures.append("divide treasury horses want 16, got %s" % str(split))
	if int(_treasury.state.marks) != 320:
		failures.append("after divide treasury marks want 320 got %s" % _treasury.state.marks)
	if int(_treasury.state.horses) != 18:
		failures.append("after divide horses want 18 (2+16) got %s" % _treasury.state.horses)
	if int(_treasury.state.royal_escrow_marks) != 160:
		failures.append("quinto escrow marks want 160 got %s" % _treasury.state.royal_escrow_marks)
	if int(_treasury.state.royal_escrow_horses) != 8:
		failures.append("quinto escrow horses want 8 got %s" % _treasury.state.royal_escrow_horses)
	if bool(split.get("gift_to_alvar", false)):
		failures.append("default divide must not divert mesnada to Álvar")
	var martin: MesnadaMember = _honor.roster.member(&"martin_antolinez")
	if martin == null or not (martin.loyalty > 0.55):
		failures.append("mesnada share should tick Martín loyalty, got %s" % (martin.loyalty if martin else "null"))
	return failures


func _test_gift_to_alvar_from_mesnada() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	_honor.roster = MesnadaRoster.from_starting_seed()
	_logged.clear()
	var alvar_before := 0.72
	var martin_before := 0.55
	var alvar: MesnadaMember = _honor.roster.member(&"alvar_fanez")
	var martin: MesnadaMember = _honor.roster.member(&"martin_antolinez")
	if alvar:
		alvar_before = alvar.loyalty
	if martin:
		martin_before = martin.loyalty
	var honra_before := 40.0
	if _honor and _honor.state:
		honra_before = float(_honor.state.honra)
	var split: Dictionary = _treasury.divide_booty(PILE, {"to_alvar": true})
	if int(split.get("quinto_marks", 0)) != 160 or int(split.get("mesnada_marks", 0)) != 320:
		failures.append("gift must not change buckets, got %s" % str(split))
	if int(split.get("gift_marks", 0)) != 320 or int(split.get("gift_horses", 0)) != 16:
		failures.append("gift-to-Álvar should take mesnada 320/16, got %s" % str(split))
	if not bool(split.get("gift_to_alvar", false)):
		failures.append("gift_to_alvar flag missing")
	if int(_treasury.state.marks) != 320 or int(_treasury.state.royal_escrow_marks) != 160:
		failures.append("gift must not steal quinto or treasury")
	if martin == null or not is_equal_approx(martin.loyalty, martin_before):
		failures.append("full Álvar gift should leave Martín loyalty, got %s" % (martin.loyalty if martin else "null"))
	if alvar == null or not (alvar.loyalty > alvar_before):
		failures.append("Álvar loyalty should tick from mesnada share")
	if "gift_to_alvar" not in _logged:
		failures.append("gift_to_alvar honor missing, logged %s" % str(_logged))
	if _honor and not is_equal_approx(float(_honor.state.honra), honra_before + 3.0):
		failures.append("gift_to_alvar honra want %s got %s" % [honra_before + 3.0, _honor.state.honra])
	return failures


func _test_ui_spanish_and_confirm() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	_honor.roster = MesnadaRoster.from_starting_seed()
	var packed: PackedScene = load(UI_SCENE)
	if packed == null:
		failures.append("booty_divide.tscn missing")
		return failures
	var ui := packed.instantiate() as Control
	get_root().add_child(ui)
	if ui.has_method("bind_pile"):
		ui.call("bind_pile", PILE)
	elif ui.has_method("_refresh"):
		ui.set("pile", PILE)
		ui.call("_refresh")
	var title := ui.get_node_or_null(NodePath("Center/Title")) as Label
	var confirm_btn := ui.get_node_or_null(NodePath("Center/Confirm")) as Button
	var gift_btn := ui.get_node_or_null(NodePath("Center/GiftAlvar")) as CheckButton
	var quinto := ui.get_node_or_null(NodePath("Center/Buckets/Quinto/Amount")) as Label
	var mesnada := ui.get_node_or_null(NodePath("Center/Buckets/Mesnada/Amount")) as Label
	var treasury_lbl := ui.get_node_or_null(NodePath("Center/Buckets/Treasury/Amount")) as Label
	if title == null or title.text != "Reparto del botín":
		failures.append("title want Reparto del botín got %s" % (title.text if title else "null"))
	if confirm_btn == null or confirm_btn.text != "Confirmar":
		failures.append("confirm want Confirmar")
	if gift_btn == null or not gift_btn.text.contains("Álvar"):
		failures.append("gift control must name Álvar")
	if quinto == null or not quinto.text.contains("160") or not quinto.text.contains("marcos"):
		failures.append("quinto bucket want 160 marcos, got %s" % (quinto.text if quinto else "null"))
	if mesnada == null or not mesnada.text.contains("320"):
		failures.append("mesnada bucket want 320, got %s" % (mesnada.text if mesnada else "null"))
	if treasury_lbl == null or not treasury_lbl.text.contains("320"):
		failures.append("treasury bucket want 320, got %s" % (treasury_lbl.text if treasury_lbl else "null"))
	if ui.anchor_right < 0.99 or ui.anchor_bottom < 0.99:
		failures.append("booty UI must fill 720p viewport")
	if int(_treasury.state.marks) != 0:
		failures.append("showing the UI must not divide yet")
	if ui.has_method("confirm"):
		var split: Dictionary = ui.call("confirm")
		if int(split.get("quinto_marks", 0)) != 160 or int(split.get("treasury_marks", 0)) != 320:
			failures.append("UI confirm split want 160/320/320, got %s" % str(split))
	if int(_treasury.state.marks) != 320:
		failures.append("UI confirm treasury marks want 320 got %s" % _treasury.state.marks)
	if int(_treasury.state.horses) != 18:
		failures.append("UI confirm horses want 18 got %s" % _treasury.state.horses)
	ui.queue_free()
	return failures


func _test_alcocer_embassy_waits_for_divide() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	if _runner and _runner.has_method("restore"):
		_runner.restore(&"a1_alcocer", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
	var packed: Resource = load(ALCOCER)
	if packed == null or not (packed is PackedScene):
		failures.append("alcocer world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	_logged.clear()
	_completed.clear()
	var scene_before: Node = current_scene
	world.run_sortie()
	if bool(world.get("_divided")):
		failures.append("sortie must not divide booty")
	if String(_runner.current_id) == "a1_embassy1":
		failures.append("embassy travel must wait for divide")
	var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
	if _runner.has_method("can_travel") and bool(_runner.can_travel(&"a1_alcocer", &"a1_embassy1", flags)):
		failures.append("can_travel embassy must be false before divide")
	if "alcocer_sell" in _logged:
		failures.append("sortie must not apply alcocer_sell")
	var keep_ui: Node = world.find_child("KeepOrSell", true, false)
	if keep_ui == null or not bool(keep_ui.visible):
		failures.append("KeepOrSell must show after sortie win")
	var divide_ui: Node = world.find_child("BootyDivide", true, false)
	if divide_ui and bool(divide_ui.visible):
		failures.append("BootyDivide must wait for sell")
	world.choose_sell()
	if "alcocer_sell" not in _logged:
		failures.append("sell must apply alcocer_sell, logged %s" % str(_logged))
	if not is_equal_approx(float(_honor.state.onores), 28.0):
		failures.append("sortie + sell onores want 28 (8+18+10) got %s" % _honor.state.onores)
	if String(_runner.current_id) == "a1_embassy1":
		failures.append("sell must not skip the divide UI")
	if divide_ui == null or not bool(divide_ui.visible):
		failures.append("BootyDivide must show after sell")
	world.confirm_divide()
	if current_scene != scene_before:
		failures.append("divide must not change_scene when current_scene != world")
	if not bool(world.get("_divided")):
		failures.append("confirm_divide must resolve the split")
	if String(_runner.current_id) != "a1_embassy1":
		failures.append("divide travel must land on a1_embassy1, got %s" % _runner.current_id)
	flags = _runner.flags if "flags" in _runner else PackedStringArray()
	if "alcocer_booty_divided" not in flags:
		failures.append("divide must set alcocer_booty_divided")
	if _completed.count("a1_alcocer") > 1:
		failures.append("beat_completed must not double-fire, got %s" % str(_completed))
	world.free()
	return failures


func _test_castejon_sell_pile_reuses_ui() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset()
	if _runner and _runner.has_method("restore"):
		_runner.restore(&"a1_castejon", PackedStringArray(["hub_lock_cardena", "horse_companion"]))
	var packed: Resource = load(CASTJON)
	if packed == null or not (packed is PackedScene):
		failures.append("castejon world.tscn failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	get_root().add_child(world)
	world.run_take()
	world.choose_sell()
	if int(_treasury.state.marks) != 0:
		failures.append("Castejón sell must defer the split, marks got %s" % _treasury.state.marks)
	var divide_ui: Node = world.find_child("BootyDivide", true, false)
	if divide_ui == null or not bool(divide_ui.visible):
		failures.append("Castejón sell must open BootyDivide")
	world.confirm_divide()
	if int(_treasury.state.marks) != 320:
		failures.append("Castejón confirm treasury marks want 320 got %s" % _treasury.state.marks)
	if int(_treasury.state.royal_escrow_horses) != 8:
		failures.append("Castejón quinto horses want 8 got %s" % _treasury.state.royal_escrow_horses)
	if String(_runner.current_id) != "a1_alcocer":
		failures.append("Castejón divide travel want a1_alcocer got %s" % _runner.current_id)
	world.free()
	return failures


func _on_honor_logged(event: Variant) -> void:
	if event != null and "id" in event:
		_logged.append(String(event.id))


func _on_beat_completed(beat_id: StringName) -> void:
	_completed.append(String(beat_id))


func _reset() -> void:
	if _honor:
		_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	_logged.clear()
	_completed.clear()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_booty_divide: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_booty_divide: %s" % failure)
	quit(1)
