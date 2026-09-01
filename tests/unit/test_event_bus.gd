extends SceneTree
## Headless EventBus test (gdUnit4 is still a placeholder under addons/gdUnit4).
## Run: godot --headless --path . -s res://tests/unit/test_event_bus.gd
## When gdUnit4 v6.2.1 is vendored, rewrite this as a GdUnitTestSuite.


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_autoloads_are_nodes())
	failures.append_array(_check_soft_warn_and_hard_fail())
	_finish(failures)


func _check_autoloads_are_nodes() -> PackedStringArray:
	var failures: PackedStringArray = []
	var names: PackedStringArray = PackedStringArray([
		"EventBus",
		"HonorService",
		"SaveService",
		"ChapterRunner",
		"CampaignClock",
		"TreasuryService",
		"GameState",
		"Loc",
		"MobileLook",
		"HumanoidLooks",
		"DialogueManager",
	])
	for name in names:
		var node: Node = get_root().get_node_or_null(NodePath(name))
		if node == null:
			failures.append("%s autoload missing or not a Node" % name)
	# -s scripts do not see autoload identifiers at compile time; look up nodes.
	var game_state: Node = get_root().get_node_or_null(NodePath("GameState"))
	var campaign_clock: Node = get_root().get_node_or_null(NodePath("CampaignClock"))
	if game_state == null or not game_state.has_method("clock"):
		failures.append("GameState.clock() missing")
	elif game_state.call("clock") != campaign_clock:
		failures.append("GameState.clock() did not return the CampaignClock autoload")
	return failures


func _check_soft_warn_and_hard_fail() -> PackedStringArray:
	var failures: PackedStringArray = []
	var bus: Node = get_root().get_node_or_null(NodePath("EventBus"))
	if bus == null:
		return PackedStringArray(["EventBus autoload missing"])
	var warned: Array[StringName] = []
	var failed: Array[StringName] = []
	bus.soft_warn.connect(func(reason: StringName) -> void:
		warned.append(reason)
	)
	bus.hard_fail.connect(func(reason: StringName) -> void:
		failed.append(reason)
	)

	bus.soft_warn.emit(&"cannot_feed")
	if warned.size() != 1 or warned[0] != &"cannot_feed":
		failures.append("soft_warn did not emit cannot_feed")
	if failed.size() != 0:
		failures.append("soft_warn collapsed into hard_fail")

	bus.hard_fail.emit(&"name_empty")
	if failed.size() != 1 or failed[0] != &"name_empty":
		failures.append("hard_fail did not emit name_empty")
	if warned.size() != 1:
		failures.append("hard_fail collapsed into soft_warn")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_event_bus: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_event_bus: %s" % failure)
	quit(1)
