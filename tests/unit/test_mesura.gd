extends SceneTree
## Headless mesura / ira dump test (gdUnit4 is still a placeholder).
## Run: godot --headless --path . -s res://tests/unit/test_mesura.gd

const MESURA := preload("res://game/actors/player/mesura_component.gd")
const COMBAT := preload("res://game/actors/player/cid_combat.gd")
const HURT := preload("res://game/combat/hurt_box.gd")
const HIT := preload("res://game/combat/hit_box.gd")
const HUD := preload("res://game/ui/mesura_hud.gd")


func _initialize() -> void:
	Engine.time_scale = 1.0
	var failures: PackedStringArray = []
	failures.append_array(_test_traits_from_json())
	failures.append_array(_test_dump_sinks_honra_not_onores())
	failures.append_array(_test_hold_refuses_dump())
	failures.append_array(_test_dump_requires_ira())
	failures.append_array(_test_parry_window())
	failures.append_array(_test_hold_time_scale_and_restore())
	failures.append_array(_test_hold_lowers_in_flight_weapon())
	failures.append_array(_test_rotate_in_signal_and_cooldown())
	failures.append_array(_test_dump_stamina_and_honra_band())
	failures.append_array(_test_mesura_regen_and_strike_pause())
	failures.append_array(_test_slam_combo_with_mesura())
	failures.append_array(_test_trait_cap())
	failures.append_array(_test_hud_and_loc())
	failures.append_array(_test_cid_scene_wires_mesura())
	_finish(failures)


func _honor() -> Node:
	return root.get_node_or_null("HonorService")


func _loc() -> Node:
	return root.get_node_or_null("Loc")


func _test_traits_from_json() -> PackedStringArray:
	var failures: PackedStringArray = []
	var mes: MesuraComponent = MESURA.new()
	if mes.traits.is_empty():
		failures.append("mesura_traits.json did not load")
		mes.free()
		return failures
	if not is_equal_approx(mes.mesura, float(mes.traits.get("mesura_start", -1.0))):
		failures.append("mesura start must come from JSON")
	if not is_equal_approx(mes.ira, float(mes.traits.get("ira_start", -1.0))):
		failures.append("ira start must come from JSON")
	if int(mes.traits.get("trait_cap", 0)) != 6:
		failures.append("trait_cap want 6")
	var rows: Variant = mes.traits.get("traits", [])
	if not rows is Array or (rows as Array).size() != 6:
		failures.append("traits array must list 6 ids")
	mes.free()
	return failures


func _test_dump_sinks_honra_not_onores() -> PackedStringArray:
	var failures: PackedStringArray = []
	var honor := _honor()
	if honor == null or not honor.has_method("reset_state"):
		failures.append("HonorService missing")
		return failures
	honor.reset_state()
	var mes: MesuraComponent = MESURA.new()
	mes.name = "Mesura"
	root.add_child(mes)
	var honra0: float = honor.state.honra
	var onores0: float = honor.state.onores
	var honor0: float = honor.state.honor
	mes.ira = float(mes.traits.get("ira_max", 0.0))
	if not mes.try_dump():
		failures.append("dump with full ira must succeed")
	var catalog: HonorEvent = honor.event_by_id(&"rage_dump")
	var want := honra0
	if catalog != null:
		want = clampf(honra0 + catalog.delta_for(&"honra"), 0.0, 100.0)
	if not is_equal_approx(honor.state.honra, want):
		failures.append("dump honra want %s got %s" % [want, honor.state.honra])
	if not is_equal_approx(honor.state.onores, onores0):
		failures.append("dump must not change onores")
	if not is_equal_approx(honor.state.honor, honor0):
		failures.append("dump must not change honor")
	if mes.ira != 0.0:
		failures.append("dump must empty ira")
	root.remove_child(mes)
	mes.free()
	honor.reset_state()
	return failures


