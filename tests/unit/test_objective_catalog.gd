extends SceneTree
## Headless objective catalog. Run: godot --headless --path . -s res://tests/unit/test_objective_catalog.gd


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_opening_objectives())
	failures.append_array(_test_locks_and_journal())
	_finish(failures)


func _test_opening_objectives() -> PackedStringArray:
	var failures: PackedStringArray = []
	var catalog: ObjectiveCatalog = ObjectiveCatalog.from_file()
	if catalog.objectives.is_empty():
		failures.append("catalog failed to load")
		return failures
	var empty := PackedStringArray()
	var talk: Dictionary = catalog.current("a1_vivar", empty)
	if str(talk.get("id", "")) != "vivar_talk":
		failures.append("vivar without flag must ask for first names, got %s" % str(talk.get("id", "")))
	var seen := PackedStringArray(["vivar_seen"])
	var leave: Dictionary = catalog.current("a1_vivar", seen)
	if str(leave.get("id", "")) != "vivar_leave":
		failures.append("vivar_seen must point at the south gate")
	var burgos_start: Dictionary = catalog.current("a1_burgos", PackedStringArray(["burgos_shutters_seen"]))
	if str(burgos_start.get("id", "")) != "burgos_child":
		failures.append("burgos without child_heard must ask for the child, got %s" % str(burgos_start.get("id", "")))
	var after_child := PackedStringArray(["burgos_child_heard"])
	var burgos_inn: Dictionary = catalog.current("a1_burgos", after_child)
	if str(burgos_inn.get("id", "")) != "burgos_inn":
		failures.append("after the child Burgos must point at the inn, got %s" % str(burgos_inn.get("id", "")))
	var after_inn := PackedStringArray(["burgos_child_heard", "burgos_inn_asked"])
	var burgos_camp: Dictionary = catalog.current("a1_burgos", after_inn)
	if str(burgos_camp.get("id", "")) != "burgos_camp":
		failures.append("after the inn Burgos must point at the river camp, got %s" % str(burgos_camp.get("id", "")))
	var choose: Dictionary = catalog.current("a1_arcas", empty)
	if str(choose.get("lock_reason_key", "")) != "lock.arcas_choose":
		failures.append("unresolved arcas must explain the locked exit")
	var cheated := PackedStringArray(["arcas_cheated"])
	var after: Dictionary = catalog.current("a1_arcas", cheated)
	if str(after.get("id", "")) != "arcas_cheat_done":
		failures.append("arcas_cheated must not keep the choose prompt")
	return failures


func _test_locks_and_journal() -> PackedStringArray:
	var failures: PackedStringArray = []
	var catalog: ObjectiveCatalog = ObjectiveCatalog.from_file()
	var locked := PackedStringArray(["hub_lock_cardena", "vivar_seen", "burgos_shutters_seen"])
	var reason := catalog.lock_reason("a1_castejon", "a1_cardena", locked)
	if reason != "lock.cardena_closed":
		failures.append("hub lock must explain Cardeña is closed, got %s" % reason)
	var journal: Array = catalog.journal("a1_burgos", PackedStringArray(["vivar_seen", "burgos_shutters_seen"]))
	var ids: PackedStringArray = PackedStringArray()
	for item in journal:
		if item is Dictionary:
			ids.append(str(item.get("id", "")))
	if "vivar_leave" not in ids and "vivar_talk" not in ids:
		failures.append("journal must recap Vivar after leaving it")
	if "arcas_choose" in ids:
		failures.append("journal must not spoil Arcas before the chapter")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_objective_catalog: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_objective_catalog: %s" % failure)
	quit(1)
