extends Node3D
## a1_cardena: Jimena, Elvira, Sol, Sisebuto. Gift and hub lock.
# Crossing Cardeña is a plazo rest-skip, never a feeding night.

const BEAT_ID := &"a1_cardena"
const HUB_LOCK := &"hub_lock_cardena"
const DIALOGUE_PATH := "res://content/chapters/a1_cardena/cardena.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const CARDENA_DATA_PATH := "res://data/honor_events/cardena.json"
const BEATS_PATH := "res://content/chapters/a1_cardena/beats.json"
const GIFT_EVENT := &"cardena_gift_monastery"
const NAIL_KEY := "a1_cardena.jimena_nail"

var _talking: bool = false
var _gifted: bool = false
var _left: bool = false
var _data: Dictionary = {}


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_load_data()
	_connect_farewell_zone()


func start_farewell(_cue: String = "farewell") -> void:
	if _left or _talking:
		return
	_talking = true
	_whisper(NAIL_KEY)
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		complete_farewell()
		return
	if _try_balloon(resource, "farewell"):
		return
	await _walk_lines(resource, "farewell")
	_talking = false
	complete_farewell()


func run_farewell() -> void:
	# Headless: walk Jimena / Elvira / Sol / Sisebuto / Cid, then leave.
	_talking = true
	_whisper(NAIL_KEY)
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "farewell")
	_talking = false
	complete_farewell()


func start_cue(cue: String) -> void:
	if cue == "farewell" or cue == "leave":
		start_farewell()


func give_monastery_gift() -> void:
	if _gifted:
		return
	_gifted = true
	_apply_honor(GIFT_EVENT)
	_deduct_gift_marks()


func complete_farewell() -> void:
	if _left:
		return
	_left = true
	give_monastery_gift()
	if CampaignClock and CampaignClock.has_method("advance_plazo"):
		CampaignClock.advance_plazo(1)
	_leave_for_navapalos()


func _leave_for_navapalos() -> void:
	var dest := &"a1_navapalos"
	var travelled := false
	if ChapterRunner and ChapterRunner.has_method("travel"):
		travelled = bool(ChapterRunner.travel(dest))
	if not travelled:
		_set_flag(HUB_LOCK)
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
	_checkpoint()
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return
	if ChapterRunner and ChapterRunner.has_method("goto"):
		ChapterRunner.goto(dest)


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


func _deduct_gift_marks() -> void:
	if TreasuryService == null or TreasuryService.state == null:
		return
	var cost := _tunable_int("gift_marks")
	TreasuryService.state.marks = maxi(0, int(TreasuryService.state.marks) - cost)


func _connect_farewell_zone() -> void:
	var zone: Area3D = get_node_or_null("FarewellZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_farewell_entered):
		zone.body_entered.connect(_on_farewell_entered)


func _on_farewell_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		start_farewell()


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


func _load_data() -> void:
	_data = {}
	for path in PackedStringArray([CARDENA_DATA_PATH, BEATS_PATH]):
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for key in parsed.keys():
				if key != "events" and key != "steps" and not _data.has(key):
					_data[key] = parsed[key]


func _tunable_int(key: String) -> int:
	if _data.is_empty():
		_load_data()
	return int(_data.get(key, 0))


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


func _on_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _dialogue_manager()
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_dialogue_ended)
	_talking = false
	complete_farewell()


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
