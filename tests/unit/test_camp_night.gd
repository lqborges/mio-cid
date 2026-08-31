extends SceneTree
## Headless Treasury / CampaignClock / camp-night test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_camp_night.gd
## Autoload identifiers are not visible to a -s MainLoop script; look them up.

const SEG_PAUSED := 0
const SEG_CAMP_NIGHT := 1
const SEG_REFUSE_48H := 2
const SEG_SIEGE := 3
const SEG_LISTS_WAIT := 4

var _clock: Variant
var _treasury: Variant
var _honor: Variant
var _save: Variant
var _bus: Variant


func _initialize() -> void:
	var failures: PackedStringArray = []
	_clock = get_root().get_node_or_null(NodePath("CampaignClock"))
	_treasury = get_root().get_node_or_null(NodePath("TreasuryService"))
	_honor = get_root().get_node_or_null(NodePath("HonorService"))
	_save = get_root().get_node_or_null(NodePath("SaveService"))
	_bus = get_root().get_node_or_null(NodePath("EventBus"))
	if _clock == null or _treasury == null or _honor == null or _save == null or _bus == null:
		failures.append("required autoload missing")
		_finish(failures)
		return
	failures.append_array(_test_no_unfed_streak_except_clock())
	failures.append_array(_test_plazo_never_feeds())
	failures.append_array(_test_paused_siege_lists_skip_do_not_starve())
	failures.append_array(_test_feeds_only_camp_night_and_refuse())
	failures.append_array(_test_cheat_through_castejon())
	failures.append_array(_test_refuse_through_third_unfed())
	failures.append_array(_test_booty_horses_follow_fractions())
	failures.append_array(_test_treasury_clock_save_roundtrip())
	failures.append_array(_test_cold_start_roster_load())
	_reset_campaign()
	_finish(failures)


func _test_no_unfed_streak_except_clock() -> PackedStringArray:
	var failures: PackedStringArray = []
	if not ("unfed_streak" in _clock):
		failures.append("unfed_streak must live on CampaignClock")
	var honor := HonorState.new()
	for prop in honor.get_property_list():
		if str(prop.get("name", "")) == "unfed_streak":
			failures.append("unfed_streak must not live on HonorState")
			break
	var chest := Treasury.new()
	for prop in chest.get_property_list():
		if str(prop.get("name", "")) == "unfed_streak":
			failures.append("unfed_streak must not live on Treasury")
			break
	return failures


func _test_plazo_never_feeds() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	_honor.roster = MesnadaRoster.from_starting_seed()
	_treasury.state.marks = 200
	_honor.state.onores = 8.0
	_clock.unfed_streak = 1
	_clock.days_elapsed = 4
	_clock.segment = SEG_CAMP_NIGHT
	_clock.advance_plazo(1)
	if _clock.plazo_days_left != 8:
		failures.append("advance_plazo(1) want 8 left, got %s" % _clock.plazo_days_left)
	if _treasury.state.marks != 200:
		failures.append("advance_plazo must not spend marks, got %s" % _treasury.state.marks)
	if _clock.unfed_streak != 1:
		failures.append("advance_plazo must not touch unfed_streak")
	if _clock.days_elapsed != 4:
		failures.append("advance_plazo must not advance days_elapsed")
	if not is_equal_approx(_honor.state.onores, 8.0):
		failures.append("advance_plazo must not fire camp HonorEvents")
	return failures


func _test_paused_siege_lists_skip_do_not_starve() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	_honor.roster = MesnadaRoster.from_starting_seed()
	_treasury.state.marks = 200
	var onores: float = _honor.state.onores
	_clock.segment = SEG_PAUSED
	_clock.tick_night()
	if _clock.days_elapsed != 0:
		failures.append("PAUSED tick_night must advance nothing")
	if _treasury.state.marks != 200:
		failures.append("PAUSED must not feed")
	_clock.segment = SEG_SIEGE
	_clock.advance_calendar(14)
	_clock.tick_night()
	if _clock.days_elapsed != 15:
		failures.append("SIEGE skip+tick want days 15, got %s" % _clock.days_elapsed)
	if _treasury.state.marks != 200:
		failures.append("SIEGE must not starve, marks %s" % _treasury.state.marks)
	if _clock.unfed_streak != 0:
		failures.append("SIEGE must not increment unfed_streak")
	if not is_equal_approx(_honor.state.onores, onores):
		failures.append("SIEGE must not fire camp HonorEvents")
	_clock.segment = SEG_LISTS_WAIT
	_clock.advance_calendar(21)
	if _treasury.state.marks != 200:
		failures.append("LISTS_WAIT skip must not spend marks")
	if _clock.unfed_streak != 0:
		failures.append("LISTS_WAIT must not increment unfed_streak")
	return failures


