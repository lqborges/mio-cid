extends Node
# Autoload singleton. Do not add class_name — Godot 4 hides the Node behind the named class.

const SAVE_DIR := "user://saves"
const CURRENT_VERSION := 1
const SLOT_MIN := 1
const SLOT_MAX := 5
# Integrity, not secrecy. Never a Steam ID, hardware id, or user path.
const HMAC_KEY := "mio-cid.save.hmac.v1"

var last_error: StringName = &""


func slot_path(slot: int) -> String:
	return "%s/slot%d.json.gz" % [SAVE_DIR, slot]


func autosave_path() -> String:
	return "%s/autosave.json.gz" % SAVE_DIR


func autosave_prev_path() -> String:
	return "%s/autosave.prev.json.gz" % SAVE_DIR


func chapter_path(chapter_id: String) -> String:
	return "%s/autosave.chapter.%s.json.gz" % [SAVE_DIR, chapter_id.validate_filename()]


func slot_exists(slot: int) -> bool:
	if slot < SLOT_MIN or slot > SLOT_MAX:
		return false
	return FileAccess.file_exists(slot_path(slot))


func collect_payload() -> Dictionary:
	var payload := {
		"version": CURRENT_VERSION,
		"chapter": String(GameState.chapter_id()),
		"flags": _flags_array(),
		"honor": _honor_dict(),
		"applied_once": _applied_once_ids(),
	}
	var roster: Variant = GameState.roster()
	if roster != null:
		if roster.has_method("to_save"):
			payload["mesnada"] = roster.to_save()
		if "lanzas" in roster:
			payload["lanzas"] = int(roster.lanzas)
	payload["treasury"] = _treasury_dict()
	payload["clock"] = _clock_dict()
	return payload


func hmac_hex(payload: Dictionary) -> String:
	var ctx := HMACContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256, HMAC_KEY.to_utf8_buffer())
	if err != OK:
		push_error("SaveService: HMAC start failed (%s)" % err)
		return ""
	err = ctx.update(_canonical_payload_bytes(payload))
	if err != OK:
		push_error("SaveService: HMAC update failed (%s)" % err)
		return ""
	return ctx.finish().hex_encode()


func _canonical_json(data: Variant) -> String:
	# indent "", sort_keys, full_precision — same flags for HMAC bytes and the file.
	return JSON.stringify(data, "", true, true)


func _stable_payload(payload: Dictionary) -> Dictionary:
	# Round-trip through JSON so save HMAC matches load-time stringify of parsed numbers.
	var body: Dictionary = payload.duplicate(true)
	body.erase("hmac")
	var parsed: Variant = JSON.parse_string(_canonical_json(body))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return body


func migrate(payload: Dictionary) -> Dictionary:
	var out: Dictionary = payload.duplicate(true)
	out.erase("hmac")
	var version := int(out.get("version", 0))
	if version < 1:
		out["version"] = CURRENT_VERSION
		if not out.has("chapter"):
			out["chapter"] = ""
		if not out.has("flags"):
			out["flags"] = []
		if not out.has("honor"):
			out["honor"] = {
				"onores": 8.0,
				"honor": 15.0,
				"honra": 40.0,
				"stains": [],
			}
	if not out.has("treasury"):
		out["treasury"] = {
			"marks": 0,
			"horses": 2,
			"cloth": 0,
			"arms": 0,
			"royal_escrow_marks": 0,
			"royal_escrow_horses": 0,
		}
	if not out.has("clock"):
		out["clock"] = {
			"segment": "paused",
			"days_elapsed": 0,
			"unfed_streak": 0,
			"plazo_days_left": 9,
		}
	return out


func save(slot: int) -> Error:
	if slot < SLOT_MIN or slot > SLOT_MAX:
		last_error = &"io"
		return ERR_INVALID_PARAMETER
	return _write_payload(slot_path(slot), collect_payload(), false)


func load(slot: int) -> Dictionary:
	if slot < SLOT_MIN or slot > SLOT_MAX:
		last_error = &"io"
		return {}
	return load_file(slot_path(slot))


func load_file(path: String) -> Dictionary:
	var payload := _verified_payload(path)
	if payload.is_empty():
		return {}
	apply_payload(payload)
	return payload


func autosave() -> Error:
	return _write_payload(autosave_path(), collect_payload(), true)


