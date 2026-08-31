extends SceneTree
## Headless SaveService HMAC / envelope test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_save_hmac.gd
## When gdUnit4 v6.2.1 is vendored, rewrite this as a GdUnitTestSuite.
## Autoload identifiers are not visible to a -s MainLoop script; look them up.

var _save: Variant
var _honor: Variant


func _initialize() -> void:
	var failures: PackedStringArray = []
	_save = get_root().get_node_or_null(NodePath("SaveService"))
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	if _save == null:
		failures.append("SaveService autoload missing")
		_finish(failures)
		return
	if _honor == null:
		failures.append("HonorService autoload missing")
		_finish(failures)
		return
	_wipe_saves()
	_honor.reset_state()
	_honor.roster = null
	failures.append_array(_test_hmac_excludes_hmac_field())
	failures.append_array(_test_canonical_key_order())
	failures.append_array(_test_envelope_hmac_outside_payload())
	failures.append_array(_test_honor_roundtrip())
	failures.append_array(_test_roster_loyalty_when_present())
	failures.append_array(_test_tamper_does_not_apply())
	failures.append_array(_test_atomic_write_and_autosave())
	failures.append_array(_test_payload_has_no_screenshot_or_pii())
	_honor.reset_state()
	_honor.roster = null
	_wipe_saves()
	_finish(failures)


func _test_hmac_excludes_hmac_field() -> PackedStringArray:
	var failures: PackedStringArray = []
	var payload := {"version": 1, "chapter": "a1_cardena", "flags": []}
	var digest: String = _save.hmac_hex(payload)
	if digest.is_empty():
		failures.append("hmac_hex returned empty")
		return failures
	payload["hmac"] = "should-not-change-digest"
	if _save.hmac_hex(payload) != digest:
		failures.append("HMAC must exclude the hmac field")
	return failures


func _test_canonical_key_order() -> PackedStringArray:
	var failures: PackedStringArray = []
	var a := {"version": 1, "chapter": "a1_burgos"}
	var b := {"chapter": "a1_burgos", "version": 1}
	if _save.hmac_hex(a) != _save.hmac_hex(b):
		failures.append("HMAC must be over canonical (sorted-key) payload bytes")
	return failures


func _test_envelope_hmac_outside_payload() -> PackedStringArray:
	var failures: PackedStringArray = []
	_honor.reset_state()
	if _save.save(1) != OK:
		failures.append("save(1) failed: %s" % _save.last_error)
		return failures
	var envelope: Dictionary = _save._parse_envelope(_save.slot_path(1))
	if not envelope.has("payload") or not envelope.has("hmac"):
		failures.append("on-disk envelope must be {payload, hmac}")
		return failures
	if typeof(envelope["payload"]) != TYPE_DICTIONARY:
		failures.append("payload must be an object, not a hmac-bearing string blob")
		return failures
	var payload: Dictionary = envelope["payload"]
	if payload.has("hmac"):
		failures.append("hmac must live outside payload")
	var honor: Variant = payload.get("honor", {})
	if typeof(honor) != TYPE_DICTIONARY:
		failures.append("payload.honor missing")
	elif not honor.has("onores") or not honor.has("stains"):
		failures.append("payload.honor must include meters and stains")
	if not payload.has("chapter") or not payload.has("flags"):
		failures.append("payload must include chapter_id and flags stub")
	if str(envelope["hmac"]) != _save.hmac_hex(payload):
		failures.append("stored hmac does not match canonical payload bytes")
	return failures


func _test_honor_roundtrip() -> PackedStringArray:
	var failures: PackedStringArray = []
	_honor.reset_state()
	var before: HonorState = _honor.state
	_honor.state.onores = 24.0
	_honor.state.honor = 18.0
	_honor.state.honra = 36.0
	_honor.state.stains = PackedStringArray(["arcas_cheat"])
	if _save.save(2) != OK:
		failures.append("honor save failed: %s" % _save.last_error)
		return failures
	_honor.reset_state()
	var loaded: Dictionary = _save.load(2)
	if loaded.is_empty():
		failures.append("honor load failed: %s" % _save.last_error)
		return failures
	if _honor.state != before:
		failures.append("load replaced HonorState; HUD meter_changed would drop")
	if not is_equal_approx(_honor.state.onores, 24.0):
		failures.append("loaded onores want 24 got %s" % _honor.state.onores)
	if not is_equal_approx(_honor.state.honor, 18.0):
		failures.append("loaded honor want 18 got %s" % _honor.state.honor)
	if not is_equal_approx(_honor.state.honra, 36.0):
		failures.append("loaded honra want 36 got %s" % _honor.state.honra)
	if not _honor.state.has_stain(&"arcas_cheat"):
		failures.append("loaded stains missing arcas_cheat")
	return failures


