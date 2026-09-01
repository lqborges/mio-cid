extends Node
# Autoload singleton. Do not add class_name — Godot 4 hides the Node behind the named class.

enum Segment { PAUSED, CAMP_NIGHT, REFUSE_48H, SIEGE, LISTS_WAIT }

signal night_ticked(day: int)

@export var segment: Segment = Segment.PAUSED
@export var days_elapsed: int = 0
@export var unfed_streak: int = 0
@export var plazo_days_left: int = 9
@export var lists_seed: int = 0


func reset() -> void:
	segment = Segment.PAUSED
	days_elapsed = 0
	unfed_streak = 0
	plazo_days_left = 9
	lists_seed = 0


func feeds_tonight() -> bool:
	return segment == Segment.CAMP_NIGHT or segment == Segment.REFUSE_48H


func set_segment_name(name: String) -> void:
	segment = _parse_segment(name.to_lower())


func segment_id() -> String:
	match segment:
		Segment.CAMP_NIGHT:
			return "camp_night"
		Segment.REFUSE_48H:
			return "refuse_48h"
		Segment.SIEGE:
			return "siege"
		Segment.LISTS_WAIT:
			return "lists_wait"
		_:
			return "paused"


func tick_night() -> void:
	if segment == Segment.PAUSED:
		return
	days_elapsed += 1
	if feeds_tonight():
		TreasuryService.camp_night()
	night_ticked.emit(days_elapsed)
	if EventBus:
		EventBus.clock_night.emit(StringName(segment_id()), days_elapsed)


func advance_plazo(days: int) -> void:
	# Independent HUD countdown. Never a feeding segment; never camp_night.
	if days <= 0:
		return
	plazo_days_left = maxi(0, plazo_days_left - days)
	_maybe_plazo_expired()


func advance_calendar(days: int) -> void:
	# Siege / lists rest-skip. Calendar only; no mouth-cost.
	if days <= 0:
		return
	days_elapsed += days


func rest_camp() -> void:
	var previous := segment
	segment = Segment.CAMP_NIGHT
	tick_night()
	segment = previous


func run_refuse_48h() -> void:
	var previous := segment
	segment = Segment.REFUSE_48H
	tick_night()
	tick_night()
	segment = previous


func to_save() -> Dictionary:
	return {
		"segment": segment_id(),
		"days_elapsed": days_elapsed,
		"unfed_streak": unfed_streak,
		"plazo_days_left": plazo_days_left,
		"lists_seed": lists_seed,
	}


func from_save(data: Dictionary) -> void:
	segment = _parse_segment(str(data.get("segment", "paused")))
	days_elapsed = maxi(0, int(data.get("days_elapsed", 0)))
	unfed_streak = maxi(0, int(data.get("unfed_streak", 0)))
	plazo_days_left = maxi(0, int(data.get("plazo_days_left", 9)))
	lists_seed = int(data.get("lists_seed", 0))


func _parse_segment(name: String) -> Segment:
	match name:
		"camp_night":
			return Segment.CAMP_NIGHT
		"refuse_48h":
			return Segment.REFUSE_48H
		"siege":
			return Segment.SIEGE
		"lists_wait":
			return Segment.LISTS_WAIT
		_:
			return Segment.PAUSED


func _maybe_plazo_expired() -> void:
	if plazo_days_left > 0:
		return
	if ChapterRunner == null or not ("current_id" in ChapterRunner):
		return
	var beat := String(ChapterRunner.current_id)
	if beat.is_empty() or beat == "a1_navapalos":
		return
	if beat.begins_with("a1_") and EventBus:
		EventBus.hard_fail.emit(&"plazo_expired")
