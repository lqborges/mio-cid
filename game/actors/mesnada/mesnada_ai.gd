class_name MesnadaAI
extends Node3D

## Named captains follow Cid in an isometric wedge. Unnamed lanzas are a
## roster count plus cheap bodies. NavigationAgent is used when a region
## exists; otherwise steer to the slot on XZ (no bake).

const TUNABLES_PATH := "res://data/mesnada/follow.json"
const CAPTAIN_SCENE_PATH := "res://content/art/characters/captain/captain.tscn"
const LANZA_SCENE_PATH := "res://content/art/characters/lanza/lanza.tscn"
const FOLLOWER := preload("res://game/actors/mesnada/mesnada_follower.gd")

@export var leader_path: NodePath = NodePath("../Cid")
@export var spawn_missing_captains: bool = false
@export var spawn_lanza_bodies: bool = true
@export var lanza_body_limit: int = -1

var tunables: Dictionary = {}
var roster: MesnadaRoster = null
var leader: Node3D
var formation: StringName = &"follow"
var order: StringName = &"follow"
var banner_position: Vector3 = Vector3.ZERO
var banner_facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var captains: Array = []
var lanzas: Array = []

var _banner: Node3D
var _fallback_facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var _started: bool = false


func _init() -> void:
	load_tunables()


func _enter_tree() -> void:
	start_mesnada()


func _ready() -> void:
	start_mesnada()


func start_mesnada() -> void:
	if _started:
		return
	_started = true
	if tunables.is_empty():
		load_tunables()
	add_to_group("mesnada_ai")
	_banner = get_node_or_null("Banner")
	if _banner != null:
		_banner.visible = formation == &"wedge"
	_collect_existing()
	_resolve_leader()
	_resolve_roster()
	if spawn_missing_captains:
		_spawn_missing_captains()
	if spawn_lanza_bodies:
		_sync_lanza_bodies()
	_assign_slots()
	ensure_navigation_plane()
	apply_lod()
	_connect_bus()


