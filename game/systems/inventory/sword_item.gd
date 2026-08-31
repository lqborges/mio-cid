class_name SwordItem
extends Resource
## Plot swords. Phase is the only source of truth; never treasury stacks.

const ITEMS_DIR := "res://data/items"

@export var id: StringName  # &"colada" | &"tizona"
@export var acquired_beat: StringName
@export var gifted_beat: StringName = &"a3_despedida"
@export var recovered_beat: StringName = &"a3_toledo"
@export var lists_champion: StringName

enum Phase { NOT_YET, IN_HAND, GIFTED_TO_INFANTES, IN_COURT, IN_CHAMPION_HAND }

@export var phase: Phase = Phase.NOT_YET


func lootable() -> bool:
	return false


func can_player_wield() -> bool:
	return phase == Phase.IN_HAND


func phase_name() -> String:
	match phase:
		Phase.IN_HAND:
			return "IN_HAND"
		Phase.GIFTED_TO_INFANTES:
			return "GIFTED_TO_INFANTES"
		Phase.IN_COURT:
			return "IN_COURT"
		Phase.IN_CHAMPION_HAND:
			return "IN_CHAMPION_HAND"
		_:
			return "NOT_YET"


func set_phase_name(raw: String) -> void:
	match raw:
		"IN_HAND":
			phase = Phase.IN_HAND
		"GIFTED_TO_INFANTES":
			phase = Phase.GIFTED_TO_INFANTES
		"IN_COURT":
			phase = Phase.IN_COURT
		"IN_CHAMPION_HAND":
			phase = Phase.IN_CHAMPION_HAND
		_:
			phase = Phase.NOT_YET


static func from_id(item_id: StringName) -> SwordItem:
	var stem := String(item_id)
	var path := "%s/%s.json" % [ITEMS_DIR, stem]
	if not FileAccess.file_exists(path):
		return _fallback(item_id)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fallback(item_id)
	return from_dict(parsed as Dictionary)


static func from_dict(data: Dictionary) -> SwordItem:
	var item := SwordItem.new()
	item.id = StringName(str(data.get("id", "")))
	item.acquired_beat = StringName(str(data.get("acquired_beat", "")))
	item.gifted_beat = StringName(str(data.get("gifted_beat", "a3_despedida")))
	item.recovered_beat = StringName(str(data.get("recovered_beat", "a3_toledo")))
	var champion: Variant = data.get("wielded_in_lists_by", data.get("lists_champion", ""))
	item.lists_champion = StringName(str(champion))
	item.phase = Phase.NOT_YET
	return item


static func _fallback(item_id: StringName) -> SwordItem:
	var item := SwordItem.new()
	item.id = item_id
	if item_id == &"colada":
		item.acquired_beat = &"a1_tevar"
		item.lists_champion = &"martin_antolinez"
	elif item_id == &"tizona":
		item.acquired_beat = &"a3_bucar"
		item.lists_champion = &"pero_bermudez"
	item.gifted_beat = &"a3_despedida"
	item.recovered_beat = &"a3_toledo"
	item.phase = Phase.NOT_YET
	return item
