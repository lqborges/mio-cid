extends SceneTree
## Headless DialogueBridge test. Tags emit EventBus.
## Run: godot --headless --path . -s res://tests/unit/test_dialogue_bridge.gd
## Autoload identifiers are not visible to a -s MainLoop script; look them up.


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_bridge_emits_honor_logged())
	failures.append_array(_check_loc_smoke_keys())
	_finish(failures)


func _check_bridge_emits_honor_logged() -> PackedStringArray:
	var failures: PackedStringArray = []
	var bus: Node = get_root().get_node_or_null(NodePath("EventBus"))
	if bus == null:
		return PackedStringArray(["EventBus autoload missing"])
	var script: Script = load("res://game/systems/speech/dialogue_bridge.gd") as Script
	if script == null:
		return PackedStringArray(["dialogue_bridge.gd failed to load"])
	var bridge: Node = script.new() as Node
	if bridge == null:
		return PackedStringArray(["dialogue_bridge.gd did not instantiate"])

	var logged: Array = []
	bus.honor_logged.connect(func(event: Variant) -> void:
		logged.append(event)
	)

	bridge.call("handle_line", {
		"tags": PackedStringArray(["honor_event=burgos_camp_river", "flag_set=smoke_seen"]),
	})
	if logged.size() != 1:
		failures.append("honor_event tag did not emit EventBus.honor_logged")
	else:
		var got: Variant = logged[0]
		var id := str(got)
		if typeof(got) == TYPE_OBJECT and "id" in got:
			id = str(got.id)
		if id != "burgos_camp_river":
			failures.append("honor_event tag did not emit EventBus.honor_logged")

	bridge.free()
	return failures


func _check_loc_smoke_keys() -> PackedStringArray:
	var failures: PackedStringArray = []
	var loc: Node = get_root().get_node_or_null(NodePath("Loc"))
	if loc == null or not loc.has_method("text"):
		return PackedStringArray(["Loc autoload missing"])
	var child := str(loc.call("text", "_dev.smoke.child"))
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
