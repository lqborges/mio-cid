extends Node3D
## a3_bucar: Valencia shore. Infantes flee, captains cover, Tizona in hand.

const BEAT_ID := &"a3_bucar"
const DEST := &"a3_despedida"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const BUCAR_ID := &"bucar"
const TIZONA_ID := &"tizona"
const WIN_EVENT := &"bucar_win"
const BATTLE_KEY := "a3_bucar.battle"
const FLEE_KEY := "a3_bucar.flee"
const COVER_KEY := "a3_bucar.cover"
const WIN_KEY := "a3_bucar.win"
const TIZONA_KEY := "a3_bucar.tizona_kept"
const PLACE_KEY := "a3_bucar.place_name"
const DIALOGUE_PATH := "res://content/chapters/a3_bucar/bucar.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DEST_SCENE := "res://content/chapters/a3_despedida/world.tscn"

var tizona: SwordItem
var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var _battle_started: bool = false
var _fled: bool = false
var _covered: bool = false
var _won: bool = false
var _win_started: bool = false
var _talking: bool = false
var _left: bool = false
var _ferran_cover: Vector3 = Vector3.ZERO
var _diego_cover: Vector3 = Vector3.ZERO


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if ChapterRunner and ChapterRunner.has_method("add_flag"):
		ChapterRunner.add_flag(HORSE_FLAG)
		if ChapterRunner.has_method("has_flag") and not bool(ChapterRunner.has_flag(HUB_LOCK)):
			ChapterRunner.add_flag(String(HUB_LOCK))
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_ensure_roster()
	_bind_mesnada()
	_hide_plazo_bar()
	_ensure_tizona()
	_bind_bucar()
	_connect_host()
	_connect_battle_zone()
	_cache_cover_marks()
	_show_place_name()
	_name_horse()
	_label_people()
	_whisper(BATTLE_KEY)


func start_battle(_cue: String = "battle") -> void:
	if _battle_started or _won:
		return
	_battle_started = true
	_form_wedge()
	_whisper(BATTLE_KEY)
	start_flee()


func run_battle() -> void:
	# Headless: open the shore fight without walking BattleZone.
	start_battle()


func start_flee(_cue: String = "flee") -> void:
	if _fled or _won:
		return
	_battle_started = true
	_fled = true
	_hide_infantes()
	_set_flag(&"infantes_fled_bucar")
	_whisper(FLEE_KEY)
	start_cover()


func run_flee() -> void:
	if not _battle_started:
		start_battle()
		return
	start_flee()


func start_cover(_cue: String = "cover") -> void:
	if _covered or _won:
		return
	if not _fled:
		start_flee()
		return
	_covered = true
	_place_captains_cover()
	_set_flag(&"captains_covered_bucar")
	_whisper(COVER_KEY)


func run_cover() -> void:
	if not _fled:
		run_flee()
		return
	start_cover()


func start_cue(cue: String) -> void:
	if cue == "battle" or cue == "dawn":
		start_battle()
	elif cue == "flee":
		start_flee()
	elif cue == "cover":
		start_cover()
	elif cue == "win":
		start_win()


func run_win() -> void:
	# Headless: skip-cinematic Tizona so same-frame tests can assert IN_HAND.
	if not _battle_started:
		run_battle()
	_win_started = true
	_finish_win()


func start_win(_cue: String = "win") -> void:
	if _won or _win_started:
		return
	if not _battle_started:
		run_battle()
	_win_started = true
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_finish_win()
		return
	if _try_balloon(resource, "win"):
		return
	await _walk_lines(resource, "win")
	_talking = false
	_finish_win()


func _finish_win() -> void:
	if _won:
		return
	_won = true
	if not _fled:
		start_flee()
	_hold_mesnada()
	_disable_host()
	_apply_honor(WIN_EVENT)
	_acquire_tizona()
	_set_flag(&"tizona_acquired")
	_whisper(TIZONA_KEY)
	_leave_for_despedida()


func try_travel_despedida() -> bool:
	if not _won:
		return false
	if not _dest_ready():
		return false
	return _travel(DEST)


func can_leave_to_despedida() -> bool:
	if not _won:
		return false
	return _can_travel(DEST)


func _leave_for_despedida() -> void:
	if EventBus and EventBus.has_signal("beat_completed"):
		EventBus.beat_completed.emit(BEAT_ID)
	_checkpoint()
	if not _dest_ready():
		return
	_travel(DEST)


func _dest_ready() -> bool:
	return ResourceLoader.exists(DEST_SCENE)


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


func _acquire_tizona() -> void:
	_ensure_tizona()
	if tizona == null:
		return
	tizona.phase = SwordItem.Phase.IN_HAND


func _ensure_tizona() -> void:
	if tizona != null:
		return
	if GameState and GameState.has_method("sword"):
		tizona = GameState.sword(TIZONA_ID)
	if tizona == null:
		tizona = SwordItem.from_id(TIZONA_ID)


