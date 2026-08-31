extends Control
## Unfed lanzas leaving after a refused sand-chest. Refuse path only.

@onready var line: Label = $Line


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if line:
		line.text = ""
	if EventBus:
		if EventBus.has_signal("clock_night") and not EventBus.clock_night.is_connected(_on_clock_night):
			EventBus.clock_night.connect(_on_clock_night)
		if EventBus.has_signal("member_deserted") and not EventBus.member_deserted.is_connected(_on_member_deserted):
			EventBus.member_deserted.connect(_on_member_deserted)


func watch() -> void:
	visible = true
	refresh()


func refresh() -> void:
	if line == null:
		line = get_node_or_null("Line") as Label
	if line == null:
		return
	var lanzas := 0
	var roster: Variant = GameState.roster() if GameState else null
	if roster != null and "lanzas" in roster:
		lanzas = int(roster.lanzas)
	var streak := 0
	if CampaignClock and "unfed_streak" in CampaignClock:
		streak = int(CampaignClock.unfed_streak)
	var title := _loc("a1_arcas.ticker_title")
	var lanzas_word := _loc("a1_arcas.ticker_lanzas")
	var hunger := _loc("a1_arcas.ticker_hunger")
	line.text = "%s — %s %d  ·  %s %d" % [title, lanzas_word, lanzas, hunger, streak]
	visible = true


func _on_clock_night(_segment: StringName, _day: int) -> void:
	if visible:
		refresh()


func _on_member_deserted(_id: StringName) -> void:
	if visible:
		refresh()


func _loc(key: String) -> String:
	return Loc.text(key) if Loc else key
