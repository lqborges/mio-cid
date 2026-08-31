extends Node3D
## a1_embassy1: Álvar takes a horse gift to Alfonso and returns.

const BEAT_ID := &"a1_embassy1"
const DEST := &"a1_poyo"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const DONE_FLAG := "embassy1_done"
const LANDS_FLAG := "minaya_lands_restored"
const FLOOD_FLAG := "recruitment_flood"
const GIFT_PATH := "res://data/gifts/embassy_1.json"
const DIALOGUE_PATH := "res://content/chapters/a1_embassy1/embassy1.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const PROMPT_KEY := "a1_embassy1.prompt"
const LEAVE_KEY := "a1_embassy1.alvar_leave"
const RETURN_KEY := "a1_embassy1.alvar_return"
const LANDS_KEY := "a1_embassy1.lands_restored"
const BLOCKED_KEY := "ui.embassy_ledger.blocked"

var gift: GiftToKing
var last_event: HonorEvent
var last_choice: StringName = &""

var _gifted: bool = false
var _alvar_gone: bool = false
var _returned: bool = false
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
	_bind_mesnada()
	_hide_plazo_bar()
	_load_gift()
	_connect_gift_zone()
	_connect_ledger()
	_hide_ledger()
	_whisper(PROMPT_KEY)


func start_gift(_cue: String = "gift") -> void:
	if _gifted:
		return
	_show_ledger()


func run_gift(choice_id: StringName) -> HonorEvent:
	# Headless: skip the leave cinematic so tests stay green.
	_skip_cinematic = true
	if not _gifted:
		start_gift()
	return confirm_gift(choice_id)


func attempt_gift(choice_id: StringName) -> HonorEvent:
	# Tests must call resolve even when the ledger greys the row.
	_skip_cinematic = true
	_load_gift()
	var honor := _honor_state()
	var treasury := _treasury_state()
	if gift == null:
		return HonorEvent.new()
	var ev: HonorEvent = gift.resolve(choice_id, honor, treasury)
	if ev == null or String(ev.id).is_empty():
		var opt: GiftOption = gift.option(choice_id)
		_whisper(_blocked_loc(_block_reason(opt, treasury, honor)))
		return ev if ev else HonorEvent.new()
	_finish_gift(choice_id, ev)
	return ev


func confirm_gift(choice_id: StringName) -> HonorEvent:
	if _gifted:
		return last_event
	start_gift()
	var ui := _ledger()
	if ui:
		if ui.has_method("select"):
			ui.call("select", choice_id)
		if ui.has_method("confirm"):
			var ev: HonorEvent = ui.call("confirm")
			return ev
	return attempt_gift(choice_id)


func start_cue(cue: String) -> void:
	if cue == "gift" or cue == "ledger":
		start_gift()
	elif cue == "leave":
		_alvar_leave()
	elif cue == "return":
		complete_return()


func complete_return() -> void:
	if _returned:
		return
	if not _gifted:
		return
	_alvar_return()
	_set_return_flags()
	_leave_for_poyo()


func _on_ledger_confirmed(choice_id: StringName, event: HonorEvent) -> void:
	_finish_gift(choice_id, event)


func _on_ledger_blocked(choice_id: StringName, reason: StringName = &"") -> void:
	last_choice = choice_id
	_whisper(_blocked_loc(reason))


func _finish_gift(choice_id: StringName, event: HonorEvent) -> void:
	if _gifted:
		return
	if event == null or String(event.id).is_empty():
		_whisper(BLOCKED_KEY)
		return
	_gifted = true
	last_choice = choice_id
	last_event = event
	_hide_ledger()
	_alvar_leave()
	_schedule_return()


func _schedule_return() -> void:
	if _skip_cinematic:
		complete_return()
		return
	var player: AnimationPlayer = get_node_or_null("LeaveCinematic") as AnimationPlayer
	if player == null or not player.is_playing():
		complete_return()
		return
	if not player.animation_finished.is_connected(_on_leave_cinematic_finished):
		player.animation_finished.connect(_on_leave_cinematic_finished)


func _on_leave_cinematic_finished(_anim: StringName = &"") -> void:
	var player: AnimationPlayer = get_node_or_null("LeaveCinematic") as AnimationPlayer
	if player and player.animation_finished.is_connected(_on_leave_cinematic_finished):
		player.animation_finished.disconnect(_on_leave_cinematic_finished)
	complete_return()


