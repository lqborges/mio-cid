class_name HallWhisper
extends Control

@onready var line: Label = $Line


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if line:
		line.text = ""
		line.visible = false
	if EventBus:
		EventBus.honor_logged.connect(_on_honor_logged)


func whisper_key(key: String) -> void:
	if key.is_empty():
		return
	_show(Loc.text(key) if Loc else key)


func _on_honor_logged(event: HonorEvent) -> void:
	if event == null:
		return
	var key := String(event.ui_whisper_key)
	if key.is_empty():
		return
	whisper_key(key)


func _show(text: String) -> void:
	if line == null or text.is_empty():
		return
	line.text = text
	line.visible = true
