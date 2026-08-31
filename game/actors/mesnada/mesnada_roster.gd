class_name MesnadaRoster
extends Resource

## Named knights the player feeds. Unnamed lanzas are a count, not rows.

const CHARACTERS_DIR := "res://data/characters"
const STARTING_IDS: Array[StringName] = [
	&"alvar_fanez",
	&"martin_antolinez",
	&"pero_bermudez",
	&"muno_gustioz",
	&"felez_munoz",
]

@export var members: Array[MesnadaMember] = []
@export var lanzas: int = 12


func member(character_id: StringName) -> MesnadaMember:
	for m in members:
		if m != null and m.id == character_id:
			return m
	return null


func add_member(m: MesnadaMember) -> void:
	if m == null:
		return
	if member(m.id) != null:
		return
	members.append(m)


func gift_to(character_id: StringName, value_marks: float, public: bool) -> void:
	var m := member(character_id)
	if m == null or not m.alive:
		return
	m.receive_gift(value_marks, public)


func tick_starvation(onores: float, unfed_loyalty_delta: float) -> PackedStringArray:
	var deserted := PackedStringArray()
	for m in members:
		if m == null or not m.alive:
			continue
		if m.tick_starvation(onores, unfed_loyalty_delta):
			# Graves stay in the array so lists and save still see the id.
			m.alive = false
			deserted.append(String(m.id))
			_emit_deserted(m.id)
	return deserted


func living_named_captains() -> int:
	var n := 0
	for m in members:
		if m != null and m.alive and m.role == &"captain":
			n += 1
	return n


func loyalty_avg() -> float:
	var total := 0.0
	var n := 0
	for m in members:
		if m != null and m.alive:
			total += m.loyalty
			n += 1
	return total / float(n) if n > 0 else 0.0


func to_save() -> Array:
	var out: Array = []
	for m in members:
		if m == null:
			continue
		out.append({
			"id": String(m.id),
			"loyalty": m.loyalty,
			"alive": m.alive,
			"will_swear_riepto": m.will_swear_riepto,
		})
	return out


static func from_starting_seed() -> MesnadaRoster:
	var roster := MesnadaRoster.new()
	for character_id in STARTING_IDS:
		roster.add_member(MesnadaMember.from_id(character_id))
	return roster


static func load_all_characters() -> Array[MesnadaMember]:
	var out: Array[MesnadaMember] = []
	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir == null:
		push_error("MesnadaRoster: missing %s" % CHARACTERS_DIR)
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			var loaded := MesnadaMember.from_json_path("%s/%s" % [CHARACTERS_DIR, name])
			if loaded != null:
				out.append(loaded)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _emit_deserted(character_id: StringName) -> void:
	var tree := Engine.get_main_loop()
	if tree == null or not (tree is SceneTree):
		return
	var bus: Node = (tree as SceneTree).root.get_node_or_null(NodePath("EventBus"))
	if bus != null:
		bus.member_deserted.emit(character_id)
