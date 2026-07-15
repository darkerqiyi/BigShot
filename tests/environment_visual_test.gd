extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	_test_world_collision_contract(game)
	_test_encounter_contract(game)
	_test_layer_contract(game)
	_test_pixel_source_contract()
	_test_parallax_snap(game)
	game.queue_free()
	await process_frame
	_finish()


func _test_world_collision_contract(game: Node) -> void:
	var floor := game.get_node("World/Floor") as StaticBody2D
	var floor_shape := floor.get_node("CollisionShape2D").shape as RectangleShape2D
	_expect(floor.position == Vector2(10000, 640) and floor_shape.size == Vector2(20000, 112), "expanded mission floor collision is incorrect")
	var expected_platforms := {
		"PlatformA": [Vector2(1600, 507), Vector2(260, 22)],
		"PlatformB": [Vector2(3000, 503), Vector2(300, 22)],
		"PlatformC": [Vector2(4500, 511), Vector2(250, 22)],
		"PlatformD": [Vector2(6200, 502), Vector2(280, 22)],
		"PlatformE": [Vector2(8200, 507), Vector2(260, 22)],
		"PlatformF": [Vector2(9400, 503), Vector2(300, 22)],
		"PlatformG": [Vector2(11600, 511), Vector2(250, 22)],
		"PlatformH": [Vector2(14500, 502), Vector2(280, 22)],
		"PlatformI": [Vector2(16600, 507), Vector2(260, 22)],
		"PlatformJ": [Vector2(18400, 503), Vector2(300, 22)],
	}
	for platform_name in expected_platforms:
		var platform := game.get_node("World/%s" % platform_name) as StaticBody2D
		var shape := platform.get_node("CollisionShape2D").shape as RectangleShape2D
		_expect(platform.position == expected_platforms[platform_name][0], "%s position changed during art pass" % platform_name)
		_expect(shape.size == expected_platforms[platform_name][1], "%s collision size changed during art pass" % platform_name)
	var gate := game.get_node("World/BossGate") as StaticBody2D
	var gate_shape := gate.get_node("CollisionShape2D").shape as RectangleShape2D
	_expect(gate.position == Vector2(17800, 360) and gate_shape.size == Vector2(28, 720), "Boss gate physics does not match the expanded arena")
	_expect(game.camera.level_width == 20000.0, "camera does not cover the expanded mission")


func _test_encounter_contract(game: Node) -> void:
	_expect(game.enemies.get_child_count() == 0, "mission enemies spawned before their authored sector trigger")
	_expect(game.MISSION_ENCOUNTERS.size() == 4, "expanded mission does not contain four major gated encounters")
	var expected_counts := [7, 6, 8, 7]
	var expected_triggers := [2830.0, 7800.0, 10800.0, 13600.0]
	var expected_gates := [5200.0, 10500.0, 13300.0, 16200.0]
	for index in range(game.MISSION_ENCOUNTERS.size()):
		var encounter: Dictionary = game.MISSION_ENCOUNTERS[index]
		var authored_count := 0
		for wave in encounter["waves"]:
			authored_count += (wave as Array).size()
		_expect(authored_count == expected_counts[index], "encounter %d authored enemy count changed" % (index + 1))
		_expect(float(encounter["trigger_x"]) == expected_triggers[index] and float(encounter["gate_x"]) == expected_gates[index], "encounter %d route bounds changed" % (index + 1))
	var first_waves: Array = game.MISSION_ENCOUNTERS[0]["waves"]
	_expect((first_waves[0] as Array).size() == 1 and str(first_waves[0][0]["kind"]) == "gunner", "first-contact roll lesson is not a single readable ranged threat")
	_expect((first_waves[1] as Array).size() == 3 and first_waves[1].all(func(entry: Dictionary) -> bool: return str(entry["kind"]) == "assault"), "first-contact grenade lesson is not a compact assault group")
	_expect(game.FIRST_RUN_TARGET_SECONDS == Vector2i(350, 460) and game.SKILLED_TARGET_SECONDS == Vector2i(240, 360), "mission duration targets no longer match the 5–8/4–6 minute brief")
	_expect(game.boss.global_position.distance_to(Vector2(19000, 520)) < 0.1, "Boss spawn does not match the expanded arena")
	var opening_seconds := (2830.0 - 230.0) / 260.0
	_expect(opening_seconds >= 9.9 and opening_seconds <= 10.1, "opening safe run no longer matches the requested 10-second target")
	var jump_apex := 590.0 * 590.0 / (2.0 * 1800.0)
	for platform_name in ["PlatformA", "PlatformB", "PlatformC", "PlatformD", "PlatformE", "PlatformF", "PlatformG", "PlatformH", "PlatformI", "PlatformJ"]:
		var platform := game.get_node("World/%s" % platform_name) as StaticBody2D
		var platform_shape := platform.get_node("CollisionShape2D").shape as RectangleShape2D
		var platform_top: float = platform.position.y - platform_shape.size.y * 0.5
		_expect(584.0 - platform_top <= jump_apex - 3.0, "%s remains above the player's reliable jump apex" % platform_name)
	for hazard in game.get_tree().get_nodes_in_group("mission_hazards"):
		_expect(float(hazard.strip_width) <= 72.0, "road hazard remains wider than the player's reliable running jump")
	_expect(game.get_tree().get_nodes_in_group("mission_pickups").size() == 5, "expanded route is missing its five finite supply pickups")
	_expect(game.get_tree().get_nodes_in_group("mission_hazards").size() == 3, "expanded route is missing readable environmental hazards")
	_expect(game.get_tree().get_nodes_in_group("mission_platforms").size() == 2, "platform sector is missing its two moving platforms")


