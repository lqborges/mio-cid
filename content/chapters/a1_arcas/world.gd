extends Node3D
## a1_arcas: sand chests. Cheat stains and pays; refuse watches desertion.

const BEAT_ID := &"a1_arcas"
const DIALOGUE_PATH := "res://content/chapters/a1_arcas/arcas.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const ARCAS_DATA_PATH := "res://data/honor_events/arcas.json"
const BEATS_PATH := "res://content/chapters/a1_arcas/beats.json"
const CHEAT_EVENT := &"arcas_cheat"
const REFUSE_EVENT := &"arcas_refuse"

var _talking: bool = false
var _resolved: bool = false
var _left: bool = false
var _data: Dictionary = {}


func _ready() -> void:
	if ChapterRunner and "current_id" in ChapterRunner:
		ChapterRunner.current_id = BEAT_ID
	if EventBus and EventBus.has_signal("beat_started"):
		EventBus.beat_started.emit(BEAT_ID)
	_ensure_roster()
	_load_data()
	_connect_offer_zone()


func start_offer(_cue: String = "offer") -> void:
	if _resolved or _talking:
		return
	_talking = true
	_hide_choice()
	var resource := _load_dialogue()
	if resource == null:
		_talking = false
		_show_choice()
		return
	if _try_balloon(resource, "offer"):
		return
	await _walk_lines(resource, "offer")
	_talking = false
	if not _resolved:
		_show_choice()


func run_offer() -> void:
	# Headless: walk Martín / Raquel / Vidas first, then present the branch.
	_talking = true
	_hide_choice()
	var resource := _load_dialogue()
	if resource:
		await _walk_lines(resource, "offer")
	_talking = false
	if not _resolved:
		_show_choice()


func choose_cheat() -> void:
	if _resolved:
		return
	_resolved = true
	_hide_choice()
	_ensure_roster()
	_apply_honor(CHEAT_EVENT)
	if TreasuryService and TreasuryService.state:
		TreasuryService.state.marks += _tunable_int("cheat_marks")
	_tick_martin_loyalty()
	_confirm_choice("cheat", "a1_arcas.cheat_done")


func choose_refuse() -> void:
	if _resolved:
		return
	_resolved = true
	_hide_choice()
	_ensure_roster()
	_apply_honor(REFUSE_EVENT)
	_watch_desertion()
	if CampaignClock and CampaignClock.has_method("run_refuse_48h"):
		CampaignClock.run_refuse_48h()
	_refresh_ticker()
	_confirm_choice("refuse", "a1_arcas.refuse_done")


func cheated() -> bool:
	return _has_flag(&"arcas_cheated")


func _tick_martin_loyalty() -> void:
	var roster: Variant = GameState.roster() if GameState else null
	if roster == null or not roster.has_method("member"):
		return
	var martin: Variant = roster.member(&"martin_antolinez")
	if martin == null or not ("loyalty" in martin):
		return
	var delta := _tunable_float("martin_loyalty_delta")
	martin.loyalty = clampf(float(martin.loyalty) + delta, 0.0, 1.0)


func _watch_desertion() -> void:
	var ticker: Node = find_child("DesertionTicker", true, false)
	if ticker and ticker.has_method("watch"):
		ticker.call("watch")
	elif ticker:
		ticker.visible = true
		if ticker.has_method("refresh"):
			ticker.call("refresh")


func _refresh_ticker() -> void:
	var ticker: Node = find_child("DesertionTicker", true, false)
	if ticker and ticker.has_method("refresh"):
		ticker.call("refresh")


func _show_choice() -> void:
	var ui: Node = find_child("ChoiceUI", true, false)
	if ui == null:
		return
	if ui.has_method("present"):
		ui.call("present")
	else:
		ui.visible = true


func _hide_choice() -> void:
	var ui: Node = find_child("ChoiceUI", true, false)
	if ui == null:
		return
	if ui.has_method("dismiss"):
		ui.call("dismiss")
	else:
		ui.visible = false


func _confirm_choice(cue: String, whisper_key: String) -> void:
	# Stay on the sandbar for the confirm line. Immediate goto skipped it.
	_whisper(whisper_key)
	_free_balloon()
	var resource := _load_dialogue()
	if resource == null:
		_travel_to_cardena()
		return
	_talking = true
	if _try_balloon(resource, cue):
		return
	_talking = false
	_travel_to_cardena()


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


func _free_balloon() -> void:
	var roots: Array[Node] = [self]
	var tree := get_tree()
	if tree:
		roots.append(tree.root)
		if tree.current_scene:
			roots.append(tree.current_scene)
	var seen: Dictionary = {}
	for root in roots:
		if root == null or seen.has(root):
			continue
		seen[root] = true
		for node in root.find_children("*", "TalkBalloon", true, false):
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()


func _travel_to_cardena() -> void:
	if not _resolved or _left:
		return
	var dest := &"a1_cardena"
	if ChapterRunner and ChapterRunner.has_method("can_travel"):
		var flags: PackedStringArray = ChapterRunner.flags if "flags" in ChapterRunner else PackedStringArray()
		if not bool(ChapterRunner.call("can_travel", BEAT_ID, dest, flags)):
			return
	_left = true
	var travelled := false
	if ChapterRunner and ChapterRunner.has_method("travel"):
		travelled = bool(ChapterRunner.travel(dest))
	if not travelled:
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return
	if ChapterRunner and ChapterRunner.has_method("goto"):
		ChapterRunner.goto(dest)


func _connect_offer_zone() -> void:
	var zone: Area3D = get_node_or_null("OfferZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_offer_entered):
		zone.body_entered.connect(_on_offer_entered)


func _on_offer_entered(body: Node) -> void:
	if body != null and body.has_method("facing_dir"):
		start_offer()


func _ensure_roster() -> void:
	if HonorService == null:
		return
	var roster: Variant = HonorService.roster if "roster" in HonorService else null
	if roster != null:
		return
	HonorService.roster = MesnadaRoster.from_starting_seed()


func _load_data() -> void:
	_data = {}
	for path in PackedStringArray([ARCAS_DATA_PATH, BEATS_PATH]):
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


func _tunable_float(key: String) -> float:
	if _data.is_empty():
		_load_data()
	return float(_data.get(key, 0.0))


func _has_flag(flag_id: StringName) -> bool:
	if ChapterRunner and ChapterRunner.has_method("has_flag"):
		return bool(ChapterRunner.has_flag(flag_id))
	if ChapterRunner and "flags" in ChapterRunner:
		return String(flag_id) in ChapterRunner.flags
	return false


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
	if not _resolved:
		_show_choice()
		return
	_travel_to_cardena()


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
