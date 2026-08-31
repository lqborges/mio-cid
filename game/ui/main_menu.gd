extends Control

const VIVAR_SCENE := "res://content/chapters/a1_vivar/world.tscn"

@onready var _status: Label = $Center/Status
@onready var _slots: HBoxContainer = $Center/Slots


func _ready() -> void:
	$Center/NewGame.pressed.connect(_on_new_game)
	$Center/Load.pressed.connect(_on_load_pressed)
	$Center/Quit.pressed.connect(_on_quit)
	_rebuild_slots()
	_slots.visible = false
	if _status:
		_status.text = ""


func _on_new_game() -> void:
	_reset_campaign()
	if SaveService:
		SaveService.save(1)
		SaveService.autosave()
	_enter_game()


func _on_load_pressed() -> void:
	_rebuild_slots()
	_slots.visible = not _slots.visible


func _on_quit() -> void:
	get_tree().quit()


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
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = &"a1_vivar"
	if ChapterRunner and "flags" in ChapterRunner:
		ChapterRunner.flags = PackedStringArray()


func _enter_game() -> void:
	if ResourceLoader.exists(VIVAR_SCENE):
		get_tree().change_scene_to_file(VIVAR_SCENE)
		return
	if _status:
		_status.text = "partida nueva"


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
