extends Node3D
## a3_despedida: Valencia hall then the road. Swords gifted; Avengalvón must live.

const BEAT_ID := &"a3_despedida"
const DEST := &"a3_corpes"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const AVENGALVON_ID := &"avengalvon"
const COLADA_ID := &"colada"
const TIZONA_ID := &"tizona"
const FAIL_REASON := &"avengalvon_dead"
const PROMPT_KEY := "a3_despedida.prompt"
const SWORDS_KEY := "a3_despedida.swords"
const LEAVE_KEY := "a3_despedida.daughters_leave"
const ROAD_KEY := "a3_despedida.road"
const AMBUSH_KEY := "a3_despedida.ambush"
const LETS_GO_KEY := "a3_despedida.lets_go"
const NEED_KEY := "a3_despedida.need_agree"
const PLACE_KEY := "a3_despedida.place_name"
const DIALOGUE_PATH := "res://content/chapters/a3_despedida/despedida.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DEST_SCENE := "res://content/chapters/a3_corpes/world.tscn"

var colada: SwordItem
var tizona: SwordItem
var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var _agreed: bool = false
var _gifted: bool = false
var _daughters_gone: bool = false
var _ambush_started: bool = false
var _let_go: bool = false
var _failed: bool = false
var _talking: bool = false
var _left: bool = false
var _skip_cinematic: bool = false


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
	_restore_avengalvon_if_ready()
	_bind_mesnada()
	_hide_plazo_bar()
	_ensure_swords()
	_bind_avengalvon()
	_protect_infantes()
	_connect_zones()
	_show_place_name()
	_name_horse()
	_label_people()
	if not _avengalvon_alive():
		_fail_avengalvon()
		return
	_whisper(PROMPT_KEY)


func start_cue(cue: String) -> void:
	if cue == "depart" or cue == "gift" or cue == "agree":
		start_departure()
	elif cue == "leave":
		start_daughters_leave()
	elif cue == "ambush" or cue == "road":
		start_ambush()
	elif cue == "lets_go":
		start_let_go()


func start_departure(_cue: String = "depart") -> void:
	if _failed or _agreed or _talking:
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_agree_and_gift()
		return
	if _try_balloon(resource, "depart"):
		return
	_walk_depart(resource)


func run_departure() -> void:
	# Headless: skip-cinematic agree so same-frame tests can assert GIFTED_TO_INFANTES.
	if _failed:
		return
	_skip_cinematic = true
	_agree_and_gift()


func start_daughters_leave(_cue: String = "leave") -> void:
	if _failed or _daughters_gone:
		return
	if not _agreed:
		_whisper(NEED_KEY)
		return
	_finish_daughters_leave()


func start_ambush(_cue: String = "ambush") -> void:
	if _failed or _ambush_started:
		return
	if not _agreed:
		_whisper(NEED_KEY)
		return
	if not _daughters_gone:
		_finish_daughters_leave()
	_ambush_started = true
	_move_infantes_to_road()
	_whisper(AMBUSH_KEY)
	if not _avengalvon_alive():
		_fail_avengalvon()


func run_ambush() -> void:
	# Headless: murder-attempt then he lets them go.
	if _failed:
		return
	_skip_cinematic = true
	if not _agreed:
		run_departure()
	if _failed:
		return
	start_ambush()
	start_let_go()


func start_let_go(_cue: String = "lets_go") -> void:
	if _failed or _let_go:
		return
	if not _ambush_started:
		start_ambush()
	if _failed:
		return
	if _skip_cinematic:
		_finish_let_go()
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_finish_let_go()
		return
	if _try_balloon(resource, "lets_go"):
		return
	_walk_lets_go(resource)


func try_travel_corpes() -> bool:
	if not _let_go:
		return false
	if not _dest_ready():
		return false
	return _travel(DEST)


func can_leave_to_corpes() -> bool:
	if not _let_go:
		return false
	return _can_travel(DEST)


func swords_gifted() -> bool:
	_ensure_swords()
	if colada == null or tizona == null:
		return false
	if colada.phase != SwordItem.Phase.GIFTED_TO_INFANTES:
		return false
	if tizona.phase != SwordItem.Phase.GIFTED_TO_INFANTES:
		return false
	return not colada.lootable() and not tizona.lootable()


