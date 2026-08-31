extends Node3D
## a1_burgos: shutters, v. 20 child, inn refusal, mesura gate, river camp.
# WHY: v. 20 is the shutter line; v. 9 is the Vivar departure, not this beat.

const BEAT_ID := &"a1_burgos"
const SEEN_FLAG := &"burgos_shutters_seen"
const BEATS_PATH := "res://content/chapters/a1_burgos/beats.json"
const DIALOGUE_PATH := "res://content/chapters/a1_burgos/burgos.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DRAW_STEEL_EVENT := &"burgos_draw_steel"
const CAMP_RIVER_EVENT := &"burgos_camp_river"
const V20_KEY := "poem.v20"

var _talking: bool = false
var _steel_drawn: bool = false
var _camped: bool = false
var _cid_in_burgales: bool = false


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	apply_beats()
	_connect_zones()


func apply_beats() -> void:
	var applied := false
	if FileAccess.file_exists(BEATS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BEATS_PATH))
		if parsed is Dictionary:
			var steps: Variant = parsed.get("steps", [])
			if steps is Array:
				for step in steps:
					if not step is Dictionary:
						continue
					var flags: Variant = step.get("set_flags", [])
					if flags is Array:
						for flag in flags:
							_set_flag(StringName(str(flag)))
							applied = true
	if not applied:
		_set_flag(SEEN_FLAG)


func speak_v20() -> void:
	_whisper_v20()


func start_child_v20(_cue: String = "child_v20") -> void:
	if _talking:
		return
	_talking = true
	_whisper_v20()
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		return
	if _try_balloon(resource, "child_v20"):
		return
	await _walk_lines(resource, "child_v20")
	_talking = false


func run_child_v20() -> void:
	# Headless: whisper + walk the cue, no balloon.
	_talking = true
	_whisper_v20()
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "child_v20")
	_talking = false


func start_inn_refusal(_cue: String = "innkeeper") -> void:
	if _talking:
		return
	_talking = true
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		return
	if _try_balloon(resource, "innkeeper"):
		return
	await _walk_lines(resource, "innkeeper")
	_talking = false


func run_inn_refusal() -> void:
	_talking = true
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "innkeeper")
	_talking = false


func start_cue(cue: String) -> void:
	if cue == "child_v20":
		start_child_v20()
	elif cue == "innkeeper":
		start_inn_refusal()
	elif cue == "camp_river":
		camp_on_river()
	elif cue == "draw_steel":
		draw_steel_on_burgaleses()


func camp_on_river() -> void:
	if _camped:
		return
	_camped = true
	_apply_honor(CAMP_RIVER_EVENT)
	if EventBus and EventBus.has_signal("beat_completed"):
		EventBus.beat_completed.emit(BEAT_ID)


func draw_steel_on_burgaleses() -> void:
	# Mesura gate: honra crash. Burgaleses stay; the inn is not stormed.
	if _steel_drawn:
		return
	_steel_drawn = true
	_apply_honor(DRAW_STEEL_EVENT)


func can_storm_inn() -> bool:
	return false


func inn_is_closed() -> bool:
	return true


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if _cid_in_burgales and event.is_action_pressed("slam"):
		draw_steel_on_burgaleses()


func _connect_zones() -> void:
	var burgales: Area3D = get_node_or_null("BurgalesZone") as Area3D
	if burgales:
		if not burgales.body_entered.is_connected(_on_burgales_entered):
			burgales.body_entered.connect(_on_burgales_entered)
		if not burgales.body_exited.is_connected(_on_burgales_exited):
			burgales.body_exited.connect(_on_burgales_exited)
	var camp: Area3D = get_node_or_null("RiverCamp") as Area3D
	if camp and not camp.body_entered.is_connected(_on_camp_entered):
		camp.body_entered.connect(_on_camp_entered)


func _on_burgales_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		_cid_in_burgales = true


func _on_burgales_exited(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		_cid_in_burgales = false


func _on_camp_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		camp_on_river()


func _whisper_v20() -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", V20_KEY)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(V20_KEY))


func _on_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _dialogue_manager()
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_dialogue_ended)
	_talking = false


func _try_balloon(resource: Resource, cue: String) -> bool:
	var dm := _dialogue_manager()
	if dm and dm.has_method("show_dialogue_balloon_scene") and ResourceLoader.exists(BALLOON_PATH):
		if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)
		dm.show_dialogue_balloon_scene(BALLOON_PATH, resource, cue, [self])
		return true
	return false


func _set_flag(flag_id: StringName) -> void:
	if ChapterRunner and ChapterRunner.has_method("set_flag"):
		ChapterRunner.set_flag(flag_id)
	elif ChapterRunner and "flags" in ChapterRunner:
		var packed: PackedStringArray = ChapterRunner.flags
		if String(flag_id) not in packed:
			packed.append(String(flag_id))
			ChapterRunner.flags = packed


func _apply_honor(event_id: StringName) -> void:
	if HonorService == null:
		return
	if HonorService.has_method("apply_id"):
		HonorService.apply_id(event_id)
	elif HonorService.has_method("apply"):
		HonorService.call("apply", event_id)


func _walk_lines(resource: Resource, cue: String) -> void:
	var dm := _dialogue_manager()
	if dm == null or not dm.has_method("get_next_dialogue_line"):
		return
	var line: Variant = await dm.get_next_dialogue_line(resource, cue)
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
