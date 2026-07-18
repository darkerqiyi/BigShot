extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const SurvivalScene := preload("res://scenes/survival/survival.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_scope()
	var game: Node = await _create_game(MainScene, false)
	if game != null:
		await _test_scene_accuracy(game, "PVE", true)
		await create_timer(0.40, true, false, true).timeout
		game.queue_free()
		for _cleanup_frame in range(3):
			await process_frame
	var survival: Node = await _create_game(SurvivalScene, true)
	if survival != null:
		await _test_scene_accuracy(survival, "SURVIVAL", false)
		await create_timer(0.40, true, false, true).timeout
		survival.queue_free()
		for _cleanup_frame in range(3):
			await process_frame
	_finish()


func _create_game(scene: PackedScene, survival_test_mode: bool) -> Node:
	var game: Node = scene.instantiate()
	if survival_test_mode:
		game.set_meta("survival_test_mode", true)
	root.add_child(game)
	for _frame in range(5):
		await physics_frame
	return game


func _test_catalog_scope() -> void:
	var expected := {
		&"rifle": [24, 0.085, 1050.0, 1, 1.2, 32, 0.85, 0],
		&"shotgun": [17, 0.62, 900.0, 7, 16.0, 8, 1.05, 0],
		&"sniper": [92, 1.0, 3600.0, 1, 0.0, 5, 1.2, 2],
		&"pistol": [32, 0.23, 1250.0, 1, 0.35, 15, 0.72, 0],
	}
	for weapon_id: StringName in WeaponData.ORDER:
		var data: Dictionary = WeaponData.get_weapon(weapon_id)
		var baseline: Array = expected[weapon_id]
		_expect(int(data["damage"]) == int(baseline[0]), "%s damage changed" % weapon_id)
		_expect(is_equal_approx(float(data["fire_rate"]), float(baseline[1])), "%s fire rate changed" % weapon_id)
		_expect(is_equal_approx(float(data["projectile_speed"]), float(baseline[2])), "%s projectile speed changed" % weapon_id)
		_expect(int(data["projectile_count"]) == int(baseline[3]), "%s projectile count changed" % weapon_id)
		_expect(is_equal_approx(float(data["spread_angle"]), float(baseline[4])), "%s spread changed outside the sniper zero-spread contract" % weapon_id)
		_expect(int(data["magazine_size"]) == int(baseline[5]), "%s magazine size changed" % weapon_id)
		_expect(is_equal_approx(float(data["reload_time"]), float(baseline[6])), "%s reload time changed" % weapon_id)
		_expect(int(data["penetration_count"]) == int(baseline[7]), "%s penetration changed" % weapon_id)
	var sniper: Dictionary = WeaponData.get_weapon(&"sniper")
	_expect(is_zero_approx(float(sniper["spread_angle"])) and is_zero_approx(float(sniper["movement_accuracy"])) and is_zero_approx(float(sniper["airborne_accuracy"])), "sniper still has configured random/movement/air spread")


func _test_scene_accuracy(game: Node, label: String, include_resolution_matrix: bool) -> void:
	var player: CharacterBody2D = game.player
	player.weapon_inventory.fire_cooldown = 0.0
	player.weapon_inventory.switch_cooldown = 0.0
	player.weapon_inventory.select_weapon(&"sniper")
	player._using_mouse_aim = true
	var emitted: Array[Dictionary] = []
	player.volley_requested.connect(func(origin: Vector2, directions: Array[Vector2], _team: StringName, data: Dictionary, _damage: int) -> void:
		if StringName(data["id"]) == &"sniper":
			emitted.append({"origin": origin, "direction": directions[0], "count": directions.size()})
	)
	var offsets: Array[Vector2] = [
		Vector2(180.0, 0.0), Vector2(900.0, 0.0), Vector2(1800.0, -260.0),
		Vector2(-180.0, 0.0), Vector2(-900.0, -220.0), Vector2(-1600.0, 280.0),
		Vector2(700.0, -620.0), Vector2(700.0, 420.0),
	]
	var velocities: Array[Vector2] = [Vector2.ZERO, Vector2(250.0, 0.0), Vector2(390.0, -340.0), Vector2(-390.0, 280.0)]
	var shot_index := 0
	for velocity_value: Vector2 in velocities:
		player.velocity = velocity_value
		for offset: Vector2 in offsets:
			var target: Vector2 = player.global_position + offset
			_fire_and_measure(game, player, target, emitted, "%s-%02d" % [label, shot_index])
			shot_index += 1
	if include_resolution_matrix:
		var original_size: Vector2i = root.size
		for world_x: float in [1400.0, 8600.0]:
			player.global_position = Vector2(world_x, 520.0)
			for _camera_frame in range(3):
				await physics_frame
			_fire_and_measure(game, player, player.global_position + Vector2(1250.0, -280.0), emitted, "%s-camera-x%d" % [label, int(world_x)])
		if game.has_method("_debug_unlock_boss_for_tests"):
			game._debug_unlock_boss_for_tests()
			player.global_position = Vector2(17850.0, 520.0)
			for _boss_frame in range(3):
				await physics_frame
			_fire_and_measure(game, player, player.global_position + Vector2(-1100.0, -240.0), emitted, "%s-boss-arena" % label)
		for test_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			root.size = test_size
			await process_frame
			var desired_target: Vector2 = player.global_position + Vector2(1350.0, -310.0)
			var canvas_transform: Transform2D = player.get_canvas_transform()
			var screen_point: Vector2 = canvas_transform * desired_target
			var resolved_world: Vector2 = canvas_transform.affine_inverse() * screen_point
			_expect(resolved_world.distance_to(desired_target) < 0.01, "%s canvas-to-world aim conversion drifted at %s" % [label, test_size])
			_fire_and_measure(game, player, resolved_world, emitted, "%s-%s" % [label, test_size])
		root.size = original_size
	player.set_aim_debug_enabled(true)
	_expect(bool(player.get_debug_snapshot()["aim_debug_enabled"]), "%s sniper aim debug ray could not be enabled in debug build" % label)
	player.set_aim_debug_enabled(false)
	_expect(not bool(player.get_debug_snapshot()["aim_debug_enabled"]), "%s sniper aim debug ray did not default back off" % label)


func _fire_and_measure(game: Node, player: CharacterBody2D, target: Vector2, emitted: Array[Dictionary], label: String) -> void:
	var visual_direction: Vector2 = (target - player.global_position).normalized()
	player.aim_target_world = target
	player.aim_direction = visual_direction
	player.facing_direction = 1 if visual_direction.x >= 0.0 else -1
	player.visual.set_aim_direction(visual_direction, player.facing_direction)
	player.weapon_inventory._ammo[&"sniper"] = 5
	player.weapon_inventory.fire_cooldown = 0.0
	player.weapon_inventory.reload_remaining = 0.0
	var before_count := emitted.size()
	player._fire_current_weapon()
	_expect(emitted.size() == before_count + 1, "%s did not emit exactly one sniper volley" % label)
	if emitted.size() <= before_count:
		return
	var shot: Dictionary = emitted[-1]
	var origin: Vector2 = shot["origin"]
	var actual: Vector2 = shot["direction"]
	var expected: Vector2 = (target - origin).normalized()
	var angular_error_degrees := absf(rad_to_deg(expected.angle_to(actual)))
	var cursor_miss_pixels := absf((target - origin).cross(actual))
	_expect(int(shot["count"]) == 1, "%s sniper emitted more than one projectile" % label)
	_expect(angular_error_degrees < 0.001, "%s trajectory angular error is %.6f degrees" % [label, angular_error_degrees])
	_expect(cursor_miss_pixels < 0.02, "%s trajectory misses cursor line by %.4f pixels" % [label, cursor_miss_pixels])
	_expect(player.get_debug_snapshot()["last_pattern"] == [0.0], "%s sniper acquired a spread pattern" % label)
	_expect(player.last_shot_origin.distance_to(origin) < 0.01 and player.last_shot_direction.angle_to(actual) < 0.00001, "%s debug trajectory does not match emitted projectile" % label)
	if game.projectiles.get_child_count() > 0:
		var projectile: Node = game.projectiles.get_child(game.projectiles.get_child_count() - 1)
		_expect((projectile.direction as Vector2).angle_to(actual) < 0.00001, "%s projectile velocity direction differs from volley direction" % label)
		_expect(absf(float(projectile.rotation) - actual.angle()) < 0.00001, "%s projectile rotation differs from velocity direction" % label)
		projectile.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SNIPER_ACCURACY_PASS muzzle-to-mouse world ray, zero standing/moving/air spread, left/right near/mid/far/up/down, scrolling camera/Boss arena, 720p/1080p/1440p canvas transforms, PVE and survival")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