func _bind_bucar() -> void:
	var bucar: Node = _bucar()
	if bucar == null:
		return
	if "character_id" in bucar and String(bucar.get("character_id")) == "":
		bucar.set("character_id", BUCAR_ID)
	var member := MesnadaMember.from_id(BUCAR_ID)
	if member and "unkillable" in bucar:
		bucar.unkillable = member.unkillable
	var hurt: Node = bucar.get_node_or_null("HurtBox")
	if hurt and hurt.has_signal("died") and not hurt.died.is_connected(_on_bucar_died):
		hurt.died.connect(_on_bucar_died)


func _on_bucar_died() -> void:
	_finish_win()


func _connect_host() -> void:
	var host: Node = get_node_or_null("Host")
	if host == null:
		return
	for child in host.get_children():
		if child == _bucar():
			continue
		var hurt: Node = child.get_node_or_null("HurtBox")
		if hurt and hurt.has_signal("died") and not hurt.died.is_connected(_on_host_dummy_died):
			hurt.died.connect(_on_host_dummy_died)


func _on_host_dummy_died() -> void:
	pass


func _cache_cover_marks() -> void:
	var ferran: Node3D = get_node_or_null("Infantes/Ferran") as Node3D
	var diego: Node3D = get_node_or_null("Infantes/Diego") as Node3D
	if ferran:
		_ferran_cover = ferran.global_position
	if diego:
		_diego_cover = diego.global_position


func _hide_infantes() -> void:
	var infantes: Node = get_node_or_null("Infantes")
	if infantes == null:
		return
	for child in infantes.get_children():
		_set_body_active(child, false)


func _place_captains_cover() -> void:
	var pero: Node3D = get_node_or_null("Mesnada/PeroBermudez") as Node3D
	var martin: Node3D = get_node_or_null("Mesnada/MartinAntolinez") as Node3D
	if pero and _ferran_cover != Vector3.ZERO:
		pero.global_position = _ferran_cover
	if martin and _diego_cover != Vector3.ZERO:
		martin.global_position = _diego_cover


func _disable_host() -> void:
	var host: Node = get_node_or_null("Host")
	if host == null:
		return
	for child in host.get_children():
		_set_body_active(child, false)


func _set_body_active(node: Node, active: bool) -> void:
	# PROCESS_MODE_DISABLED still leaves bodies on the physics server.
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if not body.has_meta("host_layer"):
			body.set_meta("host_layer", body.collision_layer)
		body.collision_layer = int(body.get_meta("host_layer")) if active else 0
		if node is Area3D:
			(node as Area3D).monitorable = active
	if not active and node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_set_body_active(child, active)


func _connect_battle_zone() -> void:
	var zone: Area3D = get_node_or_null("BattleZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_battle_entered):
		zone.body_entered.connect(_on_battle_entered)


func _on_battle_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_battle()


func _form_wedge() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"charge")


func _hold_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"hold")


func _bind_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	var roster: Variant = _roster()
	if roster and mesnada.has_method("bind_roster"):
		mesnada.bind_roster(roster)
	if "lanza_body_limit" in mesnada and roster and "lanzas" in roster:
		mesnada.lanza_body_limit = int(roster.lanzas)
		if mesnada.has_method("_sync_lanza_bodies"):
			mesnada.call("_sync_lanza_bodies")


func _ensure_roster() -> void:
	var honor := _honor()
	if honor == null:
		return
	if honor.get("roster") != null:
		return
	honor.roster = MesnadaRoster.from_starting_seed()


func _roster() -> Variant:
	if GameState and GameState.has_method("roster"):
		var found: Variant = GameState.roster()
		if found != null:
			return found
	var honor := _honor()
	if honor:
		return honor.get("roster")
	return null


func _honor() -> Node:
	return _autoload("HonorService")


func _apply_honor(event_id: StringName) -> void:
	var honor := _honor()
	if honor == null:
		return
	if honor.has_method("apply_id"):
		honor.apply_id(event_id)
	elif honor.has_method("apply"):
		honor.call("apply", event_id)


func _bucar() -> Node:
	return get_node_or_null("Host/Bucar")


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _show_place_name() -> void:
	var label: Label3D = get_node_or_null("PlaceName") as Label3D
	if label == null:
		return
	label.text = _loc(PLACE_KEY)
	label.visible = true


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func _name_horse() -> void:
	_set_flag(&"babieca_named")
	var horse: Node = get_node_or_null("Horse")
	if horse and horse.has_method("apply_name"):
		horse.call("apply_name", HORSE_ID, HORSE_KEY)
	var label: Label3D = get_node_or_null("Horse/Name") as Label3D
	if label:
		label.text = _loc(HORSE_KEY)
		label.visible = true


func _label_people() -> void:
	var bucar: Label3D = get_node_or_null("Host/Bucar/Name") as Label3D
	if bucar:
		bucar.text = _loc("char.bucar")
	var ferran: Label3D = get_node_or_null("Infantes/Ferran/Name") as Label3D
	if ferran:
		ferran.text = _loc("char.ferran_gonzalez")
	var diego: Label3D = get_node_or_null("Infantes/Diego/Name") as Label3D
	if diego:
		diego.text = _loc("char.diego_gonzalez")


