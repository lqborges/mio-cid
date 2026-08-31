extends SceneTree
## Headless a1_cardena farewell and hub-lock test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . --audio-driver Dummy -s res://tests/unit/test_a1_cardena.gd

const WORLD := "res://content/chapters/a1_cardena/world.tscn"
const CID := "res://content/art/characters/cid/cid.tscn"
const NAIL := "a1_cardena.jimena_nail"

var _honor: Variant
var _treasury: Variant
var _clock: Variant
var _runner: Variant
var _loc: Variant
var _world: Node = null


func _initialize() -> void:
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_loc = get_root().get_node_or_null(NodePath("Loc"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_scene_loads())
	if _world:
		failures.append_array(_check_greybox_lights())
		failures.append_array(_check_separate_speakers())
		failures.append_array(_check_spanish_nail_copy())
		failures.append_array(_check_gift_honra_and_marks())
		failures.append_array(await _check_farewell_walk())
		_world.free()
		_world = null
	failures.append_array(_check_gift_at_zero_marks())
	failures.append_array(_check_hub_lock_travel())
	_finish(failures)


func _check_scene_loads() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("a1_cardena/world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	if _world == null:
		failures.append("a1_cardena world did not instantiate")
		return failures
	get_root().add_child(_world)
	var cid: Node = _world.get_node_or_null("Cid")
	if cid == null or not (cid is CharacterBody3D):
		failures.append("world missing instanced Cid")
	var cid_scene: Resource = load(CID)
	if cid_scene == null:
		failures.append("cid.tscn failed to load")
	if _world.get_node_or_null("Jimena") == null:
		failures.append("world missing Jimena")
	if _world.get_node_or_null("Elvira") == null:
		failures.append("world missing Elvira")
	if _world.get_node_or_null("Sol") == null:
		failures.append("world missing Sol")
	if _world.get_node_or_null("Sisebuto") == null:
		failures.append("world missing Sisebuto")
	if _world.get_node_or_null("Chapel") == null:
		failures.append("world missing Chapel")
	if _world.get_node_or_null("CypressA") == null:
		failures.append("world missing Cypress")
	if _world.get_node_or_null("Candle") == null:
		failures.append("world missing Candle")
	if _world.get_node_or_null("FarewellZone") == null:
		failures.append("world missing FarewellZone")
	if _world.find_child("PlazoBar", true, false) == null:
		failures.append("plazo bar missing from a1_cardena HUD")
	if _world.find_child("HallWhisper", true, false) == null:
		failures.append("hall whisper missing from a1_cardena HUD")
	if _world.find_child("HonorMeters", true, false) == null:
		failures.append("honor meters missing from a1_cardena HUD")
	if _runner and "current_id" in _runner and String(_runner.current_id) != "a1_cardena":
		failures.append("ChapterRunner.current_id want a1_cardena got %s" % _runner.current_id)
	return failures


func _check_greybox_lights() -> PackedStringArray:
	var failures: PackedStringArray = []
	var lights := _world.find_children("*", "DirectionalLight3D", true, false)
	if lights.size() != 1:
		failures.append("a1_cardena must have exactly 1 DirectionalLight3D, has %d" % lights.size())
	var extras := _world.find_children("*", "OmniLight3D", true, false)
	extras.append_array(_world.find_children("*", "SpotLight3D", true, false))
	if extras.size() != 0:
		failures.append("a1_cardena has extra local lights")
	var boxes := _world.find_children("*", "CSGBox3D", true, false)
	if boxes.size() < 8:
		failures.append("a1_cardena greybox missing chapel/cloister CSG")
	var trees := _world.find_children("*", "CSGCylinder3D", true, false)
	if trees.size() < 2:
		failures.append("a1_cardena greybox missing cypress CSG")
	return failures


func _check_separate_speakers() -> PackedStringArray:
	var failures: PackedStringArray = []
	var jimena: Node = _world.get_node_or_null("Jimena")
	var elvira: Node = _world.get_node_or_null("Elvira")
	var sol: Node = _world.get_node_or_null("Sol")
	var abbot: Node = _world.get_node_or_null("Sisebuto")
	if jimena == null or elvira == null or sol == null or abbot == null:
		failures.append("Jimena, Elvira, Sol, and Sisebuto must all be in the scene")
		return failures
	var jid := str(jimena.get("character_id")) if "character_id" in jimena else ""
	var eid := str(elvira.get("character_id")) if "character_id" in elvira else ""
	var sid := str(sol.get("character_id")) if "character_id" in sol else ""
	var aid := str(abbot.get("character_id")) if "character_id" in abbot else ""
	if jid != "jimena":
		failures.append("Jimena character_id want jimena got %s" % jid)
	if eid != "elvira":
		failures.append("Elvira character_id want elvira got %s" % eid)
	if sid != "sol":
		failures.append("Sol character_id want sol got %s" % sid)
	if aid != "sisebuto":
		failures.append("Sisebuto character_id want sisebuto got %s" % aid)
	if jid == eid or eid == sid:
		failures.append("family capsules must be separate ids")
	return failures


func _check_spanish_nail_copy() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _loc == null or not _loc.has_method("text"):
		failures.append("Loc autoload missing")
		return failures
	var line := str(_loc.call("text", NAIL))
	if line == NAIL or line.is_empty():
		failures.append("Loc did not resolve a1_cardena.jimena_nail")
	if not line.to_lower().contains("uña") and not line.to_lower().contains("una"):
		failures.append("nail line Spanish missing uña, got %s" % line)
	return failures


func _check_gift_honra_and_marks() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _honor == null or _treasury == null:
		failures.append("HonorService or TreasuryService missing")
		return failures
	if not _world.has_method("give_monastery_gift"):
		failures.append("world missing give_monastery_gift")
		return failures
	_treasury.state.marks = 80
	var honra_before := 40.0
	if "state" in _honor and _honor.state != null and "honra" in _honor.state:
		honra_before = float(_honor.state.honra)
	_world.give_monastery_gift()
	_world.give_monastery_gift()
	if int(_treasury.state.marks) != 40:
		failures.append("gift marks want 40 (80-40) got %s" % _treasury.state.marks)
	var honra_after := honra_before
	if "state" in _honor and _honor.state != null and "honra" in _honor.state:
		honra_after = float(_honor.state.honra)
	if not is_equal_approx(honra_after, honra_before + 4.0):
		failures.append("gift honra want +4, %s -> %s" % [honra_before, honra_after])
	return failures


func _check_farewell_walk() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not _world.has_method("run_farewell"):
		failures.append("world missing run_farewell")
		return failures
	var scene_before: Node = current_scene
	await _world.run_farewell()
	if current_scene != scene_before:
		failures.append("headless farewell must not change_scene when current_scene != world")
	var whisper: Node = _world.find_child("HallWhisper", true, false)
	var shown := ""
	if whisper:
		var label: Node = whisper.get_node_or_null("Line")
		if label and "text" in label:
			shown = str(label.get("text"))
	if not shown.to_lower().contains("uña") and not shown.to_lower().contains("carne"):
		failures.append("hall-whisper did not show the nail line, got %s" % shown)
	return failures


func _check_gift_at_zero_marks() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep_campaign()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("zero-marks: world.tscn failed to load")
		return failures
	_world = (packed as PackedScene).instantiate()
	get_root().add_child(_world)
	_treasury.state.marks = 0
	var honra_before := float(_honor.state.honra)
	_world.give_monastery_gift()
	if int(_treasury.state.marks) != 0:
		failures.append("gift at 0 marks must stay 0, got %s" % _treasury.state.marks)
	if not is_equal_approx(float(_honor.state.honra), honra_before + 4.0):
		failures.append("gift at 0 marks must still apply honra +4")
	_world.free()
	_world = null
	return failures


func _check_hub_lock_travel() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("travel"):
		failures.append("ChapterRunner.travel missing")
		return failures
	if _runner.has_method("restore"):
		_runner.restore(&"a1_cardena", PackedStringArray())
	else:
		_runner.current_id = &"a1_cardena"
		_runner.flags = PackedStringArray()
	var scene_before: Node = current_scene
	if not _runner.travel(&"a1_navapalos"):
		failures.append("cardena -> navapalos should travel")
	if "hub_lock_cardena" not in _runner.flags:
		failures.append("travel must set hub_lock_cardena")
	if _runner.current_id != &"a1_navapalos":
		failures.append("travel must land on a1_navapalos, got %s" % _runner.current_id)
	if current_scene != scene_before:
		failures.append("travel() must not change_scene; goto is the scene swap")
	var flags: PackedStringArray = _runner.flags if "flags" in _runner else PackedStringArray()
	if _runner.has_method("can_travel"):
		if bool(_runner.can_travel(&"a1_navapalos", &"a1_cardena", flags)):
			failures.append("can_travel navapalos -> cardena must be false after hub lock")
		if bool(_runner.can_travel(&"a1_cardena", &"a1_vivar", flags)):
			failures.append("can_travel cardena -> vivar must be false")
		if bool(_runner.can_travel(&"a1_cardena", &"a1_burgos", flags)):
			failures.append("can_travel cardena -> burgos must be false")
		if bool(_runner.can_travel(&"a1_cardena", &"a1_arcas", flags)):
			failures.append("can_travel cardena -> arcas must be false")
	if ResourceLoader.exists("res://content/chapters/a1_navapalos/world.tscn"):
		failures.append("PR-10 must not ship a1_navapalos/world.tscn")
	return failures


func _prep_campaign() -> void:
	if _honor:
		if _honor.has_method("reset_state"):
			_honor.reset_state()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	if _runner:
		if _runner.has_method("restore"):
			_runner.restore(&"a1_cardena", PackedStringArray())
		else:
			if "flags" in _runner:
				_runner.flags = PackedStringArray()
			if "current_id" in _runner:
				_runner.current_id = &"a1_cardena"


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a1_cardena: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a1_cardena: %s" % failure)
	quit(1)
