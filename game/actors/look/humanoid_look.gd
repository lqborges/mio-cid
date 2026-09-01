extends Node3D

## Primitive portrait of a named person from the Cantar. No class_name —
## autoloads cannot see global class ids when a -s test boots.

const PORTRAITS_PATH := "res://data/look/portraits.json"
const NAME_TO_ID := {
	"Cid": "cid",
	"Jimena": "jimena",
	"Elvira": "elvira",
	"Sol": "sol",
	"Alfonso": "alfonso",
	"Alvar": "alvar_fanez",
	"AlvarFanez": "alvar_fanez",
	"Martin": "martin_antolinez",
	"MartinAntolinez": "martin_antolinez",
	"PeroBermudez": "pero_bermudez",
	"MunoGustioz": "muno_gustioz",
	"Felez": "felez_munoz",
	"FelezMunoz": "felez_munoz",
	"Ferran": "ferran_gonzalez",
	"FerranGonzalez": "ferran_gonzalez",
	"Diego": "diego_gonzalez",
	"DiegoGonzalez": "diego_gonzalez",
	"GarciaOrdonez": "garcia_ordonez",
	"Raquel": "raquel",
	"Vidas": "vidas",
	"Sisebuto": "sisebuto",
	"Jeronimo": "jeronimo",
	"Yusuf": "yusuf",
	"Bucar": "bucar",
	"Avengalvon": "avengalvon",
	"Ramon": "ramon_berenguer",
	"RamonBerenguer": "ramon_berenguer",
	"Fariz": "fariz",
	"Galve": "galve",
	"Gabriel": "gabriel",
	"BurgosChild": "burgos_child",
	"AsurGonzalez": "asur_gonzalez",
	"DiegoTellez": "diego_tellez",
}

var who_id: String = "host"
var skin: Color = Color(0.74, 0.56, 0.44)
var hair: Color = Color(0.16, 0.10, 0.06)
var cloth: Color = Color(0.28, 0.24, 0.20)
var cloak_color: Color = Color(0.20, 0.12, 0.10)
var metal: Color = Color(0.58, 0.58, 0.60)
var accent: Color = Color(0.72, 0.58, 0.22)
var leather: Color = Color(0.32, 0.22, 0.14)
var flags: Dictionary = {}


func build_for(host: Node) -> void:
	who_id = resolve_who(host)
	_apply_portrait(_portrait_for(who_id))
	_hide_placeholders(host)
	_build()
	var scale_v := float(flags.get("scale", 1.0))
	if scale_v != 1.0:
		scale = Vector3.ONE * scale_v


func tint_cloth(color: Color) -> void:
	cloth = color
	for child in get_children():
		if child is MeshInstance3D and str(child.get_meta("slot", "")) in ["cloth", "cloak", "skirt", "robe"]:
			_paint(child as MeshInstance3D, color)


static func resolve_who(host: Node) -> String:
	if host == null:
		return "host"
	var body := host
	if host.name == "Visual" and host.get_parent():
		body = host.get_parent()
	for key in ["member_id", "character_id"]:
		if key in body:
			var raw := String(body.get(key))
			if not raw.is_empty():
				return raw
	var mapped := String(NAME_TO_ID.get(String(body.name), ""))
	if not mapped.is_empty():
		return mapped
	if "kind" in body and String(body.get("kind")) == "lanza":
		return "lanza"
	if "kind" in body and String(body.get("kind")) == "captain":
		return "alvar_fanez"
	if body.is_in_group("player") or String(body.name) == "Cid":
		return "cid"
	return "host"


static func should_attach(host: Node) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	if host.get_node_or_null("Humanoid") != null:
		return false
	if host.get_node_or_null("Body") is CSGPrimitive3D:
		return false
	var probe: Node = host
	while probe:
		if probe.is_in_group("horse_companion") or String(probe.name) == "Horse":
			return false
		probe = probe.get_parent()
	for child in host.get_children():
		if child is MeshInstance3D and _is_person_capsule((child as MeshInstance3D).mesh):
			return true
	return false


