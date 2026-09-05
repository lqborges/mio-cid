extends CanvasLayer
# Autoload singleton. Do not add class_name.
# Objectives, onboarding, and settings. Persists to user://, not campaign saves.

const CATALOG_SCRIPT := preload("res://game/systems/objectives/objective_catalog.gd")
const TIPS_PATH := "res://data/onboarding/tips.json"
const PLACES_PATH := "res://data/travel/places.json"
const SETTINGS_PATH := "user://player_guide.json"
const IRON := Color(0.18, 0.16, 0.13, 0.92)
const PARCHMENT := Color(0.91, 0.85, 0.72)
const DIM := Color(0.05, 0.04, 0.03, 0.62)
const TRAVEL_HOLD_MSEC := 2400

const DEFAULT_SETTINGS := {
	"reduced_motion": false,
	"shake": true,
	"flash": true,
	"subtitle_size": 18,
	"vol_master": 1.0,
	"vol_vo": 1.0,
	"vol_sfx": 1.0,
	"vol_music": 0.8,
	"vol_ui": 1.0,
	"locale": "es",
}

var catalog: ObjectiveCatalog
var tips: Array = []
var places: Dictionary = {}
var dismissed_tips: PackedStringArray = PackedStringArray()
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _active_tip: String = ""
var _hud_panel: Control
var _hud_title: Label
var _hud_detail: Label
var _hold_bar: ColorRect
var _toast: Control
var _toast_title: Label
var _toast_body: Label
var _travel_panel: Control
var _travel_kicker: Label
var _travel_place: Label
var _travel_dest: String = ""
var _travel_until_msec: int = 0
var _last_chapter: String = ""
var _moved: bool = false
var _interacted: bool = false
var _mesura_held: bool = false
var _dialogue_was_open: bool = false
var _choice_was_open: bool = false
var _blocked_until_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	catalog = CATALOG_SCRIPT.from_file()
	_load_tips()
	_load_places()
	_load_settings()
	_apply_locale()
	_apply_audio()
	_build_hud()
	_build_toast()
	_build_travel()
	var bus := _bus()
	if bus:
		if bus.has_signal("beat_started") and not bus.beat_started.is_connected(_on_beat_started):
			bus.beat_started.connect(_on_beat_started)
		if bus.has_signal("beat_completed") and not bus.beat_completed.is_connected(_on_beat_completed):
			bus.beat_completed.connect(_on_beat_completed)
	_refresh_hud()


func _input(event: InputEvent) -> void:
	InputGlyphs.note_event(event)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		note_moved()


func _process(_delta: float) -> void:
	_poll_onboarding()
	_tick_travel()
	_refresh_hud()


func current_objective() -> Dictionary:
	if catalog == null:
		return {}
	return catalog.current(_chapter_id(), _guide_flags())


func journal_entries() -> Array:
	if catalog == null:
		return []
	return catalog.journal(_chapter_id(), _guide_flags())


func lock_reason(to_id: String) -> String:
	if catalog == null:
		return ""
	var key := catalog.lock_reason(_chapter_id(), to_id, _guide_flags())
	if key.is_empty():
		var runner := _runner()
		if runner != null and runner.has_method("can_travel"):
			if not bool(runner.can_travel(StringName(_chapter_id()), StringName(to_id), _chapter_flags())):
				key = "lock.generic"
	return key


func note_moved() -> void:
	_moved = true


func note_interacted() -> void:
	_interacted = true
	_complete_tip_if("interacted")


func note_mesura() -> void:
	_mesura_held = true
	_complete_tip_if("mesura_held")


func note_blocked(key: String) -> void:
	if _is_main_menu():
		return
	var now := Time.get_ticks_msec()
	if now < _blocked_until_msec:
		return
	_blocked_until_msec = now + 1600
	if _hud_detail:
		_hud_detail.text = _loc(key, "Mesura holds the blade.")


