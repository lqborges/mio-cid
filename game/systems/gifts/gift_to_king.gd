class_name GiftToKing
extends Resource

## Embassy gift up to Alfonso. Not an autoload.

const DEFAULT_PATH := "res://data/gifts/embassy_1.json"
const EVENT_ID := &"embassy1_gift"

@export var id: StringName
@export var beat: StringName
@export var bearer_id: StringName = &"alvar_fanez"
@export var event_id: StringName = EVENT_ID
@export var spend_escrow_first: bool = false
@export var options: Array[GiftOption] = []
@export var alfonso_response: StringName = &""


func resolve(choice_id: StringName, honor: HonorState, treasury: Treasury) -> HonorEvent:
	var opt := _find(choice_id)
	if opt == null or not opt.affordable(treasury, honor, spend_escrow_first):
		return HonorEvent.new()  # caller shows blocked copy; no assert
	_spend(treasury, opt)
	var ev := HonorEvent.new()
	ev.id = event_id if event_id != &"" else EVENT_ID
	ev.deltas = { "honor": opt.honor_delta }
	ev.tags = PackedStringArray(["gift_up", String(beat)])
	ev.beat = beat
	_apply_honor(ev, honor)
	return ev


func _spend(treasury: Treasury, opt: GiftOption) -> void:
	var horses_left := opt.horses
	var marks_left := opt.marks
	if spend_escrow_first:
		var take_h := mini(maxi(0, treasury.royal_escrow_horses), horses_left)
		treasury.royal_escrow_horses -= take_h
		horses_left -= take_h
		var take_m := mini(maxi(0, treasury.royal_escrow_marks), marks_left)
		treasury.royal_escrow_marks -= take_m
		marks_left -= take_m
	treasury.horses = maxi(0, treasury.horses - horses_left)
	treasury.marks = maxi(0, treasury.marks - marks_left)


func option(choice_id: StringName) -> GiftOption:
	return _find(choice_id)


func _find(choice_id: StringName) -> GiftOption:
	for opt in options:
		if opt != null and opt.id == choice_id:
			return opt
	return null


func _apply_honor(ev: HonorEvent, honor: HonorState) -> void:
	var service := _honor_service()
	if service and service.has_method("apply"):
		var state: Variant = service.get("state") if "state" in service else null
		if honor == null or honor == state:
			service.apply(ev)
			return
	if honor:
		honor.apply(ev)


func _honor_service() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath("HonorService"))
	return null


static func from_file(path: String = DEFAULT_PATH) -> GiftToKing:
	if not FileAccess.file_exists(path):
		push_warning("GiftToKing: missing %s" % path)
		return GiftToKing.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return from_dict(parsed)
	push_warning("GiftToKing: %s is not an object" % path)
	return GiftToKing.new()


static func from_dict(data: Dictionary) -> GiftToKing:
	var gift := GiftToKing.new()
	gift.id = _name(data.get("id", ""))
	gift.beat = _name(data.get("beat", ""))
	gift.bearer_id = _name(data.get("bearer", data.get("bearer_id", "alvar_fanez")))
	if gift.bearer_id == &"":
		gift.bearer_id = &"alvar_fanez"
	gift.alfonso_response = _name(data.get("alfonso_response", ""))
	gift.event_id = _name(data.get("honor_event", data.get("honor_event_id", data.get("event_id", ""))))
	if gift.event_id == &"":
		gift.event_id = EVENT_ID
	gift.spend_escrow_first = bool(data.get("spend_escrow_first", true))
	var raw: Variant = data.get("player_options", data.get("options", []))
	var packed: Array[GiftOption] = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				packed.append(GiftOption.from_dict(item))
	gift.options = packed
	return gift


static func _name(raw: Variant) -> StringName:
	if raw == null:
		return &""
	var text := str(raw)
	return StringName(text) if not text.is_empty() else &""
