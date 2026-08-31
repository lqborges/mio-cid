class_name KeepOrSell
extends Control

## Keep/sell overlay. Labels from Loc (Spanish first, English keys).

signal resolved(choice: StringName, result: Dictionary)

## When true, sell marks the town sold and fires honor without dividing the pile.
@export var defer_split: bool = false

var holding: Resource

@onready var _title: Label = $Center/Title
@onready var _place: Label = $Center/Place
@onready var _booty: Label = $Center/Booty
@onready var _warn: Label = $Center/Warn
@onready var _keep: Button = $Center/Keep
@onready var _sell: Button = $Center/Sell


func _ready() -> void:
	if _keep:
		_keep.pressed.connect(_on_keep)
	if _sell:
		_sell.pressed.connect(_on_sell)
	_refresh()


func bind_holding(next: Resource) -> void:
	holding = next
	_refresh()


func _on_keep() -> void:
	if holding == null or not holding.has_method("keep"):
		return
	var result: Dictionary = holding.keep()
	resolved.emit(&"keep", result)


func _on_sell() -> void:
	if holding == null or not holding.has_method("sell"):
		return
	var result: Dictionary
	if defer_split:
		result = holding.sell({}, false)
	else:
		result = holding.sell()
	resolved.emit(&"sell", result)


func _refresh() -> void:
	var title := _label("Center/Title")
	var keep_btn := get_node_or_null(NodePath("Center/Keep")) as Button
	var sell_btn := get_node_or_null(NodePath("Center/Sell")) as Button
	var place := _label("Center/Place")
	var booty := _label("Center/Booty")
	var warn := _label("Center/Warn")
	if title:
		title.text = _loc("ui.keep_or_sell.title")
	if keep_btn:
		keep_btn.text = _loc("ui.keep_or_sell.keep")
	if sell_btn:
		sell_btn.text = _loc("ui.keep_or_sell.sell")
	if holding == null:
		if place:
			place.text = ""
		if booty:
			booty.text = ""
		if warn:
			warn.text = ""
		return
	if place:
		var key := String(holding.get("display_name_key"))
		place.text = _loc(key) if not key.is_empty() else str(holding.get("location_id"))
	if booty:
		var pile: Variant = holding.get("booty")
		var marks := 0
		var horses := 0
		if pile is Dictionary:
			marks = int(pile.get("marks", 0))
			horses = int(pile.get("horses", 0))
		booty.text = "%s %s · %s %s" % [
			str(marks),
			_loc("ui.keep_or_sell.marks"),
			str(horses),
			_loc("ui.keep_or_sell.horses"),
		]
	if warn:
		if bool(holding.get("alfonso_protectorate")):
			warn.text = _loc("ui.keep_or_sell.protectorate_warn")
		elif bool(holding.get("keep_past_deadline_fail")):
			warn.text = _loc("ui.keep_or_sell.deadline_warn")
		else:
			warn.text = ""


func _label(path: String) -> Label:
	return get_node_or_null(NodePath(path)) as Label


func _loc(key: String) -> String:
	var loc: Node = null
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		loc = (loop as SceneTree).root.get_node_or_null(NodePath("Loc"))
	if loc and loc.has_method("text"):
		return str(loc.call("text", key))
	return key
