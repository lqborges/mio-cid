class_name HitBox
extends Area3D

## Street-melee volume. Layers: 1 world, 2 player, 3 hurtbox_killable,
## 4 lance_wedge, 5 street_melee, 6 unkillable, 7 spectator, 8 horse.
## Friendly-fire-off swings live on street_melee and mask hurtbox_killable only.

const LAYER_HURTBOX_KILLABLE := 4
const LAYER_LANCE_WEDGE := 8
const LAYER_STREET_MELEE := 16
const LAYER_UNKILLABLE := 32
const LAYER_SPECTATOR := 64
const LAYER_HORSE := 128

signal hit(hurt: HurtBox)

var source: Node = null
var damage: float = 0.0
var damage_type: StringName = &"slash"
var stagger: float = 0.0

var _struck: Dictionary = {}


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = LAYER_STREET_MELEE
	collision_mask = LAYER_HURTBOX_KILLABLE
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func arm(p_damage: float, p_type: StringName, p_stagger: float) -> void:
	damage = p_damage
	damage_type = p_type
	stagger = p_stagger
	_struck.clear()
	monitoring = true
	poll_overlaps()


func disarm() -> void:
	monitoring = false
	_struck.clear()


func poll_overlaps() -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		strike_area(area)


func strike_area(area: Area3D) -> bool:
	if area is HurtBox:
		return strike(area as HurtBox)
	return false


func strike(hurt: HurtBox) -> bool:
	if not monitoring or hurt == null or not is_instance_valid(hurt):
		return false
	if _struck.has(hurt):
		return false
	if (hurt.collision_layer & LAYER_UNKILLABLE) != 0:
		return false
	if (hurt.collision_layer & LAYER_SPECTATOR) != 0:
		return false
	if source != null and source.has_method("can_hit") and not source.can_hit(hurt):
		return false
	if not hurt.can_take_hit():
		return false
	_struck[hurt] = true
	hurt.apply_hit(damage, damage_type, stagger, source)
	hit.emit(hurt)
	return true


func _on_area_entered(area: Area3D) -> void:
	strike_area(area)
