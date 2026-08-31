extends Node


func honor() -> Variant:
	return _service_prop(HonorService, &"state")


func treasury() -> Variant:
	return _service_prop(TreasuryService, &"state")


func roster() -> Variant:
	return _service_prop(HonorService, &"roster")


func clock() -> Node:
	return CampaignClock


func chapter_id() -> StringName:
	var value: Variant = _service_prop(ChapterRunner, &"current_id")
	if value is StringName:
		return value
	if value is String:
		var as_str := value as String
		if not as_str.is_empty():
			return StringName(as_str)
	return &""


func flags() -> PackedStringArray:
	var value: Variant = _service_prop(ChapterRunner, &"flags")
	if value is PackedStringArray:
		return value
	if value is Array:
		var packed := PackedStringArray()
		for item in value:
			packed.append(str(item))
		return packed
	return PackedStringArray()


func _service_prop(service: Object, prop: StringName) -> Variant:
	if service == null:
		return null
	if prop in service:
		return service.get(prop)
	return null
