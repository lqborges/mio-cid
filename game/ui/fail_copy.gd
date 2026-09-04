class_name FailCopy
extends Control

const MENU_SCENE := "res://game/ui/main_menu.tscn"

static var last_reason: StringName = &"name_empty"

const COPY := {
	&"name_empty": "the name is empty",
	&"you_fell": "the name is empty",
	&"alfonso_host": "the name is empty",
	&"alfonso_wrath": "the name is empty",
	&"plazo_expired": "the name is empty",
	&"avengalvon_dead": "the name is empty",
	&"steel_in_cortes": "the name is empty",
}

@onready var _line: Label = $Center/Line
@onready var _reason: Label = $Center/Reason


func _ready() -> void:
	$Center/Reload.pressed.connect(_on_reload)
	$Center/Menu.pressed.connect(_on_menu)
	show_reason(last_reason)


func show_reason(reason: StringName) -> void:
	last_reason = reason
	if _line:
		_line.text = _copy_for(reason)
	if _reason:
		_reason.visible = OS.is_debug_build()
		_reason.text = String(reason) if _reason.visible else ""


func _copy_for(reason: StringName) -> String:
	var key := "fail.%s" % String(reason)
	if Loc != null and Loc.has_method("text"):
		var value := str(Loc.text(key))
		if not value.is_empty() and value != key:
			return value
	return str(COPY.get(reason, COPY[&"name_empty"]))


func _on_reload() -> void:
	if SaveService == null:
		_on_menu()
		return
	var payload: Dictionary = SaveService.load_file(SaveService.autosave_path())
	if payload.is_empty():
		_on_menu()
		return
	var chapter := GameState.chapter_id() if GameState else &""
	if chapter != &"" and ChapterRunner != null and ChapterRunner.has_method("goto"):
		ChapterRunner.goto(chapter)
		return
	var vivar := "res://content/chapters/a1_vivar/world.tscn"
	if ResourceLoader.exists(vivar):
		get_tree().change_scene_to_file(vivar)
		return
	_on_menu()


func _on_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
