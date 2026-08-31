extends "res://content/chapters/a2_yusuf/day1.gd"
## Graph entry: day 1 field; day 2 after yusuf_day1_done when this is the current scene.

const DAY2_SCENE := "res://content/chapters/a2_yusuf/day2.tscn"


func _ready() -> void:
	if _should_enter_day2() and _enter_day2():
		return
	super._ready()


func _hold_for_day2() -> void:
	super._hold_for_day2()
	_enter_day2()


func _should_enter_day2() -> bool:
	if ChapterRunner == null or not ChapterRunner.has_method("has_flag"):
		return false
	return bool(ChapterRunner.has_flag(DAY1_FLAG))


func _enter_day2() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return false
	if not ResourceLoader.exists(DAY2_SCENE):
		return false
	tree.change_scene_to_file(DAY2_SCENE)
	return true
