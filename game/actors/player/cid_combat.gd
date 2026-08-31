class_name CidCombat
extends Node

## Foot melee: slam is a 3-hit slash/thrust/bash; leap hops with a hitbox;
## shout staggers a ring; weapon_swap is ignite (damage type). Unkillable
## and spectator hurtboxes are refused.

const MOVESET_PATH := "res://data/combat/sword.json"
const TUNABLES_PATH := "res://data/combat/tunables.json"
const DIFFICULTY_DIR := "res://data/difficulty"
const FAIL_COPY_PATH := "res://game/ui/fail_copy.tscn"
const YOU_FELL_PATH := "res://game/ui/you_fell.tscn"
const YOU_FELL := &"you_fell"

@export var leap_speed: float = 8.0
@export var leap_impulse: float = 4.8
@export var slam_air_velocity_y: float = -12.0

var weapon_index: int = 0
var moveset: WeaponMoveset = WeaponMoveset.new()
var tunables: Dictionary = {}
var difficulty: Dictionary = {}
var stamina: float = 0.0
var max_stamina: float = 0.0
var combo_step: int = 0
var last_move: StringName = &""
var allow_death_reload: bool = true
var player_hurt: HurtBox = null
var hit_box: HitBox = null
var shout_ring: HitBox = null
var sword_mesh: MeshInstance3D = null

var _combo_left: float = 0.0
var _attack_left: float = 0.0
var _dead: bool = false
var _spent_stamina: bool = false


func _init() -> void:
	load_tunables()


func _ready() -> void:
	_resolve_nodes()
	_wire_player_hurt()
	_apply_sword_visual()
	set_physics_process(true)


func load_tunables() -> void:
	moveset = WeaponMoveset.from_json_path(MOVESET_PATH)
	tunables = _load_json(TUNABLES_PATH)
	var diff_id := str(tunables.get("default_difficulty", "mesura"))
	difficulty = _load_json("%s/%s.json" % [DIFFICULTY_DIR, diff_id])
	max_stamina = float(tunables.get("player_stamina", 0.0))
	stamina = max_stamina


func set_difficulty(id: StringName) -> void:
	difficulty = _load_json("%s/%s.json" % [DIFFICULTY_DIR, String(id)])
	_wire_player_hurt()


func bind_hurt(hurt: HurtBox) -> void:
	player_hurt = hurt
	_wire_player_hurt()


func is_dead() -> bool:
	return _dead


func is_staggered() -> bool:
	return player_hurt != null and is_instance_valid(player_hurt) and player_hurt.stagger_left > 0.0


func is_winded() -> bool:
	return stamina <= 0.0


func try_sprint(delta: float) -> bool:
	var cost := float(tunables.get("sprint_stamina_per_sec", 0.0)) * delta
	if stamina <= 0.0:
		return false
	stamina = maxf(stamina - cost, 0.0)
	_spent_stamina = true
	return stamina > 0.0


func damage_type_for(move_id: StringName) -> StringName:
	if weapon_index == 1:
		return &"ignite"
	if move_id == &"bash":
		return &"shield_bash"
	return move_id


func can_hit(hurt: HurtBox) -> bool:
	if hurt == null or not is_instance_valid(hurt):
		return false
	if not hurt.can_take_hit():
		return false
	var node: Node = hurt
	while node != null:
		if "unkillable" in node and bool(node.get("unkillable")):
			return false
		if "spectator" in node and bool(node.get("spectator")):
			return false
		node = node.get_parent()
	return true


func try_current_hit(hurt: HurtBox) -> bool:
	if hit_box == null:
		return false
	return hit_box.strike(hurt)


func slam() -> void:
	var body := _body()
	if body != null:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		if not body.is_on_floor():
			body.velocity.y = minf(body.velocity.y, slam_air_velocity_y)
	_try_melee_combo()