func load_tunables() -> void:
	tunables = {}
	if not FileAccess.file_exists(TUNABLES_PATH):
		push_warning("MesnadaAI: missing %s" % TUNABLES_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TUNABLES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MesnadaAI: %s is not one object" % TUNABLES_PATH)
		return
	tunables = parsed as Dictionary


func bind_roster(next: MesnadaRoster) -> void:
	roster = next
	if roster != null:
		if spawn_missing_captains:
			_spawn_missing_captains()
		_sync_lanza_bodies()
		_assign_slots()


func set_leader(node: Node3D) -> void:
	leader = node


func set_leader_facing(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0001:
		_fallback_facing = flat.normalized()


func register_follower(body: Node) -> void:
	if body == null or not is_instance_valid(body) or not body.has_method("bind_ai"):
		return
	var kind := str(body.get("kind"))
	var is_captain := body.is_in_group("mesnada_captain") or kind == "captain"
	if is_captain:
		if not captains.has(body):
			captains.append(body)
	elif not lanzas.has(body):
		lanzas.append(body)
	body.bind_ai(self)


func plant_banner_at(pos: Vector3, facing: Vector3) -> void:
	formation = &"wedge"
	banner_position = pos
	set_leader_facing(facing)
	banner_facing = _fallback_facing
	_place_banner()


func plant_banner_at_leader() -> void:
	var origin := _leader_position()
	plant_banner_at(origin, leader_facing())


func clear_banner() -> void:
	formation = &"follow"
	if _banner != null:
		_banner.visible = false


func set_order(next: StringName) -> void:
	match next:
		&"charge", &"hold", &"flee", &"follow":
			order = next
		_:
			order = &"follow"


func skinned_cap() -> int:
	return int(tunables.get("skinned_cap", 0))


func visible_lanza_body_cap() -> int:
	var cap := int(tunables.get("visible_lanza_bodies", 0))
	if lanza_body_limit >= 0:
		return mini(cap, lanza_body_limit)
	return cap


func lanza_count() -> int:
	if roster != null:
		return int(roster.lanzas)
	return 0


func lod_level(distance: float, kind: StringName, skinned_used: int) -> StringName:
	var impostor_d := float(tunables.get("impostor_distance", 0.0))
	if impostor_d > 0.0 and distance >= impostor_d:
		return &"hidden"
	var lod_d := float(tunables.get("lod_distance", 0.0))
	if kind == &"captain" and skinned_used < skinned_cap() and (lod_d <= 0.0 or distance < lod_d):
		return &"skinned"
	return &"capsule"


func wedge_local_offset(index: int) -> Vector3:
	var i := maxi(index, 0)
	var row := 0
	var consumed := 0
	var depth := float(tunables.get("wedge_row_depth", 0.0))
	var width := float(tunables.get("wedge_row_width", 0.0))
	while i >= consumed + row + 1:
		consumed += row + 1
		row += 1
	var row_count := row + 1
	var i_in_row := i - consumed
	var lateral := (float(i_in_row) - float(row_count - 1) * 0.5) * width
	return Vector3(lateral, 0.0, float(row) * depth)


func world_slot(index: int) -> Vector3:
	return world_slot_from(index, formation_origin(), formation_facing())


func world_slot_from(index: int, origin: Vector3, facing: Vector3) -> Vector3:
	var local := wedge_local_offset(index)
	var fwd := Vector3(facing.x, 0.0, facing.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0.0, 0.0, -1.0)
	else:
		fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	return origin + right * local.x + (-fwd) * local.z


func formation_origin() -> Vector3:
	if formation == &"wedge":
		return banner_position
	return _leader_position() - leader_facing() * float(tunables.get("follow_distance", 0.0))


func formation_facing() -> Vector3:
	if formation == &"wedge":
		return banner_facing
	return leader_facing()


func leader_facing() -> Vector3:
	if leader != null and is_instance_valid(leader) and leader.has_method("facing_dir"):
		var dir: Variant = leader.call("facing_dir")
		if dir is Vector3:
			var flat := Vector3((dir as Vector3).x, 0.0, (dir as Vector3).z)
			if flat.length_squared() > 0.0001:
				return flat.normalized()
	if leader is Node3D and is_instance_valid(leader) and (leader as Node3D).is_inside_tree():
		var b: Vector3 = -(leader as Node3D).global_transform.basis.z
		b.y = 0.0
		if b.length_squared() > 0.0001:
			return b.normalized()
	return _fallback_facing


func charge_point() -> Vector3:
	return formation_origin() + formation_facing() * float(tunables.get("follow_distance", 0.0))


func flee_origin() -> Vector3:
	return formation_origin() - formation_facing() * float(tunables.get("flee_distance", 0.0))


func flee_slot(index: int) -> Vector3:
	return world_slot_from(index, flee_origin(), formation_facing())


func order_speed() -> float:
	match order:
		&"charge":
			return float(tunables.get("charge_speed", 0.0))
		&"flee":
			return float(tunables.get("flee_speed", 0.0))
		_:
			return float(tunables.get("walk_speed", 0.0))


func follow_speed(error: float) -> float:
	var threshold := float(tunables.get("catch_up_distance", 0.0))
	if threshold > 0.0 and error > threshold:
		return float(tunables.get("catch_up_speed", 0.0))
	return float(tunables.get("walk_speed", 0.0))


func speed_for(body: Node) -> float:
	match order:
		&"charge":
			return float(tunables.get("charge_speed", 0.0))
		&"flee":
			return float(tunables.get("flee_speed", 0.0))
		&"hold":
			return float(tunables.get("walk_speed", 0.0))
		_:
			return follow_speed(_slot_error(body))


func living_captains() -> Array:
	return _living(captains)


func living_lanzas() -> Array:
	return _living(lanzas)


func slot_index_for(body: Node) -> int:
	if body == null:
		return 0
	var slot := 0
	for cap in living_captains():
		if cap == body:
			return slot
		slot += 1
	for lan in living_lanzas():
		if lan == body:
			return slot
		slot += 1
	return int(body.get("slot_index"))


func apply_lod() -> void:
	var origin := _leader_position()
	var used := 0
	for body in captains:
		if body == null or not is_instance_valid(body) or body.gone:
			continue
		var level := lod_level(origin.distance_to(_body_position(body)), &"captain", used)
		if level == &"skinned":
			used += 1
		body.set_lod(level)
	for body in lanzas:
		if body == null or not is_instance_valid(body) or body.gone:
			continue
		body.set_lod(lod_level(origin.distance_to(_body_position(body)), &"lanza", used))


func ensure_navigation_plane() -> void:
	if not is_inside_tree():
		return
	var region := _find_nav_region()
	if region == null:
		return
	var mesh: NavigationMesh = region.navigation_mesh
	if mesh != null and mesh.get_polygon_count() > 0:
		return
	mesh = NavigationMesh.new()
	var half := float(tunables.get("nav_plane_half", 0.0))
	var y := float(tunables.get("nav_plane_y", 0.0))
	mesh.vertices = PackedVector3Array([
		Vector3(-half, y, -half),
		Vector3(half, y, -half),
		Vector3(half, y, half),
		Vector3(-half, y, half),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	mesh.add_polygon(PackedInt32Array([0, 2, 3]))
	region.navigation_mesh = mesh


func plant_banner_prompt() -> String:
	var loc := _loc()
	if loc != null and loc.has_method("text"):
		return str(loc.text("mesnada.plant_banner"))
	return "mesnada.plant_banner"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("plant_banner"):
		return
	if formation == &"wedge":
		clear_banner()
	else:
		plant_banner_at_leader()
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	apply_lod()


func _make_follower(kind: StringName, member_id: StringName) -> Node:
	var path := CAPTAIN_SCENE_PATH if kind == &"captain" else LANZA_SCENE_PATH
	var packed: Resource = load(path)
	var body: Node
	if packed is PackedScene:
		body = (packed as PackedScene).instantiate()
	else:
		body = FOLLOWER.new()
	body.set("kind", kind)
	if member_id != &"":
		body.set("member_id", member_id)
	return body


func _collect_existing() -> void:
	for child in get_children():
		if child.has_method("bind_ai"):
			register_follower(child)


func _resolve_leader() -> void:
	if leader != null and is_instance_valid(leader):
		return
	if not leader_path.is_empty() and has_node(leader_path):
		var node := get_node(leader_path)
		if node is Node3D:
			leader = node as Node3D
			return
	var parent := get_parent()
	if parent != null:
		var named: Node = parent.get_node_or_null("Cid")
		if named is Node3D:
			leader = named as Node3D
			return
	var tree := get_tree()
	if tree != null:
		var grouped: Node = tree.get_first_node_in_group("player")
		if grouped is Node3D:
			leader = grouped as Node3D


func _resolve_roster() -> void:
	if _roster_usable(roster):
		return
	var existing: Variant = null
	var state := _autoload("GameState")
	if state != null and state.has_method("roster"):
		existing = state.roster()
	if _roster_usable(existing):
		roster = existing as MesnadaRoster
		return
	roster = MesnadaRoster.from_starting_seed()
	var honor := _autoload("HonorService")
	if honor != null and not _roster_usable(honor.get("roster")):
		honor.roster = roster


func _roster_usable(value: Variant) -> bool:
	if not (value is MesnadaRoster):
		return false
	var next: MesnadaRoster = value as MesnadaRoster
	if next.members.size() > 0:
		return true
	return int(next.lanzas) > 0


func _spawn_missing_captains() -> void:
	if roster == null:
		return
	var have: Dictionary = {}
	for body in captains:
		if body != null:
			have[String(body.get("member_id"))] = true
	for member in roster.members:
		if member == null:
			continue
		if not member.alive:
			continue
		if str(member.role) != "captain":
			continue
		if have.has(String(member.id)):
			continue
		var body := _make_follower(&"captain", member.id)
		add_child(body)
		register_follower(body)
		have[String(member.id)] = true


func _sync_lanza_bodies() -> void:
	if not spawn_lanza_bodies:
		return
	var want := mini(lanza_count(), visible_lanza_body_cap())
	while lanzas.size() < want:
		var body := _make_follower(&"lanza", &"")
		add_child(body)
		register_follower(body)
	while lanzas.size() > want:
		var extra: Node = lanzas.pop_back()
		if extra != null and is_instance_valid(extra):
			if extra.has_method("mark_gone"):
				extra.mark_gone()
			extra.queue_free()


func _assign_slots() -> void:
	_sort_captains_by_roster()
	for body in captains:
		if body == null:
			continue
		if roster != null:
			body.member = roster.member(body.get("member_id"))
			if body.member != null and not body.member.alive:
				body.mark_gone()
	var slot := 0
	for body in captains:
		if not _is_live(body):
			continue
		body.slot_index = slot
		slot += 1
	for body in lanzas:
		if not _is_live(body):
			continue
		body.slot_index = slot
		slot += 1


func _sort_captains_by_roster() -> void:
	if roster == null:
		return
	var order_ids: Array[StringName] = []
	for member in roster.members:
		if member != null and member.role == &"captain":
			order_ids.append(member.id)
	captains.sort_custom(func(a: Node, b: Node) -> bool:
		return order_ids.find(a.get("member_id")) < order_ids.find(b.get("member_id"))
	)


func _leader_position() -> Vector3:
	if leader is Node3D and is_instance_valid(leader):
		var node := leader as Node3D
		if node.is_inside_tree():
			return node.global_position
		return node.position
	if is_inside_tree():
		return global_position
	return position


func _place_banner() -> void:
	if _banner == null:
		_banner = get_node_or_null("Banner")
	if _banner == null:
		return
	_banner.visible = true
	_banner.global_position = banner_position
	var look := banner_position + banner_facing
	look.y = banner_position.y
	if not look.is_equal_approx(banner_position):
		_banner.look_at(look, Vector3.UP)


func handle_desertion(character_id: StringName) -> void:
	for body in captains:
		if body == null or not is_instance_valid(body):
			continue
		if body.get("member_id") == character_id or str(body.get("member_id")) == String(character_id):
			body.mark_gone()
	_assign_slots()


func _is_live(body: Variant) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if bool(body.get("gone")):
		return false
	var member: Variant = body.get("member")
	if member != null and member.get("alive") == false:
		return false
	return true


func _living(bodies: Array) -> Array:
	var out: Array = []
	for body in bodies:
		if _is_live(body):
			out.append(body)
	return out


func _body_position(body: Variant) -> Vector3:
	if body is Node3D and is_instance_valid(body):
		var node := body as Node3D
		if node.is_inside_tree():
			return node.global_position
		return node.position
	return Vector3.ZERO


func _slot_error(body: Node) -> float:
	if body == null or not is_instance_valid(body):
		return 0.0
	var delta := world_slot(slot_index_for(body)) - _body_position(body)
	delta.y = 0.0
	return delta.length()


func _connect_bus() -> void:
	var bus := _event_bus()
	if bus == null or not bus.has_signal("member_deserted"):
		return
	if not bus.member_deserted.is_connected(handle_desertion):
		bus.member_deserted.connect(handle_desertion)


func _event_bus() -> Node:
	return _autoload("EventBus")


func _loc() -> Node:
	return _autoload("Loc")


func _autoload(node_name: String) -> Node:
	var tree := Engine.get_main_loop()
	if tree == null or not (tree is SceneTree):
		return null
	return (tree as SceneTree).root.get_node_or_null(NodePath(node_name))


func _find_nav_region() -> NavigationRegion3D:
	var parent := get_parent()
	if parent != null:
		var sibling: Node = parent.get_node_or_null("NavigationRegion3D")
		if sibling is NavigationRegion3D:
			return sibling as NavigationRegion3D
	if is_inside_tree():
		var found := get_tree().get_first_node_in_group("mesnada_nav")
		if found is NavigationRegion3D:
			return found as NavigationRegion3D
	return null
