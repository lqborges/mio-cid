class_name HonorEvent
extends Resource

@export var id: StringName
@export var deltas: Dictionary = {}  # keys: "onores"|"honor"|"honra" -> float
@export var tags: PackedStringArray = []
@export var stain_id: StringName = &""
@export var clear_stain: StringName = &""
@export var flags_set: PackedStringArray = []
@export var hard_fail: bool = false
@export var hard_fail_reason: StringName = &""
@export var beat: StringName = &""
@export var once: bool = false
@export var ui_whisper_key: StringName = &""


func delta_for(meter: StringName) -> float:
	var key := String(meter)
	if deltas.has(key):
		return float(deltas[key])
	if deltas.has(meter):
		return float(deltas[meter])
	return 0.0


func has_tag(tag: StringName) -> bool:
	return String(tag) in tags


static func from_dict(data: Dictionary) -> HonorEvent:
	var ev := HonorEvent.new()
	ev.id = StringName(str(data.get("id", "")))
	ev.deltas = _normalized_deltas(data.get("deltas", {}))
	ev.tags = _to_packed(data.get("tags", []))
	ev.stain_id = _optional_name(data.get("stain_id", ""))
	ev.clear_stain = _optional_name(data.get("clear_stain", ""))
	ev.flags_set = _to_packed(data.get("flags_set", []))
	ev.hard_fail = bool(data.get("hard_fail", false))
	ev.hard_fail_reason = _optional_name(data.get("hard_fail_reason", ""))
	ev.beat = _optional_name(data.get("beat", ""))
	ev.once = bool(data.get("once", false))
	ev.ui_whisper_key = _optional_name(data.get("ui_whisper_key", ""))
	return ev


static func _normalized_deltas(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	var src: Dictionary = raw
	for key in [&"onores", &"honor", &"honra"]:
		var as_str := String(key)
		if src.has(as_str):
			out[as_str] = float(src[as_str])
		elif src.has(key):
			out[as_str] = float(src[key])
	return out


static func _to_packed(raw: Variant) -> PackedStringArray:
	var packed := PackedStringArray()
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for item in raw:
			if item == null:
				continue
			packed.append(str(item))
	return packed


static func _optional_name(raw: Variant) -> StringName:
	if raw == null:
		return &""
	var text := str(raw)
	return StringName(text) if not text.is_empty() else &""