func _test_feeds_only_camp_night_and_refuse() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	if _clock.feeds_tonight():
		failures.append("PAUSED must not feed tonight")
	_clock.segment = SEG_CAMP_NIGHT
	if not _clock.feeds_tonight():
		failures.append("CAMP_NIGHT must feed tonight")
	_clock.segment = SEG_REFUSE_48H
	if not _clock.feeds_tonight():
		failures.append("REFUSE_48H must feed tonight")
	_clock.segment = SEG_SIEGE
	if _clock.feeds_tonight():
		failures.append("SIEGE must not feed tonight")
	_clock.segment = SEG_LISTS_WAIT
	if _clock.feeds_tonight():
		failures.append("LISTS_WAIT must not feed tonight")
	_reset_campaign()
	_honor.roster = MesnadaRoster.from_starting_seed()
	var marks_before: int = _treasury.state.marks
	_clock.run_refuse_48h()
	if _clock.unfed_streak != 2:
		failures.append("refuse_48h is two feed ticks, streak want 2 got %s" % _clock.unfed_streak)
	if _clock.segment != SEG_PAUSED:
		failures.append("run_refuse_48h should restore previous segment")
	if _clock.days_elapsed != 2:
		failures.append("refuse_48h should advance two nights, got %s" % _clock.days_elapsed)
	if _treasury.state.marks != marks_before:
		failures.append("refuse_48h from 0 marks should still spend nothing")
	return failures


func _test_cheat_through_castejon() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	var roster: MesnadaRoster = MesnadaRoster.from_starting_seed()
	_honor.roster = roster
	if _treasury.state.marks != 0 or _treasury.state.horses != 2:
		failures.append("start treasury want 0 marks 2 horses")
	if roster.lanzas != 12 or roster.living_named_captains() != 5:
		failures.append("start mouths want 12 lanzas + 5 captains")
	if _treasury.mouths() != 17:
		failures.append("start mouths want 17 got %s" % _treasury.mouths())
	if not is_equal_approx(_honor.state.onores, 8.0):
		failures.append("start onores want 8")
	_honor.apply_id(&"arcas_cheat")
	_treasury.state.marks += 600
	if _treasury.state.marks != 600:
		failures.append("arcas_cheat marks want 600 got %s" % _treasury.state.marks)
	if not is_equal_approx(_honor.state.onores, 30.0):
		failures.append("arcas_cheat onores want 30 got %s" % _honor.state.onores)
	_clock.rest_camp()
	if _treasury.state.marks != 464:
		failures.append("cheat river camp marks want 464 (600-136) got %s" % _treasury.state.marks)
	if not is_equal_approx(_honor.state.onores, 31.0):
		failures.append("camp_fed onores want 31 got %s" % _honor.state.onores)
	if _clock.unfed_streak != 0:
		failures.append("camp_fed must reset unfed_streak")
	if roster.lanzas != 12:
		failures.append("fed night must not drop lanzas")
	_treasury.state.marks -= 40
	if _treasury.state.marks != 424:
		failures.append("Cardeña gift 40 want marks 424 got %s" % _treasury.state.marks)
	var split: Dictionary = _treasury.divide_booty({"marks": 800, "horses": 40})
	_honor.apply_id(&"castejon_take")
	if int(split.get("quinto_marks", 0)) != 160 or int(split.get("mesnada_marks", 0)) != 320:
		failures.append("castejon marks split want 160/320/320, got %s" % str(split))
	if int(split.get("quinto_horses", 0)) != 8 or int(split.get("mesnada_horses", 0)) != 16:
		failures.append("castejon horses must follow fractions, not all-to-treasury: %s" % str(split))
	if _treasury.state.marks != 744:
		failures.append("after take treasury marks want 744 got %s" % _treasury.state.marks)
	if _treasury.state.horses != 18:
		failures.append("after take horses want 18 (2+16) got %s" % _treasury.state.horses)
	if _treasury.state.royal_escrow_horses != 8:
		failures.append("quinto horses want 8 escrow got %s" % _treasury.state.royal_escrow_horses)
	if not is_equal_approx(_honor.state.onores, 45.0):
		failures.append("castejon_take onores want 45 got %s" % _honor.state.onores)
	_treasury.state.marks += 400
	_honor.apply_id(&"castejon_sell")
	if _treasury.state.marks != 1144:
		failures.append("after sell marks want 1144 got %s" % _treasury.state.marks)
	if not is_equal_approx(_honor.state.onores, 55.0):
		failures.append("castejon_sell onores want 55 got %s" % _honor.state.onores)
	_treasury.state.horses -= 10
	if _treasury.state.horses != 8:
		failures.append("ten_horses embassy want 8 horses got %s" % _treasury.state.horses)
	if _treasury.state.horses >= 30:
		failures.append("thirty_horses must stay blocked on the cheat branch")
	return failures