func avengalvon_survived() -> bool:
	if _failed or not _let_go:
		return false
	return _avengalvon_alive()


func _agree_and_gift() -> void:
	if _failed or _agreed:
		return
	_agreed = true
	_set_flag(&"despedida_agreed")
	_gift_swords()
	_finish_daughters_leave()


func _gift_swords() -> void:
	if _gifted:
		return
	_ensure_swords()
	_set_sword_gifted(colada)
	_set_sword_gifted(tizona)
	_gifted = true
	_set_flag(&"swords_gifted")
	_whisper(SWORDS_KEY)


func _set_sword_gifted(item: SwordItem) -> void:
	if item == null:
		return
	item.phase = SwordItem.Phase.GIFTED_TO_INFANTES
	if EventBus and EventBus.has_signal("sword_phase_changed"):
		EventBus.sword_phase_changed.emit(item.id, int(item.phase))


func _finish_daughters_leave() -> void:
	if _daughters_gone:
		return
	_daughters_gone = true
	_set_flag(&"daughters_left")
	_set_body_active(get_node_or_null("Elvira"), false)
	_set_body_active(get_node_or_null("Sol"), false)
	_whisper(LEAVE_KEY)
	_whisper("a3_despedida.jimena_stay")


func _finish_let_go() -> void:
	if _let_go or _failed:
		return
	if not _avengalvon_alive():
		_fail_avengalvon()
		return
	_let_go = true
	_talking = false
	_disable_infantes()
	_set_flag(&"avengalvon_alive_despedida")
	_grant_keep_avengalvon()
	_whisper(LETS_GO_KEY)
	_whisper(ROAD_KEY)
	_leave_for_corpes()


func _leave_for_corpes() -> void:
	if _left:
		return
	# ChapterRunner.travel emits beat_completed; only emit here if travel does not run.
	if not _dest_ready() or not _travel(DEST):
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_checkpoint()


func _dest_ready() -> bool:
	return ResourceLoader.exists(DEST_SCENE)


func _fail_avengalvon() -> void:
	if _failed:
		return
	_failed = true
	_mark_avengalvon_dead()
	var script: Script = load("res://game/ui/fail_copy.gd") as Script
	if script and "last_reason" in script:
		script.last_reason = FAIL_REASON
	if EventBus and EventBus.has_signal("hard_fail"):
		EventBus.hard_fail.emit(FAIL_REASON)


func _mark_avengalvon_dead() -> void:
	var roster: Variant = _roster()
	if roster == null or not roster.has_method("member"):
		return
	var member: Variant = roster.member(AVENGALVON_ID)
	if member and "alive" in member:
		member.alive = false


func _avengalvon_alive() -> bool:
	var roster: Variant = _roster()
	if roster and roster.has_method("member"):
		var member: Variant = roster.member(AVENGALVON_ID)
		if member != null and "alive" in member and not bool(member.alive):
			return false
	var body: Node = _avengalvon()
	if body == null:
		return roster != null and roster.has_method("member") and roster.member(AVENGALVON_ID) != null
	var hurt: Node = body.get_node_or_null("HurtBox")
	if hurt and "hp" in hurt and float(hurt.hp) <= 0.0:
		return false
	return true


func _restore_avengalvon_if_ready() -> void:
	var roster: Variant = _roster()
	if roster == null or not roster.has_method("add_member"):
		return
	if roster.has_method("member") and roster.member(AVENGALVON_ID) != null:
		return
	var member := MesnadaMember.from_id(AVENGALVON_ID)
	if member:
		roster.add_member(member)


func _bind_avengalvon() -> void:
	var body: Node = _avengalvon()
	if body == null:
		return
	if "character_id" in body and String(body.get("character_id")) == "":
		body.set("character_id", AVENGALVON_ID)
	var member := MesnadaMember.from_id(AVENGALVON_ID)
	if member and "unkillable" in body:
		body.unkillable = member.unkillable
	var hurt: Node = body.get_node_or_null("HurtBox")
	if hurt and hurt.has_signal("died") and not hurt.died.is_connected(_on_avengalvon_died):
		hurt.died.connect(_on_avengalvon_died)


