class_name GiftOption
extends Resource

## One embassy bundle. Horses are animals, not marks.

@export var id: StringName
@export var horses: int = 0
@export var marks: int = 0
@export var honor_delta: float = 0.0
@export var blocked_if_horses_lt: int = 0
@export var blocked_if_onores_gt: float = 100.0


func affordable(t: Treasury, honor: HonorState) -> bool:
	if t == null or honor == null:
		return false
	if t.horses < horses or t.marks < marks or t.horses < blocked_if_horses_lt:
		return false
	return honor.onores <= blocked_if_onores_gt


static func from_dict(data: Dictionary) -> GiftOption:
	var opt := GiftOption.new()
	opt.id = _name(data.get("id", ""))
	opt.horses = maxi(0, int(data.get("horses", 0)))
	opt.marks = maxi(0, int(data.get("marks", 0)))
	opt.honor_delta = float(data.get("honor_delta", 0.0))
	opt.blocked_if_horses_lt = maxi(0, int(data.get("blocked_if_horses_lt", 0)))
	if data.has("blocked_if_onores_gt"):
		opt.blocked_if_onores_gt = float(data.get("blocked_if_onores_gt"))
	return opt


static func _name(raw: Variant) -> StringName:
	if raw == null:
		return &""
	var text := str(raw)
	return StringName(text) if not text.is_empty() else &""