func dismiss_active_tip() -> void:
	if _active_tip.is_empty():
		return
	if _active_tip not in dismissed_tips:
		dismissed_tips.append(_active_tip)
	_active_tip = ""
	_hide_toast()
	_save_settings()


func replay_tips() -> void:
	dismissed_tips = PackedStringArray()
	_active_tip = ""
	_moved = false
	_interacted = false
	_mesura_held = false
	_save_settings()
	_consider_tips()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	if key == "locale":
		_apply_locale()
	_apply_audio()
	_save_settings()


func reduced_motion() -> bool:
	return bool(settings.get("reduced_motion", false))


func shake_enabled() -> bool:
	return bool(settings.get("shake", true)) and not reduced_motion()


func flash_enabled() -> bool:
	return bool(settings.get("flash", true)) and not reduced_motion()


func subtitle_size() -> int:
	return int(settings.get("subtitle_size", 18))


func help_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(InputGlyphs.prompt("click_move", _loc("tip.move.verb", "Mover")))
	lines.append(InputGlyphs.prompt("interact", _loc("hud.interact_verb", "Hablar")))
	lines.append(InputGlyphs.prompt("mesura", _loc("hud.mesura", "Mesura")))
	lines.append(InputGlyphs.prompt("slam", _loc("hud.slam", "Golpe")))
	lines.append(InputGlyphs.prompt("leap", _loc("hud.leap", "Salto")))
	lines.append(InputGlyphs.prompt("dodge", _loc("hud.dodge", "Esquiva")))
	lines.append(InputGlyphs.prompt("shout", _loc("hud.shout", "Grito")))
	lines.append(InputGlyphs.prompt("pause", _loc("ui.pause.title", "Pausa")))
	return lines


func announce_travel(to_id: String) -> void:
	if to_id.is_empty():
		return
	_travel_dest = to_id
	_travel_until_msec = Time.get_ticks_msec() + TRAVEL_HOLD_MSEC
	if _travel_kicker:
		_travel_kicker.text = _loc("travel.arrive", "Llegáis a")
	if _travel_place:
		_travel_place.text = place_title(to_id)
	if _travel_panel:
		_travel_panel.visible = true
	_hide_toast()


func place_title(chapter_id: String) -> String:
	var row: Variant = places.get(chapter_id, {})
	var key := ""
	if row is Dictionary:
		key = str((row as Dictionary).get("title_key", ""))
	if key.is_empty():
		return chapter_id
	return _loc(key, chapter_id)


func travel_visible() -> bool:
	return _travel_panel != null and _travel_panel.visible


func dismiss_travel() -> void:
	_travel_dest = ""
	_travel_until_msec = 0
	if _travel_panel:
		_travel_panel.visible = false


func format_interact_prompt(verb_key: String, fallback: String) -> String:
	var verb := _loc(verb_key, fallback)
	if verb.begins_with("E — ") or verb.begins_with("E - "):
		verb = verb.substr(4)
	return InputGlyphs.prompt("interact", verb)


func _on_beat_started(id: StringName) -> void:
	_last_chapter = String(id)
	if _travel_panel != null and _travel_panel.visible:
		if _travel_dest.is_empty() or String(id) == _travel_dest:
			_travel_until_msec = Time.get_ticks_msec() + 2000
	_consider_tips()
	_refresh_hud()


func _on_beat_completed(_id: StringName) -> void:
	_refresh_hud()


func _poll_onboarding() -> void:
	if _is_main_menu():
		_hide_toast()
		return
	if _stick_moving():
		note_moved()
		_complete_tip_if("moved")
	var dialogue_open := _group_visible("talk_balloon")
	if dialogue_open and not _dialogue_was_open:
		_consider_tips()
	if _dialogue_was_open and not dialogue_open:
		_complete_tip_if("dialogue_closed")
	_dialogue_was_open = dialogue_open
	var choice_open := _group_visible("modal_choice")
	if choice_open and not _choice_was_open:
		_consider_tips()
	if _choice_was_open and not choice_open:
		_complete_tip_if("choice_closed")
	_choice_was_open = choice_open
	if Input.is_action_pressed("mesura"):
		note_mesura()