func autosave_chapter(chapter_id: StringName = &"") -> Error:
	var chapter := String(chapter_id)
	if chapter.is_empty():
		chapter = String(GameState.chapter_id())
	if chapter.is_empty():
		return autosave()
	return _write_payload(chapter_path(chapter), collect_payload(), false)


func apply_payload(payload: Dictionary) -> void:
	var body := migrate(payload)
	_apply_honor(body.get("honor", {}))
	_apply_chapter(body)
	_apply_roster(body)
	_apply_applied_once(body)
	_apply_treasury(body.get("treasury", {}))
	_apply_clock(body.get("clock", {}))


func _canonical_payload_bytes(payload: Dictionary) -> PackedByteArray:
	return _canonical_json(_stable_payload(payload)).to_utf8_buffer()


func _envelope(payload: Dictionary) -> Dictionary:
	var body := _stable_payload(payload)
	return {
		"payload": body,
		"hmac": hmac_hex(body),
	}


func _write_payload(path: String, payload: Dictionary, keep_prev: bool) -> Error:
	return _atomic_write(path, _canonical_json(_envelope(payload)), keep_prev)


func _verified_payload(path: String) -> Dictionary:
	last_error = &""
	path = _adopt_tmp_if_needed(path)
	if path.is_empty() or not FileAccess.file_exists(path):
		last_error = &"missing"
		return {}
	var envelope := _parse_envelope(path)
	if envelope.is_empty():
		if last_error == &"":
			last_error = &"save_damaged"
		return {}
	if not envelope.has("payload") or not envelope.has("hmac"):
		last_error = &"save_damaged"
		return {}
	var payload: Variant = envelope["payload"]
	if typeof(payload) != TYPE_DICTIONARY:
		last_error = &"save_damaged"
		return {}
	var body: Dictionary = payload
	if not _hmac_matches(body, str(envelope["hmac"])):
		# Integrity only. Never phone home on a bad digest.
		last_error = &"save_damaged"
		return {}
	var version := int(body.get("version", 0))
	if version > CURRENT_VERSION:
		last_error = &"unsupported_version"
		return {}
	last_error = &""
	return migrate(body)


func _hmac_matches(payload: Dictionary, digest_hex: String) -> bool:
	var expected := hmac_hex(payload)
	if expected.is_empty() or expected.length() != digest_hex.length():
		return false
	var crypto := Crypto.new()
	return crypto.constant_time_compare(expected.to_utf8_buffer(), digest_hex.to_utf8_buffer())


