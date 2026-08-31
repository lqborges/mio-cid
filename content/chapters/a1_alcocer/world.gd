extends Node3D
## a1_alcocer: occupy, wait, dawn sortie, then sell and divide booty.

const BEAT_ID := &"a1_alcocer"
const DEST := &"a1_embassy1"
const HUB_LOCK := &"hub_lock_cardena"
const HORSE_FLAG := "horse_companion"
const DIVIDE_FLAG := "alcocer_booty_divided"
const TOWN_ID := &"alcocer"
const WIN_EVENT := &"alcocer_sortie_win"
const OCCUPY_KEY := "a1_alcocer.occupy"
const WAIT_KEY := "a1_alcocer.wait"
const DAWN_KEY := "a1_alcocer.dawn"
const WIN_KEY := "a1_alcocer.sortie_win"
const SELL_KEY := "a1_alcocer.sell_done"
const DIVIDE_KEY := "a1_alcocer.divide_done"
const GIFT_KEY := "a1_alcocer.gift_alvar"
const DIALOGUE_PATH := "res://content/chapters/a1_alcocer/alcocer.dialogue"
const BALLOON_PATH := "res://game/ui/talk_balloon.tscn"
const FARIZ_ID := &"fariz"
const GALVE_ID := &"galve"

var holding: Resource
var _raid_started: bool = false
var _occupied: bool = false
var _waited: bool = false
var _sortie_started: bool = false
var _won: bool = false
var _sold: bool = false
var _divided: bool = false
var _garrison_left: int = 0
var _captains_left: int = 0


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
	_hide_plazo_bar()
	_connect_keep_or_sell()
	_connect_booty_divide()
	_hide_keep_or_sell()
	_hide_booty_divide()
	_set_host_active(false)
	_set_zone_monitoring("WaitZone", false)
	_connect_occupy_zone()
	_connect_wait_zone()
	_connect_garrison()
	_bind_taifa_captains()
	_connect_captains()
	_whisper(OCCUPY_KEY)


func start_occupy(_cue: String = "occupy") -> void:
	if _raid_started or _occupied or _won:
		return
	_raid_started = true
	_form_wedge()


func run_occupy() -> void:
	# Headless: take the town without walking OccupyZone.
	start_occupy()
	_garrison_left = 0
	complete_occupy()


func start_wait(_cue: String = "wait") -> void:
	if not _occupied or _waited or _won:
		return
	complete_wait()


func run_wait() -> void:
	# Headless: occupy if needed, then campaign-clock wait (not plazo).
	if not _occupied:
		run_occupy()
	start_wait()


func start_sortie(_cue: String = "dawn") -> void:
	if not _waited or _sortie_started or _won:
		return
	_sortie_started = true
	_whisper(DAWN_KEY)
	_set_host_active(true)
	_form_wedge()


func run_sortie() -> void:
	# Headless: wait if needed, then win the sortie without walking the field.
	if not _waited:
		run_wait()
	start_sortie()
	_captains_left = 0
	complete_sortie()


func start_cue(cue: String) -> void:
	if cue == "occupy" or cue == "take":
		start_occupy()
	elif cue == "wait":
		start_wait()
	elif cue == "dawn" or cue == "sortie":
		start_sortie()
	elif cue == "win":
		complete_sortie()
	elif cue == "keep":
		choose_keep()
	elif cue == "sell":
		choose_sell()
	elif cue == "divide":
		confirm_divide()


func complete_occupy() -> void:
	if _occupied or _won:
		return
	_raid_started = true
	_occupied = true
	_hold_town()
	_whisper(OCCUPY_KEY)
	_set_zone_monitoring("OccupyZone", false)
	_set_zone_monitoring("WaitZone", true)


func complete_wait() -> void:
	if _waited or _won:
		return
	if not _occupied:
		complete_occupy()
	_waited = true
	_whisper(WAIT_KEY)
	if CampaignClock and CampaignClock.has_method("rest_camp"):
		CampaignClock.rest_camp()
	_set_zone_monitoring("WaitZone", false)
	start_sortie()


func complete_sortie() -> void:
	if _won:
		return
	if not _waited:
		complete_wait()
	_sortie_started = true
	_won = true
	_whisper(WIN_KEY)
	var honor := _honor()
	if honor and honor.has_method("apply_id"):
		honor.apply_id(WIN_EVENT)
	_show_keep_or_sell()


func _hold_town() -> void:
	_load_holding()
	if holding == null:
		return
	# take_event_id is the sortie win; occupy must not apply it.
	holding.held = true
	holding.sold = false
	holding.days_held = 0


func choose_keep() -> void:
	if _divided:
		return
	if not _won:
		complete_sortie()
	var ui := _keep_or_sell()
	if ui and ui.has_method("_on_keep"):
		ui.call("_on_keep")
		return
	_on_keep_or_sell(&"keep", {})


func choose_sell() -> void:
	if _divided:
		return
	if not _won:
		complete_sortie()
	var ui := _keep_or_sell()
	if ui and ui.has_method("_on_sell"):
		ui.call("_on_sell")
		return
	_on_keep_or_sell(&"sell", {})


func confirm_divide(gift_alvar: bool = false) -> void:
	if _divided:
		return
	if not _sold:
		choose_sell()
	var ui := _booty_divide()
	if ui:
		if ui.has_method("set_gift_to_alvar"):
			ui.call("set_gift_to_alvar", gift_alvar)
		if ui.has_method("confirm"):
			ui.call("confirm")
			return
	_finish_divide({})