func _test_hold_refuses_dump() -> PackedStringArray:
	var failures: PackedStringArray = []
	var honor := _honor()
	if honor:
		honor.reset_state()
	var mes: MesuraComponent = MESURA.new()
	mes.ira = float(mes.traits.get("ira_max", 0.0))
	mes.set_holding(true)
	if not mes.is_waiting() or not mes.rotate_in_ready:
		failures.append("hold must wait and mark rotate-in")
	if mes.try_dump():
		failures.append("hold must refuse dump")
	if mes.ira <= 0.0:
		failures.append("refused dump must keep ira")
	mes.set_holding(false)
	mes.free()
	return failures


func _test_dump_requires_ira() -> PackedStringArray:
	var failures: PackedStringArray = []
	var honor := _honor()
	if honor:
		honor.reset_state()
	var mes: MesuraComponent = MESURA.new()
	mes.ira = 0.0
	if mes.try_dump():
		failures.append("empty ira must not dump")
	mes.ira = float(mes.traits.get("dump_ira_min", 0.0)) - 1.0
	if mes.try_dump():
		failures.append("ira below dump_ira_min must not dump")
	mes.free()
	return failures


func _test_parry_window() -> PackedStringArray:
	var failures: PackedStringArray = []
	var body := Node.new()
	var combat: CidCombat = COMBAT.new()
	var mes: MesuraComponent = MESURA.new()
	var hurt: HurtBox = HURT.new()
	mes.name = "Mesura"
	combat.name = "CidCombat"
	body.add_child(combat)
	body.add_child(mes)
	root.add_child(body)
	combat.bind_hurt(hurt)
	var hp: float = hurt.hp
	mes.set_holding(true)
	if not mes.is_parry_open():
		failures.append("hold start must open parry window")
	combat.take_damage(12.0, &"slash", 0.1, null)
	if not is_equal_approx(hurt.hp, hp):
		failures.append("parry must ignore the hit, hp %s -> %s" % [hp, hurt.hp])
	var window := float(mes.traits.get("hold_parry_window_ms", 0.0)) / 1000.0
	mes.tick(window + 0.05)
	if mes.is_parry_open():
		failures.append("parry window must close after hold_parry_window_ms")
	combat.take_damage(12.0, &"slash", 0.1, null)
	if is_equal_approx(hurt.hp, hp):
		failures.append("hit after parry window must land")
	var after_window: float = hurt.hp
	mes.set_holding(false)
	combat.take_damage(12.0, &"slash", 0.1, null)
	if is_equal_approx(hurt.hp, after_window):
		failures.append("unheld Cid must take the hit")
	root.remove_child(body)
	hurt.free()
	body.free()
	Engine.time_scale = 1.0
	return failures


func _test_hold_time_scale_and_restore() -> PackedStringArray:
	var failures: PackedStringArray = []
	var mes: MesuraComponent = MESURA.new()
	mes.name = "Mesura"
	root.add_child(mes)
	var want := float(mes.traits.get("hold_time_scale", 1.0))
	mes.set_holding(true)
	if not is_equal_approx(Engine.time_scale, want):
		failures.append("hold time_scale want %s got %s" % [want, Engine.time_scale])
	mes.set_holding(false)
	if not is_equal_approx(Engine.time_scale, 1.0):
		failures.append("release must restore time_scale, got %s" % Engine.time_scale)
	mes.set_holding(true)
	if mes.is_inside_tree():
		root.remove_child(mes)
	else:
		mes._restore_world_clock()
	if not is_equal_approx(Engine.time_scale, 1.0):
		failures.append("free while held must restore time_scale, got %s" % Engine.time_scale)
		mes._restore_world_clock()
	mes.free()
	Engine.time_scale = 1.0
	return failures


func _test_hold_lowers_in_flight_weapon() -> PackedStringArray:
	var failures: PackedStringArray = []
	var body := Node.new()
	var combat: CidCombat = COMBAT.new()
	var mes: MesuraComponent = MESURA.new()
	var box: HitBox = HIT.new()
	mes.name = "Mesura"
	combat.name = "CidCombat"
	body.add_child(combat)
	body.add_child(mes)
	body.add_child(box)
	combat.hit_box = box
	root.add_child(body)
	combat.slam()
	if not box.monitoring:
		failures.append("slam should arm HitBox")
	if not combat.is_attacking():
		failures.append("slam should leave an in-flight attack")
	mes.set_holding(true)
	if box.monitoring:
		failures.append("hold must disarm in-flight HitBox")
	if combat.is_attacking():
		failures.append("hold must zero _attack_left")
	mes.set_holding(false)
	root.remove_child(body)
	body.free()
	Engine.time_scale = 1.0
	return failures