func _consider_tips() -> void:
	if _is_main_menu():
		_hide_toast()
		return
	if not _active_tip.is_empty():
		return
	var chapter := _chapter_id()
	for item in tips:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		var tip_id := str(row.get("id", ""))
		if tip_id.is_empty() or tip_id in dismissed_tips:
			continue
		if not _tip_ready(row, chapter):
			continue
		_show_tip(row)
		return


func _tip_ready(row: Dictionary, chapter: String) -> bool:
	var when := str(row.get("when", ""))
	var chapters: Variant = row.get("chapters", [])
	if chapters is Array and not (chapters as Array).is_empty():
		if chapter not in chapters:
			return false
	match when:
		"chapter_start":
			return true
		"after":
			return str(row.get("after", "")) in dismissed_tips
		"dialogue_open":
			return _group_visible("talk_balloon")
		"modal_choice":
			return _group_visible("modal_choice")
		_:
			return false


func _complete_tip_if(signal_name: String) -> void:
	if _active_tip.is_empty():
		return
	for item in tips:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		if str(row.get("id", "")) != _active_tip:
			continue
		if str(row.get("complete_on", "")) == signal_name:
			dismiss_active_tip()
			_consider_tips()
		return


func _show_tip(row: Dictionary) -> void:
	_active_tip = str(row.get("id", ""))
	if _toast_title:
		_toast_title.text = _loc(str(row.get("title_key", "")), _active_tip)
	if _toast_body:
		_toast_body.text = _loc(str(row.get("body_key", "")), "")
	if _toast:
		_toast.visible = true


func _hide_toast() -> void:
	if _toast:
		_toast.visible = false


func _tick_travel() -> void:
	if _travel_panel == null or not _travel_panel.visible:
		return
	# New Game calls goto while MainMenu is still current_scene. Keep the
	# card through that deferred change; only drop it if the menu is idle.
	if _is_main_menu() and _travel_dest.is_empty():
		dismiss_travel()
		return
	if Time.get_ticks_msec() < _travel_until_msec:
		return
	if not _travel_dest.is_empty() and _chapter_id() != _travel_dest:
		# Scene change is still queued; keep the card until arrival or timeout.
		if Time.get_ticks_msec() < _travel_until_msec + 1800:
			return
	dismiss_travel()


func _refresh_hud() -> void:
	if _hud_title == null or _hud_panel == null:
		return
	if _is_main_menu():
		_hud_panel.visible = false
		return
	if _travel_panel != null and _travel_panel.visible:
		_hud_panel.visible = false
		return
	var obj := current_objective()
	if obj.is_empty():
		_hud_panel.visible = false
		return
	_hud_panel.visible = true
	_hud_title.text = _loc(str(obj.get("title_key", "")), "")
	var bits: PackedStringArray = PackedStringArray()
	var person := _loc(str(obj.get("person_key", "")), "")
	var place := _loc(str(obj.get("place_key", "")), "")
	var detail := _loc(str(obj.get("detail_key", "")), "")
	if not person.is_empty() and person != str(obj.get("person_key", "")):
		bits.append(person)
	if not place.is_empty() and place != str(obj.get("place_key", "")):
		bits.append(place)
	if not detail.is_empty() and detail != str(obj.get("detail_key", "")):
		bits.append(detail)
	if Time.get_ticks_msec() >= _blocked_until_msec:
		_hud_detail.text = " · ".join(bits)
	_update_mount_hold()


func _guide_flags() -> PackedStringArray:
	var flags := _chapter_flags()
	var extra := _scene_guide_flags()
	for flag in extra:
		if flag not in flags:
			flags.append(flag)
	return flags


func _scene_guide_flags() -> PackedStringArray:
	var out := PackedStringArray()
	var scene := _current_scene()
	if scene == null:
		return out
	if "cheated" in scene or scene.has_method("cheated"):
		if bool(scene.get("_resolved")):
			if scene.has_method("cheated") and bool(scene.call("cheated")):
				out.append("arcas_cheated")
			else:
				out.append("arcas_refused")
	return out


