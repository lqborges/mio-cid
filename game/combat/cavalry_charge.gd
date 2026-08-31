class_name CavalryCharge
extends Node

## Couch-lance stub. Volume lives on lance_wedge (friendly fire on).
## panic_for(shout/fire) is the later hook; it does not auto-wire kit shout.

const MOVESET_PATH := "res://data/combat/sword.json"
const LAYER_LANCE_WEDGE := 8
const LAYER_HURTBOX_KILLABLE := 4

var hit_box: HitBox = null
var moveset: WeaponMoveset = WeaponMoveset.new()
var horse: Node = null
var last_move: StringName = &""
var _couch_left: float = 0.0


func _init() -> void:
	moveset = WeaponMoveset.from_json_path(MOVESET_PATH)


func _ready() -> void:
	if horse == null:
		horse = get_parent()
	if hit_box == null:
		hit_box = _find_lance(horse)
	apply_wedge_layers()
	set_physics_process(true)


func bind_horse(body: Node) -> void:
	horse = body
	hit_box = _find_lance(horse)
	apply_wedge_layers()


func _find_lance(body: Node) -> HitBox:
	if body == null:
		return null
	var under_visual: Node = body.get_node_or_null("Visual/LanceHitBox")
	if under_visual is HitBox:
		return under_visual as HitBox
	var root_box: Node = body.get_node_or_null("LanceHitBox")
	if root_box is HitBox:
		return root_box as HitBox
	return null


func apply_wedge_layers() -> void:
	if hit_box == null:
		return
	hit_box.collision_layer = LAYER_LANCE_WEDGE
	hit_box.collision_mask = LAYER_HURTBOX_KILLABLE
	hit_box.source = horse if horse != null else self


func is_couching() -> bool:
	return _couch_left > 0.0


func couch() -> bool:
	var move := moveset.move(&"lance_couch")
	if move.is_empty():
		return false
	var cost := float(move.get("stamina", 0.0))
	if horse != null and horse.has_method("spend_stamina"):
		if not bool(horse.call("spend_stamina", cost)):
			return false
	last_move = &"lance_couch"
	_couch_left = float(move.get("duration", 0.0))
	apply_wedge_layers()
	if hit_box != null:
		hit_box.arm(
			float(move.get("damage", 0.0)),
			&"lance_couch",
			float(move.get("stagger", 0.0))
		)
	return true


func disarm() -> void:
	_couch_left = 0.0
	if hit_box != null:
		hit_box.disarm()


func dismount_hook() -> bool:
	last_move = &"dismount_hook"
	disarm()
	if horse != null and horse.has_method("dismount"):
		return bool(horse.call("dismount"))
	return false


func panic_for(reason: StringName) -> void:
	if reason != &"shout" and reason != &"fire" and reason != &"lion" and reason != &"crowd":
		return
	disarm()
	if horse != null and horse.has_method("panic"):
		horse.call("panic", reason)


func auto_couch_distance() -> float:
	if horse != null and "tunables" in horse:
		var data: Variant = horse.get("tunables")
		if data is Dictionary:
			return float((data as Dictionary).get("straight_couch_m", 0.0))
	return 0.0


func _physics_process(delta: float) -> void:
	if _couch_left <= 0.0:
		return
	if hit_box != null and hit_box.monitoring:
		hit_box.poll_overlaps()
	_couch_left = maxf(_couch_left - delta, 0.0)
	if _couch_left <= 0.0:
		if hit_box != null:
			hit_box.disarm()
