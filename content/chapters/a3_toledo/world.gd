extends Node3D
## a3_toledo: Cortes de Toledo. García first, then the three asks. Not a duel.

const BEAT_ID := &"a3_toledo"
const DEST := &"a3_valencia_wait"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const HORSE_ID := &"babieca"
const HORSE_KEY := "a2_jeronimo.horse_name"
const PLACE_KEY := "a3_toledo.place_name"
const TABLE_KEY := "a3_toledo.table"
const WAIT_KEY := "a3_toledo.wait"
const GARCIA_DONE_KEY := "a3_toledo.garcia_done"
const ASK1_KEY := "a3_toledo.ask1_done"
const ASK2_KEY := "a3_toledo.ask2_done"
const ASK3_KEY := "a3_toledo.ask3_done"
const GIVE_KEY := "a3_toledo.give_swords"
const PRINCES_KEY := "a3_toledo.princes"
const GARCIA_PATH := "res://data/speech/garcia_preliminary.json"
const TRIAL_PATH := "res://data/speech/toledo.json"
const PRINCES_PATH := "res://data/speech/navarre_aragon.json"
const DEST_SCENE := "res://content/chapters/a3_valencia_wait/world.tscn"
const ASK_EVENTS := [&"toledo_ask1_swords", &"toledo_ask2_dowry", &"toledo_ask3_riepto"]
const ASK_WHISPERS := ["a3_toledo.ask1_done", "a3_toledo.ask2_done", "a3_toledo.ask3_done"]
const BETROTHAL_FLAGS := ["elvira_betrothed_navarre", "sol_betrothed_aragon"]

var _garcia_started: bool = false
var _garcia_done: bool = false
var _asks_started: bool = false
var _asks_won: bool = false
var _swords_in_court: bool = false
var _swords_given: bool = false
var _princes_asked: bool = false
var _ask_honored: Array[bool] = [false, false, false]
var _left: bool = false
var _steel: bool = false


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
	_hold_mesnada()
	_load_garcia()
	_load_toledo()
	_connect_trials()
	_connect_zones()
	_show_place_name()
	_name_horse()
	_label_people()
	_whisper(TABLE_KEY)


func start_cue(cue: String) -> void:
	match cue:
		"garcia":
			start_garcia()
		"asks", "cortes":
			start_asks()
		"garcia_legal":
			run_garcia_legal()
		"garcia_mesura":
			run_garcia_mesura()
		"garcia_ira":
			run_garcia_ira()
		"legal":
			run_legal()
		"mesura":
			run_mesura()
		"ira":
			run_ira()
		"swords", "swords_legal":
			run_swords_legal()
		"dowry", "dowry_legal":
			run_dowry_legal()
		"riepto", "riepto_legal":
			run_riepto_legal()
		"skip_to_riepto":
			run_skip_to_riepto()
		"draw_steel", "steel":
			run_draw_steel()
		"give_swords":
			give_swords_to_champions()
		"princes", "navarre":
			play_navarre_aragon()


func start_garcia(_cue: String = "garcia") -> void:
	if _garcia_started or _garcia_done or _steel:
		return
	_garcia_started = true
	_freeze_cid(true)
	_bind_ui(garcia_trial())
	_whisper(TABLE_KEY)


func start_asks(_cue: String = "asks") -> void:
	if _asks_started or _asks_won or _steel:
		return
	_asks_started = true
	_freeze_cid(true)
	_bind_ui(trial())
	_whisper("a3_toledo.ask1_prompt")


func run_garcia_legal() -> void:
	_submit_garcia(&"legal")


func run_garcia_mesura() -> void:
	_submit_garcia(&"mesura")


func run_garcia_ira() -> void:
	_submit_garcia(&"ira")


func run_legal() -> void:
	if not _garcia_done:
		run_garcia_legal()
		return
	_submit_asks(&"legal")


func run_mesura() -> void:
	if not _garcia_done:
		run_garcia_mesura()
		return
	_submit_asks(&"mesura")


