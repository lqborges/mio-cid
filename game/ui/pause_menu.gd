extends CanvasLayer
## Escape overlay: resume / main menu / quit. PROCESS_MODE_ALWAYS so it lives while paused.

const MENU_SCENE := "res://game/ui/main_menu.tscn"
const IRON := Color(0.18, 0.16, 0.13, 0.92)
const PARCHMENT := Color(0.91, 0.85, 0.72)

var _panel: Control
var _title: Label
var _resume: Button
var _menu: Button
var _quit: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false
	_build()
	_apply_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not event.is_action_pressed("pause") and not event.is_action_pressed("ui_cancel"):
		return
	if _is_main_menu():
		return
	get_viewport().set_input_as_handled()
	if visible:
		resume()
	else:
		open()


func open() -> void:
	if _is_main_menu():
		return
	_apply_labels()
	visible = true
	var tree := get_tree()
	if tree:
		tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
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
	_panel.offset_left = -160.0
	_panel.offset_top = -130.0
	_panel.offset_right = 160.0
	_panel.offset_bottom = 130.0
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
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", PARCHMENT)
	_title.add_theme_font_size_override("font_size", 28)
	col.add_child(_title)

	_resume = _make_button("Resume", resume)
	_menu = _make_button("Menu", _on_menu)
	_quit = _make_button("Quit", _on_quit)
	col.add_child(_resume)
	col.add_child(_menu)
	col.add_child(_quit)


func _make_button(node_name: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(cb)
	return btn


func _apply_labels() -> void:
	if _title:
		_title.text = _loc("ui.pause.title", "Pausa")
	if _resume:
		_resume.text = _loc("ui.pause.resume", "Continuar")
	if _menu:
		_menu.text = _loc("ui.pause.menu", "Menú principal")
	if _quit:
		_quit.text = _loc("ui.pause.quit", "Salir")


func _loc(key: String, fallback: String) -> String:
	var loc := get_node_or_null("/root/Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t
