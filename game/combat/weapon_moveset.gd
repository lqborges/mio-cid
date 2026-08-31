class_name WeaponMoveset
extends Resource

## Foot-melee kit. Combos are data (≤ 3). lance_couch / dismount_hook feed CavalryCharge.

@export var id: StringName = &""
@export var max_combo: int = 0
@export var combo: PackedStringArray = []
@export var slash: Dictionary = {}
@export var thrust: Dictionary = {}
@export var shield_bash: Dictionary = {}
@export var leap: Dictionary = {}
@export var shout: Dictionary = {}
@export var lance_couch: Dictionary = {}
@export var dismount_hook: Dictionary = {}


func move(move_id: StringName) -> Dictionary:
	match move_id:
		&"slash":
			return slash
		&"thrust":
			return thrust
		&"bash", &"shield_bash":
			return shield_bash
		&"leap":
			return leap
		&"shout":
			return shout
		&"lance_couch":
			return lance_couch
		&"dismount_hook":
			return dismount_hook
		_:
			return {}


func combo_cap() -> int:
	return mini(max_combo, combo.size())


static func from_json_path(path: String) -> WeaponMoveset:
	if not FileAccess.file_exists(path):
		push_warning("WeaponMoveset: missing %s" % path)
		return WeaponMoveset.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("WeaponMoveset: %s is not one object" % path)
		return WeaponMoveset.new()
	return from_dict(parsed as Dictionary)


static func from_dict(data: Dictionary) -> WeaponMoveset:
	var ms := WeaponMoveset.new()
	ms.id = StringName(str(data.get("id", "")))
	ms.max_combo = int(data.get("max_combo", 0))
	ms.combo = _to_packed(data.get("combo", []))
	ms.slash = _to_move(data.get("slash", {}))
	ms.thrust = _to_move(data.get("thrust", {}))
	ms.shield_bash = _to_move(data.get("shield_bash", data.get("bash", {})))
	ms.leap = _to_move(data.get("leap", {}))
	ms.shout = _to_move(data.get("shout", {}))
	ms.lance_couch = _to_move(data.get("lance_couch", {}))
	ms.dismount_hook = _to_move(data.get("dismount_hook", {}))
	return ms


static func _to_move(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


static func _to_packed(raw: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for item in raw:
			out.append(str(item))
	return out