func _chapter_flags() -> PackedStringArray:
	var runner := _runner()
	if runner != null and "flags" in runner:
		var value: Variant = runner.flags
		if value is PackedStringArray:
			return (value as PackedStringArray).duplicate()
		if value is Array:
			var packed := PackedStringArray()
			for item in value:
				packed.append(str(item))
			return packed
	return PackedStringArray()


func _chapter_id() -> String:
	var runner := _runner()
	if runner != null and "current_id" in runner:
		return String(runner.current_id)
	return _last_chapter


func _build_hud() -> void:
	var panel := Control.new()
	_hud_panel = panel
	panel.name = "ObjectiveHud"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 280.0
	panel.offset_right = -280.0
	panel.offset_top = 12.0
	panel.offset_bottom = 72.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_to_group("hud_click_sink")
	add_child(panel)
	var box := ColorRect.new()
	box.color = IRON
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12.0
	col.offset_right = -12.0
	col.offset_top = 6.0
	col.offset_bottom = -6.0
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	_hud_title = Label.new()
	_hud_title.name = "Title"
	_hud_title.add_theme_color_override("font_color", PARCHMENT)
	_hud_title.add_theme_font_size_override("font_size", 16)
	_hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hud_title)
	_hud_detail = Label.new()
	_hud_detail.name = "Detail"
	_hud_detail.add_theme_color_override("font_color", Color(0.82, 0.76, 0.64))
	_hud_detail.add_theme_font_size_override("font_size", 13)
	_hud_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hud_detail)
	panel.visible = false
	_hold_bar = ColorRect.new()
	_hold_bar.name = "MountHold"
	_hold_bar.color = PARCHMENT
	_hold_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hold_bar.offset_left = 16.0
	_hold_bar.offset_right = 16.0
	_hold_bar.offset_top = -6.0
	_hold_bar.offset_bottom = -2.0
	_hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_bar.visible = false
	panel.add_child(_hold_bar)


func _update_mount_hold() -> void:
	if _hold_bar == null:
		return
	var tree := get_tree()
	var horse: Node = tree.get_first_node_in_group("horse_companion") if tree else null
	var progress := 0.0
	if horse != null and horse.has_method("mount_progress"):
		progress = float(horse.call("mount_progress"))
	_hold_bar.visible = progress > 0.02
	if _hold_bar.visible:
		_hold_bar.offset_right = 16.0 + 200.0 * progress


func _build_toast() -> void:
	_toast = Control.new()
	_toast.name = "OnboardingToast"
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -260.0
	_toast.offset_right = 260.0
	_toast.offset_top = -210.0
	_toast.offset_bottom = -96.0
	_toast.mouse_filter = Control.MOUSE_FILTER_STOP
	_toast.add_to_group("hud_click_sink")
	_toast.visible = false
	add_child(_toast)
	var box := ColorRect.new()
	box.color = IRON
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(box)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14.0
	col.offset_right = -14.0
	col.offset_top = 10.0
	col.offset_bottom = -10.0
	col.add_theme_constant_override("separation", 6)
	_toast.add_child(col)
	_toast_title = Label.new()
	_toast_title.name = "Title"
	_toast_title.add_theme_color_override("font_color", PARCHMENT)
	_toast_title.add_theme_font_size_override("font_size", 18)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_title)
	_toast_body = Label.new()
	_toast_body.name = "Body"
	_toast_body.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	_toast_body.add_theme_font_size_override("font_size", 14)
	_toast_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_body)
	var dismiss := Button.new()
	dismiss.name = "Dismiss"
	dismiss.text = _loc("tip.dismiss", "Entendido")
	dismiss.pressed.connect(dismiss_active_tip)
	col.add_child(dismiss)