func leap() -> void:
	var move := moveset.move(&"leap")
	if not _spend(float(move.get("stamina", 0.0))):
		return
	last_move = &"leap"
	_arm_hit(move, &"leap")
	_play_sfx(&"leap")
	var body := _body()
	if body == null:
		return
	var facing := Vector3(0.0, 0.0, -1.0)
	if body.has_method("facing_dir"):
		var d: Vector3 = body.facing_dir()
		d.y = 0.0
		if d.length_squared() > 0.0001:
			facing = d.normalized()
	body.velocity = facing * leap_speed + Vector3.UP * leap_impulse


func shout() -> void:
	var move := moveset.move(&"shout")
	if not _spend(float(move.get("stamina", 0.0))):
		return
	last_move = &"shout"
	if hit_box != null:
		hit_box.disarm()
	_arm_shout(move)
	_play_sfx(&"shout")


func weapon_swap() -> void:
	weapon_index = 1 - weapon_index
	# Ignite is a damage-type swap, not a second weapon model.
	if weapon_index == 1:
		_play_sfx(&"ignite")
	else:
		_play_sfx(&"sword")
	_apply_sword_visual()


func take_damage(amount: float, damage_type: StringName = &"slash", stagger: float = 0.0, source: Node = null) -> void:
	if _dead:
		return
	if player_hurt != null and is_instance_valid(player_hurt):
		player_hurt.apply_hit(amount, damage_type, stagger, source)
		return
	_on_player_died()


func _physics_process(delta: float) -> void:
	_tick_attack(delta)
	_tick_combo(delta)
	_regen(delta)
	_spent_stamina = false


func _try_melee_combo() -> void:
	var cap := moveset.combo_cap()
	if cap <= 0 or combo_step >= cap:
		return
	var move_id := StringName(moveset.combo[combo_step])
	var move := moveset.move(move_id)
	if not _spend(float(move.get("stamina", 0.0))):
		return
	combo_step += 1
	_combo_left = float(tunables.get("combo_window", 0.0))
	last_move = move_id
	if shout_ring != null:
		shout_ring.disarm()
	_arm_hit(move, move_id)
	_play_sfx(&"slam")


func _arm_hit(move: Dictionary, move_id: StringName) -> void:
	_attack_left = float(move.get("duration", 0.0))
	if hit_box == null:
		return
	hit_box.source = self
	hit_box.arm(_scaled_damage(move), damage_type_for(move_id), float(move.get("stagger", 0.0)))


func _arm_shout(move: Dictionary) -> void:
	_attack_left = float(move.get("duration", 0.0))
	if shout_ring == null:
		return
	shout_ring.source = self
	var shape_node := shout_ring.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is SphereShape3D:
		(shape_node.shape as SphereShape3D).radius = float(move.get("radius", 0.0))
	shout_ring.arm(_scaled_damage(move), &"shout", float(move.get("stagger", 0.0)))


func _scaled_damage(move: Dictionary) -> float:
	var amount := float(move.get("damage", 0.0))
	if weapon_index == 1:
		amount *= float(tunables.get("ignite_damage_mult", 1.0))
	return amount


func _spend(cost: float) -> bool:
	if _dead:
		return false
	if cost > stamina:
		return false
	stamina = maxf(stamina - cost, 0.0)
	_spent_stamina = true
	return true


func _tick_attack(delta: float) -> void:
	if _attack_left <= 0.0:
		return
	if hit_box != null and hit_box.monitoring:
		hit_box.poll_overlaps()
	if shout_ring != null and shout_ring.monitoring:
		shout_ring.poll_overlaps()
	_attack_left = maxf(_attack_left - delta, 0.0)
	if _attack_left <= 0.0:
		if hit_box != null:
			hit_box.disarm()
		if shout_ring != null:
			shout_ring.disarm()


func _tick_combo(delta: float) -> void:
	if _combo_left <= 0.0:
		return
	_combo_left = maxf(_combo_left - delta, 0.0)
	if _combo_left <= 0.0:
		combo_step = 0