func _test_refuse_through_third_unfed() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	var roster: MesnadaRoster = MesnadaRoster.from_starting_seed()
	_honor.roster = roster
	var failed: Array[StringName] = []
	var on_fail := func(reason: StringName) -> void:
		failed.append(reason)
	_bus.hard_fail.connect(on_fail)
	_honor.apply_id(&"arcas_refuse")
	if _treasury.state.marks != 0:
		failures.append("refuse starts at 0 marks")
	if not is_equal_approx(_honor.state.onores, 8.0):
		failures.append("arcas_refuse must not add onores")
	_clock.segment = SEG_CAMP_NIGHT
	_clock.tick_night()
	if roster.lanzas != 9:
		failures.append("refuse night 1 lanzas want 9 (12-1-2) got %s" % roster.lanzas)
	if _clock.unfed_streak != 1:
		failures.append("refuse night 1 streak want 1 got %s" % _clock.unfed_streak)
	if not is_equal_approx(_honor.state.onores, 0.0):
		failures.append("camp_unfed onores want 0 got %s" % _honor.state.onores)
	if not _treasury.commute_horse():
		failures.append("night 2 slaughter should commute one horse")
	if _treasury.state.horses != 1 or _treasury.state.marks != 10:
		failures.append("slaughter want 1 horse +10 marks, got %s h %s m" % [_treasury.state.horses, _treasury.state.marks])
	_clock.segment = SEG_REFUSE_48H
	_clock.tick_night()
	if roster.lanzas != 6:
		failures.append("refuse night 2 lanzas want 6 got %s" % roster.lanzas)
	if _clock.unfed_streak != 2:
		failures.append("refuse night 2 streak want 2 got %s" % _clock.unfed_streak)
	if failed.size() != 0:
		failures.append("name_empty must not fire before the third unfed night")
	_clock.tick_night()
	if _clock.unfed_streak != 3:
		failures.append("refuse night 3 streak want 3 got %s" % _clock.unfed_streak)
	if roster.living_named_captains() != 3:
		failures.append("night 3 living captains want 3 got %s" % roster.living_named_captains())
	var martin: MesnadaMember = roster.member(&"martin_antolinez")
	var felez: MesnadaMember = roster.member(&"felez_munoz")
	if martin == null or martin.alive or felez == null or felez.alive:
		failures.append("Martín and Félez should desert on night 3")
	if failed.size() != 1 or failed[0] != &"name_empty":
		failures.append("third unfed + captains < 4 must hard_fail name_empty, got %s" % str(failed))
	_bus.hard_fail.disconnect(on_fail)
	return failures


