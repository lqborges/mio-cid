extends SceneTree
## Headless a1_arcas sand-chest test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_a1_arcas.gd

const WORLD := "res://content/chapters/a1_arcas/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"

var _honor: Variant
var _treasury: Variant
var _clock: Variant
var _runner: Variant
var _loc: Variant
var _world: Node = null


func _initialize() -> void:
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_loc = get_root().get_node_or_null(NodePath("Loc"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_scene_loads())
	if _world:
		failures.append_array(_check_greybox_lights())
		failures.append_array(_check_separate_lenders())
		failures.append_array(_check_lenders_interactable())
		failures.append_array(_check_nameplates())
		failures.append_array(_check_spanish_choice_copy())
		failures.append_array(await _check_choice_after_offer())
		failures.append_array(_check_choice_ui_is_modal())
		failures.append_array(_check_offer_end_does_not_travel())
		failures.append_array(_check_confirm_end_travels())
		failures.append_array(_check_cheat_stain_and_marks())
		_world.free()
		_world = null
	failures.append_array(_check_refuse_desertion())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_arcas/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_arcas world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	var cid_scene: Resource = load(CID)
	if cid_scene == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Martin") == null:
		failures.append("world missing Martín")
	if _world.get_node_or_null("Raquel") == null:
		failures.append("world missing Raquel")
	if _world.get_node_or_null("Vidas") == null:
		failures.append("world missing Vidas")
	if _world.get_node_or_null("SandChestA") == null or _world.get_node_or_null("SandChestB") == null:
		failures.append("world missing sand chests")
	if _world.get_node_or_null("River") == null:
		failures.append("world missing river")
	if _world.find_child("ChoiceUI", true, false) == null:
		failures.append("choice UI missing from a1_arcas HUD")
	if _world.find_child("DesertionTicker", true, false) == null:
		failures.append("desertion ticker missing from a1_arcas HUD")
	if _world.find_child("PlazoBar", true, false) == null:
		failures.append("plazo bar missing from a1_arcas HUD")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_arcas HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a1_arcas":
		failures.append("ChapterRunner.current_id want a1_arcas got %s" % _runner.current_id)
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_arcas must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_arcas has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 6:
		failures.append("a1_arcas greybox missing river/camp/chest CSG")
	return failures


func _check_separate_lenders() -> PackedStringArray:
	var failures: PackedStringArray = []
	var raquel: Node = _world.get_node_or_null("Raquel")
	var vidas: Node = _world.get_node_or_null("Vidas")
	var martin: Node = _world.get_node_or_null("Martin")
	if raquel == null or vidas == null or martin == null:
		failures.append("Raquel, Vidas, and Martín must all be in the scene")
		return failures
	var rid := str(raquel.get("character_id")) if "character_id" in raquel else ""
	var vid := str(vidas.get("character_id")) if "character_id" in vidas else ""
	var mid := str(martin.get("character_id")) if "character_id" in martin else ""
	if rid != "raquel":
		failures.append("Raquel character_id want raquel got %s" % rid)
	if vid != "vidas":
		failures.append("Vidas character_id want vidas got %s" % vid)
	if rid == vid:
		failures.append("Raquel and Vidas must be separate ids")
	if mid != "martin_antolinez":
		failures.append("Martín character_id want martin_antolinez got %s" % mid)
	return failures


func _check_lenders_interactable() -> PackedStringArray:
	var failures: PackedStringArray = []
	for name in ["Martin", "Raquel", "Vidas"]:
		var npc: Node = _world.get_node_or_null(name)
		if npc == null:
			failures.append("missing %s" % name)
			continue
		if not npc.has_method("interact"):
			failures.append("%s missing interact()" % name)
		if not npc.is_in_group("interactable"):
			failures.append("%s must be in interactable group" % name)
	return failures


func _check_nameplates() -> PackedStringArray:
	var failures: PackedStringArray = []
	var looks: Node = get_root().get_node_or_null("HumanoidLooks")
	if looks and looks.has_method("ensure"):
		looks.call("ensure", _world)
	for path in ["Martin/Name", "Raquel/Name", "Vidas/Name"]:
		var label: Label3D = _world.get_node_or_null(path) as Label3D
		if label == null:
			failures.append("missing nameplate %s" % path)
			continue
		if label.fixed_size:
			failures.append("%s nameplate must not use fixed_size" % path)
		if label.font_size > 32:
			failures.append("%s nameplate font_size %s is too large" % [path, label.font_size])
		if label.pixel_size > 0.006:
			failures.append("%s nameplate pixel_size %s is too large" % [path, label.pixel_size])
		var world_h := float(label.font_size) * float(label.pixel_size)
		if world_h > 0.18:
			failures.append("%s nameplate world height %s is too tall" % [path, world_h])
	return failures


func _check_offer_end_does_not_travel() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null:
		failures.append("ChapterRunner missing for offer-end travel check")
		return failures
	if "current_id" in _runner:
		_runner.current_id = &"a1_arcas"
	if "flags" in _runner:
		_runner.flags = PackedStringArray()
	_world.set("_resolved", false)
	_world.set("_left", false)
	if _world.has_method("_on_dialogue_ended"):
		_world.call("_on_dialogue_ended")
	if String(_runner.current_id) == "a1_cardena":
		failures.append("offer dialogue end must present the choice, not travel")
	var ui: Node = _world.find_child("ChoiceUI", true, false)
	if ui == null or not bool(ui.visible):
		failures.append("offer dialogue end must show ChoiceUI")
	return failures


func _check_confirm_end_travels() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null:
		failures.append("ChapterRunner missing for confirm-end travel check")
		return failures
	if "current_id" in _runner:
		_runner.current_id = &"a1_arcas"
	if "flags" in _runner:
		_runner.flags = PackedStringArray()
	_world.set("_resolved", true)
	_world.set("_left", false)
	if _world.has_method("_on_dialogue_ended"):
		_world.call("_on_dialogue_ended")
	if String(_runner.current_id) != "a1_cardena":
		failures.append("confirm dialogue end must travel to a1_cardena, got %s" % _runner.current_id)
	_world.set("_left", false)
	return failures


func _check_spanish_choice_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var cheat := str(_loc.call("text", "a1_arcas.choice_cheat"))
	var refuse := str(_loc.call("text", "a1_arcas.choice_refuse"))
	if cheat == "a1_arcas.choice_cheat" or cheat.is_empty():
		failures.append("Loc did not resolve a1_arcas.choice_cheat")
	if not cheat.to_lower().contains("arena"):
		failures.append("cheat choice Spanish missing arena, got %s" % cheat)
	if refuse == "a1_arcas.choice_refuse" or refuse.is_empty():
		failures.append("Loc did not resolve a1_arcas.choice_refuse")
	if not refuse.to_lower().contains("rehusar"):
		failures.append("refuse choice Spanish missing Rehusar, got %s" % refuse)
	return failures


func _check_choice_after_offer() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ui: Node = _world.find_child("ChoiceUI", true, false)
	if ui and bool(ui.visible):
		failures.append("choice UI must stay hidden until Raquel and Vidas finish")
	if not _world.has_method("run_offer"):
		failures.append("world missing run_offer")
		return failures
	await _world.run_offer()
	if ui == null or not bool(ui.visible):
		failures.append("choice UI should present after the offer cue")
	if _world.has_method("start_offer"):
		_world.start_offer()
		if ui and not bool(ui.visible):
			failures.append("start_offer must not hide ChoiceUI once the branch is up")
	return failures


func _check_choice_ui_is_modal() -> PackedStringArray:
	var failures: PackedStringArray = []
	var ui: Node = _world.find_child("ChoiceUI", true, false)
	if ui == null:
		failures.append("ChoiceUI missing for modal check")
		return failures
	if not ui.is_in_group("modal_choice"):
		failures.append("ChoiceUI must join modal_choice so E/LMB cannot walk or re-talk")
	if not ui.is_in_group("hud_click_sink"):
		failures.append("ChoiceUI must join hud_click_sink")
	var cid: Node = _world.get_node_or_null("Cid")
	if cid and cid.has_method("_modal_ui_open") and ui.visible:
		if not bool(cid.call("_modal_ui_open")):
			failures.append("Cid must treat visible ChoiceUI as modal")
		if cid.has_method("_input"):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(640, 360)
			cid.call("_input", click)
			var vp := cid.get_viewport()
			if vp and vp.is_input_handled():
				failures.append("Cid _input must not eat the Arcas choice buttons")
	return failures


func _check_cheat_stain_and_marks() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _honor == null or _treasury == null:
		failures.append("HonorService or TreasuryService missing")
		return failures
	if not _world.has_method("choose_cheat"):
		failures.append("world missing choose_cheat")
		return failures
	_prep_campaign()
	_world.set("_resolved", false)
	_world.set("_left", false)
	_world.set("_talking", false)
	var roster: MesnadaRoster = _honor.roster
	var martin: MesnadaMember = roster.member(&"martin_antolinez") if roster else null
	var loyalty_before := 0.55
	if martin:
		loyalty_before = float(martin.loyalty)
	_world.choose_cheat()
	_world.choose_cheat()
	if int(_treasury.state.marks) != 600:
		failures.append("cheat marks want 600 got %s" % _treasury.state.marks)
	if not is_equal_approx(_honor.state.onores, 30.0):
		failures.append("cheat onores want 30 got %s" % _honor.state.onores)
	if not is_equal_approx(_honor.state.honra, 34.0):
		failures.append("cheat honra want 34 got %s" % _honor.state.honra)
	if not _honor.state.has_stain(&"arcas_cheat"):
		failures.append("cheat must stain arcas_cheat")
	if _runner == null or not ("arcas_cheated" in _runner.flags):
		failures.append("cheat must set arcas_cheated")
	if roster == null:
		failures.append("cheat missing roster")
		return failures
	if roster.lanzas != 12:
		failures.append("cheat men stay: lanzas want 12 got %s" % roster.lanzas)
	if roster.living_named_captains() != 5:
		failures.append("cheat men stay: captains want 5 got %s" % roster.living_named_captains())
	if _clock and int(_clock.unfed_streak) != 0:
		failures.append("cheat must not tick unfed_streak")
	if martin:
		var want := clampf(loyalty_before + 0.08, 0.0, 1.0)
		if not is_equal_approx(float(martin.loyalty), want):
			failures.append("cheat Martín loyalty want %s got %s" % [want, martin.loyalty])
	var whisper: Node = _world.find_child("HallWhisper", true, false)
	var shown := ""
	if whisper:
		var label: Node = whisper.get_node_or_null("Line")
		if label and "text" in label:
			shown = str(label.get("text"))
	if not shown.contains("marcos"):
		failures.append("cheat cue should confirm marks, got %s" % shown)
	return failures


func _check_refuse_desertion() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("refuse path: world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	get_root().add_child(_world)
	if not _world.has_method("choose_refuse"):
		failures.append("world missing choose_refuse")
		_world.free()
		_world = null
		return failures
	var roster: MesnadaRoster = _honor.roster
	_world.choose_refuse()
	if int(_treasury.state.marks) != 0:
		failures.append("refuse marks want 0 got %s" % _treasury.state.marks)
	if _honor.state.has_stain(&"arcas_cheat"):
		failures.append("refuse must not stain arcas_cheat")
	if _runner and "arcas_cheated" in _runner.flags:
		failures.append("refuse must not set arcas_cheated")
	if _runner == null or "arcas_refused" not in _runner.flags:
		failures.append("refuse must persist arcas_refused")
	if not is_equal_approx(_honor.state.honra, 43.0):
		failures.append("refuse honra want 43 got %s" % _honor.state.honra)
	if not is_equal_approx(_honor.state.onores, 0.0):
		failures.append("refuse two unfed nights onores want 0 got %s" % _honor.state.onores)
	if _clock == null or int(_clock.unfed_streak) != 2:
		failures.append("refuse_48h streak want 2 got %s" % (_clock.unfed_streak if _clock else "?"))
	if roster == null or roster.lanzas != 6:
		failures.append("refuse night 2 lanzas want 6 got %s" % (roster.lanzas if roster else "?"))
	if roster and roster.living_named_captains() != 5:
		failures.append("refuse_48h must not drop named captains yet, got %s" % roster.living_named_captains())
	var ticker: Node = _world.find_child("DesertionTicker", true, false)
	if ticker == null or not bool(ticker.visible):
		failures.append("refuse must show the desertion ticker")
	else:
		var label: Node = ticker.get_node_or_null("Line")
		var shown := ""
		if label and "text" in label:
			shown = str(label.get("text"))
		if shown.is_empty():
			failures.append("desertion ticker is blank")
		elif not shown.contains("6"):
			failures.append("desertion ticker should show 6 lanzas, got %s" % shown)
	var whisper: Node = _world.find_child("HallWhisper", true, false)
	var line := ""
	if whisper:
		var label: Node = whisper.get_node_or_null("Line")
		if label and "text" in label:
			line = str(label.get("text"))
	if not line.to_lower().contains("ayuna") and not line.to_lower().contains("mesnada"):
		failures.append("refuse cue should confirm hunger, got %s" % line)
	_world.free()
	_world = null
	return failures


func _prep_campaign() -> void:
	if _honor:
		if _honor.has_method("reset_state"):
			_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	if _runner:
		if "flags" in _runner:
			_runner.flags = PackedStringArray()
		if "current_id" in _runner:
			_runner.current_id = &""


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a1_arcas: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_arcas: %s" % failure)
	quit(1)
