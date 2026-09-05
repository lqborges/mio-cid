class_name ObjectiveCatalog
extends RefCounted
## Data-driven current objective + journal. Designers edit JSON, not GDScript.

const CATALOG_PATH := "res://data/objectives/catalog.json"

var objectives: Array = []
var locks: Array = []


static func from_file(path: String = CATALOG_PATH) -> ObjectiveCatalog:
	var catalog := ObjectiveCatalog.new()
	if not FileAccess.file_exists(path):
		push_warning("ObjectiveCatalog: missing %s" % path)
		return catalog
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		catalog.load_dict(parsed)
	return catalog


func load_dict(data: Dictionary) -> void:
	objectives.clear()
	locks.clear()
	var raw_obj: Variant = data.get("objectives", [])
	if raw_obj is Array:
		for item in raw_obj:
			if item is Dictionary:
				objectives.append((item as Dictionary).duplicate(true))
	var raw_locks: Variant = data.get("locks", [])
	if raw_locks is Array:
		for item in raw_locks:
			if item is Dictionary:
				locks.append((item as Dictionary).duplicate(true))


func current(chapter_id: String, flags: PackedStringArray) -> Dictionary:
	var best: Dictionary = {}
	var best_priority := -1
	for item in objectives:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		if str(row.get("chapter", "")) != chapter_id:
			continue
		if not _flags_match(row, flags):
			continue
		var priority := int(row.get("priority", 0))
		if priority >= best_priority:
			best_priority = priority
			best = row
	return best.duplicate(true)


func journal(chapter_id: String, flags: PackedStringArray) -> Array:
	var out: Array = []
	var seen := {}
	for chapter in _chapter_order():
		var row: Dictionary = {}
		if chapter == chapter_id:
			row = current(chapter, flags)
		elif _chapter_visited(chapter, flags):
			row = _completed_for(chapter, flags)
		if row.is_empty():
			continue
		if bool(row.get("spoiler", false)) or not bool(row.get("journal", true)):
			continue
		var id := str(row.get("id", ""))
		if id.is_empty() or seen.has(id):
			continue
		seen[id] = true
		out.append(row)
	return out


func _completed_for(chapter: String, flags: PackedStringArray) -> Dictionary:
	var match := current(chapter, flags)
	if not match.is_empty() and _row_has_visit_evidence(match):
		return match
	for item in objectives:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		if str(row.get("chapter", "")) != chapter:
			continue
		if str(row.get("done_key", "")) != "" and _flags_match(row, flags):
			return row.duplicate(true)
	return {}


func _chapter_visited(chapter: String, flags: PackedStringArray) -> bool:
	return not _completed_for(chapter, flags).is_empty()


func _row_has_visit_evidence(row: Dictionary) -> bool:
	if str(row.get("done_key", "")) != "":
		return true
	var all_flags: Variant = row.get("when_all_flags", [])
	if all_flags is Array and not (all_flags as Array).is_empty():
		return true
	var any_flags: Variant = row.get("when_any_flags", [])
	return any_flags is Array and not (any_flags as Array).is_empty()


func lock_reason(from_id: String, to_id: String, flags: PackedStringArray) -> String:
	for item in locks:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		var want_from := str(row.get("from", ""))
		var want_to := str(row.get("to", ""))
		if not want_from.is_empty() and want_from != from_id:
			continue
		if not want_to.is_empty() and want_to != to_id:
			continue
		if not _flags_match(row, flags):
			continue
		return str(row.get("reason_key", ""))
	return ""


func _flags_match(row: Dictionary, flags: PackedStringArray) -> bool:
	for flag in row.get("when_all_flags", []):
		if str(flag) not in flags:
			return false
	var any_flags: Variant = row.get("when_any_flags", [])
	if any_flags is Array and not (any_flags as Array).is_empty():
		var hit := false
		for flag in any_flags:
			if str(flag) in flags:
				hit = true
				break
		if not hit:
			return false
	for flag in row.get("when_none_flags", []):
		if str(flag) in flags:
			return false
	return true


func _chapter_passed(past_id: String, current_id: String) -> bool:
	var order := _chapter_order()
	var past_i := order.find(past_id)
	var cur_i := order.find(current_id)
	if past_i < 0 or cur_i < 0:
		return false
	return past_i < cur_i


func _chapter_order() -> PackedStringArray:
	return PackedStringArray([
		"a1_vivar", "a1_burgos", "a1_arcas", "a1_cardena", "a1_navapalos",
		"a1_castejon", "a1_alcocer", "a1_embassy1", "a1_poyo", "a1_tevar",
		"a2_murviedro", "a2_siege", "a2_jeronimo", "a2_embassy2", "a2_yusuf",
		"a2_embassy3", "a2_repay_raquel", "a2_tagus", "a2_bodas",
		"a3_leon", "a3_bucar", "a3_despedida", "a3_corpes", "a3_querella",
		"a3_toledo", "a3_valencia_wait", "a3_carrion", "a3_pentecost",
	])
