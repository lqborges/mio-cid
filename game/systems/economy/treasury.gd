class_name Treasury
extends Resource

## Marks are silver; onores is a meter. Eating spends marks, not onores.

@export var marks: int = 0
@export var horses: int = 2
@export var cloth: int = 0
@export var arms: int = 0
@export var royal_escrow_marks: int = 0
@export var royal_escrow_horses: int = 0


func reset() -> void:
	marks = 0
	horses = 2
	cloth = 0
	arms = 0
	royal_escrow_marks = 0
	royal_escrow_horses = 0


func commute_horse(horse_marks: int = 10) -> void:
	# Default 10 is overwritten by economy.json horse_marks at runtime.
	if horses <= 0:
		return
	horses -= 1
	marks += maxi(0, horse_marks)


func to_save() -> Dictionary:
	return {
		"marks": marks,
		"horses": horses,
		"cloth": cloth,
		"arms": arms,
		"royal_escrow_marks": royal_escrow_marks,
		"royal_escrow_horses": royal_escrow_horses,
	}


func from_save(data: Dictionary) -> void:
	marks = maxi(0, int(data.get("marks", 0)))
	horses = maxi(0, int(data.get("horses", 2)))
	cloth = maxi(0, int(data.get("cloth", 0)))
	arms = maxi(0, int(data.get("arms", 0)))
	royal_escrow_marks = maxi(0, int(data.get("royal_escrow_marks", 0)))
	royal_escrow_horses = maxi(0, int(data.get("royal_escrow_horses", 0)))
