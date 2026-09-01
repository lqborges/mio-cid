extends SceneTree
## Headless spectator lists.

const WORLD := "res://content/chapters/a3_carrion/world.tscn"
const PENTECOST := "res://content/chapters/a3_pentecost/world.tscn"
const LAYER_SPECTATOR := 64

var _honor: Variant
var _runner: Variant
var _state: Variant
var _bus: Variant
var _fails: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_runner = get_root().get_node_or_null(NodePath("ChapterRunner"))
	_state = get_root().get_node_or_null(NodePath("GameState"))
	_bus = get_root().get_node_or_null(NodePath("EventBus"))
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_spectator())
	failures.append_array(_check_generous_resolve())
	failures.append_array(_check_all_losses_name_empty())
	_finish(failures)


func _check_spectator() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep(true)
	var packed: Resource = load(WORLD)
	if packed == null:
		failures.append("carrion world failed to load")
		return failures
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	if not bool(world.call("cid_is_spectator")):
		failures.append("Cid must be spectator with no HurtBox")
	var cid: Node = world.get_node_or_null("Cid")
	if cid == null:
		failures.append("Cid missing")
	else:
		if int(cid.collision_layer) != LAYER_SPECTATOR:
			failures.append("Cid collision_layer want spectator 64, got %s" % cid.collision_layer)
		if cid.get_node_or_null("HurtBox") != null:
			failures.append("Cid must have no HurtBox")
		if cid.has_method("possess_pawn") and bool(cid.call("possess_pawn", cid)):
			failures.append("possess_pawn must denylist Cid")
	if world.get_node_or_null("ListCamera") == null:
		failures.append("ListCamera missing")
	world.free()
	return failures


func _check_generous_resolve() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep(true)
	var packed: Resource = load(WORLD)
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	world.call("resolve_lists")
	if not bool(world.call("lists_resolved")):
		failures.append("resolve_lists must finish")
	var results: Array = world.call("lists_results")
	var wins := 0
	for row in results:
		if row is Dictionary and bool(row.get("won", false)):
			wins += 1
	if wins != 3:
		failures.append("generous lists want 3-0, got %d (%s)" % [wins, str(results)])
	if _fails.size() != 0:
		failures.append("generous lists must not hard_fail, got %s" % str(_fails))
	if not ResourceLoader.exists(PENTECOST):
		failures.append("a3_pentecost must keep shipping")
	if not bool(world.get("_left")):
		failures.append("win must travel to pentecost")
	world.free()
	return failures


func _check_all_losses_name_empty() -> PackedStringArray:
	var failures: PackedStringArray = []
	_prep(false)
	var packed: Resource = load(WORLD)
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	_fails.clear()
	world.call("resolve_lists")
	if _fails.find("name_empty") < 0:
		failures.append("losing all three must hard_fail name_empty, got %s" % str(_fails))
	if bool(world.get("_left")):
		failures.append("name_empty must not travel to pentecost")
	world.free()
	return failures


func _prep(generous: bool) -> void:
	if _honor and _honor.has_method("reset_state"):
		_honor.reset_state()
		_honor.roster = MesnadaRoster.from_starting_seed()
	if _state and _state.has_method("reset_swords"):
		_state.reset_swords()
	if generous:
		if _state:
			if _state and _state.has_method("clock"):
				var clock: Variant = _state.clock()
				if clock != null and "lists_seed" in clock:
					clock.lists_seed = 7
			var tizona: SwordItem = _state.sword(&"tizona")
			var colada: SwordItem = _state.sword(&"colada")
			if tizona:
				tizona.set_phase_name("IN_CHAMPION_HAND")
			if colada:
				colada.set_phase_name("IN_CHAMPION_HAND")
		if _honor and _honor.state:
			_honor.state.honra = 40.0
	else:
		if _honor and _honor.roster:
			var roster: MesnadaRoster = _honor.roster
			var jeronimo := roster.member(&"jeronimo")
			if jeronimo == null:
				jeronimo = MesnadaMember.from_id(&"jeronimo")
				roster.add_member(jeronimo)
			for mid in [&"pero_bermudez", &"martin_antolinez", &"muno_gustioz", &"felez_munoz", &"jeronimo"]:
				var m := roster.member(mid)
				if m:
					m.alive = false
					m.loyalty = 0.1
					m.will_swear_riepto = false
			if _honor.state:
				_honor.state.honra = 4.0
		if _state:
			if _state and _state.has_method("clock"):
				var clock: Variant = _state.clock()
				if clock != null and "lists_seed" in clock:
					clock.lists_seed = 3
	if _runner and _runner.has_method("restore"):
		_runner.restore(
			&"a3_carrion",
			PackedStringArray(["hub_lock_cardena", "horse_companion", "lists_wait_done", "infantes_fled_bucar"])
		)
	if _bus and _bus.has_signal("hard_fail") and not _bus.hard_fail.is_connected(_on_hard_fail):
		_bus.hard_fail.connect(_on_hard_fail)
	_fails.clear()


func _on_hard_fail(reason: StringName) -> void:
	_fails.append(String(reason))


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a3_carrion: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_carrion: %s" % failure)
	quit(1)
