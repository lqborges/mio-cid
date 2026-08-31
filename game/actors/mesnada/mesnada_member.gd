class_name MesnadaMember
extends Resource

## Named person. Runtime loyalty lives here; JSON seed uses loyalty_0.

@export var id: StringName
@export var display_name_key: StringName
@export var poem_formula_key: StringName
@export var role: StringName
@export var combat: float
@export var birth: float
@export var diplomacy: float
@export var mesura_max: float
@export var loyalty: float
@export var gift_bias: StringName
@export var alive: bool = true
@export var essential: bool = false
@export var desertion_capable: bool = false
@export var unkillable: bool = false
@export var list_eligible: bool = false
@export var list_index: int = -1
@export var recruitable_beat: StringName = &""
@export var must_survive_until: StringName = &""
@export var vo_id: StringName = &""
@export var will_swear_riepto: bool = true


func receive_gift(value_marks: float, public: bool) -> void:
	loyalty = clampf(
		loyalty + value_marks * 0.002 + (0.04 if public else 0.0),
		0.0,
		1.0
	)


func tick_starvation(onores: float, unfed_loyalty_delta: float) -> bool:
	if not desertion_capable:
		return false
	if onores > 5.0:
		return false
	# economy.json stores a signed sink; subtract magnitude so −0.20 still drops.
	loyalty -= absf(unfed_loyalty_delta)
	return loyalty < 0.15


static func from_id(character_id: StringName) -> MesnadaMember:
	var stem := String(character_id)
	var tres_path := "res://data/characters/%s.tres" % stem
	if ResourceLoader.exists(tres_path):
		var res: Resource = load(tres_path)
		if res is MesnadaMember:
			return (res as MesnadaMember).duplicate(true) as MesnadaMember
	return from_json_path("res://data/characters/%s.json" % stem)


static func from_json_path(path: String) -> MesnadaMember:
	if not FileAccess.file_exists(path):
		push_error("MesnadaMember: missing %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MesnadaMember: %s is not one object" % path)
		return null
	return from_dict(parsed as Dictionary)


static func from_dict(data: Dictionary) -> MesnadaMember:
	var m := MesnadaMember.new()
	m.id = StringName(str(data.get("id", "")))
	m.display_name_key = StringName(str(data.get("display_name_key", "")))
	m.poem_formula_key = StringName(str(data.get("poem_formula_key", "")))
	m.role = StringName(str(data.get("role", "")))
	m.combat = float(data.get("combat", 0.0))
	m.birth = float(data.get("birth", 0.0))
	m.diplomacy = float(data.get("diplomacy", 0.0))
	m.mesura_max = float(data.get("mesura_max", 0.0))
	m.loyalty = float(data.get("loyalty_0", 0.0))
	m.gift_bias = StringName(str(data.get("gift_bias", "")))
	m.essential = bool(data.get("essential", false))
	m.desertion_capable = bool(data.get("desertion_capable", false))
	m.unkillable = bool(data.get("unkillable", false))
	m.list_eligible = bool(data.get("list_eligible", false))
	m.list_index = int(data.get("list_index", -1))
	m.recruitable_beat = StringName(str(data.get("recruitable_beat", "")))
	var until: Variant = data.get("must_survive_until", "")
	m.must_survive_until = &"" if until == null else StringName(str(until))
	m.vo_id = StringName(str(data.get("vo_id", data.get("id", ""))))
	m.alive = true
	m.will_swear_riepto = true
	return m
