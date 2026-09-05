class_name DummyEnemy
extends CharacterBody3D

## Greybox fodder for the arena fps check. Capsule only; no particles, no shadows.

const TUNABLES_PATH := "res://data/combat/tunables.json"
const ROLES_PATH := "res://data/combat/roles.json"

@export var unkillable: bool = false
@export var character_id: StringName = &""

@onready var hurt_box: HurtBox = $HurtBox
@onready var mesh: MeshInstance3D = $Visual/MeshInstance3D


func _ready() -> void:
	add_to_group("combat_dummy")
	floor_snap_length = 0.25
	var looks := get_tree().root.get_node_or_null("HumanoidLooks") if is_inside_tree() else null
	if looks and looks.has_method("ensure"):
		looks.call("ensure", self)
	if mesh != null:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stash_live()
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


func revive() -> void:
	# Second (and later) sallies need a living Host; death greys the mesh and zeros layers.
	if unkillable:
		return
	_stash_live()
	collision_layer = int(get_meta("live_layer"))
	if hurt_box != null:
		if hurt_box.max_hp <= 0.0:
			_load_hp()
		hurt_box.hp = hurt_box.max_hp
		hurt_box.stagger_left = 0.0
		hurt_box._apply_collision()
	if mesh != null and has_meta("live_albedo"):
		var mat := mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color = get_meta("live_albedo")
		var humanoid := get_node_or_null("Visual/Humanoid")
		if humanoid and humanoid.has_method("tint_cloth"):
			humanoid.call("tint_cloth", get_meta("live_albedo"))


func _stash_live() -> void:
	if not has_meta("live_layer"):
		set_meta("live_layer", collision_layer)
	if mesh == null or has_meta("live_albedo"):
		return
	var mat := mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		set_meta("live_albedo", (mat as StandardMaterial3D).albedo_color)


func _apply_character() -> void:
	var member := MesnadaMember.from_id(character_id)
	if member == null:
		_load_hp()
		return
	unkillable = member.unkillable
	if member.role == &"taifa_captain":
		add_to_group("taifa_captain")
	_apply_role(String(member.role))
	if unkillable or hurt_box == null:
		return
	var hp := float(member.combat)
	if hp <= 0.0:
		_load_hp()
		return
	hurt_box.max_hp = hp
	hurt_box.hp = hp


func _apply_role(role_id: String) -> void:
	var mapped := role_id
	if mapped == "taifa_captain":
		mapped = "captain"
	if mapped.is_empty() or not FileAccess.file_exists(ROLES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROLES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var row: Variant = (parsed as Dictionary).get(mapped, {})
	if typeof(row) != TYPE_DICTIONARY:
		return
	var data: Dictionary = row
	var scale_v := float(data.get("scale", 1.0))
	if scale_v != 1.0:
		scale = Vector3.ONE * scale_v
	var cloth: Variant = data.get("cloth", [])
	if cloth is Array and (cloth as Array).size() >= 3:
		var a: Array = cloth
		var color := Color(float(a[0]), float(a[1]), float(a[2]))
		set_meta("live_albedo", color)
		var humanoid := get_node_or_null("Visual/Humanoid")
		if humanoid and humanoid.has_method("tint_cloth"):
			humanoid.call("tint_cloth", color)


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
	_stash_live()
	collision_layer = 0
	if hurt_box != null:
		hurt_box.set_deferred("monitorable", false)
	if mesh != null:
		var mat := mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			var local := mat.duplicate() as StandardMaterial3D
			local.albedo_color = Color(0.28, 0.26, 0.24)
			mesh.set_surface_override_material(0, local)
	var humanoid := get_node_or_null("Visual/Humanoid")
	if humanoid and humanoid.has_method("tint_cloth"):
		humanoid.call("tint_cloth", Color(0.28, 0.26, 0.24))