func _test_rotate_in_signal_and_cooldown() -> PackedStringArray:
	var failures: PackedStringArray = []
	var mes: MesuraComponent = MESURA.new()
	var got: Array = []
	mes.rotate_in_requested.connect(func() -> void:
		got.append(true)
	)
	mes.set_holding(true)
	if got.is_empty():
		failures.append("hold must emit rotate_in_requested")
	if mes.rotate_cd <= 0.0:
		failures.append("rotate_in must start a cooldown")
	var base_cd: float = mes.rotate_cd
	mes.set_holding(false)
	if not mes.grant_trait(&"dejar_golpear"):
		failures.append("dejar_golpear grant failed")
	mes.rotate_cd = 0.0
	mes.set_holding(true)
	var reduced: float = float(mes.traits.get("rotate_in_cooldown_sec", 0.0)) * mes.rotate_in_cooldown_mult()
	if not is_equal_approx(mes.rotate_cd, reduced):
		failures.append("dejar_golpear cooldown want %s got %s" % [reduced, mes.rotate_cd])
	if not is_equal_approx(base_cd, float(mes.traits.get("rotate_in_cooldown_sec", 0.0))):
		failures.append("base rotate cooldown should match JSON")
	mes.set_holding(false)
	mes.free()
	Engine.time_scale = 1.0
	return failures


func _test_dump_stamina_and_honra_band() -> PackedStringArray:
	var failures: PackedStringArray = []
	var honor := _honor()
	if honor == null or not honor.has_method("reset_state"):
		failures.append("HonorService missing")
		return failures
	honor.reset_state()
	var body := Node.new()
	var combat: CidCombat = COMBAT.new()
	var mes: MesuraComponent = MESURA.new()
	mes.name = "Mesura"
	combat.name = "CidCombat"
	body.add_child(combat)
	body.add_child(mes)
	root.add_child(body)
	mes.traits["dump_stamina"] = 10.0
	mes.ira = float(mes.traits.get("ira_max", 0.0))
	var ira0: float = mes.ira
	var honra_blocked: float = honor.state.honra
	combat.stamina = 4.0
	if mes.try_dump():
		failures.append("dump_stamina above stamina must fail")
	if not is_equal_approx(mes.ira, ira0):
		failures.append("failed dump must keep ira")
	if not is_equal_approx(honor.state.honra, honra_blocked):
		failures.append("failed dump must not sink honra")
	if not is_equal_approx(combat.stamina, 4.0):
		failures.append("failed dump must not spend stamina")
	combat.stamina = 100.0
	var stam0: float = combat.stamina
	if not mes.try_dump():
		failures.append("dump with dump_stamina must succeed")
	if not is_equal_approx(combat.stamina, stam0 - 10.0):
		failures.append("dump must spend dump_stamina, want %s got %s" % [stam0 - 10.0, combat.stamina])
	if combat.last_move != &"dump":
		failures.append("dump_strike must set last_move dump")
	honor.reset_state()
	mes.traits["dump_honra_min"] = -10.0
	mes.traits["dump_honra_max"] = -10.0
	mes.ira = float(mes.traits.get("ira_max", 0.0))
	var honra0: float = honor.state.honra
	if not mes.try_dump():
		failures.append("banded dump must succeed")
	if not is_equal_approx(honor.state.honra, honra0 - 10.0):
		failures.append("dump honra must clamp to band, want %s got %s" % [honra0 - 10.0, honor.state.honra])
	root.remove_child(body)
	body.free()
	honor.reset_state()
	return failures


func _test_mesura_regen_and_strike_pause() -> PackedStringArray:
	var failures: PackedStringArray = []
	var mes: MesuraComponent = MESURA.new()
	var start: float = mes.mesura
	mes.tick(1.0)
	if mes.mesura <= start:
		failures.append("mesura must regen while not striking")
	var mid: float = mes.mesura
	mes.note_strike()
	mes.tick(0.2)
	if not is_equal_approx(mes.mesura, mid):
		failures.append("strike must pause mesura regen")
	mes.free()
	return failures