func _on_avengalvon_died() -> void:
	_fail_avengalvon()


func _protect_infantes() -> void:
	for path in ["Infantes/Ferran", "Infantes/Diego"]:
		var body: Node = get_node_or_null(path)
		if body == null:
			continue
		var hurt: Node = body.get_node_or_null("HurtBox")
		if hurt == null:
			continue
		if "spectator" in hurt:
			hurt.spectator = true
		if hurt.has_method("_apply_collision"):
			hurt.call("_apply_collision")


func _move_infantes_to_road() -> void:
	var mark: Node3D = get_node_or_null("Avengalvon") as Node3D
	var origin := Vector3(0.0, 0.05, -16.0)
	if mark:
		origin = mark.global_position
	var ferran: Node3D = get_node_or_null("Infantes/Ferran") as Node3D
	var diego: Node3D = get_node_or_null("Infantes/Diego") as Node3D
	if ferran:
		ferran.global_position = origin + Vector3(-1.4, 0.0, 1.2)
	if diego:
		diego.global_position = origin + Vector3(1.4, 0.0, 1.2)


func _disable_infantes() -> void:
	var infantes: Node = get_node_or_null("Infantes")
	if infantes == null:
		return
	for child in infantes.get_children():
		_set_body_active(child, false)


func _set_body_active(node: Node, active: bool) -> void:
	if node == null:
		return
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


func _connect_zones() -> void:
	_connect_zone("GiftZone", _on_gift_entered)
	_connect_zone("AmbushZone", _on_ambush_entered)


func _connect_zone(node_name: String, cb: Callable) -> void:
	var zone: Area3D = get_node_or_null(node_name) as Area3D
	if zone and not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)


func _is_player_or_horse(body: Node) -> bool:
	if body == null:
		return false
	return body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")


func _on_gift_entered(body: Node) -> void:
	if _is_player_or_horse(body):
		start_departure()


func _on_ambush_entered(body: Node) -> void:
	if not _is_player_or_horse(body):
		return
	start_ambush()
	if _ambush_started and not _let_go and not _failed:
		start_let_go()


func _ensure_swords() -> void:
	if colada == null:
		colada = _sword(COLADA_ID)
	if tizona == null:
		tizona = _sword(TIZONA_ID)


func _sword(item_id: StringName) -> SwordItem:
	if GameState and GameState.has_method("sword"):
		var found: SwordItem = GameState.sword(item_id)
		if found:
			return found
	return SwordItem.from_id(item_id)


func _grant_keep_avengalvon() -> void:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return
	var mesura: Node = cid.get_node_or_null("Mesura")
	if mesura == null:
		mesura = cid.find_child("Mesura", true, false)
	if mesura and mesura.has_method("grant_trait"):
		mesura.call("grant_trait", &"keep_avengalvon")


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


func _avengalvon() -> Node:
	return get_node_or_null("Avengalvon")


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
	_set_label("Avengalvon/Name", "char.avengalvon")
	_set_label("Jimena/Name", "char.jimena")
	_set_label("Elvira/Name", "char.elvira")
	_set_label("Sol/Name", "char.sol")
	_set_label("Infantes/Ferran/Name", "char.ferran_gonzalez")
	_set_label("Infantes/Diego/Name", "char.diego_gonzalez")


func _set_label(path: String, key: String) -> void:
	var label: Label3D = get_node_or_null(path) as Label3D
	if label:
		label.text = _loc(key)


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


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


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
	if _ambush_started and not _let_go and not _failed:
		_finish_let_go()
		return
	if not _agreed and not _failed:
		_agree_and_gift()


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


func _walk_depart(resource: Resource) -> void:
	await _walk_lines(resource, "depart")
	_talking = false
	_agree_and_gift()


func _walk_lets_go(resource: Resource) -> void:
	await _walk_lines(resource, "lets_go")
	_talking = false
	_finish_let_go()


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
