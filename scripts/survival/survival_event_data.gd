extends RefCounted
class_name SurvivalEventData


static func all_events() -> Array[Dictionary]:
	return [
		{
			"event_id": &"supply_drop",
			"display_name": "SUPPLY DROP",
			"description": "SELECT ONE FIELD RESOURCE",
			"allowed_maps": [&"industrial_district", &"sublevel_09"],
			"allowed_waves": [3, 5, 7],
			"weight": 1.0,
			"duration": 0.0,
			"reward_type": &"supply_choice",
			"maximum_occurrences": 1,
			"cooldown_waves": 1,
			"incompatible_states": [&"upgrade_selection", &"boss", &"complete", &"stopped"],
			"timing": &"post_wave",
			"blocks_wave_start": true,
			"pauses_combat": true,
			"debug_force_enabled": true,
		},
	]


static func get_event(event_id: StringName) -> Dictionary:
	for definition in all_events():
		if StringName(definition.get("event_id", &"")) == event_id:
			return definition.duplicate(true)
	return {}
