class_name DuelResolver
extends RefCounted
## Spectator lists. Cid is never a fighter.

const SUBSTITUTES: Array[StringName] = [&"felez_munoz", &"jeronimo"]
const PRIMARY_IDS: Array[StringName] = [&"pero_bermudez", &"martin_antolinez", &"muno_gustioz"]
const SHOUT_SILENCE := &"shout_silence"
const SHOUT_ONCE := &"shout_once"
const SHOUT_TOO_MUCH := &"shout_too_much"
const CID_ID := &"cid"


func resolve_all(
	roster: MesnadaRoster,
	honor: HonorState,
	swords: Dictionary,
	flags: PackedStringArray,
	shouts: Array,
	seed: int
) -> Array:
	var out: Array = []
	var used: Array[StringName] = []
	var padded := _pad_shouts(shouts)
	var force := _canonical(roster, swords)
	for i in 3:
		var champ := _pick(i, roster, honor, used)
		if champ == null:
			out.append({"duel_index": i, "champion_id": &"", "won": false})
			continue
		used.append(champ.id)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + i
		var score := _score(champ, honor, swords, flags, padded[i], rng.randf(), i, padded)
		out.append({
			"duel_index": i,
			"champion_id": champ.id,
			"won": force or score >= 0.50,
		})
	return out


func _pick(duel_index: int, roster: MesnadaRoster, honor: HonorState, used: Array[StringName]) -> MesnadaMember:
	var primary := _primary_for(duel_index, roster)
	if _eligible(primary, honor, used):
		return primary
	for sid in SUBSTITUTES:
		var sub := _member_or_load(roster, sid)
		if _eligible(sub, honor, used):
			return sub
	return null


func _primary_for(duel_index: int, roster: MesnadaRoster) -> MesnadaMember:
	if roster == null:
		return null
	var want := duel_index + 1
	for m in roster.members:
		if m != null and m.list_index == want:
			return m
	if duel_index >= 0 and duel_index < PRIMARY_IDS.size():
		return roster.member(PRIMARY_IDS[duel_index])
	return null


func _eligible(m: MesnadaMember, honor: HonorState, used: Array[StringName]) -> bool:
	if m == null:
		return false
	if m.id == CID_ID or String(m.id) == "cid":
		return false
	if not m.alive or not m.list_eligible:
		return false
	if m.id in used:
		return false
	if not _will_swear(m, honor):
		return false
	return true


func _will_swear(m: MesnadaMember, honor: HonorState) -> bool:
	if m == null:
		return false
	var honra := 40.0
	if honor != null and "honra" in honor:
		honra = float(honor.honra)
	if honra < 10.0 and m.loyalty < 0.3:
		return false
	return bool(m.will_swear_riepto)


func _canonical(roster: MesnadaRoster, swords: Dictionary) -> bool:
	if roster == null:
		return false
	if not _phase_is(swords, &"tizona", "IN_CHAMPION_HAND"):
		return false
	if not _phase_is(swords, &"colada", "IN_CHAMPION_HAND"):
		return false
	for pid in PRIMARY_IDS:
		var m := roster.member(pid)
		if m == null or not m.alive or m.loyalty < 0.45:
			return false
	return true


func _score(
	champ: MesnadaMember,
	honor: HonorState,
	swords: Dictionary,
	flags: PackedStringArray,
	shout: StringName,
	rng_u: float,
	duel_index: int,
	all_shouts: Array
) -> float:
	var honra := 40.0
	if honor != null and "honra" in honor:
		honra = float(honor.honra)
	var morale := _morale(champ.loyalty, flags)
	var shout_raw := _shout_raw(shout)
	if duel_index == 2 and _too_much_count(all_shouts) >= 2:
		shout_raw -= 0.05
	var shout_mapped := clampf((shout_raw + 1.0) * 0.5, 0.0, 1.0)
	var correct := 1.0 if _correct_sword(champ, swords) else 0.0
	return (
		0.35 * (champ.combat / 100.0)
		+ 0.20 * champ.loyalty
		+ 0.10 * morale
		+ 0.15 * correct
		+ 0.10 * (honra / 100.0)
		+ 0.05 * shout_mapped
		+ 0.05 * clampf(rng_u, 0.0, 1.0)
	)


func _morale(loyalty: float, flags: PackedStringArray) -> float:
	var morale := 0.70
	var fled := "infantes_fled_bucar" in flags
	var covered := "captains_covered_bucar" in flags
	if fled and not covered:
		morale += 0.15
	if covered:
		morale -= 0.10
	morale += 0.10 * loyalty
	return clampf(morale, 0.0, 1.0)


func _shout_raw(shout: StringName) -> float:
	if shout == SHOUT_SILENCE:
		return 0.05
	if shout == SHOUT_TOO_MUCH:
		return -0.05
	return 0.0


func _too_much_count(shouts: Array) -> int:
	var n := 0
	for item in shouts:
		if StringName(str(item)) == SHOUT_TOO_MUCH:
			n += 1
	return n


func _pad_shouts(shouts: Array) -> Array:
	var out: Array = []
	for i in 3:
		if i < shouts.size():
			out.append(StringName(str(shouts[i])))
		else:
			out.append(SHOUT_SILENCE)
	return out


func _correct_sword(champ: MesnadaMember, swords: Dictionary) -> bool:
	if champ == null:
		return false
	if champ.id == &"pero_bermudez":
		return _phase_is(swords, &"tizona", "IN_CHAMPION_HAND")
	if champ.id == &"martin_antolinez":
		return _phase_is(swords, &"colada", "IN_CHAMPION_HAND")
	return false


func _phase_is(swords: Dictionary, item_id: StringName, phase_name: String) -> bool:
	var key := String(item_id)
	if not swords.has(key):
		return false
	var raw: Variant = swords[key]
	if raw is SwordItem:
		return (raw as SwordItem).phase_name() == phase_name
	return str(raw) == phase_name


func _member_or_load(roster: MesnadaRoster, character_id: StringName) -> MesnadaMember:
	if roster != null:
		var found := roster.member(character_id)
		if found != null:
			return found
	return MesnadaMember.from_id(character_id)