func run_ira() -> void:
	if not _garcia_done:
		run_garcia_ira()
		return
	_submit_asks(&"ira")


func run_swords_legal() -> void:
	_submit_asks_at(0, &"legal")


func run_dowry_legal() -> void:
	_submit_asks_at(1, &"legal")


func run_riepto_legal() -> void:
	_submit_asks_at(2, &"legal")


func run_skip_to_riepto() -> void:
	_submit_asks(&"skip_to_riepto")


func run_draw_steel() -> void:
	if not _garcia_done:
		_submit_garcia(&"draw_steel")
		return
	_submit_asks(&"draw_steel")


func try_travel_wait() -> bool:
	if not _asks_won:
		return false
	if not _dest_ready():
		_whisper(WAIT_KEY)
		return false
	return _travel(DEST)


func can_leave_to_wait() -> bool:
	if not _asks_won:
		return false
	return _can_travel(DEST)


func garcia_done() -> bool:
	return _garcia_done


func asks_won() -> bool:
	return _asks_won


func swords_in_court() -> bool:
	return _phase_is(&"tizona", "IN_COURT") and _phase_is(&"colada", "IN_COURT")


func swords_in_champion_hand() -> bool:
	return _phase_is(&"tizona", "IN_CHAMPION_HAND") and _phase_is(&"colada", "IN_CHAMPION_HAND")


func princes_asked() -> bool:
	return _princes_asked


func garcia_trial() -> SpeechTrial:
	return get_node_or_null("GarciaTrial") as SpeechTrial


func trial() -> SpeechTrial:
	return get_node_or_null("SpeechTrial") as SpeechTrial


func place_name_text() -> String:
	return _loc(PLACE_KEY)


func give_swords_to_champions() -> void:
	if _swords_given:
		return
	_set_sword_phase(&"tizona", "IN_CHAMPION_HAND")
	_set_sword_phase(&"colada", "IN_CHAMPION_HAND")
	_swords_given = true
	_set_flag(&"swords_to_champions")
	_whisper(GIVE_KEY)


func play_navarre_aragon() -> void:
	if _princes_asked:
		return
	if not FileAccess.file_exists(PRINCES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRINCES_PATH))
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	if str(data.get("type", "")) == "speech_trial":
		return
	if bool(data.get("skill_check", false)):
		return
	_princes_asked = true
	var flags: Variant = data.get("set_flags", BETROTHAL_FLAGS)
	if flags is Array:
		for flag in flags:
			_set_flag(StringName(str(flag)))
	_whisper(PRINCES_KEY)


func _submit_garcia(line_id: StringName) -> void:
	if _garcia_done or _steel:
		return
	start_garcia()
	var node := garcia_trial()
	if node == null:
		return
	node.submit_line(node.current_index(), line_id)


func _submit_asks(line_id: StringName) -> void:
	if _asks_won or _steel:
		return
	start_asks()
	var node := trial()
	if node == null:
		return
	node.submit_line(node.current_index(), line_id)


func _submit_asks_at(ask_index: int, line_id: StringName) -> void:
	if _asks_won or _steel:
		return
	start_asks()
	var node := trial()
	if node == null:
		return
	node.submit_line(ask_index, line_id)


func _load_garcia() -> void:
	_load_trial(garcia_trial(), "GarciaTrial", GARCIA_PATH)


func _load_toledo() -> void:
	_load_trial(trial(), "SpeechTrial", TRIAL_PATH)


func _load_trial(node: SpeechTrial, node_name: String, path: String) -> void:
	if node == null:
		node = SpeechTrial.new()
		node.name = node_name
		add_child(node)
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	node.win_threshold = float(data.get("win_threshold", 0.0))
	var asks: Array[SpeechAsk] = []
	var raw_asks: Variant = data.get("asks", [])
	if raw_asks is Array:
		for item in raw_asks:
			if item is Dictionary:
				asks.append(_ask_from_dict(item))
	node.asks = asks


