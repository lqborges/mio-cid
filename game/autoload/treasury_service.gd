extends Node
# Autoload singleton. Do not add class_name — Godot 4 hides the Node behind the named class.

const ECONOMY_PATH := "res://data/economy.json"

var state: Treasury = Treasury.new()
var tunables: Dictionary = {}


func _ready() -> void:
	if state == null:
		state = Treasury.new()
	load_economy()


func load_economy() -> Dictionary:
	tunables = {}
	if not FileAccess.file_exists(ECONOMY_PATH):
		push_warning("TreasuryService: missing %s" % ECONOMY_PATH)
		return tunables
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_PATH))
	if parsed is Dictionary:
		tunables = parsed
	else:
		push_warning("TreasuryService: %s is not an object" % ECONOMY_PATH)
	return tunables


func reset() -> void:
	if state == null:
		state = Treasury.new()
	else:
		state.reset()
	load_economy()


func tunable_int(key: String, fallback: int) -> int:
	if tunables.is_empty():
		load_economy()
	return int(tunables.get(key, fallback))


func tunable_float(key: String, fallback: float) -> float:
	if tunables.is_empty():
		load_economy()
	return float(tunables.get(key, fallback))


func tunable_bool(key: String, fallback: bool) -> bool:
	if tunables.is_empty():
		load_economy()
	return bool(tunables.get(key, fallback))


func mouths() -> int:
	var roster := _roster(false)
	if roster == null:
		return 0
	return maxi(0, int(roster.lanzas)) + roster.living_named_captains()


func commute_horse() -> bool:
	if state == null or state.horses <= 0:
		return false
	state.commute_horse(tunable_int("horse_marks", 10))
	return true


func camp_night() -> Dictionary:
	# Mouth-cost. CampaignClock is the only caller during play; tests may call directly.
	if tunables.is_empty():
		load_economy()
	var roster := _roster(true)
	var mouths_n := 0
	if roster != null:
		mouths_n = maxi(0, int(roster.lanzas)) + roster.living_named_captains()
	var per_mouth := tunable_int("feed_marks_per_mouth", 8)
	var cost: int = mouths_n * per_mouth
	var result := {
		"fed": false,
		"mouths": mouths_n,
		"cost": cost,
		"shortfall": 0,
		"event_id": &"",
	}
	if state.marks >= cost:
		state.marks -= cost
		result["fed"] = true
		result["event_id"] = &"camp_fed"
		if CampaignClock:
			CampaignClock.unfed_streak = 0
		if HonorService:
			HonorService.apply_id(&"camp_fed")
		return result
	var shortfall: int = cost - state.marks
	state.marks = 0
	result["shortfall"] = shortfall
	result["event_id"] = &"camp_unfed"
	if HonorService:
		HonorService.apply_id(&"camp_unfed")
	if roster != null:
		var lost: int = tunable_int("unfed_lanzas_base", 1) + int(floor(float(shortfall) / 50.0)) * tunable_int(
			"unfed_lanzas_per_50_marks_short", 1
		)
		roster.lanzas = maxi(0, int(roster.lanzas) - lost)
		var onores := 0.0
		if HonorService and HonorService.state:
			onores = HonorService.state.onores
		var deserted: PackedStringArray = roster.tick_starvation(
			onores, tunable_float("camp_unfed_loyalty", -0.20)
		)
		if HonorService:
			for _id in deserted:
				HonorService.apply_id(&"captain_deserted")
	if CampaignClock:
		CampaignClock.unfed_streak += 1
	if HonorService and HonorService.has_method("consider_name_empty"):
		HonorService.consider_name_empty()
	return result


func divide_booty(pile: Dictionary) -> Dictionary:
	# TownHolding (PR-16) will call this; cheat/refuse fixtures need the fractions now.
	if tunables.is_empty():
		load_economy()
	if state == null:
		state = Treasury.new()
	var marks: int = maxi(0, int(pile.get("marks", 0)))
	var horses: int = maxi(0, int(pile.get("horses", 0)))
	var cloth: int = maxi(0, int(pile.get("cloth", 0)))
	var arms: int = maxi(0, int(pile.get("arms", 0)))
	var quinto_f := tunable_float("quinto_fraction", 0.2)
	var mesnada_f := tunable_float("mesnada_fraction", 0.4)
	var quinto_marks := _share(marks, quinto_f)
	var mesnada_marks := _share(marks, mesnada_f)
	var keep_marks: int = marks - quinto_marks - mesnada_marks
	var quinto_horses := 0
	var mesnada_horses := 0
	var keep_horses := 0
	if tunable_bool("horses_all_to_treasury", false):
		keep_horses = horses
	elif tunable_bool("horses_follow_fractions", true):
		quinto_horses = _share(horses, quinto_f)
		mesnada_horses = _share(horses, mesnada_f)
		keep_horses = horses - quinto_horses - mesnada_horses
	else:
		keep_horses = horses
	state.royal_escrow_marks += quinto_marks
	state.royal_escrow_horses += quinto_horses
	state.marks += keep_marks
	state.horses += keep_horses
	state.cloth += cloth
	state.arms += arms
	_gift_mesnada_share(mesnada_marks, mesnada_horses)
	return {
		"quinto_marks": quinto_marks,
		"mesnada_marks": mesnada_marks,
		"treasury_marks": keep_marks,
		"quinto_horses": quinto_horses,
		"mesnada_horses": mesnada_horses,
		"treasury_horses": keep_horses,
	}


func _share(total: int, fraction: float) -> int:
	if total <= 0 or fraction <= 0.0:
		return 0
	return int(floor(float(total) * fraction + 1e-9))


func _gift_mesnada_share(mesnada_marks: int, mesnada_horses: int) -> void:
	# Mesnada horses leave the player herd; marks/horses tick loyalty as gifts-down.
	var roster := _roster(false)
	if roster == null:
		return
	var living: Array = []
	for member in roster.members:
		if member != null and member.alive:
			living.append(member)
	if living.is_empty():
		return
	var horse_value: int = mesnada_horses * tunable_int("horse_marks", 10)
	var n: int = living.size()
	var each_marks: int = mesnada_marks / n
	var extra_marks: int = mesnada_marks % n
	var each_horse: int = horse_value / n
	var extra_horse: int = horse_value % n
	for i in n:
		var gift: int = each_marks + each_horse
		if i == 0:
			gift += extra_marks + extra_horse
		living[i].receive_gift(float(gift), false)


func _roster(seed_if_missing: bool) -> MesnadaRoster:
	var roster: Variant = GameState.roster() if GameState else null
	if roster is MesnadaRoster:
		return roster
	if not seed_if_missing:
		return null
	var seeded := MesnadaRoster.from_starting_seed()
	if HonorService:
		HonorService.roster = seeded
	return seeded
