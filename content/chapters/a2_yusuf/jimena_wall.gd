extends StaticBody3D
## Spectator on the Valencia wall. Not a combatant and not a climb target.

const LAYER_SPECTATOR := 64

@export var character_id: StringName = &"jimena"


func _ready() -> void:
	add_to_group("spectator")
	add_to_group(String(character_id))
	collision_layer = LAYER_SPECTATOR
	collision_mask = 0
	var hurt: Node = get_node_or_null("HurtBox")
	if hurt is Area3D:
		var box := hurt as Area3D
		if "spectator" in box:
			box.set("spectator", true)
		if "unkillable" in box:
			box.set("unkillable", true)
		box.collision_layer = LAYER_SPECTATOR
		box.collision_mask = 0
		box.monitorable = false
		box.monitoring = false
