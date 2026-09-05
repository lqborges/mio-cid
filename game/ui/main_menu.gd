extends Control

const VIVAR_SCENE := "res://content/chapters/a1_vivar/world.tscn"

@onready var _status: Label = $Center/Status
@onready var _slots: HBoxContainer = $Center/Slots


func _ready() -> void:
	$Center/NewGame.pressed.connect(_on_new_game)
	$Center/Load.pressed.connect(_on_load_pressed)
	$Center/Quit.pressed.connect(_on_quit)
	var language := get_node_or_null("Center/Language") as Button
	if language and not language.pressed.is_connected(_on_language_pressed):
		language.pressed.connect(_on_language_pressed)
	_rebuild_slots()
	_slots.visible = false
	if _status:
		_status.text = ""
	_apply_labels()
	var loc := get_node_or_null("/root/Loc")
	if loc != null and loc.has_signal("locale_changed") and not loc.locale_changed.is_connected(_on_locale_changed):
		loc.locale_changed.connect(_on_locale_changed)


func _on_new_game() -> void:
	# Always start. A two-click overwrite confirm looked like a dead menu
	# once all five slots existed from prior play.
	var slot := _first_empty_slot()
	if slot == 0:
		slot = 1
	_reset_campaign()
	if SaveService:
		SaveService.save(slot)
		SaveService.autosave()
	_rebuild_slots()
	_enter_game()


func _on_load_pressed() -> void:
	_rebuild_slots()
	_slots.visible = not _slots.visible


func _on_quit() -> void:
	get_tree().quit()


func _on_language_pressed() -> void:
	var next := "en" if _current_locale() == "es" else "es"
	var guide := get_node_or_null("/root/PlayerGuide")
	if guide != null and guide.has_method("set_setting"):
		guide.call("set_setting", "locale", next)
		return
	var loc := get_node_or_null("/root/Loc")
	if loc != null and loc.has_method("set_locale"):
		loc.call("set_locale", next)


func _on_locale_changed(_code: String) -> void:
	_apply_labels()


func _apply_labels() -> void:
	var new_game := get_node_or_null("Center/NewGame") as Button
	if new_game:
		new_game.text = _loc("ui.menu.new", "Nueva partida")
	var load_btn := get_node_or_null("Center/Load") as Button
	if load_btn:
		load_btn.text = _loc("ui.menu.load", "Cargar")
	var quit := get_node_or_null("Center/Quit") as Button
	if quit:
		quit.text = _loc("ui.menu.quit", "Salir")
	var language := get_node_or_null("Center/Language") as Button
	if language:
		language.text = "Español" if _current_locale() == "en" else "English"


func _current_locale() -> String:
	var loc := get_node_or_null("/root/Loc")
	if loc != null and "locale" in loc:
		return str(loc.get("locale"))
	return "es"


func _loc(key: String, fallback: String) -> String:
	var loc := get_node_or_null("/root/Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t


func _on_slot(slot: int) -> void:
	if SaveService == null:
		return
	var payload: Dictionary = SaveService.load(slot)
	if payload.is_empty():
		if _status:
			_status.text = String(SaveService.last_error)
		return
	_enter_game()


func _reset_campaign() -> void:
	if HonorService:
		HonorService.reset_state()
		HonorService.roster = MesnadaRoster.from_starting_seed()
	if TreasuryService:
		TreasuryService.reset()
	if CampaignClock:
		CampaignClock.reset()
	if GameState and GameState.has_method("reset_swords"):
		GameState.reset_swords()
	if ChapterRunner and ChapterRunner.has_method("reset"):
		ChapterRunner.reset()
	elif ChapterRunner:
		if "current_id" in ChapterRunner:
			ChapterRunner.current_id = &"a1_vivar"
		if "flags" in ChapterRunner:
			ChapterRunner.flags = PackedStringArray()


func _first_empty_slot() -> int:
	if SaveService == null or not SaveService.has_method("slot_exists"):
		return 1
	for slot in range(1, 6):
		if not SaveService.slot_exists(slot):
			return slot
	return 0


func _enter_game() -> void:
	# New Game resets current_id to Vivar. Load keeps the saved beat.
	var dest := _resume_chapter()
	if ChapterRunner and ChapterRunner.has_method("goto"):
		ChapterRunner.goto(dest)
		return
	var path := ""
	if ChapterRunner and ChapterRunner.has_method("_scene_path"):
		path = str(ChapterRunner._scene_path(dest))
	if path.is_empty() or not ResourceLoader.exists(path):
		path = VIVAR_SCENE
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
		return
	if _status:
		_status.text = "partida nueva"


func _resume_chapter() -> StringName:
	if ChapterRunner and "current_id" in ChapterRunner:
		var saved := StringName(String(ChapterRunner.current_id))
		if not String(saved).is_empty():
			return saved
	return &"a1_vivar"


func _rebuild_slots() -> void:
	for child in _slots.get_children():
		child.queue_free()
	for slot in range(1, 6):
		var btn := Button.new()
		btn.text = str(slot)
		btn.custom_minimum_size = Vector2(48, 36)
		var exists := SaveService != null and SaveService.has_method("slot_exists") and SaveService.slot_exists(slot)
		btn.disabled = not exists
		var captured := slot
		btn.pressed.connect(func() -> void: _on_slot(captured))
		_slots.add_child(btn)