static func _is_person_capsule(mesh: Mesh) -> bool:
	if not (mesh is CapsuleMesh):
		return false
	var cap := mesh as CapsuleMesh
	return cap.height >= 1.2 and cap.height <= 2.2 and cap.radius <= 0.55


func _portrait_for(id: String) -> Dictionary:
	var table: Dictionary = {}
	if FileAccess.file_exists(PORTRAITS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PORTRAITS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			table = parsed
	if table.has(id):
		return table[id]
	return table.get("host", {})


func _apply_portrait(data: Dictionary) -> void:
	skin = _col(data.get("skin"), skin)
	hair = _col(data.get("hair"), hair)
	cloth = _col(data.get("cloth"), cloth)
	cloak_color = _col(data.get("cloak_color"), cloth.darkened(0.2))
	metal = _col(data.get("metal"), metal)
	accent = _col(data.get("accent"), accent)
	flags = {
		"kit": str(data.get("kit", "lanza")),
		"beard": bool(data.get("beard", false)),
		"mail": bool(data.get("mail", false)),
		"cloak": bool(data.get("cloak", false)),
		"crown": bool(data.get("crown", false)),
		"veil": bool(data.get("veil", false)),
		"turban": bool(data.get("turban", false)),
		"mitre": bool(data.get("mitre", false)),
		"tonsure": bool(data.get("tonsure", false)),
		"robe": bool(data.get("robe", false)),
		"cap": bool(data.get("cap", false)),
		"scale": float(data.get("scale", 1.0)),
	}
	var kit := str(flags.kit)
	if kit in ["lady", "king", "clerk", "bishop", "merchant", "taifa"]:
		flags.robe = true


func _col(raw: Variant, fallback: Color) -> Color:
	if raw is Array and (raw as Array).size() >= 3:
		var a: Array = raw
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


func _build() -> void:
	var robe := bool(flags.robe)
	_part("Pelvis", _box(Vector3(0.26, 0.16, 0.16)), Vector3(0.0, 0.94, 0.0), cloth, "cloth")
	var torso_c := metal if bool(flags.mail) else cloth
	_part("Torso", _box(Vector3(0.38, 0.44, 0.22)), Vector3(0.0, 1.24, 0.02), torso_c, "cloth" if not bool(flags.mail) else "metal")
	_part("Belt", _box(Vector3(0.40, 0.06, 0.24)), Vector3(0.0, 1.02, 0.02), accent, "metal")
	_part("Neck", _cyl(0.055, 0.10), Vector3(0.0, 1.50, 0.02), skin, "skin")
	_part("Head", _sphere(0.135), Vector3(0.0, 1.64, 0.02), skin, "skin")
	_part("Nose", _box(Vector3(0.04, 0.05, 0.06)), Vector3(0.0, 1.62, -0.12), skin, "skin")
	if bool(flags.tonsure):
		_part("HairRing", _cyl(0.14, 0.05), Vector3(0.0, 1.72, 0.02), hair, "hair")
	elif bool(flags.turban):
		_part("Turban", _cyl(0.16, 0.12), Vector3(0.0, 1.76, 0.02), cloth.lightened(0.15), "cloth")
		_part("TurbanTop", _sphere(0.12), Vector3(0.0, 1.84, 0.02), cloth.lightened(0.2), "cloth")
	elif bool(flags.mitre):
		_part("Mitre", _box(Vector3(0.20, 0.22, 0.12)), Vector3(0.0, 1.84, 0.02), cloth, "cloth")
		_part("MitrePeak", _box(Vector3(0.10, 0.12, 0.08)), Vector3(0.0, 1.98, 0.02), accent, "metal")
	elif bool(flags.veil):
		_part("Hair", _sphere(0.15), Vector3(0.0, 1.68, 0.03), hair, "hair")
		_part("Veil", _box(Vector3(0.28, 0.32, 0.22)), Vector3(0.0, 1.62, 0.06), cloth.lightened(0.35), "cloth")
		_part("HairFall", _box(Vector3(0.20, 0.26, 0.10)), Vector3(0.0, 1.46, 0.12), hair, "hair")
	elif bool(flags.cap):
		_part("Hair", _sphere(0.14), Vector3(0.0, 1.68, 0.02), hair, "hair")
		_part("Cap", _cyl(0.15, 0.08), Vector3(0.0, 1.76, 0.02), cloth.darkened(0.15), "cloth")
	else:
		_part("Hair", _sphere(0.145), Vector3(0.0, 1.70, 0.03), hair, "hair")
	if bool(flags.crown):
		_part("Crown", _cyl(0.15, 0.06), Vector3(0.0, 1.78, 0.02), accent, "metal")
		_part("CrownJewel", _box(Vector3(0.05, 0.07, 0.05)), Vector3(0.0, 1.84, -0.10), Color(0.55, 0.08, 0.10), "metal")
	if bool(flags.beard):
		_part("Beard", _box(Vector3(0.16, 0.13, 0.11)), Vector3(0.0, 1.50, -0.10), hair, "hair")
	if robe:
		_part("Robe", _box(Vector3(0.46, 0.72, 0.28)), Vector3(0.0, 0.56, 0.02), cloth, "robe")
	else:
		var leg_c := cloth
		_limb("ThighL", Vector3(-0.10, 0.62, 0.01), 0.075, 0.40, leg_c, "cloth")
		_limb("ThighR", Vector3(0.10, 0.62, 0.01), 0.075, 0.40, leg_c, "cloth")
		_limb("ShinL", Vector3(-0.10, 0.24, 0.01), 0.065, 0.36, leg_c, "cloth")
		_limb("ShinR", Vector3(0.10, 0.24, 0.01), 0.065, 0.36, leg_c, "cloth")
	_part("FootL", _box(Vector3(0.10, 0.07, 0.20)), Vector3(-0.10, 0.04, -0.05), leather, "leather")
	_part("FootR", _box(Vector3(0.10, 0.07, 0.20)), Vector3(0.10, 0.04, -0.05), leather, "leather")
	_limb("ArmL", Vector3(-0.26, 1.30, 0.02), 0.055, 0.32, cloth, "cloth")
	_limb("ArmR", Vector3(0.26, 1.30, 0.02), 0.055, 0.32, cloth, "cloth")
	_limb("ForeL", Vector3(-0.28, 1.02, -0.02), 0.048, 0.30, skin, "skin")
	_limb("ForeR", Vector3(0.28, 1.02, -0.02), 0.048, 0.30, skin, "skin")
	_part("HandL", _box(Vector3(0.07, 0.07, 0.09)), Vector3(-0.28, 0.84, -0.04), skin, "skin")
	_part("HandR", _box(Vector3(0.07, 0.07, 0.09)), Vector3(0.28, 0.84, -0.04), skin, "skin")
	if bool(flags.cloak):
		_part("Cloak", _box(Vector3(0.48, 0.74, 0.12)), Vector3(0.0, 1.08, 0.16), cloak_color, "cloak")
	if bool(flags.mail):
		_part("PauldronL", _box(Vector3(0.12, 0.08, 0.16)), Vector3(-0.24, 1.44, 0.02), metal, "metal")
		_part("PauldronR", _box(Vector3(0.12, 0.08, 0.16)), Vector3(0.24, 1.44, 0.02), metal, "metal")


func _limb(node_name: String, pos: Vector3, radius: float, height: float, color: Color, slot: String) -> void:
	_part(node_name, _cyl(radius, height), pos, color, slot)


func _part(node_name: String, mesh: Mesh, pos: Vector3, color: Color, slot: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.set_meta("slot", slot)
	_paint(mi, color)
	add_child(mi)


func _paint(mi: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mi.material_override = mat


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	return mesh


func _cyl(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return mesh


func _hide_placeholders(host: Node) -> void:
	for child in host.get_children():
		if child == self:
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is CapsuleMesh:
			(child as MeshInstance3D).visible = false
		if child.name in ["FacingMarker", "Veil"] and child is GeometryInstance3D:
			(child as GeometryInstance3D).visible = false