func _test_booty_horses_follow_fractions() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	_honor.roster = MesnadaRoster.from_starting_seed()
	var split: Dictionary = _treasury.divide_booty({"marks": 800, "horses": 40})
	if _treasury.state.horses == 42:
		failures.append("horses must not all go to treasury (2+40)")
	if _treasury.state.horses != 18:
		failures.append("booty horses want 18 got %s" % _treasury.state.horses)
	if int(split.get("mesnada_horses", 0)) != 16:
		failures.append("mesnada horses leave the herd, want 16 got %s" % split.get("mesnada_horses", 0))
	if bool(_treasury.tunables.get("horses_all_to_treasury", true)):
		failures.append("economy.json horses_all_to_treasury must be false")
	if not bool(_treasury.tunables.get("horses_follow_fractions", false)):
		failures.append("economy.json horses_follow_fractions must be true")
	return failures


func _test_treasury_clock_save_roundtrip() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	_honor.roster = MesnadaRoster.from_starting_seed()
	_treasury.state.marks = 410
	_treasury.state.horses = 12
	_treasury.state.royal_escrow_marks = 160
	_treasury.state.royal_escrow_horses = 8
	_clock.segment = SEG_CAMP_NIGHT
	_clock.days_elapsed = 11
	_clock.unfed_streak = 2
	_clock.plazo_days_left = 4
	if _save.save(1) != OK:
		failures.append("treasury/clock save failed: %s" % _save.last_error)
		return failures
	_reset_campaign()
	var loaded: Dictionary = _save.load(1)
	if loaded.is_empty():
		failures.append("treasury/clock load failed: %s" % _save.last_error)
		return failures
	if not loaded.has("treasury") or not loaded.has("clock"):
		failures.append("payload must include treasury and clock")
	if _treasury.state.marks != 410 or _treasury.state.horses != 12:
		failures.append("loaded treasury want 410m/12h got %s/%s" % [_treasury.state.marks, _treasury.state.horses])
	if _treasury.state.royal_escrow_horses != 8:
		failures.append("loaded escrow horses want 8")
	if _clock.unfed_streak != 2:
		failures.append("loaded unfed_streak want 2 got %s" % _clock.unfed_streak)
	if _clock.plazo_days_left != 4:
		failures.append("loaded plazo want 4 got %s" % _clock.plazo_days_left)
	if _clock.segment != SEG_CAMP_NIGHT:
		failures.append("loaded segment want CAMP_NIGHT")
	if _clock.segment_id() != "camp_night":
		failures.append("loaded segment_id want camp_night got %s" % _clock.segment_id())
	return failures


func _test_cold_start_roster_load() -> PackedStringArray:
	var failures: PackedStringArray = []
	_reset_campaign()
	var roster: MesnadaRoster = MesnadaRoster.from_starting_seed()
	_honor.roster = roster
	var martin: MesnadaMember = roster.member(&"martin_antolinez")
	if martin == null:
		failures.append("cold-start seed missing Martín")
		return failures
	martin.alive = false
	roster.lanzas = 6
	if _save.save(2) != OK:
		failures.append("cold-start save failed: %s" % _save.last_error)
		return failures
	_honor.roster = null
	var loaded: Dictionary = _save.load(2)
	if loaded.is_empty():
		failures.append("cold-start load failed: %s" % _save.last_error)
		return failures
	var restored: Variant = _honor.roster
	if restored == null:
		failures.append("cold-start load must restore mesnada when HonorService.roster was null")
		return failures
	if restored.lanzas != 6:
		failures.append("cold-start lanzas want 6 got %s" % restored.lanzas)
	var again: MesnadaMember = restored.member(&"martin_antolinez")
	if again == null or again.alive:
		failures.append("cold-start Martín must stay dead")
	var alvar: MesnadaMember = restored.member(&"alvar_fanez")
	if alvar == null or not alvar.alive:
		failures.append("cold-start Álvar must still ride")
	return failures


func _reset_campaign() -> void:
	_honor.reset_state()
	_honor.roster = null
	_treasury.reset()
	_clock.reset()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_camp_night: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_camp_night: %s" % failure)
	quit(1)
