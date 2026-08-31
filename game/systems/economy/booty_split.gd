class_name BootySplit
extends RefCounted

## Quinto / mesnada / treasury buckets. Fractions come from TreasuryService tunables.


static func preview(pile: Dictionary, fractions: Dictionary, gift: Dictionary = {}) -> Dictionary:
	var marks: int = maxi(0, int(pile.get("marks", 0)))
	var horses: int = maxi(0, int(pile.get("horses", 0)))
	var cloth: int = maxi(0, int(pile.get("cloth", 0)))
	var arms: int = maxi(0, int(pile.get("arms", 0)))
	var quinto_f := float(fractions.get("quinto_fraction", 0.0))
	var mesnada_f := float(fractions.get("mesnada_fraction", 0.0))
	var quinto_marks := share(marks, quinto_f)
	var mesnada_marks := share(marks, mesnada_f)
	var treasury_marks: int = marks - quinto_marks - mesnada_marks
	var quinto_horses := 0
	var mesnada_horses := 0
	var treasury_horses := 0
	if bool(fractions.get("horses_all_to_treasury", false)):
		treasury_horses = horses
	elif bool(fractions.get("horses_follow_fractions", true)):
		quinto_horses = share(horses, quinto_f)
		mesnada_horses = share(horses, mesnada_f)
		treasury_horses = horses - quinto_horses - mesnada_horses
	else:
		treasury_horses = horses
	var gift_marks := maxi(0, int(gift.get("marks", 0)))
	var gift_horses := maxi(0, int(gift.get("horses", 0)))
	var to_alvar := bool(gift.get("to_alvar", false)) or gift_marks > 0 or gift_horses > 0
	if to_alvar and gift_marks <= 0 and gift_horses <= 0:
		gift_marks = mesnada_marks
		gift_horses = mesnada_horses
	gift_marks = mini(gift_marks, mesnada_marks)
	gift_horses = mini(gift_horses, mesnada_horses)
	return {
		"pile_marks": marks,
		"pile_horses": horses,
		"cloth": cloth,
		"arms": arms,
		"quinto_marks": quinto_marks,
		"mesnada_marks": mesnada_marks,
		"treasury_marks": treasury_marks,
		"quinto_horses": quinto_horses,
		"mesnada_horses": mesnada_horses,
		"treasury_horses": treasury_horses,
		"gift_to_alvar": to_alvar,
		"gift_marks": gift_marks if to_alvar else 0,
		"gift_horses": gift_horses if to_alvar else 0,
	}


static func share(total: int, fraction: float) -> int:
	if total <= 0 or fraction <= 0.0:
		return 0
	return int(floor(float(total) * fraction + 1e-9))