func _loc(key: String) -> String:
	var loc := _autoload("Loc")
	if loc != null and loc.has_method("text"):
		return str(loc.text(key))
	return key


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


func _travel(to_id: StringName) -> bool:
	if _left:
		return false
	var runner := _runner()
	if runner == null or not runner.has_method("travel"):
		return false
	if "current_id" in runner:
		runner.current_id = BEAT_ID
	if not bool(runner.travel(to_id)):
		return false
	_left = true
	_checkpoint()
	var loop := Engine.get_main_loop()
	var tree: SceneTree = loop as SceneTree if loop is SceneTree else null
	if tree == null or tree.current_scene != self:
		return true
	if runner.has_method("goto"):
		runner.goto(to_id)
	return true


func _can_travel(to_id: StringName) -> bool:
	var runner := _runner()
	if runner == null or not runner.has_method("can_travel"):
		return false
	var from_id: StringName = BEAT_ID
	if "current_id" in runner and String(runner.current_id) != "":
		from_id = runner.current_id
	var flags := PackedStringArray()
	if "flags" in runner:
		flags = runner.flags
	return bool(runner.can_travel(from_id, to_id, flags))


func _has_flag(flag_id: StringName) -> bool:
	var runner := _runner()
	if runner != null and runner.has_method("has_flag"):
		return bool(runner.has_flag(flag_id))
	if runner != null and "flags" in runner:
		return String(flag_id) in runner.flags
	return false


func _set_flag(flag_id: StringName) -> void:
	var runner := _runner()
	if runner == null:
		return
	if runner.has_method("add_flag"):
		runner.add_flag(String(flag_id))
		return
	if "flags" in runner:
		var packed: PackedStringArray = runner.flags
		if String(flag_id) not in packed:
			packed.append(String(flag_id))
			runner.flags = packed


func _runner() -> Node:
	return _autoload("ChapterRunner")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(node_name))
	return get_node_or_null(NodePath("/root/%s" % node_name))


func _on_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _dialogue_manager()
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_dialogue_ended)
	_talking = false
	if _win_started and not _won:
		_finish_win()


func _try_balloon(resource: Resource, cue: String) -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var dm := _dialogue_manager()
	if dm and dm.has_method("show_dialogue_balloon_scene") and ResourceLoader.exists(BALLOON_PATH):
		if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)
		dm.show_dialogue_balloon_scene(BALLOON_PATH, resource, cue, [self])
		return true
	return false


func _walk_lines(resource: Resource, cue: String) -> void:
	last_dialogue_speakers = PackedStringArray()
	last_dialogue_keys = PackedStringArray()
	var dm := _dialogue_manager()
	if dm == null or not dm.has_method("get_next_dialogue_line"):
		return
	var line: Variant = await dm.get_next_dialogue_line(resource, cue)
	while line != null:
		_record_dialogue_line(line)
		var next_id := ""
		if typeof(line) == TYPE_OBJECT and "next_id" in line:
			next_id = str(line.next_id)
		if next_id.is_empty() or next_id == "end":
			break
		line = await dm.get_next_dialogue_line(resource, next_id)


func _record_dialogue_line(line: Variant) -> void:
	if typeof(line) != TYPE_OBJECT:
		return
	if "character" in line:
		last_dialogue_speakers.append(str(line.character))
	if "text" in line:
		last_dialogue_keys.append(str(line.text))


func _load_dialogue() -> Resource:
	if ResourceLoader.exists(DIALOGUE_PATH):
		var loaded: Variant = load(DIALOGUE_PATH)
		if loaded is Resource and loaded.has_method("get_next_dialogue_line"):
			return loaded
	if not FileAccess.file_exists(DIALOGUE_PATH):
		return null
	var text := FileAccess.get_file_as_string(DIALOGUE_PATH)
	if text.is_empty():
		return null
	var compiler: Script = load("res://addons/dialogue_manager/compiler/compiler.gd") as Script
	if compiler == null:
		return null
	var result: Variant = compiler.call("compile_string", text, DIALOGUE_PATH)
	if result == null:
		return null
	if "errors" in result and result.errors.size() > 0:
		return null
	var resource_script: Script = load("res://addons/dialogue_manager/dialogue_resource.gd") as Script
	if resource_script == null:
		return null
	var resource: Resource = resource_script.new()
	if "using_states" in result:
		resource.set("using_states", result.using_states)
	if "cues" in result:
		resource.set("cues", result.cues)
	if "first_cue" in result:
		resource.set("first_cue", result.first_cue)
	if "character_names" in result:
		resource.set("character_names", result.character_names)
	if "lines" in result:
		resource.set("lines", result.lines)
	return resource


func _dialogue_manager() -> Object:
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DialogueManager")