func run_divide(gift_alvar: bool = false) -> void:
	# Headless: win, sell, confirm the split.
	if not _won:
		run_sortie()
	confirm_divide(gift_alvar)


func _on_keep_or_sell(choice: StringName, result: Dictionary) -> void:
	if choice == &"keep":
		_finish_keep(result)
	elif choice == &"sell":
		_finish_sell(result)


func _finish_keep(result: Dictionary) -> void:
	if _divided:
		return
	if result.get("hard_fail", &"") != &"":
		_hide_keep_or_sell()
		_hide_booty_divide()


func _finish_sell(_result: Dictionary) -> void:
	if _divided or _sold:
		return
	_sold = true
	_hide_keep_or_sell()
	_whisper(SELL_KEY)
	if holding and holding.has_method("sell") and not bool(holding.get("sold")):
		holding.sell({}, false)
	_show_booty_divide()


func _on_booty_confirmed(split: Dictionary) -> void:
	_finish_divide(split)


func _finish_divide(split: Dictionary) -> void:
	if _divided:
		return
	_divided = true
	_sold = true
	_hide_keep_or_sell()
	_hide_booty_divide()
	if bool((split if split else {}).get("gift_to_alvar", false)):
		_whisper(GIFT_KEY)
	else:
		_whisper(DIVIDE_KEY)
	if ChapterRunner and ChapterRunner.has_method("add_flag"):
		ChapterRunner.add_flag(DIVIDE_FLAG)
	_leave_for_embassy()


func _leave_for_embassy() -> void:
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


func _connect_occupy_zone() -> void:
	var zone: Area3D = get_node_or_null("OccupyZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_occupy_entered):
		zone.body_entered.connect(_on_occupy_entered)


func _on_occupy_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.is_in_group("horse_companion") or body.has_method("facing_dir"):
		start_occupy()


func _connect_wait_zone() -> void:
	var zone: Area3D = get_node_or_null("WaitZone") as Area3D
	if zone and not zone.body_entered.is_connected(_on_wait_entered):
		zone.body_entered.connect(_on_wait_entered)


func _on_wait_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("player") or body.has_method("facing_dir"):
		start_wait()


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
		complete_occupy()


func _connect_captains() -> void:
	_captains_left = 0
	for node in [_captain_node("Fariz"), _captain_node("Galve")]:
		if node == null:
			continue
		var hurt: Node = node.get_node_or_null("HurtBox")
		if hurt == null or not hurt.has_signal("died"):
			continue
		_captains_left += 1
		if not hurt.died.is_connected(_on_captain_died):
			hurt.died.connect(_on_captain_died)


func _on_captain_died() -> void:
	_captains_left = maxi(0, _captains_left - 1)
	if _sortie_started and _captains_left <= 0:
		complete_sortie()


func _bind_taifa_captains() -> void:
	# Combat / unkillable come from fariz.json and galve.json, not this script.
	_apply_captain_stats(_captain_node("Fariz"), FARIZ_ID)
	_apply_captain_stats(_captain_node("Galve"), GALVE_ID)


func _apply_captain_stats(node: Node, character_id: StringName) -> void:
	if node == null:
		return
	var member := MesnadaMember.from_id(character_id)
	if member == null:
		return
	if "character_id" in node:
		node.set("character_id", character_id)
	if "unkillable" in node:
		node.set("unkillable", member.unkillable)
	var hurt: Node = node.get_node_or_null("HurtBox")
	if member.unkillable or hurt == null:
		return
	if "max_hp" in hurt:
		hurt.max_hp = member.combat
		hurt.hp = member.combat


func _captain_node(node_name: String) -> Node:
	var host: Node = get_node_or_null("Host")
	if host:
		var found: Node = host.get_node_or_null(node_name)
		if found:
			return found
	return get_node_or_null(node_name)


func _set_host_active(active: bool) -> void:
	var host: Node = get_node_or_null("Host")
	if host == null:
		return
	host.visible = active
	host.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _set_zone_monitoring(zone_name: String, on: bool) -> void:
	var zone: Area3D = get_node_or_null(zone_name) as Area3D
	if zone:
		zone.monitoring = on


func _hide_plazo_bar() -> void:
	var bar: Node = find_child("PlazoBar", true, false)
	if bar:
		bar.visible = false


func _connect_keep_or_sell() -> void:
	var ui := _keep_or_sell()
	if ui == null:
		return
	if "defer_split" in ui:
		ui.set("defer_split", true)
	if ui.has_signal("resolved") and not ui.resolved.is_connected(_on_keep_or_sell):
		ui.resolved.connect(_on_keep_or_sell)


func _connect_booty_divide() -> void:
	var ui := _booty_divide()
	if ui == null:
		return
	if ui.has_signal("confirmed") and not ui.confirmed.is_connected(_on_booty_confirmed):
		ui.confirmed.connect(_on_booty_confirmed)


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


func _show_booty_divide() -> void:
	var ui := _booty_divide()
	if ui == null:
		return
	_load_holding()
	if ui.has_method("bind_holding"):
		ui.bind_holding(holding)
	ui.visible = true


func _hide_booty_divide() -> void:
	var ui := _booty_divide()
	if ui:
		ui.visible = false


func _keep_or_sell() -> Node:
	return find_child("KeepOrSell", true, false)


func _booty_divide() -> Node:
	return find_child("BootyDivide", true, false)


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
