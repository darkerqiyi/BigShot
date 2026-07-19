extends RefCounted
class_name SurvivalMapConfig


const INDUSTRIAL_ID := &"industrial_district"
const SUBLEVEL_ID := &"sublevel_09"


static func all_maps() -> Array[Dictionary]:
	return [get_map(INDUSTRIAL_ID), get_map(SUBLEVEL_ID)]


static func get_map(map_id: StringName) -> Dictionary:
	if map_id == SUBLEVEL_ID:
		return _sublevel_09()
	return _industrial_district()


static func _industrial_district() -> Dictionary:
	return {
		"map_id": INDUSTRIAL_ID,
		"display_name": "IRON DISTRICT // 工业城区",
		"scene_path": "res://scenes/survival/survival.tscn",
		"description": "OPEN LANES // LONG-RANGE CONTROL",
		"difficulty": "STANDARD",
		"art_theme": &"industrial",
		"player_spawn": Vector2(640.0, 552.0),
		"camera_bounds": Rect2(0.0, 0.0, 1280.0, 720.0),
		"spawn_groups": {
			"left_ground": [Vector2(120.0, 552.0), Vector2(270.0, 552.0)],
			"right_ground": [Vector2(1010.0, 552.0), Vector2(1160.0, 552.0)],
			"left_upper": [],
			"right_upper": [],
		},
		"boss_spawn": Vector2(1010.0, 520.0),
		"boss_arena": Vector2(110.0, 1170.0),
		"boss_summons": PackedVector2Array([Vector2(280.0, 552.0), Vector2(1000.0, 552.0)]),
		"recovery_spawns": [Vector2(120.0, 552.0), Vector2(1160.0, 552.0)],
		"platforms": [],
		"hazards": [],
		"active_limit_offset": 0,
		"spawn_interval_scale": 1.0,
		"music": &"level",
		"ambience": &"none",
		"allowed_wave_config": &"survival_10",
	}


static func _sublevel_09() -> Dictionary:
	return {
		"map_id": SUBLEVEL_ID,
		"display_name": "SUBLEVEL-09 // 废弃地下运输站",
		"scene_path": "res://scenes/survival/survival_sublevel_09.tscn",
		"description": "TIGHT LANES // VERTICAL PRESSURE // STEAM",
		"difficulty": "TACTICAL",
		"art_theme": &"sublevel_09",
		"player_spawn": Vector2(800.0, 552.0),
		"camera_bounds": Rect2(0.0, 0.0, 1600.0, 720.0),
		"spawn_groups": {
			"left_ground": [Vector2(110.0, 552.0), Vector2(250.0, 552.0)],
			"right_ground": [Vector2(1350.0, 552.0), Vector2(1490.0, 552.0)],
			"left_upper": [Vector2(430.0, 460.0), Vector2(560.0, 460.0)],
			"right_upper": [Vector2(1040.0, 460.0), Vector2(1170.0, 460.0)],
		},
		"boss_spawn": Vector2(1260.0, 520.0),
		"boss_arena": Vector2(150.0, 1450.0),
		"boss_summons": PackedVector2Array([Vector2(300.0, 552.0), Vector2(1300.0, 552.0)]),
		"recovery_spawns": [Vector2(140.0, 552.0), Vector2(1460.0, 552.0)],
		"platforms": [
			{"name": "LeftLowPlatform", "position": Vector2(500.0, 502.0), "size": Vector2(260.0, 22.0)},
			{"name": "RightLowPlatform", "position": Vector2(1100.0, 502.0), "size": Vector2(260.0, 22.0)},
			{"name": "CenterStep", "position": Vector2(800.0, 540.0), "size": Vector2(190.0, 18.0)},
		],
		"hazards": [
			{
				"kind": &"steam_vent",
				"position": Vector2(640.0, 582.0),
				"width": 116.0,
				"warning_time": 1.25,
				"active_time": 0.95,
				"cooldown_time": 6.2,
				"player_damage": 18,
				"enemy_damage": 24,
				"initial_delay": 4.5,
			},
		],
		"active_limit_offset": -1,
		"spawn_interval_scale": 0.90,
		"music": &"level",
		"ambience": &"tunnel",
		"allowed_wave_config": &"survival_10",
	}
