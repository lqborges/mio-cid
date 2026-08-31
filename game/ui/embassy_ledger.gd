class_name EmbassyLedger
extends Control

## Gift-up ledger. Blocked options stay listed and greyed; confirm refuses them.

signal confirmed(choice_id: StringName, event: HonorEvent)
signal blocked(choice_id: StringName, reason: StringName)

var gift: GiftToKing
var selected_id: StringName = &""
var last_event: HonorEvent

var _applied: bool = false
var _buttons: Dictionary = {}


func _ready() -> void:
	var confirm_btn := _confirm_button()
	if confirm_btn and not confirm_btn.pressed.is_connected(_on_confirm):
		confirm_btn.pressed.connect(_on_confirm)
	if gift == null:
		gift = GiftToKing.from_file()
	_refresh()


func bind_gift(next: GiftToKing) -> void:
	gift = next
	selected_id = &""
	last_event = null
	_applied = false
	_refresh()


func select(choice_id: StringName) -> void:
	selected_id = choice_id
	_refresh()


func confirm() -> HonorEvent:
	if _applied:
		return last_event
	_load_gift()
	var opt := _selected()
	if opt == null:
		return HonorEvent.new()
	var honor := _honor_state()
	var treasury := _treasury_state()
	last_event = gift.resolve(selected_id, honor, treasury)
	if last_event == null or String(last_event.id).is_empty():
		blocked.emit(selected_id, _block_reason(opt, treasury, honor))
		_refresh()
		return last_event if last_event else HonorEvent.new()
	_applied = true
	confirmed.emit(selected_id, last_event)
	return last_event


func is_option_blocked(choice_id: StringName) -> bool:
	return option_block_reason(choice_id) != &""


func option_block_reason(choice_id: StringName) -> StringName:
	_load_gift()
	if gift == null:
		return &"horses"
	var opt := gift.option(choice_id)
	if opt == null:
		return &"horses"
	return _block_reason(opt, _treasury_state(), _honor_state())


func _on_confirm() -> void:
	confirm()


func _on_option_pressed(choice_id: StringName) -> void:
	select(choice_id)


func _refresh() -> void:
	_load_gift()
	var title := _label("Center/Title")
	var detail := _label("Center/Detail")
	var warn := _label("Center/Warn")
	var confirm_btn := _confirm_button()
	if title:
		title.text = _loc("ui.embassy_ledger.title")
	if confirm_btn:
		confirm_btn.text = _loc("ui.embassy_ledger.confirm")
	_rebuild_options()
	var opt := _selected()
	var reason := option_block_reason(selected_id) if opt else &""
	if detail:
		detail.text = _detail_line(opt) if opt else ""
	if warn:
		warn.text = _loc(_blocked_loc(reason)) if reason != &"" else ""
	if confirm_btn:
		confirm_btn.disabled = opt == null or _applied


func _rebuild_options() -> void:
	var box := get_node_or_null(NodePath("Center/Options")) as VBoxContainer
	if box == null or gift == null:
		return
	var ids: Array[StringName] = []
	for opt in gift.options:
		if opt != null and opt.id != &"":
			ids.append(opt.id)
	var stale: Array[Node] = []
	for child in box.get_children():
		var keep := false
		for opt_id in ids:
			if child.name == String(opt_id):
				keep = true
				break
		if not keep:
			stale.append(child)
	for child in stale:
		box.remove_child(child)
		child.free()
	_buttons.clear()
	for opt in gift.options:
		if opt == null or opt.id == &"":
			continue
		var btn := box.get_node_or_null(NodePath(String(opt.id))) as Button
		if btn == null:
			btn = Button.new()
			btn.name = String(opt.id)
			btn.custom_minimum_size = Vector2(0, 36)
			box.add_child(btn)
		var blocked_now := not opt.affordable(_treasury_state(), _honor_state(), _spend_escrow())
		btn.text = _option_label(opt)
		btn.disabled = _applied
		btn.modulate = Color(0.55, 0.52, 0.48, 1) if blocked_now else Color(1, 1, 1, 1)
		if not bool(btn.get_meta("gift_bound", false)):
			btn.pressed.connect(_on_option_pressed.bind(opt.id))
			btn.set_meta("gift_bound", true)
		_buttons[String(opt.id)] = btn


func _option_label(opt: GiftOption) -> String:
	var title := _loc("ui.gift.%s" % String(opt.id))
	if title.begins_with("ui.gift."):
		title = String(opt.id)
	return "%s — %s %s" % [title, str(opt.horses), _loc("ui.embassy_ledger.horses")]


func _detail_line(opt: GiftOption) -> String:
	if opt == null:
		return ""
	return "%s %s · %s %s" % [
		str(opt.horses),
		_loc("ui.embassy_ledger.horses"),
		str(opt.marks),
		_loc("ui.embassy_ledger.marks"),
	]


func _block_reason(opt: GiftOption, treasury: Treasury, honor: HonorState) -> StringName:
	if opt == null:
		return &"horses"
	if opt.has_method("block_reason"):
		return opt.block_reason(treasury, honor, _spend_escrow())
	if not opt.affordable(treasury, honor, _spend_escrow()):
		return &"horses"
	return &""


func _spend_escrow() -> bool:
	return gift != null and bool(gift.spend_escrow_first)


func _blocked_loc(reason: StringName) -> String:
	if reason == &"marks":
		return "ui.embassy_ledger.blocked_marks"
	if reason == &"onores":
		return "ui.embassy_ledger.blocked_onores"
	return "ui.embassy_ledger.blocked"


func _selected() -> GiftOption:
	if gift == null or selected_id == &"":
		return null
	return gift.option(selected_id)


func _load_gift() -> void:
	if gift != null:
		return
	gift = GiftToKing.from_file()


func _confirm_button() -> Button:
	return get_node_or_null(NodePath("Center/Confirm")) as Button


func _label(path: String) -> Label:
	return get_node_or_null(NodePath(path)) as Label


func _honor_state() -> HonorState:
	var service := _autoload("HonorService")
	if service and "state" in service:
		var state: Variant = service.get("state")
		if state is HonorState:
			return state
	return null


func _treasury_state() -> Treasury:
	var service := _autoload("TreasuryService")
	if service and "state" in service:
		var state: Variant = service.get("state")
		if state is Treasury:
			return state
	return null


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(node_name))
	return null


func _loc(key: String) -> String:
	var loc := _autoload("Loc")
	if loc and loc.has_method("text"):
		return str(loc.call("text", key))
	return key
