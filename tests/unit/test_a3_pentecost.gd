extends SceneTree
## Headless Pentecost: death without corpse-on-Babieca.

const WORLD := "res://content/chapters/a3_pentecost/world.tscn"
const CORPSE_SCENE := "res://content/chapters/a3_pentecost/babieca_corpse.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	if ResourceLoader.exists(CORPSE_SCENE):
		failures.append("babieca_corpse scene must not exist")
	var packed: Resource = load(WORLD)
	if packed == null or not (packed is PackedScene):
		failures.append("pentecost world failed to load")
		_finish(failures)
		return
	var honor: Node = root.get_node_or_null(NodePath("HonorService"))
	var runner: Node = root.get_node_or_null(NodePath("ChapterRunner"))
	if honor and honor.has_method("reset_state"):
		honor.reset_state()
		honor.roster = MesnadaRoster.from_starting_seed()
	if runner and runner.has_method("restore"):
		runner.restore(&"a3_pentecost", PackedStringArray(["hub_lock_cardena", "horse_companion", "lists_done"]))
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	if world.get_node_or_null("BabiecaCorpse") != null:
		failures.append("BabiecaCorpse node must not exist")
	if bool(world.call("babieca_has_corpse")):
		failures.append("Babieca must not carry a corpse")
	if world.get_node_or_null("Horse") == null:
		failures.append("living Babieca must remain")
	world.call("play_death")
	if not bool(world.call("campaign_ended")):
		failures.append("play_death must end the campaign")
	if not bool(world.call("credits_visible")):
		failures.append("credits must show over Pentecost")
	if bool(world.call("babieca_has_corpse")):
		failures.append("death must not put a corpse on Babieca")
	var cid: Node = world.get_node_or_null("Cid")
	if cid and cid.visible:
		failures.append("Cid body must not remain standing as a horse-corpse tableau")
	if runner and "flags" in runner:
		if "cid_dead" not in runner.flags:
			failures.append("pentecost must set cid_dead")
		if "pentecost_done" not in runner.flags:
			failures.append("pentecost must set pentecost_done")
	world.free()
	_finish(failures)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_a3_pentecost: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_a3_pentecost: %s" % failure)
	quit(1)
