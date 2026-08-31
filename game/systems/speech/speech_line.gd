class_name SpeechLine
extends Resource

@export var id: StringName
@export var text_key: StringName
@export var legal: float = 0.0
@export var mesura: float = 0.0
@export var ira: float = 0.0
@export var tags: PackedStringArray = []
@export var vo_id: StringName = &""


func has_tag(t: StringName) -> bool:
	return String(t) in tags
