extends Node3D
## a1_navapalos: frontier camp, Gabriel dream. Sleep, no combat.
# Plazo may hit 0 here; expiry is only if 0 before this beat.

const BEAT_ID := &"a1_navapalos"
const HUB_LOCK := &"hub_lock_cardena"
const DIALOGUE_PATH := "res://content/chapters/a1_navapalos/navapalos.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const DREAM_KEY := "a1_navapalos.gabriel_dream"

var _talking: bool = false
var _slept: bool = false
var _dreamed: bool = false


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_connect_sleep_zone()


func start_sleep(_cue: String = "dream") -> void:
	if _slept or _talking:
		return
	_slept = true
	_talking = true
	_play_cinematic()
	_whisper(DREAM_KEY)
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		complete_dream()
		return
	if _try_balloon(resource, "dream"):
		return
	await _walk_lines(resource, "dream")
	_talking = false
	complete_dream()


func run_sleep() -> void:
	# Headless: cinematic + Gabriel / Cid, then plazo completes.
	_slept = true
	_talking = true
	_play_cinematic()
	_whisper(DREAM_KEY)
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "dream")
	_talking = false
	complete_dream()


func start_cue(cue: String) -> void:
	if cue == "sleep" or cue == "dream":
		start_sleep()


func complete_dream() -> void:
	if _dreamed:
		return
	_dreamed = true
	_slept = true
	if ChapterRunner and ChapterRunner.has_method("set_flag"):
		ChapterRunner.set_flag(HUB_LOCK)
	_complete_plazo()
	_hide_plazo_bar()
	_leave_for_castejon()


func _complete_plazo() -> void:
	if CampaignClock == null or not CampaignClock.has_method("advance_plazo"):
		return
	var remaining := 0
	if "plazo_days_left" in CampaignClock:
		remaining = int(CampaignClock.plazo_days_left)
	if remaining > 0:
		CampaignClock.advance_plazo(remaining)


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _leave_for_castejon() -> void:
	var dest := &"a1_castejon"
	var travelled := false
	if ChapterRunner and ChapterRunner.has_method("can_travel"):
		var flags: PackedStringArray = ChapterRunner.flags if "flags" in ChapterRunner else PackedStringArray()
		if not bool(ChapterRunner.can_travel(BEAT_ID, dest, flags)):
			if EventBus and EventBus.has_signal("beat_completed"):
				EventBus.beat_completed.emit(BEAT_ID)
			_checkpoint()
			return
	if ChapterRunner and ChapterRunner.has_method("travel"):
		travelled = bool(ChapterRunner.travel(dest))
	if not travelled:
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


func _connect_sleep_zone() -> void:
	var zone: Area3D = get_node_or_null("SleepZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_sleep_entered):
		zone.body_entered.connect(_on_sleep_entered)


func _on_sleep_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		start_sleep()


func _play_cinematic() -> void:
	var cam: Camera3D = get_node_or_null("DreamCamera") as Camera3D
	if cam:
		cam.current = true
	var player: AnimationPlayer = get_node_or_null("SleepCinematic") as AnimationPlayer
	if player and player.has_animation("sleep"):
		player.play("sleep")


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


func _on_dialogue_ended(_resource: Variant = null) -> void:
	var dm := _dialogue_manager()
	if dm and dm.has_signal("dialogue_ended") and dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.disconnect(_on_dialogue_ended)
	_talking = false
	complete_dream()


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
