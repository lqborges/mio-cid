extends SceneTree
## Headless loyalty / seed-roster test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_loyalty.gd

const MEMBER := preload("res://game/actors/mesnada/mesnada_member.gd")
const ROSTER := preload("res://game/actors/mesnada/mesnada_roster.gd")


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_check_gift_ticks_loyalty())
	failures.append_array(_check_alvar_never_deserts())
	failures.append_array(_check_starvation_desertion())
	failures.append_array(_check_seed_invariants())
	failures.append_array(_check_roster_gifts_and_counts())
	failures.append_array(_check_raquel_and_vidas_are_separate())
	_finish(failures)


func _member_from_id(character_id: String) -> Resource:
	return MEMBER.from_id(StringName(character_id))


func _check_gift_ticks_loyalty() -> PackedStringArray:
	var failures: PackedStringArray = []
	var martin: Resource = MEMBER.new()
	martin.loyalty = 0.55
	martin.receive_gift(40.0, false)
	if not is_equal_approx(martin.loyalty, 0.63):
		failures.append("private 40-mark gift should add 0.08 loyalty, got %s" % martin.loyalty)

	var public_gift: Resource = MEMBER.new()
	public_gift.loyalty = 0.55
	public_gift.receive_gift(0.0, true)
	if not is_equal_approx(public_gift.loyalty, 0.59):
		failures.append("public gift should add 0.04 loyalty, got %s" % public_gift.loyalty)

	var both: Resource = MEMBER.new()
	both.loyalty = 0.55
	both.receive_gift(100.0, true)
	if not is_equal_approx(both.loyalty, 0.79):
		failures.append("public 100-mark gift should be 0.79, got %s" % both.loyalty)

	var cap: Resource = MEMBER.new()
	cap.loyalty = 0.99
	cap.receive_gift(100.0, true)
	if not is_equal_approx(cap.loyalty, 1.0):
		failures.append("loyalty must clamp to 1.0, got %s" % cap.loyalty)
	return failures


func _check_alvar_never_deserts() -> PackedStringArray:
	var failures: PackedStringArray = []
	var alvar: Resource = _member_from_id("alvar_fanez")
	if alvar == null:
		failures.append("alvar_fanez.json failed to load")
		return failures
	if alvar.desertion_capable:
		failures.append("Álvar must not be desertion_capable")
	if alvar.list_eligible:
		failures.append("Álvar must not be list_eligible")
	if not alvar.essential:
		failures.append("Álvar must be essential")
	var start: float = alvar.loyalty
	if alvar.tick_starvation(0.0, 0.20):
		failures.append("Álvar tick_starvation must never desert")
	if not is_equal_approx(alvar.loyalty, start):
		failures.append("Álvar loyalty must not drop on starvation")
	return failures


func _check_starvation_desertion() -> PackedStringArray:
	var failures: PackedStringArray = []
	var martin: Resource = _member_from_id("martin_antolinez")
	if martin == null:
		failures.append("martin_antolinez.json failed to load")
		return failures
	if not martin.desertion_capable:
		failures.append("Martín must be desertion_capable")
	if martin.tick_starvation(8.0, 0.20):
		failures.append("starvation must not tick while onores > 5")
	if not is_equal_approx(martin.loyalty, 0.55):
		failures.append("onores > 5 must not drop Martín loyalty")

	if martin.tick_starvation(0.0, 0.20):
		failures.append("Martín should not desert after one unfed night")
	if martin.tick_starvation(0.0, -0.20):
		failures.append("Martín should not desert after two unfed nights")
	if not martin.tick_starvation(0.0, 0.20):
		failures.append("Martín 0.55 - 0.60 must desert on the third unfed night")
	if not (martin.loyalty < 0.15):
		failures.append("desertion threshold is loyalty < 0.15")
	return failures


