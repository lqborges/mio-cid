extends SceneTree
## Headless early-game travel: Vivar gate → Burgos river → Arcas confirm → Cardeña.
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_early_game_travel.gd

var _runner: Variant
var _honor: Variant
var _treasury: Variant
var _clock: Variant


func _initialize() -> void:
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_prep()
	failures.append_array(await _walk_vivar_to_cardena())
	_finish(failures)


func _walk_vivar_to_cardena() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("goto"):
		failures.append("ChapterRunner missing goto")
		return failures
	_runner.set("_pending_scene", "")
	_runner.set("queued_scene_changes", 0)
	_runner.goto(&"a1_vivar")
	var vivar := await _await_scene("a1_vivar/world.tscn")
	if vivar == null:
		failures.append("goto a1_vivar did not become current_scene")
		return failures
	failures.append_array(_check_hud_and_nameplates(vivar, ["Alvar/Name", "Martin/Name"]))
	failures.append_array(_check_pause_menu())
	var after_vivar := int(_runner.get("queued_scene_changes"))
	if vivar.has_method("leave_solar"):
		vivar.set("_left", false)
		vivar.leave_solar()
	if vivar.has_method("_physics_process"):
		for _i in 8:
			if is_instance_valid(vivar):
				vivar._physics_process(0.016)
	if int(_runner.get("queued_scene_changes")) != after_vivar + 1:
		failures.append(
			"Vivar leave must queue one Burgos change, queued %s after %s"
			% [_runner.get("queued_scene_changes"), after_vivar]
		)
	var burgos := await _await_scene("a1_burgos/world.tscn")
	if burgos == null:
		failures.append("Vivar gate did not travel to a1_burgos")
		return failures
	if String(_runner.current_id) != "a1_burgos":
		failures.append("current_id want a1_burgos got %s" % _runner.current_id)
	var after_burgos := int(_runner.get("queued_scene_changes"))
	if burgos.has_method("camp_on_river"):
		burgos.set("_camped", false)
		burgos.camp_on_river()
	if burgos.has_method("_physics_process"):
		for _i in 8:
			if is_instance_valid(burgos):
				burgos._physics_process(0.016)
	if int(_runner.get("queued_scene_changes")) != after_burgos + 1:
		failures.append(
			"Burgos river must queue one Arcas change, queued %s after %s"
			% [_runner.get("queued_scene_changes"), after_burgos]
		)
	var arcas := await _await_scene("a1_arcas/world.tscn")
	if arcas == null:
		failures.append("Burgos river did not travel to a1_arcas")
		return failures
	failures.append_array(_check_choice_buttons(arcas))
	if arcas.has_method("choose_cheat"):
		arcas.set("_resolved", false)
		arcas.set("_left", false)
		arcas.set("_talking", false)
		arcas.choose_cheat()
	if bool(arcas.get("_talking")) and arcas.has_method("_on_dialogue_ended"):
		# Confirm balloon owns the beat; travel only when it ends.
		if String(_runner.current_id) == "a1_cardena" and bool(arcas.get("_left")):
			failures.append("Arcas confirm must stay on the sandbar until the balloon ends")
		arcas.call("_on_dialogue_ended")
	elif not bool(arcas.get("_left")) and arcas.has_method("_travel_to_cardena"):
		arcas.call("_travel_to_cardena")
	var cardena := await _await_scene("a1_cardena/world.tscn")
	if cardena == null:
		failures.append("Arcas confirm did not travel to a1_cardena")
		return failures
	if String(_runner.current_id) != "a1_cardena":
		failures.append("current_id want a1_cardena got %s" % _runner.current_id)
	return failures


func _check_hud_and_nameplates(world: Node, plates: PackedStringArray) -> PackedStringArray:
	var failures: PackedStringArray = []
	var meters: Node = world.find_child("HonorMeters", true, false)
	if meters == null:
		failures.append("%s missing HonorMeters" % world.name)
	elif meters.has_method("_meter_label"):
		var onores := str(meters.call("_meter_label", &"onores"))
		if onores != "Honores":
			failures.append("onores label want Honores, got %s" % onores)
		if (meters as Control).mouse_filter != Control.MOUSE_FILTER_STOP:
			failures.append("HonorMeters must be a click sink")
	var looks: Node = get_root().get_node_or_null("HumanoidLooks")
	if looks and looks.has_method("ensure"):
		looks.call("ensure", world)
	for path in plates:
		var label: Label3D = world.get_node_or_null(path) as Label3D
		if label == null:
			failures.append("missing nameplate %s" % path)
			continue
		if label.font_size > 32 or label.pixel_size > 0.006:
			failures.append("%s nameplate is oversized" % path)
	return failures


func _check_pause_menu() -> PackedStringArray:
	var failures: PackedStringArray = []
	var pause: Node = get_root().get_node_or_null("PauseMenu")
	if pause == null or not pause.has_method("open"):
		failures.append("PauseMenu missing")
		return failures
	pause.call("open")
	if not bool(pause.visible):
		failures.append("pause menu did not open")
	if pause.get_node_or_null("Panel/Center/Resume") == null:
		failures.append("pause missing Continuar")
	if pause.get_node_or_null("Panel/Center/Menu") == null:
		failures.append("pause missing Menú principal")
	if pause.get_node_or_null("Panel/Center/Quit") == null:
		failures.append("pause missing Salir")
	pause.call("resume")
	return failures


func _check_choice_buttons(world: Node) -> PackedStringArray:
	var failures: PackedStringArray = []
	var ui: Node = world.find_child("ChoiceUI", true, false)
	if ui == null:
		failures.append("Arcas ChoiceUI missing")
		return failures
	if not ui.is_in_group("modal_choice"):
		failures.append("ChoiceUI must be modal_choice")
	var cid: Node = world.get_node_or_null("Cid")
	if cid and ui.has_method("present"):
		ui.call("present")
		if cid.has_method("_modal_ui_open") and not bool(cid.call("_modal_ui_open")):
			failures.append("visible ChoiceUI must count as modal")
		if cid.has_method("_input"):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(640, 360)
			cid.call("_input", click)
			if cid.get("_queued_click_pos") != null:
				failures.append("ChoiceUI click must not queue click-to-move")
			if not bool(cid.get("_click_move_from_hud")):
				failures.append("ChoiceUI click must block walk without eating the GUI event")
		if ui.has_method("dismiss"):
			ui.call("dismiss")
	return failures


func _await_scene(suffix: String, frames: int = 45) -> Node:
	for _i in frames:
		await process_frame
		var scene := current_scene
		if scene != null and String(scene.scene_file_path).ends_with(suffix):
			return scene
	var got := current_scene
	if got != null and String(got.scene_file_path).ends_with(suffix):
		return got
	return null


func _prep() -> void:
	if _honor and _honor.has_method("reset_state"):
		_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	if _runner and _runner.has_method("reset"):
		_runner.reset()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_early_game_travel: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_early_game_travel: %s" % failure)
	quit(1)
