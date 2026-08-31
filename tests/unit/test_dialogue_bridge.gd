extends SceneTree
## Headless DialogueBridge test. HonorService is still a stub; tags emit EventBus.
## Run: godot --headless --path . -s res://tests/unit/test_dialogue_bridge.gd


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_bridge_emits_honor_logged())
	failures.append_array(_check_loc_smoke_keys())
	_finish(failures)


func _check_bridge_emits_honor_logged() -> PackedStringArray:
	var failures: PackedStringArray = []
	var script: Script = load("res://game/systems/speech/dialogue_bridge.gd") as Script
	if script == null:
		return PackedStringArray(["dialogue_bridge.gd failed to load"])
	var bridge: Node = script.new() as Node
	if bridge == null:
		return PackedStringArray(["dialogue_bridge.gd did not instantiate"])

	var logged: Array = []
	EventBus.honor_logged.connect(func(event: Variant) -> void:
		logged.append(event)
	)

	bridge.call("handle_line", {
		"tags": PackedStringArray(["honor_event=burgos_camp_river", "flag_set=smoke_seen"]),
	})
	if logged.size() != 1 or str(logged[0]) != "burgos_camp_river":
		failures.append("honor_event tag did not emit EventBus.honor_logged")

	# HonorService is a stub: apply must not be required for the emit path.
	if HonorService.has_method("apply"):
		failures.append("HonorService.apply exists earlier than expected; guard still required")

	bridge.free()
	return failures


func _check_loc_smoke_keys() -> PackedStringArray:
	var failures: PackedStringArray = []
	var child := Loc.text("_dev.smoke.child")
	if child == "_dev.smoke.child" or child.is_empty():
		failures.append("Loc.text did not resolve _dev.smoke.child from strings.csv")
	if not child.contains("Burgos"):
		failures.append("Spanish default for _dev.smoke.child missing Burgos")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_dialogue_bridge: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_dialogue_bridge: %s" % failure)
	quit(1)
