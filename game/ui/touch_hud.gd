extends CanvasLayer

## Virtual stick + action cluster. Injects Input actions so CidController stays the owner.

const LOGICAL_SIZE := Vector2(1280.0, 720.0)
const TABLET_SW_DP := 600.0
const PHONE_STICK_PX := 140.0
const PHONE_BUTTON_PX := 72.0
const PHONE_INSET_PX := 24.0
const PHONE_GAP_PX := 10.0
const TABLET_STICK_PX := 210.0
const TABLET_BUTTON_PX := 96.0
const TABLET_INSET_PX := 56.0
const TABLET_GAP_PX := 22.0
const STICK_DEADZONE := 0.12
const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]
const ACTION_BUTTONS := {
	"Slam": "slam",
	"Leap": "leap",
	"Shout": "shout",
	"Dodge": "dodge",
	"Interact": "interact",
	"Mesura": "mesura",
}
const LABEL_KEYS := {
	"Slam": "hud.slam",
	"Leap": "hud.leap",
	"Shout": "hud.shout",
	"Dodge": "hud.dodge",
	"Interact": "hud.interact",
	"Mesura": "hud.mesura",
}
const LABEL_FALLBACK := {
	"Slam": "Golpe",
	"Leap": "Salto",
	"Shout": "Grito",
	"Dodge": "Esquiva",
	"Interact": "Hablar",
	"Mesura": "Mesura",
}

## True while the on-screen HUD is shown so thumbs do not drive mouse-aim / slam.
static var pointer_blocked: bool = false

var debug_force_visible: bool = false
var debug_force_hidden: bool = false
var _stick_px: float = PHONE_STICK_PX
var _button_px: float = PHONE_BUTTON_PX
var _inset_px: float = PHONE_INSET_PX
var _gap_px: float = PHONE_GAP_PX
var _is_tablet: bool = false
var _stick_pointer: int = -1
var _stick_from_mouse: bool = false
var _injected: Dictionary = {}


func _ready() -> void:
	_apply_visibility()
	_wire_buttons()
	_apply_labels()
	var stick := _stick()
	if stick:
		stick.gui_input.connect(_on_stick_gui_input)
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	apply_form_factor_from_display()


func _exit_tree() -> void:
	_release_injected()
	Input.emulate_mouse_from_touch = true
	if pointer_blocked:
		pointer_blocked = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		apply_form_factor_from_display()


func force_visible(enabled: bool = true) -> void:
	debug_force_visible = enabled
	debug_force_hidden = not enabled
	_apply_visibility()