func _test_roster_loyalty_when_present() -> PackedStringArray:
	var failures: PackedStringArray = []
	var roster := MesnadaRoster.from_starting_seed()
	_honor.roster = roster
	var martin: MesnadaMember = roster.member(&"martin_antolinez")
	if martin == null:
		failures.append("starting seed missing martin_antolinez")
		_honor.roster = null
		return failures
	martin.loyalty = 0.42
	roster.lanzas = 40
	if _save.save(3) != OK:
		failures.append("roster save failed: %s" % _save.last_error)
		_honor.roster = null
		return failures
	martin.loyalty = 0.99
	roster.lanzas = 12
	var loaded: Dictionary = _save.load(3)
	if loaded.is_empty():
		failures.append("roster load failed: %s" % _save.last_error)
	if not loaded.has("mesnada"):
		failures.append("payload omitted mesnada though GameState.roster exists")
	if not is_equal_approx(martin.loyalty, 0.42):
		failures.append("loaded Martín loyalty want 0.42 got %s" % martin.loyalty)
	if roster.lanzas != 40:
		failures.append("loaded lanzas want 40 got %s" % roster.lanzas)
	_honor.roster = null
	var without: Dictionary = _save.collect_payload()
	if without.has("mesnada"):
		failures.append("payload must omit mesnada when GameState.roster is null")
	return failures


func _test_tamper_does_not_apply() -> PackedStringArray:
	var failures: PackedStringArray = []
	_honor.reset_state()
	_honor.state.onores = 30.0
	if _save.save(4) != OK:
		failures.append("tamper setup save failed")
		return failures
	var envelope: Dictionary = _save._parse_envelope(_save.slot_path(4))
	if envelope.is_empty() or typeof(envelope.get("payload", null)) != TYPE_DICTIONARY:
		failures.append("tamper setup could not parse envelope")
		return failures
	var payload: Dictionary = envelope["payload"]
	var honor: Dictionary = payload.get("honor", {})
	honor["onores"] = 1.0
	payload["honor"] = honor
	envelope["payload"] = payload
	if _save._atomic_write(_save.slot_path(4), JSON.stringify(envelope, "", true), false) != OK:
		failures.append("tamper rewrite failed")
		return failures
	_honor.state.onores = 30.0
	var loaded: Dictionary = _save.load(4)
	if not loaded.is_empty():
		failures.append("tampered payload must not load")
	if _save.last_error != &"save_damaged":
		failures.append("tampered save last_error want save_damaged got %s" % _save.last_error)
	if not is_equal_approx(_honor.state.onores, 30.0):
		failures.append("tampered save must not apply honor, got %s" % _honor.state.onores)
	return failures


func _test_atomic_write_and_autosave() -> PackedStringArray:
	var failures: PackedStringArray = []
	_honor.reset_state()
	if _save.autosave() != OK:
		failures.append("autosave failed: %s" % _save.last_error)
		return failures
	_honor.state.onores = 11.0
	if _save.autosave() != OK:
		failures.append("second autosave failed: %s" % _save.last_error)
	if not FileAccess.file_exists(_save.autosave_prev_path()):
		failures.append("autosave must keep autosave.prev")
	if _save.autosave_chapter(&"a1_cardena") != OK:
		failures.append("autosave_chapter failed: %s" % _save.last_error)
	if not FileAccess.file_exists(_save.chapter_path("a1_cardena")):
		failures.append("chapter autosave file missing")
	var dir := DirAccess.open(_save.SAVE_DIR)
	if dir == null:
		failures.append("save dir missing after write")
		return failures
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tmp"):
			failures.append("atomic write left tmp %s" % name)
		name = dir.get_next()
	dir.list_dir_end()
	if _save.save(0) == OK or _save.save(6) == OK:
		failures.append("slots outside 1-5 must fail")
	return failures


func _test_payload_has_no_screenshot_or_pii() -> PackedStringArray:
	var failures: PackedStringArray = []
	var payload: Dictionary = _save.collect_payload()
	for forbidden in ["screenshot", "png", "viewport", "steam_id", "steam", "user_id", "email"]:
		if payload.has(forbidden):
			failures.append("payload must not include %s" % forbidden)
	var dumped := JSON.stringify(payload).to_lower()
	for token in ["steam", "screenshot", "http://", "https://"]:
		if dumped.contains(token):
			failures.append("payload leaked %s" % token)
	return failures


func _wipe_saves() -> void:
	var dir := DirAccess.open(_save.SAVE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var files: PackedStringArray = []
	while name != "":
		if not dir.current_is_dir():
			files.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	for file_name in files:
		dir.remove(file_name)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_save_hmac: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_save_hmac: %s" % failure)
	quit(1)
