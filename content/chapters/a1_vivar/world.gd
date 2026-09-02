extends Node3D
## a1_vivar: empty solar, first names, plazo to the frontier.

const BEAT_ID := &"a1_vivar"
const SEEN_FLAG := &"vivar_seen"
const DIALOGUE_PATH := "res://content/chapters/a1_vivar/vivar.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"

var _talking: bool = false
var _left: bool = false


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	var frontier: Area3D = get_node_or_null("Frontier") as Area3D
	if frontier and not frontier.body_entered.is_connected(_on_frontier_entered):
		frontier.body_entered.connect(_on_frontier_entered)


func start_first_names(_cue: String = "start") -> void:
	if _talking:
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		return
	var dm := _dialogue_manager()
	if dm and dm.has_method("show_dialogue_balloon_scene") and ResourceLoader.exists(BALLOON_PATH):
		if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)
		dm.show_dialogue_balloon_scene(BALLOON_PATH, resource, "start", [self])
		return
	await _walk_lines(resource)
	_finish_first_names()


func run_first_names() -> void:
	# Headless: walk the cue, no balloon.
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource)
		_finish_first_names()
	else:
		_talking = false


func leave_solar() -> void:
	# Crossing the gate is a plazo rest-skip, never a feeding night.
	if not _left:
		if CampaignClock and CampaignClock.has_method("advance_plazo"):
			CampaignClock.advance_plazo(1)
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_left = true
	_travel_to_burgos()


func _physics_process(_delta: float) -> void:
	if _left:
		# leave_solar already queued one deferred goto. Re-calling it every
		# tick stacked change_scene_to_file and tore down Burgos on arrival.
		return
	var cid: Node3D = get_node_or_null("Cid") as Node3D
	if cid == null:
		return
	# South opening: x in the wall gap. A layer-1 gate used to stop Cid at ~8.8.
	if absf(cid.global_position.x) <= 2.8 and cid.global_position.z >= 8.0:
		leave_solar()


func _travel_to_burgos() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return
	if ChapterRunner == null:
		return
	_set_seen()
	if ChapterRunner.has_method("goto"):
		ChapterRunner.goto(&"a1_burgos")


func _on_frontier_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		leave_solar()


func _on_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _dialogue_manager()
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_dialogue_ended)
	_finish_first_names()


func _finish_first_names() -> void:
	_talking = false
	_set_seen()


func _set_seen() -> void:
	if ChapterRunner and ChapterRunner.has_method("set_flag"):
		ChapterRunner.set_flag(SEEN_FLAG)
	elif ChapterRunner and "flags" in ChapterRunner:
		var packed: PackedStringArray = ChapterRunner.flags
		if String(SEEN_FLAG) not in packed:
			packed.append(String(SEEN_FLAG))
			ChapterRunner.flags = packed


func _walk_lines(resource: Resource) -> void:
	var dm := _dialogue_manager()
	if dm == null or not dm.has_method("get_next_dialogue_line"):
		return
	var line: Variant = await dm.get_next_dialogue_line(resource, "start")
	while line != null:
		var next_id := ""
		if typeof(line) == TYPE_OBJECT and "next_id" in line:
			next_id = str(line.next_id)
		if next_id.is_empty() or next_id == "end":
			break
		line = await dm.get_next_dialogue_line(resource, next_id)


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
