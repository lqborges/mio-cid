class_name InputGlyphs
extends RefCounted
## Last-used device → readable prompt glyph. Keyboard / pad / touch.

const DEVICE_KEYBOARD := &"keyboard"
const DEVICE_GAMEPAD := &"gamepad"
const DEVICE_TOUCH := &"touch"

const KEY_FALLBACK := {
	"interact": "E",
	"mesura": "Q",
	"pause": "Esc",
	"slam": "1",
	"leap": "F",
	"shout": "R",
	"dodge": "Espacio",
	"run": "Mayús",
	"click_move": "LMB",
}

const PAD_FALLBACK := {
	"interact": "LB",
	"mesura": "View",
	"pause": "Start",
	"slam": "A",
	"leap": "X",
	"shout": "Y",
	"dodge": "B",
	"run": "L3",
	"click_move": "RS",
}

const TOUCH_FALLBACK := {
	"interact": "Toca",
	"mesura": "Mesura",
	"pause": "☰",
	"slam": "Golpe",
	"leap": "Salto",
	"shout": "Grito",
	"dodge": "Esquiva",
	"run": "Corre",
	"click_move": "Toca el suelo",
}

static var last_device: StringName = DEVICE_KEYBOARD


static func note_event(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_device = DEVICE_GAMEPAD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_device = DEVICE_TOUCH
	elif event is InputEventKey or event is InputEventMouse:
		last_device = DEVICE_KEYBOARD


static func set_device(device: StringName) -> void:
	if device == DEVICE_GAMEPAD or device == DEVICE_TOUCH or device == DEVICE_KEYBOARD:
		last_device = device


static func action_glyph(action: String) -> String:
	match last_device:
		DEVICE_TOUCH:
			return str(TOUCH_FALLBACK.get(action, "Toca"))
		DEVICE_GAMEPAD:
			var from_map := _input_map_glyph(action, true)
			return from_map if not from_map.is_empty() else str(PAD_FALLBACK.get(action, "A"))
		_:
			var from_keys := _input_map_glyph(action, false)
			return from_keys if not from_keys.is_empty() else str(KEY_FALLBACK.get(action, "?"))


static func prompt(action: String, verb: String) -> String:
	var glyph := action_glyph(action)
	if verb.is_empty():
		return glyph
	return "%s — %s" % [glyph, verb]


static func _input_map_glyph(action: String, pad: bool) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if pad and event is InputEventJoypadButton:
			return _joy_button_name(int((event as InputEventJoypadButton).button_index))
		if not pad and event is InputEventKey:
			var key := event as InputEventKey
			var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
			var label := OS.get_keycode_string(code)
			if not label.is_empty():
				return label
	return ""


static func _joy_button_name(index: int) -> String:
	match index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "View"
		_:
			return "A"