func _ask_from_dict(data: Dictionary) -> SpeechAsk:
	var ask := SpeechAsk.new()
	ask.id = StringName(str(data.get("id", "")))
	ask.prompt_key = StringName(str(data.get("prompt_key", "")))
	ask.counts_toward_win = bool(data.get("counts_toward_win", true))
	var lines: Array[SpeechLine] = []
	var raw_lines: Variant = data.get("lines", [])
	if raw_lines is Array:
		for item in raw_lines:
			if item is Dictionary:
				lines.append(_line_from_dict(item))
	ask.lines = lines
	return ask


func _line_from_dict(data: Dictionary) -> SpeechLine:
	var line := SpeechLine.new()
	line.id = StringName(str(data.get("id", "")))
	line.text_key = StringName(str(data.get("text_key", "")))
	line.legal = float(data.get("legal", 0.0))
	line.mesura = float(data.get("mesura", 0.0))
	line.ira = float(data.get("ira", 0.0))
	line.vo_id = StringName(str(data.get("vo_id", "")))
	var tags := PackedStringArray()
	var raw_tags: Variant = data.get("tags", [])
	if raw_tags is Array:
		for tag in raw_tags:
			tags.append(str(tag))
	line.tags = tags
	return line


func _connect_trials() -> void:
	var garcia := garcia_trial()
	if garcia:
		if not garcia.trial_won.is_connected(_on_garcia_won):
			garcia.trial_won.connect(_on_garcia_won)
		if not garcia.trial_failed.is_connected(_on_garcia_failed):
			garcia.trial_failed.connect(_on_garcia_failed)
		if not garcia.steel_drawn_fail.is_connected(_on_steel):
			garcia.steel_drawn_fail.connect(_on_steel)
	var node := trial()
	if node == null:
		return
	if not node.ask_resolved.is_connected(_on_ask_resolved):
		node.ask_resolved.connect(_on_ask_resolved)
	if not node.trial_won.is_connected(_on_trial_won):
		node.trial_won.connect(_on_trial_won)
	if not node.trial_failed.is_connected(_on_trial_failed):
		node.trial_failed.connect(_on_trial_failed)
	if not node.steel_drawn_fail.is_connected(_on_steel):
		node.steel_drawn_fail.connect(_on_steel)


func _bind_ui(node: SpeechTrial) -> void:
	var ui: Node = find_child("SpeechTrialUI", true, false)
	if ui and ui.has_method("bind"):
		ui.call("bind", node)


func _hide_trial_ui() -> void:
	var ui: Node = find_child("SpeechTrialUI", true, false)
	if ui == null:
		return
	if ui.has_method("bind"):
		ui.call("bind", null)
	ui.visible = false


func _on_garcia_won() -> void:
	if _garcia_done or _steel:
		return
	_garcia_done = true
	_set_flag(&"garcia_done")
	_whisper(GARCIA_DONE_KEY)
	start_asks()


func _on_garcia_failed() -> void:
	if _steel:
		_finish_steel()


func _on_ask_resolved(index: int, _tags: PackedStringArray) -> void:
	if index < 0 or index >= ASK_EVENTS.size():
		return
	if _ask_honored[index]:
		return
	_ask_honored[index] = true
	if index == 0:
		_return_swords_to_court()
	_apply_honor(ASK_EVENTS[index])
	_whisper(ASK_WHISPERS[index])


func _on_trial_won() -> void:
	if _steel or _asks_won:
		return
	_asks_won = true
	_set_flag(&"toledo_done")
	give_swords_to_champions()
	play_navarre_aragon()
	_finish_beat()


func _on_trial_failed() -> void:
	if _steel:
		_finish_steel()


func _on_steel() -> void:
	_steel = true
	_finish_steel()


func _finish_steel() -> void:
	_freeze_cid(false)
	_hide_trial_ui()


