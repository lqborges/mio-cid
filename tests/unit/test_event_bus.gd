extends SceneTree
## Headless EventBus test (gdUnit4 is still a placeholder under addons/gdUnit4).
## Run: godot --headless --path . -s res://tests/unit/test_event_bus.gd
## When gdUnit4 v6.2.1 is vendored, rewrite this as a GdUnitTestSuite.


func _initialize() -> void:
	var failures: PackedStringArray = []
	var script: GDScript = load("res://game/autoload/event_bus.gd") as GDScript
	if script == null:
		failures.append("could not load event_bus.gd")
		_finish(failures)
		return

	var bus: Node = script.new()
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

	bus.free()
	_finish(failures)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_event_bus: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_event_bus: %s" % failure)
	quit(1)
