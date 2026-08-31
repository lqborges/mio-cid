extends SceneTree
## Headless HonorState / HonorService test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_honor_state.gd
## When gdUnit4 v6.2.1 is vendored, rewrite this as a GdUnitTestSuite.


func _initialize() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_starting_values())
	failures.append_array(_test_apply_single_and_multi_meter())
	failures.append_array(_test_stains_and_clamp())
	failures.append_array(_test_soft_warn_vs_hard_fail())
	failures.append_array(_test_soft_warn_priority())
	failures.append_array(_test_service_catalog_and_facade())
	failures.append_array(_test_uncurable_combat_honra_refused())
	failures.append_array(_test_reset_keeps_resource())
	failures.append_array(_test_no_unfed_streak_on_honor_state())
	_finish(failures)


func _test_starting_values() -> PackedStringArray:
	var failures: PackedStringArray = []
	var state := HonorState.new()
	if not is_equal_approx(state.onores, 8.0):
		failures.append("start onores want 8 got %s" % state.onores)
	if not is_equal_approx(state.honor, 15.0):
		failures.append("start honor want 15 got %s" % state.honor)
	if not is_equal_approx(state.honra, 40.0):
		failures.append("start honra want 40 got %s" % state.honra)
	return failures


func _test_apply_single_and_multi_meter() -> PackedStringArray:
	var failures: PackedStringArray = []
	var single := HonorEvent.new()
	single.id = &"burgos_camp_river"
	single.deltas = {"honra": 2.0}
	var state := HonorState.new()
	var result := state.apply(single)
	if not is_equal_approx(state.honra, 42.0):
		failures.append("single-meter honra want 42 got %s" % state.honra)
	if not is_equal_approx(state.onores, 8.0) or not is_equal_approx(state.honor, 15.0):
		failures.append("single-meter mutated sibling meters")
	if result.has("soft_warn") or result.has("hard_fail"):
		failures.append("burgos_camp_river should not warn or fail")

	var multi := HonorEvent.new()
	multi.id = &"arcas_cheat"
	multi.deltas = {"onores": 22.0, "honra": -6.0}
	multi.stain_id = &"arcas_cheat"
	state = HonorState.new()
	state.apply(multi)
	if not is_equal_approx(state.onores, 30.0):
		failures.append("multi-meter onores want 30 got %s" % state.onores)
	if not is_equal_approx(state.honor, 15.0):
		failures.append("multi-meter honor should stay 15, got %s" % state.honor)
	if not is_equal_approx(state.honra, 34.0):
		failures.append("multi-meter honra want 34 got %s" % state.honra)

	HonorService.reset_state()
	var catalog_result := HonorService.apply_id(&"arcas_cheat")
	if catalog_result.has("hard_fail"):
		failures.append("arcas_cheat must not hard_fail")
	if not is_equal_approx(HonorService.state.onores, 30.0):
		failures.append("service arcas_cheat onores want 30 got %s" % HonorService.state.onores)
	if not is_equal_approx(HonorService.state.honra, 34.0):
		failures.append("service arcas_cheat honra want 34 got %s" % HonorService.state.honra)
	if not is_equal_approx(HonorService.state.honor, 15.0):
		failures.append("service arcas_cheat honor should stay 15")
	return failures


