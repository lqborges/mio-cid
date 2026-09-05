extends CanvasLayer
## Escape overlay: resume / journal / help / settings / main menu / quit.

const MENU_SCENE := "res://game/ui/main_menu.tscn"
const IRON := Color(0.18, 0.16, 0.13, 0.92)
const PARCHMENT := Color(0.91, 0.85, 0.72)

var _panel: Control
var _title: Label
var _resume: Button
var _journal: Button
var _help: Button
var _settings: Button
var _menu: Button
var _quit: Button
var _page: Control
var _page_title: Label
var _page_body: RichTextLabel
var _page_back: Button
var _settings_box: VBoxContainer
var _page_mode: StringName = &""
var _ignore_cancel_until_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false
	_build()
	_apply_labels()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	# Android Back also emits ui_cancel. Ignore that echo so the menu does not
	# open and close on the same press.
	_ignore_cancel_until_msec = Time.get_ticks_msec() + 250
	if _is_main_menu():
		get_tree().quit()
		return
	if visible:
		if _page and _page.visible:
			_hide_page()
			_focus_resume()
		else:
			resume()
	else:
		open()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	InputGlyphs.note_event(event)
	var cancel := event.is_action_pressed("ui_cancel")
	if cancel and Time.get_ticks_msec() < _ignore_cancel_until_msec:
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pause") and not cancel:
		return
	if _is_main_menu():
		return
	get_viewport().set_input_as_handled()
	if visible:
		if _page.visible:
			_hide_page()
			_focus_resume()
		else:
			resume()
	else:
		open()


func open() -> void:
	if _is_main_menu():
		return
	_apply_labels()
	_hide_page()
	visible = true
	var tree := get_tree()
	if tree:
		tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_world_input()
	_focus_resume()


func resume() -> void:
	_hide_page()
	visible = false
	var tree := get_tree()
	if tree:
		tree.paused = false


func _on_menu() -> void:
	resume()
	var tree := get_tree()
	if tree and ResourceLoader.exists(MENU_SCENE):
		tree.change_scene_to_file(MENU_SCENE)


func _on_quit() -> void:
	resume()
	get_tree().quit()


func _open_journal() -> void:
	_show_page(&"journal", _loc("ui.pause.journal", "Dietario"), _journal_text())


func _open_help() -> void:
	var guide := _guide()
	if guide and guide.has_method("replay_tips"):
		guide.call("replay_tips")
	_show_page(&"help", _loc("ui.pause.help", "Ayuda"), _help_text())


func _open_settings() -> void:
	_rebuild_settings()
	_show_page(&"settings", _loc("ui.pause.settings", "Ajustes"), "")


func _show_page(mode: StringName, heading: String, body: String) -> void:
	_page_mode = mode
	_page.visible = true
	_page_title.text = heading
	_page_body.text = body
	_page_body.visible = mode != &"settings"
	_settings_box.visible = mode == &"settings"
	_page_back.grab_focus()


func _hide_page() -> void:
	_page_mode = &""
	if _page:
		_page.visible = false


