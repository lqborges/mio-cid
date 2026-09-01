extends Node3D
## a1_tevar: battle, capture don Remont, make him eat, keep Colada.

const BEAT_ID := &"a1_tevar"
const DEST := &"a2_murviedro"
const CARDENA_ID := &"a1_cardena"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const RAMON_ID := &"ramon_berenguer"
const COLADA_ID := &"colada"
const FEED_EVENT := &"tevar_feed_count"
const BATTLE_KEY := "a1_tevar.battle"
const CAPTURE_KEY := "a1_tevar.capture"
const HUNGER_KEY := "a1_tevar.hunger"
const EAT_KEY := "a1_tevar.eat_done"
const COLADA_KEY := "a1_tevar.colada_kept"
const DIALOGUE_PATH := "res://content/chapters/a1_tevar/tevar.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"

var colada: SwordItem
var last_dialogue_speakers: PackedStringArray = PackedStringArray()
var last_dialogue_keys: PackedStringArray = PackedStringArray()
var _battle_started: bool = false
var _captured: bool = false
var _hunger_played: bool = false
var _ate: bool = false
var _eat_started: bool = false
var _talking: bool = false
var _left: bool = false


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
	_hide_choice()
	_ensure_colada()
	_bind_ramon()
	_connect_host()
	_connect_battle_zone()
	_connect_table_zone()
	_set_zone_monitoring("TableZone", false)
	_show_place_name()
	_whisper(BATTLE_KEY)


func start_battle(_cue: String = "battle") -> void:
	if _battle_started or _captured or _ate:
		return
	_battle_started = true
	_form_wedge()
	_whisper(BATTLE_KEY)


func run_battle() -> void:
	# Headless: win the pinewood without walking BattleZone.
	start_battle()
	complete_capture()


func complete_capture() -> void:
	if _captured or _ate:
		return
	_battle_started = true
	_captured = true
	_hold_mesnada()
	_disable_host_except_ramon()
	_seat_count()
	_restore_living_seated(_ramon())
	_whisper(CAPTURE_KEY)
	_set_zone_monitoring("BattleZone", false)
	_set_zone_monitoring("TableZone", true)


func start_hunger(_cue: String = "hunger") -> void:
	if not _captured or _hunger_played or _ate or _talking:
		return
	_hunger_played = true
	_talking = true
	_whisper(HUNGER_KEY)
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_show_choice()
		return
	if _try_balloon(resource, "hunger"):
		return
	await _walk_lines(resource, "hunger")
	_talking = false
	if not _ate:
		_show_choice()


func run_hunger() -> void:
	# Headless: capture if needed, walk the hunger-strike, then present eat.
	if not _captured:
		run_battle()
	_hunger_played = true
	_talking = true
	_whisper(HUNGER_KEY)
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "hunger")
	_talking = false
	if not _ate:
		_show_choice()


func start_cue(cue: String) -> void:
	if cue == "battle" or cue == "dawn":
		start_battle()
	elif cue == "capture":
		complete_capture()
	elif cue == "hunger" or cue == "table":
		start_hunger()
	elif cue == "eat":
		choose_eat()


func run_eat() -> void:
	# Headless: skip ~ eat balloon so same-frame tests can assert Colada.
	if not _captured:
		run_battle()
	_eat_started = true
	_finish_eat()


func choose_eat() -> void:
	if _ate or _eat_started:
		return
	if not _captured:
		run_battle()
	_eat_started = true
	_hide_choice()
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_finish_eat()
		return
	if _try_balloon(resource, "eat"):
		return
	await _walk_lines(resource, "eat")
	_talking = false
	_finish_eat()


func _finish_eat() -> void:
	if _ate:
		return
	_ate = true
	_hunger_played = true
	_hide_choice()
	_apply_honor(FEED_EVENT)
	_acquire_colada()
	_whisper(COLADA_KEY)
	_leave_for_murviedro()


func try_travel_cardena() -> bool:
	return _travel(CARDENA_ID)


func can_return_to_cardena() -> bool:
	return _can_travel(CARDENA_ID)


func can_leave_to_murviedro() -> bool:
	if not _ate:
		return false
	return _can_travel(DEST)


func _leave_for_murviedro() -> void:
	if _left:
		return
	_left = true
	var travelled := false
	if ChapterRunner and ChapterRunner.has_method("can_travel"):
		var flags: PackedStringArray = ChapterRunner.flags if "flags" in ChapterRunner else PackedStringArray()
		if not bool(ChapterRunner.can_travel(BEAT_ID, DEST, flags)):
			if EventBus and EventBus.has_signal("beat_completed"):
				EventBus.beat_completed.emit(BEAT_ID)
			_checkpoint()
			return
	if ChapterRunner and ChapterRunner.has_method("travel"):
		travelled = bool(ChapterRunner.travel(DEST))
	if not travelled:
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
	_checkpoint()
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return
	if ChapterRunner and ChapterRunner.has_method("goto"):
		ChapterRunner.goto(DEST)


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


func _acquire_colada() -> void:
	_ensure_colada()
	if colada == null:
		return
	colada.phase = SwordItem.Phase.IN_HAND


