class_name CidCombat
extends Node

## Input slots for the isometric kit. Hitboxes / Hunger / movesets are PR-12.

@export var leap_speed: float = 8.0
@export var leap_impulse: float = 4.8
@export var slam_air_velocity_y: float = -12.0

var weapon_index: int = 0


func slam() -> void:
	var body := _body()
	if body == null:
		return
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	if not body.is_on_floor():
		body.velocity.y = minf(body.velocity.y, slam_air_velocity_y)


func leap() -> void:
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
	pass


func weapon_swap() -> void:
	weapon_index = 1 - weapon_index


func _body() -> CharacterBody3D:
	return get_parent() as CharacterBody3D
