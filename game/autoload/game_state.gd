extends Node

const FAIL_SCENE := "res://game/ui/fail_copy.tscn"
const HORSE_COMPANION_FLAG := "horse_companion"
const SWORD_IDS := [&"colada", &"tizona"]

# Plot swords live here because there is no inventory autoload.
var _swords: Dictionary = {}


func _ready() -> void:
	_ensure_swords()
	if EventBus:
		EventBus.hard_fail.connect(_on_hard_fail)


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


func sword(item_id: StringName) -> SwordItem:
	_ensure_swords()
	var found: Variant = _swords.get(String(item_id))
	return found if found is SwordItem else null


func swords() -> Dictionary:
	_ensure_swords()
	var out := {}
	for key in _swords:
		var item: Variant = _swords[key]
		if item is SwordItem:
			out[str(key)] = (item as SwordItem).phase_name()
	return out


func apply_swords(raw: Variant) -> void:
	_ensure_swords()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	for key in data:
		var item: Variant = _swords.get(str(key))
		if item is SwordItem:
			(item as SwordItem).set_phase_name(str(data[key]))


func reset_swords() -> void:
	_swords.clear()
	_ensure_swords()


func flags() -> PackedStringArray:
	var packed := PackedStringArray()
	var value: Variant = _service_prop(ChapterRunner, &"flags")
	if value is PackedStringArray:
		packed = (value as PackedStringArray).duplicate()
	elif value is Array:
		for item in value:
			packed.append(str(item))
	var has_horse := false
	for flag in packed:
		if flag == HORSE_COMPANION_FLAG:
			has_horse = true
			break
	if not has_horse:
		packed.append(HORSE_COMPANION_FLAG)
	return packed


func _on_hard_fail(reason: StringName) -> void:
	FailCopy.last_reason = reason
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene := tree.current_scene
	if scene.scene_file_path == FAIL_SCENE:
		if scene.has_method("show_reason"):
			scene.show_reason(reason)
		return
	tree.change_scene_to_file(FAIL_SCENE)


func _ensure_swords() -> void:
	for item_id in SWORD_IDS:
		var key := String(item_id)
		if _swords.has(key) and _swords[key] is SwordItem:
			continue
		_swords[key] = SwordItem.from_id(item_id)


func _service_prop(service: Object, prop: StringName) -> Variant:
	if service == null:
		return null
	if prop in service:
		return service.get(prop)
	return null