func _test_layer_contract(game: Node) -> void:
	var sky = game.get_node("Sky/SkyPixels")
	var far = game.get_node("World/FarArt")
	var mid = game.get_node("World/MidArt")
	var level = game.get_node("World/LevelArt")
	var front = game.get_node("World/FrontArt")
	var gate_visual = game.get_node("World/BossGateVisual")
	_expect(sky.get_visual_contract()["logical_size"] == Vector2i(1280, 720), "sky is not authored for the logical viewport")
	_expect(far.z_index == -90 and mid.z_index == -70 and level.z_index == -10 and front.z_index == 80, "world layer z-order changed unexpectedly")
	_expect(is_equal_approx(far.parallax_factor, 0.15) and is_equal_approx(mid.parallax_factor, 0.45) and is_equal_approx(front.parallax_factor, 1.15), "parallax factors changed from baseline")
	var level_contract: Dictionary = level.get_visual_contract()
	_expect(level_contract["ground_top"] == 584.0 and level_contract["level_width"] == 20000.0, "level art no longer matches the expanded ground/width")
	_expect((level_contract["platform_rects"] as Array).size() == 10, "expanded platform visual set is incomplete")
	_expect(float(front.get_visual_contract()["front_top_y"]) >= 568.0, "foreground art can cover character torso or attack warnings")
	_expect(gate_visual.get_visual_contract()["rect"] == Rect2(17790, 80, 20, 504), "pixel Boss gate no longer matches the expanded arena bounds")
	_expect(ProjectSettings.get_setting("rendering/textures/default_filters/use_nearest_mipmap_filter") == false, "nearest-filter baseline changed")
	_expect(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel") == true, "world transform pixel snapping changed")


func _test_pixel_source_contract() -> void:
	for path in [
		"res://scripts/world/sky_pixel_art.gd",
		"res://scripts/world/parallax_art.gd",
		"res://scripts/world/level_art.gd",
		"res://scripts/world/boss_gate_pixel.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("draw_circle("), "%s reintroduced smooth circle primitives" % path)
		_expect(not source.contains("draw_arc("), "%s reintroduced smooth arc primitives" % path)
		_expect(not source.contains("draw_line("), "%s reintroduced antialiased line primitives" % path)


func _test_parallax_snap(game: Node) -> void:
	game.camera.global_position.x = 1000.0
	var far = game.get_node("World/FarArt")
	var mid = game.get_node("World/MidArt")
	var front = game.get_node("World/FrontArt")
	far._process(0.0)
	mid._process(0.0)
	front._process(0.0)
	_expect(far.position.x == roundf(far.position.x) and mid.position.x == roundf(mid.position.x) and front.position.x == roundf(front.position.x), "parallax layers are not snapped to logical pixels")
	_expect(far.get_visual_contract()["far_coverage"].x <= -1800.0 and far.get_visual_contract()["far_coverage"].y >= 22500.0, "far layer coverage cannot hide expanded-route seams")
	_expect(mid.get_visual_contract()["mid_coverage"].x <= -1500.0 and mid.get_visual_contract()["mid_coverage"].y >= 22600.0, "mid layer coverage cannot hide expanded-route seams")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENT_VISUAL_PASS pixel sky/far/mid/play/front layers, exact collision/platform/encounter contracts, bounded foreground, snapped scrolling, no smooth world primitives")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
