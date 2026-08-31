class_name BootyDivide
extends Control

## Confirm quinto / mesnada / treasury split. Fractions come from TreasuryService.

signal confirmed(split: Dictionary)

var holding: Resource
var pile: Dictionary = {}
var gift_alvar: bool = false
var gift_marks: int = 0
var gift_horses: int = 0
var last_split: Dictionary = {}

var _applied: bool = false


func _ready() -> void:
	var gift_btn := _gift_button()
	if gift_btn and not gift_btn.toggled.is_connected(_on_gift_toggled):
		gift_btn.toggled.connect(_on_gift_toggled)
	var confirm_btn := _confirm_button()
	if confirm_btn and not confirm_btn.pressed.is_connected(_on_confirm):
		confirm_btn.pressed.connect(_on_confirm)
	_refresh()


func bind_holding(next: Resource) -> void:
	holding = next
	pile = {}
	if holding != null:
		var raw: Variant = holding.get("booty")
		if raw is Dictionary:
			pile = (raw as Dictionary).duplicate()
	_applied = false
	_refresh()


func bind_pile(next: Dictionary) -> void:
	holding = null
	pile = next.duplicate()
	_applied = false
	_refresh()


func set_gift_to_alvar(enabled: bool, marks: int = 0, horses: int = 0) -> void:
	gift_alvar = enabled
	gift_marks = maxi(0, marks)
	gift_horses = maxi(0, horses)
	var gift_btn := _gift_button()
	if gift_btn:
		gift_btn.set_pressed_no_signal(enabled)
	_refresh()


func preview() -> Dictionary:
	var treasury := _treasury()
	if treasury == null or not treasury.has_method("preview_booty"):
		return {}
	return treasury.preview_booty(pile, _gift_payload())


func confirm() -> Dictionary:
	if _applied:
		return last_split
	var treasury := _treasury()
	if treasury == null or not treasury.has_method("divide_booty"):
		return {}
	last_split = treasury.divide_booty(pile, _gift_payload())
	_applied = true
	confirmed.emit(last_split)
	return last_split


func _on_gift_toggled(pressed: bool) -> void:
	gift_alvar = pressed
	_refresh()


func _on_confirm() -> void:
	confirm()


func _refresh() -> void:
	var title := _label("Center/Title")
	var pile_lbl := _label("Center/Pile")
	var quinto := _label("Center/Buckets/Quinto/Amount")
	var mesnada := _label("Center/Buckets/Mesnada/Amount")
	var treasury_lbl := _label("Center/Buckets/Treasury/Amount")
	var quinto_name := _label("Center/Buckets/Quinto/Name")
	var mesnada_name := _label("Center/Buckets/Mesnada/Name")
	var treasury_name := _label("Center/Buckets/Treasury/Name")
	var gift_note := _label("Center/GiftNote")
	var gift_btn := _gift_button()
	var confirm_btn := _confirm_button()
	if title:
		title.text = _loc("ui.booty_divide.title")
	if quinto_name:
		quinto_name.text = _loc("ui.booty_divide.quinto")
	if mesnada_name:
		mesnada_name.text = _loc("ui.booty_divide.mesnada")
	if treasury_name:
		treasury_name.text = _loc("ui.booty_divide.treasury")
	if gift_btn:
		gift_btn.text = _loc("ui.booty_divide.gift_alvar")
		gift_btn.set_pressed_no_signal(gift_alvar)
	if confirm_btn:
		confirm_btn.text = _loc("ui.booty_divide.confirm")
	var split := preview()
	if pile_lbl:
		pile_lbl.text = _bucket_line(
			int(split.get("pile_marks", pile.get("marks", 0))),
			int(split.get("pile_horses", pile.get("horses", 0))),
		)
	if quinto:
		quinto.text = _bucket_line(
			int(split.get("quinto_marks", 0)),
			int(split.get("quinto_horses", 0)),
		)
	if mesnada:
		mesnada.text = _bucket_line(
			int(split.get("mesnada_marks", 0)),
			int(split.get("mesnada_horses", 0)),
		)
	if treasury_lbl:
		treasury_lbl.text = _bucket_line(
			int(split.get("treasury_marks", 0)),
			int(split.get("treasury_horses", 0)),
		)
	if gift_note:
		if gift_alvar:
			gift_note.text = "%s %s" % [
				_loc("ui.booty_divide.gift_note"),
				_bucket_line(
					int(split.get("gift_marks", 0)),
					int(split.get("gift_horses", 0)),
				),
			]
		else:
			gift_note.text = ""


func _gift_payload() -> Dictionary:
	if not gift_alvar:
		return {}
	var payload := {"to_alvar": true}
	if gift_marks > 0:
		payload["marks"] = gift_marks
	if gift_horses > 0:
		payload["horses"] = gift_horses
	return payload


func _bucket_line(marks: int, horses: int) -> String:
	return "%s %s · %s %s" % [
		str(marks),
		_loc("ui.booty_divide.marks"),
		str(horses),
		_loc("ui.booty_divide.horses"),
	]


func _gift_button() -> CheckButton:
	return get_node_or_null(NodePath("Center/GiftAlvar")) as CheckButton


func _confirm_button() -> Button:
	return get_node_or_null(NodePath("Center/Confirm")) as Button


func _label(path: String) -> Label:
	return get_node_or_null(NodePath(path)) as Label


func _treasury() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath("TreasuryService"))
	return null


func _loc(key: String) -> String:
	var loc: Node = null
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		loc = (loop as SceneTree).root.get_node_or_null(NodePath("Loc"))
	if loc and loc.has_method("text"):
		return str(loc.call("text", key))
	return key
