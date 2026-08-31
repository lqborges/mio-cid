class_name SiegeCalendar
extends Resource

## Valencia 9-month calendar. Not a second clock — uses CampaignClock.SIEGE.

const DEFAULT_PATH := "res://data/siege/valencia_events.json"

@export var siege_days: int = 0
@export var rest_skip_min_days: int = 0
@export var rest_skip_max_days: int = 0
@export var wall_storm_enabled: bool = false
@export var events: Array = []


func rest_skip_days() -> int:
	return rest_skip_min_days


func event_count() -> int:
	return events.size()


func due(siege_day: int, fired: PackedStringArray) -> Array:
	var out: Array = []
	for raw in events:
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw
		var eid := str(row.get("id", ""))
		if eid.is_empty() or eid in fired:
			continue
		if int(row.get("day", 0)) <= siege_day:
			out.append(row)
	return out


static func from_file(path: String = DEFAULT_PATH) -> SiegeCalendar:
	if not FileAccess.file_exists(path):
		push_warning("SiegeCalendar: missing %s" % path)
		return SiegeCalendar.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return from_dict(parsed)
	push_warning("SiegeCalendar: %s is not an object" % path)
	return SiegeCalendar.new()


static func from_dict(data: Dictionary) -> SiegeCalendar:
	var cal := SiegeCalendar.new()
	cal.siege_days = int(data.get("siege_days", 0))
	cal.rest_skip_min_days = int(data.get("rest_skip_min_days", 0))
	cal.rest_skip_max_days = int(data.get("rest_skip_max_days", 0))
	cal.wall_storm_enabled = bool(data.get("wall_storm_enabled", false))
	var raw: Variant = data.get("events", [])
	if raw is Array:
		cal.events = raw.duplicate(true)
	return cal