func _ensure_colada() -> void:
	if colada != null:
		return
	if GameState and GameState.has_method("sword"):
		colada = GameState.sword(COLADA_ID)
	if colada == null:
		colada = SwordItem.from_id(COLADA_ID)


func _bind_ramon() -> void:
	var ramon: Node = _ramon()
	if ramon == null:
		return
	if "character_id" in ramon and String(ramon.get("character_id")) == "":
		ramon.set("character_id", RAMON_ID)
	var member := MesnadaMember.from_id(RAMON_ID)
	if member and "unkillable" in ramon:
		# Keep the pinewood fight killable; capture restores a living seat.
		ramon.unkillable = member.unkillable
	var mesh: MeshInstance3D = ramon.get_node_or_null("Visual/MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat := mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			ramon.set_meta("alive_albedo", (mat as StandardMaterial3D).albedo_color)
	var hurt: Node = ramon.get_node_or_null("HurtBox")
	if hurt and hurt.has_signal("died") and not hurt.died.is_connected(_on_ramon_died):
		hurt.died.connect(_on_ramon_died)


func _on_ramon_died() -> void:
	complete_capture()


func _connect_host() -> void:
	var host: Node = get_node_or_null("Host")
	if host == null:
		return
	for child in host.get_children():
		if child == _ramon():
			continue
		var hurt: Node = child.get_node_or_null("HurtBox")
		if hurt and hurt.has_signal("died") and not hurt.died.is_connected(_on_host_dummy_died):
			hurt.died.connect(_on_host_dummy_died)


func _on_host_dummy_died() -> void:
	# Capture is the count, not a loot pile of knights.
	pass


func _seat_count() -> void:
	var ramon: Node = _ramon()
	var seat: Node3D = get_node_or_null("TableCamp/Seat") as Node3D
	if ramon == null or seat == null:
		return
	if ramon is Node3D:
		(ramon as Node3D).global_position = seat.global_position


func _restore_living_seated(body: Node) -> void:
	# 0 HP is capture; restore a living seated pose before hunger.
	if body == null:
		return
	body.process_mode = Node.PROCESS_MODE_DISABLED
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	if body is CollisionObject3D:
		(body as CollisionObject3D).collision_layer = 0
	var hurt: Area3D = body.get_node_or_null("HurtBox") as Area3D
	if hurt:
		if "hp" in hurt and "max_hp" in hurt:
			hurt.hp = hurt.max_hp
		hurt.monitorable = false
		hurt.collision_layer = 0
	if not body.has_meta("alive_albedo"):
		return
	var mesh: MeshInstance3D = body.get_node_or_null("Visual/MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var mat := mesh.get_active_material(0)
	var live: StandardMaterial3D = StandardMaterial3D.new()
	if mat is StandardMaterial3D:
		live = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	live.albedo_color = body.get_meta("alive_albedo")
	mesh.material_override = live
	var humanoid: Node = body.get_node_or_null("Visual/Humanoid")
	if humanoid and humanoid.has_method("tint_cloth"):
		humanoid.call("tint_cloth", body.get_meta("alive_albedo"))


func _disable_host_except_ramon() -> void:
	var host: Node = get_node_or_null("Host")
	if host == null:
		return
	var ramon: Node = _ramon()
	for child in host.get_children():
		if child == ramon:
			continue
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


func _connect_table_zone() -> void:
	var zone: Area3D = get_node_or_null("TableZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_table_entered):
		zone.body_entered.connect(_on_table_entered)


func _on_table_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_hunger()


func _set_zone_monitoring(zone_name: String, on: bool) -> void:
	var zone: Area3D = get_node_or_null(zone_name) as Area3D
	if zone:
		zone.monitoring = on


func _show_choice() -> void:
	var ui: Node = find_child("TableChoice", true, false)
	if ui == null:
		return
	if ui.has_method("present"):
		ui.call("present")
	else:
		ui.visible = true


func _hide_choice() -> void:
	var ui: Node = find_child("TableChoice", true, false)
	if ui == null:
		return
	if ui.has_method("dismiss"):
		ui.call("dismiss")
	else:
		ui.visible = false


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
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath("HonorService"))
	return null


func _apply_honor(event_id: StringName) -> void:
	var honor := _honor()
	if honor == null:
		return
	if honor.has_method("apply_id"):
		honor.apply_id(event_id)
	elif honor.has_method("apply"):
		honor.call("apply", event_id)


func _ramon() -> Node:
	return get_node_or_null("Host/Ramon")


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _show_place_name() -> void:
	var label: Label3D = get_node_or_null("PlaceName") as Label3D
	if label == null:
		return
	label.text = _loc("a1_tevar.place_name")
	label.visible = true


func _loc(key: String) -> String:
	if Loc and Loc.has_method("text"):
		return str(Loc.text(key))
	return key


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


func _travel(to_id: StringName) -> bool:
	var runner := _runner()
	if runner == null or not runner.has_method("travel"):
		return false
	if "current_id" in runner:
		runner.current_id = BEAT_ID
	return bool(runner.travel(to_id))


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


func _runner() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath("ChapterRunner"))
	return null


func _on_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _dialogue_manager()
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_dialogue_ended)
	_talking = false
	if _eat_started and not _ate:
		_finish_eat()
		return
	if _captured and not _ate:
		_show_choice()


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
