extends Node3D
## a1_castejon: dawn take, loot, forced sell. Keep is Alfonso wrath, not flavor.
# Raid, not a feed night. Álvar's Henares sack is an off-map report.

const BEAT_ID := &"a1_castejon"
const DEST := &"a1_alcocer"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const TOWN_ID := &"castejon"
const TAKE_EVENT := &"castejon_take"
const SELL_EVENT := &"castejon_sell"
const KEEP_EVENT := &"castejon_keep"
const DAWN_KEY := "a1_castejon.dawn"
const TAKE_KEY := "a1_castejon.take"
const ALVAR_KEY := "a1_castejon.alvar_henares"
const SELL_KEY := "a1_castejon.sell_done"
const KEEP_KEY := "a1_castejon.keep_fail"
const DIALOGUE_PATH := "res://content/chapters/a1_castejon/castejon.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"

var holding: Resource
var _raid_started: bool = false
var _taken: bool = false
var _looted: bool = false
var _resolved: bool = false
var _garrison_left: int = 0


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
	_load_holding()
	_bind_mesnada()
	_connect_take_zone()
	_connect_garrison()
	_connect_keep_or_sell()
	_hide_keep_or_sell()
	_whisper(DAWN_KEY)


func start_take(_cue: String = "dawn") -> void:
	if _raid_started or _taken or _resolved:
		return
	_raid_started = true
	_form_wedge()


func run_take() -> void:
	# Headless: raid without walking TakeZone. Does not choose keep/sell.
	start_take()
	_garrison_left = 0
	complete_take()


func start_cue(cue: String) -> void:
	if cue == "take" or cue == "dawn":
		start_take()
	elif cue == "loot":
		complete_take()
	elif cue == "keep":
		choose_keep()
	elif cue == "sell":
		choose_sell()


func complete_take() -> void:
	if _taken or _resolved:
		return
	_raid_started = true
	_taken = true
	_loot()
	_report_alvar()
	_show_keep_or_sell()


func choose_keep() -> void:
	if _resolved:
		return
	if not _taken:
		complete_take()
	var ui := _keep_or_sell()
	if ui and ui.has_method("_on_keep"):
		ui.call("_on_keep")
		return
	_finish_keep({})


func choose_sell() -> void:
	if _resolved:
		return
	if not _taken:
		complete_take()
	var ui := _keep_or_sell()
	if ui and ui.has_method("_on_sell"):
		ui.call("_on_sell")
		return
	_finish_sell({})


func _on_keep_or_sell(choice: StringName, result: Dictionary) -> void:
	if choice == &"keep":
		_finish_keep(result)
	elif choice == &"sell":
		_finish_sell(result)


func _finish_keep(_result: Dictionary) -> void:
	if _resolved:
		return
	_resolved = true
	_hide_keep_or_sell()
	_whisper(KEEP_KEY)
	var honor := _honor()
	if honor and honor.has_method("apply_id"):
		honor.apply_id(KEEP_EVENT)
	# Stay is Alfonso wrath, not a flavor line.


func _finish_sell(_result: Dictionary) -> void:
	if _resolved:
		return
	_resolved = true
	_hide_keep_or_sell()
	_whisper(SELL_KEY)
	if holding and holding.has_method("sell") and not bool(holding.get("sold")):
		holding.sell()
	_leave_for_alcocer()


func _loot() -> void:
	if _looted:
		return
	_looted = true
	_load_holding()
	if holding and holding.has_method("occupy") and not bool(holding.get("held")):
		holding.occupy()
	_whisper(TAKE_KEY)


func _report_alvar() -> void:
	# Off-map whisper / report UI. Not a second playable map.
	_whisper(ALVAR_KEY)
	var report: Node = find_child("AlvarReport", true, false)
	if report:
		report.visible = true
		var line: Label = report.get_node_or_null("Line") as Label
		if line:
			line.text = _loc(ALVAR_KEY)
			line.visible = true


func _leave_for_alcocer() -> void:
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


func _connect_take_zone() -> void:
	var zone: Area3D = get_node_or_null("TakeZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_take_entered):
		zone.body_entered.connect(_on_take_entered)


func _on_take_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_take()


func _connect_garrison() -> void:
	var garrison: Node = get_node_or_null("Garrison")
	if garrison == null:
		return
	_garrison_left = 0
	for child in garrison.get_children():
		var hurt: Node = child.get_node_or_null("HurtBox")
		if hurt == null or not hurt.has_signal("died"):
			continue
		_garrison_left += 1
		if not hurt.died.is_connected(_on_dummy_died):
			hurt.died.connect(_on_dummy_died)


func _on_dummy_died() -> void:
	_garrison_left = maxi(0, _garrison_left - 1)
	if _raid_started and _garrison_left <= 0:
		complete_take()


func _connect_keep_or_sell() -> void:
	var ui := _keep_or_sell()
	if ui == null:
		return
	if ui.has_signal("resolved") and not ui.resolved.is_connected(_on_keep_or_sell):
		ui.resolved.connect(_on_keep_or_sell)


func _show_keep_or_sell() -> void:
	var ui := _keep_or_sell()
	if ui == null:
		return
	_load_holding()
	if ui.has_method("bind_holding"):
		ui.bind_holding(holding)
	ui.visible = true


func _hide_keep_or_sell() -> void:
	var ui := _keep_or_sell()
	if ui:
		ui.visible = false


func _keep_or_sell() -> Node:
	return find_child("KeepOrSell", true, false)


func _form_wedge() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"charge")


func _bind_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	var roster: Variant = _roster()
	if roster and mesnada.has_method("bind_roster"):
		mesnada.bind_roster(roster)
	# Refuse-branch: never fake a full lanza wall when mouths are already gone.
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


func _load_holding() -> void:
	if holding != null:
		return
	holding = TownHolding.from_id(TOWN_ID)


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


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


func _loc(key: String) -> String:
	if Loc and Loc.has_method("text"):
		return str(Loc.text(key))
	return key


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
