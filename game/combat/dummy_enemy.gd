class_name DummyEnemy
extends CharacterBody3D

## Greybox fodder for the arena fps check. Capsule only; no particles, no shadows.

const TUNABLES_PATH := "res://data/combat/tunables.json"

@export var unkillable: bool = false
@export var character_id: StringName = &""

@onready var hurt_box: HurtBox = $HurtBox
@onready var mesh: MeshInstance3D = $Visual/MeshInstance3D


func _ready() -> void:
	add_to_group("combat_dummy")
	floor_snap_length = 0.25
	if mesh != null:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if character_id != &"":
		add_to_group(String(character_id))
		_apply_character()
	if unkillable:
		# Alfonso-class bodies are not valid hurtboxes.
		if hurt_box != null:
			hurt_box.unkillable = true
			hurt_box.queue_free()
			hurt_box = null
		return
	if character_id == &"":
		_load_hp()
	if hurt_box != null and not hurt_box.died.is_connected(_on_died):
		hurt_box.died.connect(_on_died)


func _apply_character() -> void:
	var member := MesnadaMember.from_id(character_id)
	if member == null:
		_load_hp()
		return
	unkillable = member.unkillable
	if member.role == &"taifa_captain":
		add_to_group("taifa_captain")
	if unkillable or hurt_box == null:
		return
	var hp := float(member.combat)
	if hp <= 0.0:
		_load_hp()
		return
	hurt_box.max_hp = hp
	hurt_box.hp = hp


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		velocity.y -= g * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if hurt_box != null and hurt_box.stagger_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _load_hp() -> void:
	if hurt_box == null:
		return
	if not FileAccess.file_exists(TUNABLES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TUNABLES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var hp := float((parsed as Dictionary).get("dummy_hp", 0.0))
	hurt_box.max_hp = hp
	hurt_box.hp = hp


func _on_died() -> void:
	collision_layer = 0
	if hurt_box != null:
		hurt_box.set_deferred("monitorable", false)
	if mesh != null:
		var mat := mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color = Color(0.28, 0.26, 0.24)