func _test_stains_and_clamp() -> PackedStringArray:
	var failures: PackedStringArray = []
	var cheat := HonorEvent.new()
	cheat.id = &"arcas_cheat"
	cheat.deltas = {"onores": 22.0, "honra": -6.0}
	cheat.stain_id = &"arcas_cheat"
	var state := HonorState.new()
	state.apply(cheat)
	if String(cheat.stain_id) not in state.stains:
		failures.append("stain_id was not recorded")

	var repay := HonorEvent.new()
	repay.id = &"repay_raquel"
	repay.deltas = {"honra": 8.0}
	repay.clear_stain = &"arcas_cheat"
	state.apply(repay)
	if String(repay.clear_stain) in state.stains:
		failures.append("clear_stain did not remove arcas_cheat")
	if not is_equal_approx(state.honra, 42.0):
		failures.append("repay honra want 42 got %s" % state.honra)

	var crash := HonorEvent.new()
	crash.id = &"honra_crash"
	crash.deltas = {"honra": -100.0}
	state.apply(crash)
	if state.honra < 0.0:
		failures.append("honra clamped below 0")
	if not is_equal_approx(state.honra, 0.0):
		failures.append("honra should clamp to 0, got %s" % state.honra)

	var overflow := HonorEvent.new()
	overflow.id = &"onores_overflow"
	overflow.deltas = {"onores": 1000.0}
	state.apply(overflow)
	if state.onores > 100.0:
		failures.append("onores clamped above 100")
	return failures


func _test_soft_warn_vs_hard_fail() -> PackedStringArray:
	var failures: PackedStringArray = []
	var warned: Array[StringName] = []
	var failed: Array[StringName] = []
	var on_warn := func(reason: StringName) -> void:
		warned.append(reason)
	var on_fail := func(reason: StringName) -> void:
		failed.append(reason)
	EventBus.soft_warn.connect(on_warn)
	EventBus.hard_fail.connect(on_fail)

	HonorService.reset_state()
	var unfed := HonorService.apply_id(&"camp_unfed")
	if unfed.get("soft_warn", &"") != &"cannot_feed":
		failures.append("apply() camp_unfed should return soft_warn cannot_feed")
	if unfed.has("hard_fail"):
		failures.append("apply() camp_unfed must not set hard_fail")
	if warned.size() != 1 or warned[0] != &"cannot_feed":
		failures.append("camp_unfed did not emit soft_warn cannot_feed")
	if failed.size() != 0:
		failures.append("soft_warn collapsed into hard_fail")

	HonorService.reset_state()
	warned.clear()
	failed.clear()
	var keep := HonorService.apply_id(&"castejon_keep")
	if keep.get("hard_fail", &"") != &"alfonso_wrath":
		failures.append("apply() castejon_keep should return hard_fail alfonso_wrath")
	if keep.has("soft_warn"):
		failures.append("apply() castejon_keep must not set soft_warn")
	if failed.size() != 1 or failed[0] != &"alfonso_wrath":
		failures.append("castejon_keep did not emit hard_fail alfonso_wrath")
	if warned.size() != 0:
		failures.append("hard_fail collapsed into soft_warn")

	EventBus.soft_warn.disconnect(on_warn)
	EventBus.hard_fail.disconnect(on_fail)
	return failures


func _test_soft_warn_priority() -> PackedStringArray:
	var failures: PackedStringArray = []
	var warned: Array[StringName] = []
	var on_warn := func(reason: StringName) -> void:
		warned.append(reason)
	EventBus.soft_warn.connect(on_warn)

	HonorService.reset_state()
	var news := HonorService.apply_id(&"corpes_news")
	if news.get("soft_warn", &"") != &"honra_stolen":
		failures.append("corpes_news should soft_warn honra_stolen, got %s" % news.get("soft_warn", &""))
	if warned.size() != 1 or warned[0] != &"honra_stolen":
		failures.append("corpes_news did not emit honra_stolen")
	if not HonorService.state.has_stain(&"uncurable_by_combat"):
		failures.append("corpes_news must persist uncurable_by_combat on HonorState")

	HonorService.reset_state()
	HonorService.state.honra = 5.0
	warned.clear()
	var unfed := HonorService.apply_id(&"camp_unfed")
	if unfed.get("soft_warn", &"") != &"cannot_feed":
		failures.append("camp_unfed with low honra should still emit cannot_feed")
	if warned.size() != 1 or warned[0] != &"cannot_feed":
		failures.append("camp_unfed with honra=5 did not emit cannot_feed")
	if unfed.has("hard_fail"):
		failures.append("camp_unfed must not hard_fail")

	EventBus.soft_warn.disconnect(on_warn)
	return failures


