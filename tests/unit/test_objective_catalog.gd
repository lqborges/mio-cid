extends SceneTree
## Headless objective catalog. Run: godot --headless --path . -s res://tests/unit/test_objective_catalog.gd


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_opening_objectives())
	failures.append_array(_test_locks_and_journal())
	failures.append_array(_test_campaign_steps())
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
	var honest := PackedStringArray(["hub_lock_cardena", "arcas_refused"])
	var tagus: Array = catalog.journal("a2_tagus", honest)
	for item in tagus:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if str(row.get("id", "")) == "repay" or str(row.get("chapter", "")) == "a2_repay_raquel":
			failures.append("honest Arcas path must not journal the skipped repay branch")
	var cheated := PackedStringArray(["hub_lock_cardena", "arcas_cheated"])
	var repaid: Array = catalog.journal("a2_tagus", cheated)
	var repaid_ids: PackedStringArray = PackedStringArray()
	for item in repaid:
		if item is Dictionary:
			repaid_ids.append(str(item.get("id", "")))
	if "repay" not in repaid_ids:
		failures.append("cheated path at Tagus must recap the repay visit")
	return failures


func _test_campaign_steps() -> PackedStringArray:
	var failures: PackedStringArray = []
	var catalog: ObjectiveCatalog = ObjectiveCatalog.from_file()
	var alcocer_start: Dictionary = catalog.current("a1_alcocer", PackedStringArray())
	if str(alcocer_start.get("id", "")) != "alcocer_occupy":
		failures.append("Alcocer start must ask to occupy, got %s" % str(alcocer_start.get("id", "")))
	var after_wait := PackedStringArray(["alcocer_occupied", "alcocer_waited"])
	var sortie: Dictionary = catalog.current("a1_alcocer", after_wait)
	if str(sortie.get("id", "")) != "alcocer_sortie":
		failures.append("after the wait Alcocer must ask for the sortie, got %s" % str(sortie.get("id", "")))
	var hub_open: Dictionary = catalog.current("a2_jeronimo", PackedStringArray(["jeronimo_appointed"]))
	if str(hub_open.get("id", "")) != "jeronimo_embassy":
		failures.append("appointed hub must point at embassy 2, got %s" % str(hub_open.get("id", "")))
	var hub_home := PackedStringArray(["jeronimo_appointed", "embassy2_done"])
	var yusuf: Dictionary = catalog.current("a2_jeronimo", hub_home)
	if str(yusuf.get("id", "")) != "jeronimo_yusuf":
		failures.append("after embassy 2 the hub must point at Yusuf, got %s" % str(yusuf.get("id", "")))
	var escort: Dictionary = catalog.current("a2_embassy2", PackedStringArray(["avengalvon_recruited"]))
	if str(escort.get("id", "")) != "embassy2_escort":
		failures.append("recruited embassy 2 must ask for the escort, got %s" % str(escort.get("id", "")))
	var garcia: Dictionary = catalog.current("a3_toledo", PackedStringArray())
	if str(garcia.get("id", "")) != "toledo_garcia":
		failures.append("Toledo start must ask for García first, got %s" % str(garcia.get("id", "")))
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_objective_catalog: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_objective_catalog: %s" % failure)
	quit(1)
