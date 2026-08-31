class_name HonorState
extends Resource

signal meter_changed(meter: StringName, old_value: float, new_value: float, event_id: StringName)

@export var onores: float = 8.0
@export var honor: float = 15.0
@export var honra: float = 40.0
@export var stains: PackedStringArray = []
@export var rage: float = 0.0
@export var mesura: float = 50.0
# unfed_streak lives on CampaignClock only. HonorService reads the clock.

const METERS := [&"onores", &"honor", &"honra"]


func apply(event: HonorEvent) -> Dictionary:
	var result := {}
	if event == null:
		return result
	for meter in METERS:
		var d: float = event.delta_for(meter)
		if d == 0.0:
			continue
		var old: float = float(get(meter))
		var new_v := clampf(old + d, 0.0, 100.0)
		set(meter, new_v)
		meter_changed.emit(meter, old, new_v, event.id)
	if event.stain_id != &"" and String(event.stain_id) not in stains:
		stains.append(String(event.stain_id))
	if event.clear_stain != &"":
		var kept := PackedStringArray()
		var clear := String(event.clear_stain)
		for s in stains:
			if s != clear:
				kept.append(s)
		stains = kept
	if event.has_tag(&"uncurable_by_combat"):
		result["soft_warn"] = &"honra_stolen"
	if event.hard_fail:
		result["hard_fail"] = event.hard_fail_reason
	elif onores <= 0.0:
		result["soft_warn"] = &"cannot_feed"
	if honra < 10.0:
		result["soft_warn"] = &"name_empty_risk"
	return result
