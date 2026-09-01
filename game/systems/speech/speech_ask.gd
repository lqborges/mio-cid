class_name SpeechAsk
extends Resource

@export var id: StringName
@export var prompt_key: StringName
@export var counts_toward_win: bool = true  # false would be unused: García is a separate trial
@export var lines: Array[SpeechLine] = []


func get_line(line_id: StringName) -> SpeechLine:
	for l in lines:
		if l != null and l.id == line_id:
			return l
	return null
