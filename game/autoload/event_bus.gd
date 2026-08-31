extends Node

signal honor_logged(event: Variant)
signal soft_warn(reason: StringName)
signal hard_fail(reason: StringName)
signal beat_started(id: StringName)
signal beat_completed(id: StringName)
signal member_deserted(id: StringName)
signal sword_phase_changed(id: StringName, phase: int)
signal querella_sent
signal lists_finished(results: Array)
signal clock_night(segment: StringName, day: int)