func _check_seed_invariants() -> PackedStringArray:
	var failures: PackedStringArray = []
	var people: Array = ROSTER.load_all_characters()
	if people.size() != 25:
		failures.append("seed roster must be 25 people, got %s" % people.size())

	var by_id: Dictionary = {}
	for person in people:
		by_id[String(person.id)] = person

	var desertion_ids: PackedStringArray = PackedStringArray([
		"martin_antolinez", "pero_bermudez", "muno_gustioz", "felez_munoz"
	])
	for character_id in desertion_ids:
		if not by_id.has(character_id):
			failures.append("missing %s" % character_id)
			continue
		if not by_id[character_id].desertion_capable:
			failures.append("%s must be desertion_capable" % character_id)
		if not by_id[character_id].list_eligible:
			failures.append("%s must be list_eligible" % character_id)

	var alfonso: Resource = by_id.get("alfonso", null)
	if alfonso == null:
		failures.append("missing alfonso")
	else:
		if not is_equal_approx(alfonso.combat, 0.0):
			failures.append("Alfonso combat must be 0")
		if not alfonso.unkillable:
			failures.append("Alfonso must be unkillable")

	for infante_id in ["ferran_gonzalez", "diego_gonzalez", "asur_gonzalez"]:
		var infante: Resource = by_id.get(infante_id, null)
		if infante == null:
			failures.append("missing %s" % infante_id)
			continue
		if not is_equal_approx(infante.mesura_max, 0.0):
			failures.append("%s mesura_max must be 0" % infante_id)
		if infante.role != &"infante":
			failures.append("%s role must be infante" % infante_id)

	var avengalvon: Resource = by_id.get("avengalvon", null)
	if avengalvon == null or avengalvon.must_survive_until != &"a3_despedida":
		failures.append("Avengalvón must_survive_until a3_despedida")
	if avengalvon != null and not avengalvon.essential:
		failures.append("Avengalvón must be essential")

	if by_id.has("pero_bermudez") and by_id["pero_bermudez"].list_index != 1:
		failures.append("Pero list_index must be 1")
	if by_id.has("martin_antolinez") and by_id["martin_antolinez"].list_index != 2:
		failures.append("Martín list_index must be 2")
	if by_id.has("muno_gustioz") and by_id["muno_gustioz"].list_index != 3:
		failures.append("Muño list_index must be 3")
	return failures


func _check_roster_gifts_and_counts() -> PackedStringArray:
	var failures: PackedStringArray = []
	var roster: Resource = ROSTER.from_starting_seed()
	if roster.living_named_captains() != 5:
		failures.append("starting living named captains must be 5, got %s" % roster.living_named_captains())

	var deserted_ids: Array[StringName] = []
	EventBus.member_deserted.connect(func(character_id: StringName) -> void:
		deserted_ids.append(character_id)
	)

	roster.gift_to(&"alvar_fanez", 40.0, false)
	var alvar: Resource = roster.member(&"alvar_fanez")
	if alvar == null or not is_equal_approx(alvar.loyalty, 0.80):
		failures.append("gift to Álvar should tick 0.72 + 0.08 = 0.80")

	var left: PackedStringArray = PackedStringArray()
	for _i in 3:
		left = roster.tick_starvation(0.0, 0.20)
	if roster.living_named_captains() != 3:
		failures.append("after three unfed nights living captains should be 3, got %s" % roster.living_named_captains())
	if left.size() != 2:
		failures.append("third night should drop Martín and Félez, got %s" % str(left))
	if deserted_ids.size() != 2:
		failures.append("EventBus.member_deserted should fire twice, got %s" % deserted_ids.size())
	var martin: Resource = roster.member(&"martin_antolinez")
	var felez: Resource = roster.member(&"felez_munoz")
	if martin == null or martin.alive:
		failures.append("Martín should remain as a grave after desertion")
	if felez == null or felez.alive:
		failures.append("Félez should remain as a grave after desertion")
	var pero: Resource = roster.member(&"pero_bermudez")
	var muno: Resource = roster.member(&"muno_gustioz")
	if pero == null or not pero.alive:
		failures.append("Pero should still ride after three unfed nights")
	if muno == null or not muno.alive:
		failures.append("Muño should still ride after three unfed nights")
	return failures


func _check_raquel_and_vidas_are_separate() -> PackedStringArray:
	var failures: PackedStringArray = []
	var raquel: Resource = _member_from_id("raquel")
	var vidas: Resource = _member_from_id("vidas")
	if raquel == null or vidas == null:
		failures.append("raquel.json and vidas.json must both load")
		return failures
	if raquel.id == vidas.id:
		failures.append("Raquel and Vidas must not share an id")
	if raquel.role != &"usurer" or vidas.role != &"usurer":
		failures.append("Raquel and Vidas are separate usurers")
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_loyalty: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_loyalty: %s" % failure)
	quit(1)
