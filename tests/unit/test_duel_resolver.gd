extends SceneTree
## Headless DuelResolver tests. Generous lord 3-0; poor lord loses at least one.

const ResolverScript := preload("res://game/combat/duel_resolver.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_generous_three_oh())
	failures.append_array(_check_poor_lord_loses())
	failures.append_array(_check_cid_never_picked())
	_finish(failures)


func _check_generous_three_oh() -> PackedStringArray:
	var failures: PackedStringArray = []
	var roster := MesnadaRoster.from_starting_seed()
	var honor := HonorState.new()
	honor.honra = 40.0
	var swords := {"tizona": "IN_CHAMPION_HAND", "colada": "IN_CHAMPION_HAND"}
	var flags := PackedStringArray(["infantes_fled_bucar"])
	var shouts := [&"shout_silence", &"shout_silence", &"shout_silence"]
	var resolver: RefCounted = ResolverScript.new()
	var results: Array = resolver.resolve_all(roster, honor, swords, flags, shouts, 7)
	if results.size() != 3:
		failures.append("generous: want 3 results, got %d" % results.size())
		return failures
	var wins := 0
	for row in results:
		if row is Dictionary and bool(row.get("won", false)):
			wins += 1
		if row is Dictionary and String(row.get("champion_id", "")) == "cid":
			failures.append("Cid must never fight")
	if wins != 3:
		failures.append("generous lord must win 3-0, got %d" % wins)
	if String(results[0].get("champion_id", "")) != "pero_bermudez":
		failures.append("duel 0 want pero_bermudez got %s" % results[0].get("champion_id", ""))
	if String(results[1].get("champion_id", "")) != "martin_antolinez":
		failures.append("duel 1 want martin_antolinez got %s" % results[1].get("champion_id", ""))
	if String(results[2].get("champion_id", "")) != "muno_gustioz":
		failures.append("duel 2 want muno_gustioz got %s" % results[2].get("champion_id", ""))
	return failures


func _check_poor_lord_loses() -> PackedStringArray:
	var failures: PackedStringArray = []
	var roster := MesnadaRoster.from_starting_seed()
	var pero := roster.member(&"pero_bermudez")
	if pero:
		pero.alive = false
	var martin := roster.member(&"martin_antolinez")
	if martin:
		martin.loyalty = 0.2
	var honor := HonorState.new()
	honor.honra = 8.0
	var swords := {"tizona": "IN_CHAMPION_HAND", "colada": "IN_CHAMPION_HAND"}
	var flags := PackedStringArray()
	var shouts := [&"shout_once", &"shout_once", &"shout_once"]
	var resolver: RefCounted = ResolverScript.new()
	var results: Array = resolver.resolve_all(roster, honor, swords, flags, shouts, 3)
	var losses := 0
	for row in results:
		if row is Dictionary and not bool(row.get("won", false)):
			losses += 1
		if row is Dictionary and String(row.get("champion_id", "")) == "pero_bermudez":
			failures.append("dead Pero must not fight")
		if row is Dictionary and String(row.get("champion_id", "")) == "martin_antolinez":
			failures.append("Martín who will not swear must not fight")
		if row is Dictionary and String(row.get("champion_id", "")) == "alvar_fanez":
			failures.append("Álvar is not list_eligible")
	if losses < 1:
		failures.append("poor lord must lose at least one list, got %s" % str(results))
	return failures


func _check_cid_never_picked() -> PackedStringArray:
	var failures: PackedStringArray = []
	var roster := MesnadaRoster.from_starting_seed()
	var cid := MesnadaMember.new()
	cid.id = &"cid"
	cid.alive = true
	cid.list_eligible = true
	cid.list_index = 1
	cid.will_swear_riepto = true
	cid.loyalty = 1.0
	cid.combat = 99.0
	roster.add_member(cid)
	var honor := HonorState.new()
	var swords := {}
	var resolver: RefCounted = ResolverScript.new()
	var results: Array = resolver.resolve_all(roster, honor, swords, PackedStringArray(), [], 1)
	for row in results:
		if row is Dictionary and String(row.get("champion_id", "")) == "cid":
			failures.append("Cid must never be picked")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_duel_resolver: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_duel_resolver: %s" % failure)
	quit(1)