func _alvar_leave() -> void:
	if _alvar_gone:
		return
	_alvar_gone = true
	_set_alvar_present(false)
	if not _skip_cinematic:
		var player: AnimationPlayer = get_node_or_null("LeaveCinematic") as AnimationPlayer
		if player and not player.animation_finished.is_connected(_on_leave_cinematic_finished):
			player.animation_finished.connect(_on_leave_cinematic_finished)
	_play_cinematic()
	_whisper(LEAVE_KEY)


func _alvar_return() -> void:
	_returned = true
	_alvar_gone = false
	_set_alvar_present(true)
	_whisper(RETURN_KEY)
	_whisper(LANDS_KEY)


func _set_alvar_present(present: bool) -> void:
	var alvar: Node = get_node_or_null("AlvarFanez")
	if alvar == null:
		return
	alvar.visible = present
	if alvar is CollisionObject3D:
		var body := alvar as CollisionObject3D
		if not body.has_meta("alvar_layer"):
			body.set_meta("alvar_layer", body.collision_layer)
		body.collision_layer = int(body.get_meta("alvar_layer")) if present else 0
	alvar.process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED


func _set_return_flags() -> void:
	if ChapterRunner == null or not ChapterRunner.has_method("add_flag"):
		return
	ChapterRunner.add_flag(DONE_FLAG)
	ChapterRunner.add_flag(LANDS_FLAG)
	ChapterRunner.add_flag(FLOOD_FLAG)


func _leave_for_poyo() -> void:
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


func _connect_gift_zone() -> void:
	var zone: Area3D = get_node_or_null("GiftZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_gift_entered):
		zone.body_entered.connect(_on_gift_entered)


func _on_gift_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_gift()


func _connect_ledger() -> void:
	var ui := _ledger()
	if ui == null:
		return
	_load_gift()
	if ui.has_method("bind_gift"):
		ui.bind_gift(gift)
	if ui.has_signal("confirmed") and not ui.confirmed.is_connected(_on_ledger_confirmed):
		ui.confirmed.connect(_on_ledger_confirmed)
	if ui.has_signal("blocked") and not ui.blocked.is_connected(_on_ledger_blocked):
		ui.blocked.connect(_on_ledger_blocked)


func _show_ledger() -> void:
	var ui := _ledger()
	if ui == null:
		return
	_load_gift()
	if ui.has_method("bind_gift"):
		ui.bind_gift(gift)
	ui.visible = true


func _hide_ledger() -> void:
	var ui := _ledger()
	if ui:
		ui.visible = false


func _ledger() -> Node:
	return find_child("EmbassyLedger", true, false)


func _load_gift() -> void:
	if gift != null:
		return
	gift = GiftToKing.from_file(GIFT_PATH)


func _play_cinematic() -> void:
	var player: AnimationPlayer = get_node_or_null("LeaveCinematic") as AnimationPlayer
	if player and player.has_animation("leave_return"):
		player.play("leave_return")


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


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


func _honor_state() -> HonorState:
	var honor := _honor()
	if honor and "state" in honor:
		var state: Variant = honor.get("state")
		if state is HonorState:
			return state
	return null


func _treasury_state() -> Treasury:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var service: Node = (loop as SceneTree).root.get_node_or_null(NodePath("TreasuryService"))
		if service and "state" in service:
			var state: Variant = service.get("state")
			if state is Treasury:
				return state
	return null


func _block_reason(opt: GiftOption, treasury: Treasury, honor: HonorState) -> StringName:
	if opt == null:
		return &"horses"
	if opt.has_method("block_reason"):
		return opt.block_reason(treasury, honor)
	return &"horses"


func _blocked_loc(reason: StringName) -> String:
	if reason == &"marks":
		return "ui.embassy_ledger.blocked_marks"
	if reason == &"onores":
		return "ui.embassy_ledger.blocked_onores"
	return BLOCKED_KEY


func _whisper(key: String) -> void:
	var whisper: Node = find_child("HallWhisper", true, false)
	if whisper and whisper.has_method("whisper_key"):
		whisper.call("whisper_key", key)
		return
	if whisper and Loc and whisper.has_method("_show"):
		whisper.call("_show", Loc.text(key))


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