func _parse_envelope(path: String) -> Dictionary:
	var text := _read_text(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = &"save_damaged"
		return {}
	return parsed


func _read_text(path: String) -> String:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if file == null:
		last_error = &"io"
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _atomic_write(path: String, text: String, keep_prev: bool) -> Error:
	var err := _ensure_save_dir()
	if err != OK:
		last_error = &"io"
		return err
	var tmp_path := "%s.tmp" % path
	var file := FileAccess.open_compressed(tmp_path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if file == null:
		last_error = &"io"
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		last_error = &"io"
		return ERR_CANT_OPEN
	var dest_name := path.get_file()
	var tmp_name := tmp_path.get_file()
	if keep_prev and dir.file_exists(dest_name):
		var prev_name := autosave_prev_path().get_file()
		if dir.file_exists(prev_name):
			dir.remove(prev_name)
		err = dir.rename(dest_name, prev_name)
		if err != OK:
			last_error = &"io"
			return err
	# Godot 4.7 DirAccess.rename overwrites dest; do not unlink first (POSIX replace).
	err = dir.rename(tmp_name, dest_name)
	if err != OK:
		last_error = &"io"
		return err
	last_error = &""
	return OK


func _adopt_tmp_if_needed(path: String) -> String:
	if FileAccess.file_exists(path):
		return path
	var tmp_path := "%s.tmp" % path
	if not FileAccess.file_exists(tmp_path):
		return ""
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return ""
	if dir.rename(tmp_path.get_file(), path.get_file()) != OK:
		return ""
	return path


func _applied_once_ids() -> Array:
	var out: Array = []
	if HonorService == null:
		return out
	for event_id in HonorService._applied_once:
		out.append(str(event_id))
	out.sort()
	return out


func _apply_applied_once(payload: Dictionary) -> void:
	if HonorService == null:
		return
	HonorService._applied_once.clear()
	var raw: Variant = payload.get("applied_once", [])
	if raw is Array:
		for item in raw:
			HonorService._applied_once[str(item)] = true


func _ensure_save_dir() -> Error:
	var abs_path := ProjectSettings.globalize_path(SAVE_DIR)
	if DirAccess.dir_exists_absolute(abs_path):
		return OK
	return DirAccess.make_dir_recursive_absolute(abs_path)


func _honor_dict() -> Dictionary:
	var out := {
		"onores": 8.0,
		"honor": 15.0,
		"honra": 40.0,
		"stains": [],
	}
	var state: Variant = GameState.honor()
	if state == null:
		return out
	if "onores" in state:
		out["onores"] = float(state.onores)
	if "honor" in state:
		out["honor"] = float(state.honor)
	if "honra" in state:
		out["honra"] = float(state.honra)
	if "stains" in state:
		var stains: Array = []
		for stain in state.stains:
			stains.append(str(stain))
		out["stains"] = stains
	return out


func _flags_array() -> Array:
	var out: Array = []
	for flag in GameState.flags():
		out.append(str(flag))
	return out


func _apply_honor(honor: Variant) -> void:
	if typeof(honor) != TYPE_DICTIONARY:
		return
	var data: Dictionary = honor
	var state: Variant = GameState.honor()
	if state == null:
		return
	for meter in [&"onores", &"honor", &"honra"]:
		var key := String(meter)
		if meter not in state or not data.has(key):
			continue
		var old: float = float(state.get(meter))
		var new_v: float = float(data[key])
		state.set(meter, new_v)
		# Keep HonorState identity; HUD meter_changed must follow a load.
		if state.has_signal("meter_changed") and not is_equal_approx(old, new_v):
			state.emit_signal("meter_changed", meter, old, new_v, &"load")
	if "stains" in state and data.has("stains"):
		var stains := PackedStringArray()
		var raw: Variant = data["stains"]
		if raw is Array or raw is PackedStringArray:
			for item in raw:
				stains.append(str(item))
		state.stains = stains


func _apply_chapter(payload: Dictionary) -> void:
	if ChapterRunner == null:
		return
	if "current_id" in ChapterRunner:
		ChapterRunner.current_id = StringName(str(payload.get("chapter", "")))
	if "flags" in ChapterRunner:
		var packed := PackedStringArray()
		var raw: Variant = payload.get("flags", [])
		if raw is Array or raw is PackedStringArray:
			for item in raw:
				packed.append(str(item))
		ChapterRunner.flags = packed


func _treasury_dict() -> Dictionary:
	var out := {
		"marks": 0,
		"horses": 2,
		"cloth": 0,
		"arms": 0,
		"royal_escrow_marks": 0,
		"royal_escrow_horses": 0,
	}
	var treasury: Variant = GameState.treasury() if GameState else null
	if treasury != null and treasury.has_method("to_save"):
		return treasury.to_save()
	return out


func _clock_dict() -> Dictionary:
	var out := {
		"segment": "paused",
		"days_elapsed": 0,
		"unfed_streak": 0,
		"plazo_days_left": 9,
	}
	if CampaignClock != null and CampaignClock.has_method("to_save"):
		return CampaignClock.to_save()
	return out


func _apply_treasury(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var treasury: Variant = GameState.treasury() if GameState else null
	if treasury != null and treasury.has_method("from_save"):
		treasury.from_save(raw)


func _apply_clock(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	if CampaignClock != null and CampaignClock.has_method("from_save"):
		CampaignClock.from_save(raw)


func _apply_roster(payload: Dictionary) -> void:
	var roster: Variant = GameState.roster()
	# Cold-start Cargar: HonorService.roster is null until a New Game in this process.
	if roster == null and HonorService != null and (payload.has("mesnada") or payload.has("lanzas")):
		HonorService.roster = MesnadaRoster.from_starting_seed()
		roster = HonorService.roster
	if roster == null:
		return
	if payload.has("lanzas") and "lanzas" in roster:
		roster.lanzas = int(payload["lanzas"])
	if not payload.has("mesnada") or not roster.has_method("member"):
		return
	var rows: Variant = payload["mesnada"]
	if not (rows is Array):
		return
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = row
		var member: Variant = roster.member(StringName(str(data.get("id", ""))))
		if member == null:
			continue
		if "loyalty" in member and data.has("loyalty"):
			member.loyalty = float(data["loyalty"])
		if "alive" in member and data.has("alive"):
			member.alive = bool(data["alive"])
		if "will_swear_riepto" in member and data.has("will_swear_riepto"):
			member.will_swear_riepto = bool(data["will_swear_riepto"])