func _return_swords_to_court() -> void:
	if _swords_in_court:
		return
	_set_sword_phase(&"tizona", "IN_COURT")
	_set_sword_phase(&"colada", "IN_COURT")
	_swords_in_court = true
	_set_flag(&"swords_in_court")


func _set_sword_phase(item_id: StringName, phase_name: String) -> void:
	var item: SwordItem = null
	if GameState and GameState.has_method("sword"):
		item = GameState.sword(item_id)
	if item == null:
		return
	item.set_phase_name(phase_name)
	if EventBus and EventBus.has_signal("sword_phase_changed"):
		EventBus.sword_phase_changed.emit(item.id, int(item.phase))


func _phase_is(item_id: StringName, phase_name: String) -> bool:
	var item: SwordItem = null
	if GameState and GameState.has_method("sword"):
		item = GameState.sword(item_id)
	if item == null:
		return false
	return item.phase_name() == phase_name


func _finish_beat() -> void:
	_freeze_cid(false)
	_hide_trial_ui()
	if _left or _steel:
		return
	# ChapterRunner.travel emits beat_completed; only emit here if travel does not run.
	if not _dest_ready() or not _travel(DEST):
		if not _dest_ready():
			_whisper(WAIT_KEY)
		if EventBus and EventBus.has_signal("beat_completed"):
			EventBus.beat_completed.emit(BEAT_ID)
		_checkpoint()


func _dest_ready() -> bool:
	return ResourceLoader.exists(DEST_SCENE)


func _connect_zones() -> void:
	_connect_zone("CourtZone", _on_court_entered)


func _connect_zone(node_name: String, cb: Callable) -> void:
	var zone: Area3D = get_node_or_null(node_name) as Area3D
	if zone and not zone.body_entered.is_connected(cb):
		zone.body_entered.connect(cb)


func _on_court_entered(body: Node) -> void:
	if body == null or _garcia_started or _asks_started:
		return
	if not (body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir")):
		return
	start_garcia()


func _freeze_cid(on: bool) -> void:
	var cid: Node = get_node_or_null("Cid")
	if cid == null:
		return
	if cid.has_method("set_chapter_locked"):
		cid.call("set_chapter_locked", on)
	elif "chapter_locked" in cid:
		cid.chapter_locked = on


func _hold_mesnada() -> void:
	var mesnada: Node = get_node_or_null("Mesnada")
	if mesnada == null:
		return
	if mesnada.has_method("set_order"):
		mesnada.set_order(&"hold")
	if mesnada.has_method("plant_banner_at_leader"):
		mesnada.plant_banner_at_leader()


func _checkpoint() -> void:
	if SaveService == null:
		return
	if SaveService.has_method("autosave"):
		SaveService.autosave()
	if SaveService.has_method("autosave_chapter"):
		SaveService.autosave_chapter(BEAT_ID)


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


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _show_place_name() -> void:
	var label: Label3D = get_node_or_null("PlaceName") as Label3D
	if label == null:
		return
	label.text = place_name_text()
	label.visible = true


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
	_set_label("Alfonso/Name", "char.alfonso")
	_set_label("GarciaOrdonez/Name", "char.garcia_ordonez")
	_set_label("FerranGonzalez/Name", "char.ferran_gonzalez")
	_set_label("DiegoGonzalez/Name", "char.diego_gonzalez")
	_set_label("Elvira/Name", "char.elvira")
	_set_label("Sol/Name", "char.sol")
	_set_label("PeroBermudez/Name", "char.pero_bermudez")
	_set_label("MartinAntolinez/Name", "char.martin_antolinez")


func _set_label(path: String, key: String) -> void:
	var label: Label3D = get_node_or_null(path) as Label3D
	if label:
		label.text = _loc(key)


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


func _loc(key: String) -> String:
	var loc := _autoload("Loc")
	if loc != null and loc.has_method("text"):
		return str(loc.text(key))
	return key


func _runner() -> Node:
	return _autoload("ChapterRunner")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(node_name))
	return get_node_or_null(NodePath("/root/%s" % node_name))