func _test_service_catalog_and_facade() -> PackedStringArray:
	var failures: PackedStringArray = []
	HonorService.reset_state()
	if HonorService.event_by_id(&"arcas_cheat") == null:
		failures.append("core.json did not load arcas_cheat")
	if HonorService.catalog.has("colada") or HonorService.catalog.has("tizona"):
		failures.append("plot swords must not be honor events")
	var cheat: HonorEvent = HonorService.event_by_id(&"arcas_cheat")
	if cheat == null or cheat.delta_for(&"onores") == 0.0 or cheat.delta_for(&"honra") == 0.0:
		failures.append("arcas_cheat deltas map must include onores and honra")
	var facade: Variant = GameState.honor()
	if facade != HonorService.state:
		failures.append("GameState.honor() did not return HonorService.state")
	return failures


func _test_uncurable_combat_honra_refused() -> PackedStringArray:
	var failures: PackedStringArray = []
	HonorService.reset_state()
	HonorService.apply_id(&"corpes_news")
	var honra_after_news := HonorService.state.honra
	var onores_after_news := HonorService.state.onores
	var fake := HonorEvent.new()
	fake.id = &"combat_farm"
	fake.deltas = {"honra": 10.0}
	fake.tags = PackedStringArray(["battle"])
	HonorService.apply(fake)
	if not is_equal_approx(HonorService.state.honra, honra_after_news):
		failures.append("combat must not restore honra while uncurable_by_combat is active")
	if not is_equal_approx(HonorService.state.onores, onores_after_news):
		failures.append("honra-only combat refuse should not change onores")

	var mixed := HonorEvent.new()
	mixed.id = &"sortie_mix"
	mixed.deltas = {"onores": 18.0, "honra": 5.0}
	mixed.tags = PackedStringArray(["battle"])
	HonorService.apply(mixed)
	if not is_equal_approx(HonorService.state.onores, onores_after_news + 18.0):
		failures.append("battle onores after corpes_news should still apply, got %s" % HonorService.state.onores)
	if not is_equal_approx(HonorService.state.honra, honra_after_news):
		failures.append("mixed battle must leave honra unchanged after corpes_news")

	HonorService.apply_id(&"toledo_ask1_swords")
	if HonorService.state.has_stain(&"uncurable_by_combat"):
		failures.append("Toledo ask should clear uncurable_by_combat stain")
	return failures


func _test_reset_keeps_resource() -> PackedStringArray:
	var failures: PackedStringArray = []
	HonorService.reset_state()
	var before: HonorState = HonorService.state
	HonorService.apply_id(&"arcas_cheat")
	HonorService.apply_id(&"corpes_news")
	HonorService.reset_state()
	if HonorService.state != before:
		failures.append("reset_state replaced HonorState; HUD meter_changed would drop")
	if not is_equal_approx(HonorService.state.onores, 8.0):
		failures.append("reset_state onores want 8 got %s" % HonorService.state.onores)
	if not is_equal_approx(HonorService.state.honor, 15.0):
		failures.append("reset_state honor want 15 got %s" % HonorService.state.honor)
	if not is_equal_approx(HonorService.state.honra, 40.0):
		failures.append("reset_state honra want 40 got %s" % HonorService.state.honra)
	if HonorService.state.has_stain(&"arcas_cheat") or HonorService.state.has_stain(&"uncurable_by_combat"):
		failures.append("reset_state must clear stains")
	return failures


func _test_no_unfed_streak_on_honor_state() -> PackedStringArray:
	var failures: PackedStringArray = []
	var state := HonorState.new()
	for prop in state.get_property_list():
		if str(prop.get("name", "")) == "unfed_streak":
			failures.append("unfed_streak must not live on HonorState")
			break
	return failures


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("test_honor_state: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_honor_state: %s" % failure)
	quit(1)
