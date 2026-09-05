class_name HurtBox
extends Area3D

## Valid target volume. Unkillable (Alfonso, Jimena, …) and spectator
## (Cid at a3_carrion) must not receive a killable HurtBox.

const Feel := preload("res://game/combat/combat_feel.gd")

const LAYER_PLAYER := 2
const LAYER_HURTBOX_KILLABLE := 4
const LAYER_UNKILLABLE := 32
const LAYER_SPECTATOR := 64

signal damaged(amount: float, damage_type: StringName, stagger: float, source: Node)
signal died

@export var unkillable: bool = false
@export var spectator: bool = false
@export var max_hp: float = 0.0
@export var hp: float = 0.0

var incoming_mult: float = 1.0
var stagger_left: float = 0.0


func _ready() -> void:
	monitoring = false
	_apply_collision()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if stagger_left > 0.0:
		stagger_left = maxf(stagger_left - delta, 0.0)


func _apply_collision() -> void:
	if unkillable:
		# Layer 6 exists so bodies can stand in the world; they are not a hurtbox.
		collision_layer = LAYER_UNKILLABLE
		collision_mask = 0
		monitorable = false
		monitoring = false
		return
	if spectator:
		collision_layer = LAYER_SPECTATOR
		collision_mask = 0
		monitorable = false
		monitoring = false
		return
	if collision_layer != LAYER_PLAYER:
		collision_layer = LAYER_HURTBOX_KILLABLE
	collision_mask = 0
	monitorable = true
	monitoring = false


func can_take_hit() -> bool:
	if unkillable or spectator:
		return false
	if (collision_layer & LAYER_UNKILLABLE) != 0:
		return false
	if (collision_layer & LAYER_SPECTATOR) != 0:
		return false
	if not monitorable:
		return false
	return hp > 0.0


func apply_hit(amount: float, damage_type: StringName, stagger: float, source: Node) -> bool:
	if not can_take_hit():
		return false
	var dealt := maxf(amount, 0.0) * incoming_mult
	hp = maxf(hp - dealt, 0.0)
	stagger_left = maxf(stagger_left, stagger)
	damaged.emit(dealt, damage_type, stagger, source)
	Feel.note_hit(self, dealt, source)
	if hp <= 0.0:
		died.emit()
	return true