func _build_travel() -> void:
	_travel_panel = Control.new()
	_travel_panel.name = "TravelCard"
	_travel_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_travel_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_travel_panel.add_to_group("hud_click_sink")
	_travel_panel.visible = false
	add_child(_travel_panel)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_travel_panel.add_child(dim)
	var card := ColorRect.new()
	card.name = "Card"
	card.color = IRON
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -220.0
	card.offset_right = 220.0
	card.offset_top = -70.0
	card.offset_bottom = 70.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_travel_panel.add_child(card)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16.0
	col.offset_right = -16.0
	col.offset_top = 18.0
	col.offset_bottom = -18.0
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	_travel_kicker = Label.new()
	_travel_kicker.name = "Kicker"
	_travel_kicker.add_theme_color_override("font_color", Color(0.82, 0.76, 0.64))
	_travel_kicker.add_theme_font_size_override("font_size", 14)
	_travel_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_travel_kicker)
	_travel_place = Label.new()
	_travel_place.name = "Place"
	_travel_place.add_theme_color_override("font_color", PARCHMENT)
	_travel_place.add_theme_font_size_override("font_size", 28)
	_travel_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_travel_place)


func _load_places() -> void:
	places.clear()
	if not FileAccess.file_exists(PLACES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES_PATH))
	if parsed is Dictionary:
		var raw: Variant = parsed.get("places", {})
		if raw is Dictionary:
			places = (raw as Dictionary).duplicate(true)


func _load_tips() -> void:
	tips.clear()
	if not FileAccess.file_exists(TIPS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH))
	if parsed is Dictionary:
		var raw: Variant = parsed.get("tips", [])
		if raw is Array:
			tips = raw


func _load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	for key in DEFAULT_SETTINGS:
		if data.has(key):
			settings[key] = data[key]
	var loc := get_node_or_null("/root/Loc")
	if loc != null and loc.has_method("normalize_locale"):
		settings["locale"] = loc.call("normalize_locale", str(settings.get("locale", "es")))
	var raw_tips: Variant = data.get("dismissed_tips", [])
	dismissed_tips = PackedStringArray()
	if raw_tips is Array:
		for item in raw_tips:
			dismissed_tips.append(str(item))


func _save_settings() -> void:
	var body := settings.duplicate(true)
	var tip_list: Array = []
	for tip in dismissed_tips:
		tip_list.append(str(tip))
	body["dismissed_tips"] = tip_list
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(body, "", true, true))
	file.close()


func _apply_locale() -> void:
	var loc := get_node_or_null("/root/Loc")
	if loc == null:
		var tree := get_tree()
		if tree and tree.root:
			loc = tree.root.get_node_or_null("Loc")
	if loc != null and loc.has_method("set_locale"):
		loc.call("set_locale", str(settings.get("locale", "es")))


func _apply_audio() -> void:
	_set_bus_volume("Master", float(settings.get("vol_master", 1.0)))
	_set_bus_volume("VO", float(settings.get("vol_vo", 1.0)))
	_set_bus_volume("SFX", float(settings.get("vol_sfx", 1.0)))
	_set_bus_volume("Music", float(settings.get("vol_music", 0.8)))
	_set_bus_volume("Ambience", float(settings.get("vol_music", 0.8)))
	_set_bus_volume("UI", float(settings.get("vol_ui", 1.0)))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))


func _stick_moving() -> bool:
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		return true
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back"):
		return true
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.2


func _group_visible(group: String) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(group):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			return true
		if node is Control and bool((node as Control).visible):
			return true
	return false


func _is_main_menu() -> bool:
	var scene := _current_scene()
	if scene == null:
		return false
	if String(scene.name) == "MainMenu":
		return true
	var script: Script = scene.get_script()
	return script != null and String(script.resource_path).ends_with("main_menu.gd")


func _current_scene() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene


func _runner() -> Node:
	return _autoload("ChapterRunner")


func _bus() -> Node:
	return _autoload("EventBus")


func _autoload(name: String) -> Node:
	var tree := get_tree()
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(name)
	var parent := get_parent()
	if parent:
		return parent.get_node_or_null(name)
	return null


func _loc(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var loc := _autoload("Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t
