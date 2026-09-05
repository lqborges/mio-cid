extends SceneTree
## Headless a3_valencia_wait: 21 days, lists_wait, no mouth-cost.

const WORLD := "res://content/chapters/a3_valencia_wait/world.tscn"
const CARRION := "res://content/chapters/a3_carrion/world.tscn"


var _honor: Variant
var _treasury: Variant
var _clock: Variant
var _runner: Variant
var _state: Variant


func _initialize() -> void:
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_state = get_root().get_node_or_null(NodePath("GameState"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_rest_three_weeks())
	failures.append_array(_check_graph())
	_finish(failures)


func _check_rest_three_weeks() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep()
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("wait world failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	if world.get_node_or_null("Jimena") == null:
		failures.append("Jimena must rest in Valencia")
	if world.get_node_or_null("JimenaZone") == null:
		failures.append("JimenaZone missing")
	if world.get_node_or_null("RestZone") == null:
		failures.append("RestZone missing")
	var jimena: Node = world.get_node_or_null("Jimena")
	if jimena == null or not jimena.is_in_group("interactable"):
		failures.append("Jimena must be interactable")
	if _clock and str(_clock.segment_id()) != "lists_wait":
		failures.append("clock segment want lists_wait got %s" % _clock.segment_id())
	var marks_before := 0.0
	if _treasury and "state" in _treasury and _treasury.state and "marks" in _treasury.state:
		marks_before = float(_treasury.state.marks)
	var unfed_before := int(_clock.unfed_streak) if _clock else 0
	var days_before := int(_clock.days_elapsed) if _clock else 0
	world.rest_three_weeks()
	if not bool(world.call("wait_done")):
		failures.append("rest_three_weeks must mark wait done")
	if _clock and int(_clock.days_elapsed) < days_before + 21:
		failures.append("lists_wait must advance 21 days, got %s" % _clock.days_elapsed)
	if _clock and int(_clock.unfed_streak) != unfed_before:
		failures.append("lists_wait must not increment unfed_streak")
	if _treasury and "state" in _treasury and _treasury.state and "marks" in _treasury.state:
		if float(_treasury.state.marks) != marks_before:
			failures.append("lists_wait must not spend marks")
	if not ResourceLoader.exists(CARRION):
		failures.append("a3_carrion must keep shipping")
	if not bool(world.get("_left")):
		failures.append("rest must travel to a3_carrion when dest exists")
	if _runner and String(_runner.current_id) != "a3_carrion":
		failures.append("must travel() to a3_carrion, got %s" % _runner.current_id)
	world.free()
	return failures


func _check_graph() -> PackedStringArray:
	var failures: PackedStringArray = []
	if _runner == null or not _runner.has_method("can_travel"):
		failures.append("ChapterRunner.can_travel missing")
		return failures
	var flags := PackedStringArray(["hub_lock_cardena", "horse_companion"])
	if not bool(_runner.can_travel(&"a3_toledo", &"a3_valencia_wait", flags)):
		failures.append("toledo -> wait must stay open")
	if not bool(_runner.can_travel(&"a3_valencia_wait", &"a3_carrion", flags)):
		failures.append("wait -> carrion must stay open")
	return failures


func _prep() -> void:
	if _honor and _honor.has_method("reset_state"):
		_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _treasury and _treasury.has_method("reset"):
		_treasury.reset()
	if _clock and _clock.has_method("reset"):
		_clock.reset()
	if _state and _state.has_method("reset_swords"):
		_state.reset_swords()
	if _runner and _runner.has_method("restore"):
		_runner.restore(&"a3_valencia_wait", PackedStringArray(["hub_lock_cardena", "horse_companion", "toledo_done"]))


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a3_valencia_wait: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_valencia_wait: %s" % failure)
	quit(1)