func _regen(delta: float) -> void:
	if _spent_stamina or _combo_left > 0.0 or _attack_left > 0.0:
		return
	var rate := float(tunables.get("stamina_regen_per_sec", 0.0))
	rate *= float(difficulty.get("stamina_regen", 1.0))
	stamina = minf(max_stamina, stamina + rate * delta)


func _incoming() -> float:
	return float(difficulty.get("incoming", 1.0))


func _wire_player_hurt() -> void:
	if player_hurt == null or not is_instance_valid(player_hurt):
		return
	player_hurt.incoming_mult = _incoming()
	var hp := float(tunables.get("player_hp", 0.0))
	player_hurt.max_hp = hp
	if player_hurt.hp <= 0.0 or player_hurt.hp > hp:
		player_hurt.hp = hp
	if not player_hurt.died.is_connected(_on_player_died):
		player_hurt.died.connect(_on_player_died)


func _on_player_died() -> void:
	if _dead:
		return
	_dead = true
	if hit_box != null:
		hit_box.disarm()
	if shout_ring != null:
		shout_ring.disarm()
	_emit_you_fell()
	if not allow_death_reload:
		return
	var tree := _scene_tree()
	if tree == null:
		return
	if _present_you_fell(tree):
		return
	if tree.current_scene != null:
		tree.reload_current_scene()


func _emit_you_fell() -> void:
	var bus := _event_bus()
	if bus != null and bus.has_signal("hard_fail"):
		bus.hard_fail.emit(YOU_FELL)


func _present_you_fell(tree: SceneTree) -> bool:
	for path in [YOU_FELL_PATH, FAIL_COPY_PATH]:
		if not ResourceLoader.exists(path):
			continue
		var packed: Resource = load(path)
		if not (packed is PackedScene):
			continue
		var ui: Node = (packed as PackedScene).instantiate()
		if ui.has_method("present"):
			ui.call("present", YOU_FELL)
		tree.root.add_child(ui)
		return true
	return false


func _scene_tree() -> SceneTree:
	# get_tree() errors when the node is not in a tree (headless unit tests).
	if is_inside_tree():
		return get_tree()
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null


func _event_bus() -> Node:
	var tree := _scene_tree()
	if tree != null:
		return tree.root.get_node_or_null("EventBus")
	return null


func _play_sfx(sfx_id: StringName) -> void:
	var tree := _scene_tree()
	if tree == null:
		return
	var audio := tree.root.get_node_or_null("AudioService")
	if audio != null and audio.has_method("play_sfx_id"):
		audio.call("play_sfx_id", String(sfx_id))


func _resolve_nodes() -> void:
	var body := _body()
	if body == null:
		return
	var visual := body.get_node_or_null("Visual")
	if visual != null:
		hit_box = visual.get_node_or_null("HitBox") as HitBox
		sword_mesh = visual.get_node_or_null("Sword") as MeshInstance3D
	if player_hurt == null:
		player_hurt = body.get_node_or_null("HurtBox") as HurtBox
	shout_ring = body.get_node_or_null("ShoutRing") as HitBox
	if hit_box != null:
		hit_box.source = self
		if not hit_box.hit.is_connected(_on_weapon_hit):
			hit_box.hit.connect(_on_weapon_hit)
	if shout_ring != null:
		shout_ring.source = self


func _on_weapon_hit(_hurt: HurtBox) -> void:
	_play_sfx(&"sword")


func _apply_sword_visual() -> void:
	if sword_mesh == null:
		return
	var mat := sword_mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		var steel := Color(0.55, 0.55, 0.58)
		var fire := Color(0.85, 0.35, 0.08)
		(mat as StandardMaterial3D).albedo_color = fire if weapon_index == 1 else steel


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _body() -> CharacterBody3D:
	return get_parent() as CharacterBody3D
