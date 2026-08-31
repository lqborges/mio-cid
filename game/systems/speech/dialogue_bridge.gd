class_name DialogueBridge
extends Node
## Maps Dialogue Manager line tags onto HonorService / EventBus.
## HonorService may still be a stub; every service call is has_method-guarded.

const TAG_HONOR_EVENT := "honor_event"
const TAG_FLAG_SET := "flag_set"


func _ready() -> void:
	_connect_dialogue_manager()


func handle_line(line: Variant) -> void:
	if line == null:
		return
	var honor_id := _tag_value(line, TAG_HONOR_EVENT)
	if not honor_id.is_empty():
		_apply_honor(StringName(honor_id))
	var flag_raw := _tag_value(line, TAG_FLAG_SET)
	if not flag_raw.is_empty():
		for part in flag_raw.split(","):
			var flag_id := part.strip_edges()
			if not flag_id.is_empty():
				_set_flag(StringName(flag_id))


func _on_got_dialogue(line: Variant) -> void:
	handle_line(line)


func _apply_honor(event_id: StringName) -> void:
	var applied := false
	if HonorService != null:
		if HonorService.has_method("apply_id"):
			HonorService.apply_id(event_id)
			applied = true
		elif HonorService.has_method("apply"):
			HonorService.call("apply", event_id)
			applied = true
	if not applied and EventBus != null and EventBus.has_signal("honor_logged"):
		EventBus.honor_logged.emit(event_id)


func _set_flag(flag_id: StringName) -> void:
	if ChapterRunner != null and ChapterRunner.has_method("set_flag"):
		ChapterRunner.set_flag(flag_id)
	elif HonorService != null and HonorService.has_method("set_flag"):
		HonorService.set_flag(flag_id)


func _connect_dialogue_manager() -> void:
	var dm := _dialogue_manager()
	if dm == null:
		return
	if dm.has_signal("got_dialogue") and not dm.got_dialogue.is_connected(_on_got_dialogue):
		dm.got_dialogue.connect(_on_got_dialogue)


func _dialogue_manager() -> Object:
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DialogueManager")


func _tag_value(line: Variant, tag_name: String) -> String:
	if typeof(line) == TYPE_OBJECT and line.has_method("get_tag_value"):
		var from_line := str(line.call("get_tag_value", tag_name))
		if not from_line.is_empty():
			return from_line
	var prefix := "%s=" % tag_name
	for tag in _tags_of(line):
		var raw := str(tag).strip_edges()
		if raw.begins_with("#"):
			raw = raw.substr(1)
		if raw == tag_name:
			return tag_name
		if raw.begins_with(prefix):
			return raw.substr(prefix.length()).strip_edges()
	return ""


func _tags_of(line: Variant) -> PackedStringArray:
	var raw: Variant = null
	if typeof(line) == TYPE_DICTIONARY:
		raw = line.get("tags", PackedStringArray())
	elif typeof(line) == TYPE_OBJECT and "tags" in line:
		raw = line.get("tags")
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		var packed := PackedStringArray()
		for item in raw:
			packed.append(str(item))
		return packed
	return PackedStringArray()