func _is_main_menu() -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	var scene := tree.current_scene
	if scene == null:
		return false
	if String(scene.name) == "MainMenu":
		return true
	var script: Script = scene.get_script()
	if script != null and String(script.resource_path).ends_with("main_menu.gd"):
		return true
	return false


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.04, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = Control.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -180.0
	_panel.offset_top = -220.0
	_panel.offset_right = 180.0
	_panel.offset_bottom = 220.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var box := ColorRect.new()
	box.name = "Bg"
	box.color = IRON
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	var col := VBoxContainer.new()
	col.name = "Center"
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 24.0
	col.offset_top = 20.0
	col.offset_right = -24.0
	col.offset_bottom = -20.0
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", PARCHMENT)
	_title.add_theme_font_size_override("font_size", 28)
	col.add_child(_title)

	_resume = _make_button("Resume", resume)
	_journal = _make_button("Journal", _open_journal)
	_help = _make_button("Help", _open_help)
	_settings = _make_button("Settings", _open_settings)
	_menu = _make_button("Menu", _on_menu)
	_quit = _make_button("Quit", _on_quit)
	col.add_child(_resume)
	col.add_child(_journal)
	col.add_child(_help)
	col.add_child(_settings)
	col.add_child(_menu)
	col.add_child(_quit)

	_page = Control.new()
	_page.name = "Page"
	_page.set_anchors_preset(Control.PRESET_CENTER)
	_page.offset_left = -300.0
	_page.offset_top = -230.0
	_page.offset_right = 300.0
	_page.offset_bottom = 230.0
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.visible = false
	add_child(_page)
	var page_bg := ColorRect.new()
	page_bg.color = IRON
	page_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(page_bg)
	var page_col := VBoxContainer.new()
	page_col.name = "Center"
	page_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_col.offset_left = 20.0
	page_col.offset_right = -20.0
	page_col.offset_top = 16.0
	page_col.offset_bottom = -16.0
	page_col.add_theme_constant_override("separation", 10)
	_page.add_child(page_col)
	_page_title = Label.new()
	_page_title.name = "Title"
	_page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_title.add_theme_color_override("font_color", PARCHMENT)
	_page_title.add_theme_font_size_override("font_size", 24)
	page_col.add_child(_page_title)
	_page_body = RichTextLabel.new()
	_page_body.name = "Body"
	_page_body.bbcode_enabled = false
	_page_body.fit_content = false
	_page_body.scroll_active = true
	_page_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_body.custom_minimum_size = Vector2(0, 260)
	_page_body.add_theme_color_override("default_color", PARCHMENT)
	page_col.add_child(_page_body)
	_settings_box = VBoxContainer.new()
	_settings_box.name = "SettingsBox"
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.visible = false
	page_col.add_child(_settings_box)
	_page_back = _make_button("Back", _hide_page)
	page_col.add_child(_page_back)