func _test_slam_combo_with_mesura() -> PackedStringArray:
	var failures: PackedStringArray = []
	var body := Node.new()
	var combat: CidCombat = COMBAT.new()
	var mes: MesuraComponent = MESURA.new()
	mes.name = "Mesura"
	combat.name = "CidCombat"
	body.add_child(combat)
	body.add_child(mes)
	combat.slam()
	combat.slam()
	combat.slam()
	if combat.last_move != &"bash" or combat.combo_step != 3:
		failures.append("mesura sibling must not break 3-hit slam")
	var stam: float = combat.stamina
	combat.slam()
	if combat.combo_step != 3 or not is_equal_approx(combat.stamina, stam):
		failures.append("fourth slam still capped with mesura present")
	body.free()
	return failures


func _test_trait_cap() -> PackedStringArray:
	var failures: PackedStringArray = []
	var mes: MesuraComponent = MESURA.new()
	var ids: PackedStringArray = PackedStringArray()
	var rows: Variant = mes.traits.get("traits", [])
	if rows is Array:
		for row in rows:
			if row is Dictionary:
				ids.append(str((row as Dictionary).get("id", "")))
	if ids.size() != 6:
		failures.append("expected 6 trait ids")
	for id in ids:
		if not mes.grant_trait(StringName(id)):
			failures.append("grant %s failed" % id)
	if mes.unlocked.size() != 6:
		failures.append("unlocked want 6 got %s" % mes.unlocked.size())
	if mes.grant_trait(&"extra_trait"):
		failures.append("trait cap 6 must refuse a seventh")
	mes.free()
	return failures


func _test_hud_and_loc() -> PackedStringArray:
	var failures: PackedStringArray = []
	var loc := _loc()
	if loc == null or not loc.has_method("text"):
		failures.append("Loc missing")
		return failures
	if str(loc.call("text", "hud.mesura")) != "Mesura":
		failures.append("hud.mesura must display Mesura")
	if str(loc.call("text", "hud.ira")) != "Ira":
		failures.append("hud.ira must display Ira")
	if str(loc.call("text", "poem.v20")).find("buen vassallo") < 0:
		failures.append("strings.csv must not clobber poem.v20")
	var hud: MesuraHud = HUD.new()
	root.add_child(hud)
	if hud.get_child_count() != 0:
		failures.append("MesuraHud must stay a single Control")
	root.remove_child(hud)
	hud.free()
	return failures


func _test_cid_scene_wires_mesura() -> PackedStringArray:
	var failures: PackedStringArray = []
	var packed: Resource = load("res://content/art/characters/cid/cid.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("cid.tscn failed to load")
		return failures
	var node: Node = (packed as PackedScene).instantiate()
	if node.get_node_or_null("Mesura") == null:
		failures.append("Cid missing Mesura")
	if node.get_node_or_null("CidCombat") == null:
		failures.append("Cid missing CidCombat")
	if node.get_node_or_null("CameraRig/Camera3D") == null:
		failures.append("Cid missing locked Camera3D")
	if node.find_children("*", "SpringArm3D", true, false).size() != 0:
		failures.append("Cid gained a SpringArm3D")
	var combat: Node = node.get_node_or_null("CidCombat")
	if combat == null or not combat.has_method("dump_strike") or not combat.has_method("slam"):
		failures.append("CidCombat missing dump_strike / slam")
	node.free()
	var arena_res: Resource = load("res://content/chapters/_dev/arena.tscn")
	if arena_res == null or not (arena_res is PackedScene):
		failures.append("arena.tscn failed to load")
		return failures
	var arena: Node = (arena_res as PackedScene).instantiate()
	if arena.get_node_or_null("HUD/MesuraHud") == null:
		failures.append("arena missing MesuraHud")
	arena.free()
	return failures


func _finish(failures: PackedStringArray) -> void:
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("test_mesura: ok")
		quit(0)
		return
	for failure in failures:
		push_error("test_mesura: %s" % failure)
	quit(1)