func wants_visible() -> bool:
	if debug_force_hidden:
		return false
	if debug_force_visible:
		return true
	if OS.has_feature("mobile"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--touch-hud":
			return true
	for arg in OS.get_cmdline_args():
		if arg == "--touch-hud":
			return true
	return false


func stick_size() -> float:
	return _stick_px


func button_size() -> float:
	return _button_px


func edge_inset() -> float:
	return _inset_px


func is_tablet_layout() -> bool:
	return _is_tablet


static func shortest_side_dp(size_px: Vector2, dpi: int) -> float:
	var density := float(dpi) if dpi > 0 else 160.0
	return minf(size_px.x, size_px.y) * 160.0 / density


func apply_form_factor_from_display() -> void:
	var size_px := _form_factor_size_px()
	var dpi := DisplayServer.screen_get_dpi()
	if dpi <= 0:
		dpi = 160
	var logical := _logical_canvas()
	var safe_logical := _safe_area_to_logical(Rect2(DisplayServer.get_display_safe_area()), size_px, logical)
	apply_form_factor(size_px, dpi, safe_logical)


func apply_form_factor(size_px: Vector2, dpi: int = 160, safe_area: Rect2 = Rect2()) -> void:
	var dp := shortest_side_dp(size_px, dpi)
	_is_tablet = dp >= TABLET_SW_DP
	if _is_tablet:
		_stick_px = TABLET_STICK_PX
		_button_px = TABLET_BUTTON_PX
		_inset_px = TABLET_INSET_PX
		_gap_px = TABLET_GAP_PX
	else:
		_stick_px = PHONE_STICK_PX
		_button_px = PHONE_BUTTON_PX
		_inset_px = PHONE_INSET_PX
		_gap_px = PHONE_GAP_PX
	var canvas := _logical_canvas()
	var safe := safe_area
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = Rect2(Vector2.ZERO, canvas)
	_layout_controls(safe)


func _apply_visibility() -> void:
	var show := wants_visible()
	visible = show
	pointer_blocked = show
	Input.emulate_mouse_from_touch = not show
	if not show:
		_release_injected()


func _on_viewport_size_changed() -> void:
	apply_form_factor_from_display()


func _logical_canvas() -> Vector2:
	if is_inside_tree() and get_viewport():
		var vr := get_viewport().get_visible_rect().size
		if vr.x > 0.0 and vr.y > 0.0:
			return vr
	return LOGICAL_SIZE


func _form_factor_size_px() -> Vector2:
	# DeX / windowed size, not the physical panel, so a 600dp window is a tablet bucket.
	var win := Vector2(DisplayServer.window_get_size())
	if win.x > 0.0 and win.y > 0.0:
		return win
	if is_inside_tree() and get_viewport():
		var vr := get_viewport().get_visible_rect().size
		if vr.x > 0.0 and vr.y > 0.0:
			return vr
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x > 0.0 and screen.y > 0.0:
		return screen
	return LOGICAL_SIZE


func _safe_area_to_logical(safe: Rect2, screen: Vector2, logical: Vector2) -> Rect2:
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Rect2(Vector2.ZERO, logical)
	if is_inside_tree() and get_viewport():
		var xform := get_viewport().get_screen_transform()
		if not xform.is_equal_approx(Transform2D.IDENTITY):
			var inv := xform.affine_inverse()
			var mapped := Rect2(inv * safe.position, Vector2.ZERO)
			mapped.end = inv * (safe.position + safe.size)
			mapped = mapped.abs()
			var clipped := mapped.intersection(Rect2(Vector2.ZERO, logical))
			if clipped.size.x > 1.0 and clipped.size.y > 1.0:
				return clipped
	if screen.x <= 0.0 or screen.y <= 0.0:
		return Rect2(Vector2.ZERO, logical)
	return Rect2(
		safe.position.x / screen.x * logical.x,
		safe.position.y / screen.y * logical.y,
		safe.size.x / screen.x * logical.x,
		safe.size.y / screen.y * logical.y
	)


func _layout_controls(safe: Rect2) -> void:
	var stick := _stick()
	if stick:
		stick.size = Vector2(_stick_px, _stick_px)
		stick.position = Vector2(safe.position.x + _inset_px, safe.end.y - _inset_px - _stick_px)
		_style_circle(stick, _stick_px, Color(0.12, 0.13, 0.15, 0.55))
		var knob := stick.get_node_or_null("Knob") as Control
		if knob:
			var knob_px := _stick_px * 0.42
			knob.size = Vector2(knob_px, knob_px)
			knob.position = (_stick_px - knob_px) * 0.5 * Vector2.ONE
			_style_circle(knob, knob_px, Color(0.78, 0.72, 0.58, 0.9))
		_place_button("Mesura", Vector2(stick.position.x, stick.position.y - _gap_px - _button_px))
	var cluster_w := _button_px * 3.0 + _gap_px * 2.0
	var cluster_h := _button_px * 4.0 + _gap_px * 3.0
	var origin := Vector2(safe.end.x - _inset_px - cluster_w, safe.end.y - _inset_px - cluster_h)
	_place_button("Leap", origin + Vector2(_button_px + _gap_px, 0.0))
	_place_button("Shout", origin + Vector2(0.0, _button_px + _gap_px))
	_place_button("Slam", origin + Vector2((_button_px + _gap_px) * 2.0, _button_px + _gap_px))
	_place_button("Dodge", origin + Vector2(_button_px + _gap_px, (_button_px + _gap_px) * 2.0))
	_place_button("Interact", origin + Vector2(_button_px + _gap_px, (_button_px + _gap_px) * 3.0))


func _place_button(node_name: String, pos: Vector2) -> void:
	var btn := _button(node_name)
	if btn == null:
		return
	btn.size = Vector2(_button_px, _button_px)
	btn.position = pos
	btn.custom_minimum_size = Vector2(_button_px, _button_px)
	btn.add_theme_font_size_override("font_size", 14 if _is_tablet else 11)
	_style_circle(btn, _button_px, Color(0.16, 0.17, 0.2, 0.78))


func _style_circle(control: Control, size_px: float, color: Color) -> void:
	var radius := int(round(size_px * 0.5))
	if control is Button:
		var btn := control as Button
		var normal := _circle_style(color, radius)
		var hover := _circle_style(color.lightened(0.08), radius)
		var pressed := _circle_style(color.darkened(0.12), radius)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", hover)
		btn.add_theme_stylebox_override("disabled", normal)
		return
	if control is Panel:
		(control as Panel).add_theme_stylebox_override("panel", _circle_style(color, radius))


func _circle_style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.set_content_margin_all(4)
	return box


func _apply_labels() -> void:
	for node_name in LABEL_KEYS.keys():
		var btn := _button(str(node_name))
		if btn == null:
			continue
		btn.text = _loc_text(str(LABEL_KEYS[node_name]), str(LABEL_FALLBACK[node_name]))


func _loc_text(key: String, fallback: String) -> String:
	var loc := get_node_or_null("/root/Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t


func _wire_buttons() -> void:
	for node_name in ACTION_BUTTONS.keys():
		var btn := _button(str(node_name))
		if btn == null:
			continue
		var action: StringName = ACTION_BUTTONS[node_name]
		if not btn.button_down.is_connected(_on_action_down):
			btn.button_down.connect(_on_action_down.bind(action))
		if not btn.button_up.is_connected(_on_action_up):
			btn.button_up.connect(_on_action_up.bind(action))


func _on_action_down(action: StringName) -> void:
	_emit_action(action, true, 1.0)


func _on_action_up(action: StringName) -> void:
	_emit_action(action, false, 0.0)


func _emit_action(action: StringName, pressed: bool, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)
	if pressed:
		Input.action_press(action, strength)
		_injected[action] = true
	elif _injected.get(action, false):
		Input.action_release(action)
		_injected[action] = false


func _on_stick_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _stick_pointer < 0:
			_stick_pointer = touch.index
			_stick_from_mouse = false
			_update_stick_local(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _stick_pointer:
			_reset_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_pointer:
			_update_stick_local(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed and _stick_pointer < 0:
			_stick_pointer = 0
			_stick_from_mouse = true
			_update_stick_local(mb.position)
			get_viewport().set_input_as_handled()
		elif not mb.pressed and _stick_from_mouse:
			_reset_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _stick_from_mouse:
		_update_stick_local((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible or _stick_pointer < 0:
		return
	var stick := _stick()
	if stick == null:
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_pointer:
			_update_stick_local(stick.get_global_transform_with_canvas().affine_inverse() * drag.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and touch.index == _stick_pointer:
			_reset_stick()
	elif _stick_from_mouse and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_update_stick_local(stick.get_global_transform_with_canvas().affine_inverse() * motion.position)
	elif _stick_from_mouse and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_reset_stick()


func _update_stick_local(local_pos: Vector2) -> void:
	var stick := _stick()
	if stick == null:
		return
	var center := stick.size * 0.5
	var delta := local_pos - center
	var max_r := minf(center.x, center.y) * 0.5
	if max_r <= 0.0:
		return
	if delta.length() > max_r:
		delta = delta.normalized() * max_r
	var knob := stick.get_node_or_null("Knob") as Control
	if knob:
		knob.position = center + delta - knob.size * 0.5
	var n := delta / max_r
	_apply_stick_vector(n)


func _apply_stick_vector(n: Vector2) -> void:
	if n.length() < STICK_DEADZONE:
		_inject_axis("move_left", 0.0)
		_inject_axis("move_right", 0.0)
		_inject_axis("move_forward", 0.0)
		_inject_axis("move_back", 0.0)
		return
	_inject_axis("move_right", maxf(n.x, 0.0))
	_inject_axis("move_left", maxf(-n.x, 0.0))
	_inject_axis("move_back", maxf(n.y, 0.0))
	_inject_axis("move_forward", maxf(-n.y, 0.0))


func _inject_axis(action: String, strength: float) -> void:
	if strength > 0.02:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
		_injected[action] = true
	elif _injected.get(action, false):
		Input.action_release(action)
		_injected[action] = false


func _reset_stick() -> void:
	_stick_pointer = -1
	_stick_from_mouse = false
	var stick := _stick()
	if stick:
		var knob := stick.get_node_or_null("Knob") as Control
		if knob:
			knob.position = (stick.size - knob.size) * 0.5
	for action in MOVE_ACTIONS:
		_inject_axis(action, 0.0)


func _release_injected() -> void:
	_reset_stick()
	for action in _injected.keys():
		if _injected[action]:
			Input.action_release(action)
	_injected.clear()


func _stick() -> Control:
	return find_child("Stick", true, false) as Control


func _button(node_name: String) -> Button:
	return find_child(node_name, true, false) as Button