func _make_button(node_name: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(cb)
	return btn


func _apply_labels() -> void:
	if _title:
		_title.text = _loc("ui.pause.title", "Pausa")
	if _resume:
		_resume.text = _loc("ui.pause.resume", "Continuar")
	if _journal:
		_journal.text = _loc("ui.pause.journal", "Dietario")
	if _help:
		_help.text = _loc("ui.pause.help", "Ayuda")
	if _settings:
		_settings.text = _loc("ui.pause.settings", "Ajustes")
	if _menu:
		_menu.text = _loc("ui.pause.menu", "Menú principal")
	if _quit:
		_quit.text = _loc("ui.pause.quit", "Salir")
	if _page_back:
		_page_back.text = _loc("ui.pause.back", "Volver")


func _journal_text() -> String:
	var guide := _guide()
	if guide == null or not guide.has_method("journal_entries"):
		return _loc("ui.journal.empty", "Aún no hay recuerdos.")
	var rows: Variant = guide.call("journal_entries")
	if not (rows is Array) or (rows as Array).is_empty():
		return _loc("ui.journal.empty", "Aún no hay recuerdos.")
	var lines: PackedStringArray = PackedStringArray()
	for item in rows:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		var title := _loc(str(row.get("title_key", "")), "")
		var done := _loc(str(row.get("done_key", "")), "")
		var detail := _loc(str(row.get("detail_key", "")), "")
		var lock := _loc(str(row.get("lock_reason_key", "")), "")
		if not title.is_empty():
			lines.append(title)
		if not done.is_empty() and done != str(row.get("done_key", "")):
			lines.append("  %s" % done)
		elif not detail.is_empty() and detail != str(row.get("detail_key", "")):
			lines.append("  %s" % detail)
		if not lock.is_empty() and lock != str(row.get("lock_reason_key", "")):
			lines.append("  %s" % lock)
	if lines.is_empty():
		return _loc("ui.journal.empty", "Aún no hay recuerdos.")
	return "\n".join(lines)


func _help_text() -> String:
	var guide := _guide()
	var lines := PackedStringArray()
	if guide != null and guide.has_method("help_lines"):
		lines = guide.call("help_lines")
	lines.append("")
	lines.append(_loc("tip.mesura.body", ""))
	return "\n".join(lines)


func _rebuild_settings() -> void:
	for child in _settings_box.get_children():
		child.queue_free()
	var guide := _guide()
	var data: Dictionary = {}
	if guide != null and "settings" in guide:
		data = guide.settings
	_settings_box.add_child(_check("reduced_motion", _loc("ui.settings.reduced_motion", "Menos movimiento"), bool(data.get("reduced_motion", false))))
	_settings_box.add_child(_check("shake", _loc("ui.settings.shake", "Sacudida de cámara"), bool(data.get("shake", true))))
	_settings_box.add_child(_check("flash", _loc("ui.settings.flash", "Destellos"), bool(data.get("flash", true))))
	_settings_box.add_child(_slider("vol_master", _loc("ui.settings.vol_master", "Volumen"), float(data.get("vol_master", 1.0))))
	_settings_box.add_child(_slider("vol_vo", _loc("ui.settings.vol_vo", "Voces"), float(data.get("vol_vo", 1.0))))
	_settings_box.add_child(_slider("vol_sfx", _loc("ui.settings.vol_sfx", "Efectos"), float(data.get("vol_sfx", 1.0))))
	_settings_box.add_child(_slider("vol_music", _loc("ui.settings.vol_music", "Música"), float(data.get("vol_music", 0.8))))
	_settings_box.add_child(_step("subtitle_size", _loc("ui.settings.subtitle", "Subtítulos"), int(data.get("subtitle_size", 18))))


func _check(key: String, label: String, on: bool) -> CheckButton:
	var btn := CheckButton.new()
	btn.text = label
	btn.button_pressed = on
	btn.focus_mode = Control.FOCUS_ALL
	btn.toggled.connect(func(pressed: bool) -> void:
		var guide := _guide()
		if guide and guide.has_method("set_setting"):
			guide.call("set_setting", key, pressed)
	)
	return btn


func _slider(key: String, label: String, value: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name := Label.new()
	name.text = label
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", PARCHMENT)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(160, 24)
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(func(v: float) -> void:
		var guide := _guide()
		if guide and guide.has_method("set_setting"):
			guide.call("set_setting", key, v)
	)
	row.add_child(name)
	row.add_child(slider)
	return row


func _step(key: String, label: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name := Label.new()
	name.text = "%s: %d" % [label, value]
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", PARCHMENT)
	var down := Button.new()
	down.text = "–"
	down.focus_mode = Control.FOCUS_ALL
	var up := Button.new()
	up.text = "+"
	up.focus_mode = Control.FOCUS_ALL
	var apply := func(delta: int) -> void:
		var next := clampi(value + delta, 14, 26)
		value = next
		name.text = "%s: %d" % [label, value]
		var guide := _guide()
		if guide and guide.has_method("set_setting"):
			guide.call("set_setting", key, next)
	down.pressed.connect(func() -> void: apply.call(-4))
	up.pressed.connect(func() -> void: apply.call(4))
	row.add_child(name)
	row.add_child(down)
	row.add_child(up)
	return row


func _focus_resume() -> void:
	if _resume:
		_resume.grab_focus()


func _clear_world_input() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("player"):
		if node.has_method("_clear_action_queues"):
			node.call("_clear_action_queues")
		var mesura: Node = node.get_node_or_null("Mesura")
		if mesura != null and mesura.has_method("set_holding"):
			mesura.call("set_holding", false)


func _guide() -> Node:
	return _autoload("PlayerGuide")


func _autoload(name: String) -> Node:
	var tree := get_tree()
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(name)
	var parent := get_parent()
	if parent:
		return parent.get_node_or_null(name)
	return null


func _loc(key: String, fallback: String) -> String:
	var loc := _autoload("Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t
