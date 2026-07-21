extends SceneTree

const IndustrialScene := preload("res://scenes/survival/survival.tscn")
const SublevelScene := preload("res://scenes/survival/survival_sublevel_09.tscn")
const MapConfig := preload("res://scripts/survival/survival_map_config.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var maps := MapConfig.all_maps()
	_expect(maps.size() == 2, "map registry does not expose exactly two survival maps")
	_expect(StringName(maps[0]["map_id"]) == MapConfig.INDUSTRIAL_ID, "industrial map registry entry changed identity")
	_expect(StringName(maps[1]["map_id"]) == MapConfig.SUBLEVEL_ID, "Sublevel-09 map registry entry is missing")
	var sublevel_config := MapConfig.get_map(MapConfig.SUBLEVEL_ID)
	var groups: Dictionary = sublevel_config["spawn_groups"]
	_expect((groups["left_ground"] as Array).size() >= 2 and (groups["right_ground"] as Array).size() >= 2, "Sublevel-09 lacks safe ground spawn groups")
	_expect((groups["left_upper"] as Array).size() >= 2 and (groups["right_upper"] as Array).size() >= 2, "Sublevel-09 lacks upper spawn groups")
	_expect((sublevel_config["platforms"] as Array).size() >= 2, "Sublevel-09 has no authored combat platforms")
	_expect((sublevel_config["hazards"] as Array).size() == 1, "Sublevel-09 must expose one steam mechanism definition")

	var industrial_metrics := await _complete_map(IndustrialScene, MapConfig.INDUSTRIAL_ID)
	var sublevel_metrics := await _complete_map(SublevelScene, MapConfig.SUBLEVEL_ID)
	_expect(bool(industrial_metrics.get("complete", false)), "industrial map did not complete all ten waves")
	_expect(bool(sublevel_metrics.get("complete", false)), "Sublevel-09 did not complete all ten waves")
	_expect(int(industrial_metrics.get("waves", 0)) == 10 and int(sublevel_metrics.get("waves", 0)) == 10, "one map did not start all ten waves")
	_expect(int(industrial_metrics.get("upgrades", 0)) == 4 and int(sublevel_metrics.get("upgrades", 0)) == 4, "one map did not preserve four upgrade selections")
	_expect(int(industrial_metrics.get("bosses", 0)) == 1 and int(sublevel_metrics.get("bosses", 0)) == 1, "one map did not spawn exactly one Boss")
	_expect(int(industrial_metrics.get("max_active", 99)) <= 7, "industrial active cap regressed")
	_expect(int(sublevel_metrics.get("max_active", 99)) <= 6, "Sublevel-09 compact active cap was not applied")
	_expect(bool(sublevel_metrics.get("steam_verified", false)), "Sublevel-09 steam warning/damage/pause contract failed")
	await _verify_sublevel_restart()
	print("SURVIVAL_MAPS_METRICS industrial=%s sublevel=%s" % [industrial_metrics, sublevel_metrics])
	_finish()


func _complete_map(scene: PackedScene, expected_map_id: StringName) -> Dictionary:
	var game := scene.instantiate()
	game.set_meta("survival_test_mode", true)
	game.set_meta("survival_upgrade_seed", 1709)
	root.add_child(game)
	current_scene = game
	var started: Array[int] = []
	var upgrades: Array[int] = []
	var counts := {"bosses": 0, "upgrade_hazard_pause": expected_map_id != MapConfig.SUBLEVEL_ID, "boss_hazard_pause": expected_map_id != MapConfig.SUBLEVEL_ID}
	var max_active := 0
	game.wave_manager.wave_started.connect(func(wave: int, _total: int, _title: String) -> void: started.append(wave))
	game.wave_manager.upgrade_requested.connect(func(wave: int) -> void: upgrades.append(wave))
	game.wave_manager.boss_requested.connect(func(_wave: int) -> void:
		counts["bosses"] = int(counts["bosses"]) + 1
		if expected_map_id == MapConfig.SUBLEVEL_ID and not game.map_hazards.is_empty():
			counts["boss_hazard_pause"] = bool(game.map_hazards[0].suspended)
	)
	_expect(game.map_id == expected_map_id, "%s scene loaded the wrong map configuration" % expected_map_id)
	var expected_config := MapConfig.get_map(expected_map_id)
	_expect(game.player.global_position.is_equal_approx(expected_config["player_spawn"]), "%s player spawn does not match map configuration" % expected_map_id)
	_expect(game.boss.global_position.is_equal_approx(expected_config["boss_spawn"]), "%s Boss spawn does not match map configuration" % expected_map_id)
	_expect(game.camera.level_left == (expected_config["camera_bounds"] as Rect2).position.x and game.camera.level_width == (expected_config["camera_bounds"] as Rect2).end.x, "%s camera bounds were not applied" % expected_map_id)
	game.wave_manager.stop_run()
	await _verify_spawn_mobility(game, expected_config, expected_map_id)
	if expected_map_id == MapConfig.SUBLEVEL_ID:
		_expect(game.world.get_node_or_null("LeftLowPlatform") != null and game.world.get_node_or_null("RightLowPlatform") != null, "Sublevel-09 platform bodies are missing")
		_expect(game.map_hazards.size() == 1, "Sublevel-09 steam vent was not created")
		_expect(game.map_hazards[0].suspended and game.map_hazards[0].state == game.map_hazards[0].State.INITIAL_DELAY, "steam vent can activate at player spawn")
		_expect(game._choose_spawn_position("left", 2, "gunner").y < 500.0 and game._choose_spawn_position("right", 2, "gunner").y < 500.0, "Sublevel-09 upper ranged spawn groups are not selectable")
		_expect(is_equal_approx(game._choose_spawn_position("left", 1, "assault").y, 552.0) and is_equal_approx(game._choose_spawn_position("right", 1, "elite").y, 552.0), "melee/heavy roles can spawn on unreachable upper lanes")
		await _verify_sublevel_platform_mobility(game)
	else:
		_expect(game.map_hazards.is_empty(), "industrial map unexpectedly created a steam vent")
	game.player.cancel_transient_actions()
	game.player.global_position = expected_config["player_spawn"]
	game.player.velocity = Vector2.ZERO
	game.wave_manager.start_run()

	var frame_budget := 4200
	while is_instance_valid(game) and game.run_state != "complete" and frame_budget > 0:
		frame_budget -= 1
		max_active = maxi(max_active, game.wave_manager.get_alive_count())
		if game.wave_manager.get_state_name() == &"upgrade_selection" and game.upgrade_manager.selection_open:
			if expected_map_id == MapConfig.SUBLEVEL_ID and not game.map_hazards.is_empty():
				counts["upgrade_hazard_pause"] = bool(game.map_hazards[0].suspended)
			game._on_survival_upgrade_chosen(StringName(game.upgrade_manager.current_candidates[0]["id"]))
		for enemy in game.enemies.get_children():
			if bool(enemy.get("alive")):
				enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {"weapon_id": &"rifle", "damage_kind": &"projectile"})
		if game.boss.active and game.boss.alive:
			if game.boss.phase == 1:
				game.boss.take_damage(500, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper"})
			elif game.boss.transition_remaining <= 0.0:
				game.boss.take_damage(9999, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper"})
		await physics_frame

	var steam_verified := expected_map_id != MapConfig.SUBLEVEL_ID
	if expected_map_id == MapConfig.SUBLEVEL_ID and not game.map_hazards.is_empty():
		var vent = game.map_hazards[0]
		vent.set_suspended(true)
		vent.state = vent.State.WARNING
		vent.remaining = 0.2
		var frozen_remaining: float = vent.remaining
		await create_timer(0.08).timeout
		var paused_correctly := is_equal_approx(vent.remaining, frozen_remaining)
		var target: Node = game._spawn_enemy("assault", vent.global_position + Vector2(0, -30), 0.0, false, false, 1)
		target.active = false
		var health_before: int = target.health
		game.player.global_position = expected_config["player_spawn"]
		vent.set_suspended(false)
		vent.remaining = 0.01
		await create_timer(0.08).timeout
		var enemy_environment_damage: bool = target.health == health_before - vent.enemy_damage and target.last_damage_weapon_id == &"environment"
		game.player.health = game.player.runtime_max_health
		game.player._invulnerability_remaining = 0.0
		game.player.alive = true
		game.player.is_rolling = true
		game.player.global_position = vent.global_position + Vector2(0, -30)
		vent.state = vent.State.WARNING
		vent.remaining = 0.01
		vent._damage_applied = false
		await create_timer(0.08).timeout
		var environment_ignores_roll: bool = game.player.health == game.player.runtime_max_health - vent.player_damage and game.player.health > 0 and game.player.last_damage_kind == &"environment"
		steam_verified = paused_correctly and enemy_environment_damage and environment_ignores_roll and bool(counts["upgrade_hazard_pause"]) and bool(counts["boss_hazard_pause"])
		target.queue_free()

	var metrics := {
		"complete": game.run_state == "complete",
		"waves": started.size(),
		"upgrades": upgrades.size(),
		"bosses": int(counts["bosses"]),
		"max_active": max_active,
		"steam_verified": steam_verified,
		"map": expected_map_id,
	}
	game.queue_free()
	await process_frame
	await process_frame
	return metrics


func _verify_sublevel_restart() -> void:
	var game := SublevelScene.instantiate()
	game.set_meta("survival_test_mode", true)
	root.add_child(game)
	current_scene = game
	game.debug_add_upgrade(&"endurance_core")
	_expect(not game.upgrade_manager.stacks.is_empty(), "restart setup did not apply a run-local upgrade")
	var previous_id := game.get_instance_id()
	game.player.take_damage(9999, Vector2.ZERO, game.player.global_position, {"source": &"map_restart_test", "damage_kind": &"environment"})
	await create_timer(1.8).timeout
	_expect(current_scene != null and current_scene.get_instance_id() != previous_id, "Sublevel-09 death did not reload its scene")
	if current_scene != null and current_scene.get_instance_id() != previous_id:
		_expect(current_scene.map_id == MapConfig.SUBLEVEL_ID, "Sublevel-09 death restarted on a different map")
		_expect(current_scene.wave_manager.current_wave == 0, "Sublevel-09 restart retained wave progress")
		_expect(current_scene.upgrade_manager.stacks.is_empty(), "Sublevel-09 restart retained run upgrades")
		_expect(current_scene.map_hazards.size() == 1 and current_scene.map_hazards[0].state == current_scene.map_hazards[0].State.INITIAL_DELAY, "Sublevel-09 restart retained steam state")
		current_scene.queue_free()
		await process_frame


func _verify_sublevel_platform_mobility(game: Node) -> void:
	game.wave_manager.stop_run()
	game.player.global_position = Vector2(300.0, 552.0)
	game.player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	for _frame in range(14):
		await physics_frame
	game.player.request_jump()
	var landed_on_platform := false
	for _frame in range(75):
		await physics_frame
		if game.player.is_on_floor() and game.player.global_position.y < 500.0:
			landed_on_platform = true
			break
	Input.action_release("move_right")
	_expect(landed_on_platform and game.player.global_position.y <= 461.0, "player cannot reach Sublevel-09 upper combat platform with the existing jump")


func _verify_spawn_mobility(game: Node, config: Dictionary, expected_map_id: StringName) -> void:
	var player: CharacterBody2D = game.player
	var spawn: Vector2 = config["player_spawn"]
	player.cancel_transient_actions()
	player.controls_enabled = true
	player.global_position = spawn
	player.velocity = Vector2.ZERO
	await physics_frame
	var validation: Dictionary = game.validate_survival_player_spawn()
	_expect(bool(validation.get("valid", false)), "%s player spawn overlaps static collision or is outside map bounds: %s" % [expected_map_id, validation])
	_expect(not paused and player.process_mode != Node.PROCESS_MODE_DISABLED and player.controls_enabled, "%s entered with movement processing disabled" % expected_map_id)
	var bounds: Rect2 = config["camera_bounds"]
	_expect(bounds.size.x > 0.0 and bounds.end.x > bounds.position.x, "%s movement bounds are invalid" % expected_map_id)

	var start_right := player.global_position
	Input.action_press("move_right")
	for _frame in range(12):
		await physics_frame
	var right_position := player.global_position
	var right_velocity := player.velocity
	Input.action_release("move_right")
	_expect(right_position.x > start_right.x + 20.0 and right_velocity.x > 0.0, "%s computes rightward velocity but does not move from its configured spawn" % expected_map_id)

	player.global_position = spawn
	player.velocity = Vector2.ZERO
	await physics_frame
	var start_left := player.global_position
	Input.action_press("move_left")
	for _frame in range(12):
		await physics_frame
	var left_position := player.global_position
	Input.action_release("move_left")
	_expect(left_position.x < start_left.x - 20.0 and player.velocity.x < 0.0, "%s cannot move left from its configured spawn" % expected_map_id)

	player.global_position = spawn
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	var jump_start_y := player.global_position.y
	player.request_jump()
	Input.action_press("move_right")
	var jump_min_y := jump_start_y
	for _frame in range(12):
		await physics_frame
		jump_min_y = minf(jump_min_y, player.global_position.y)
	Input.action_release("move_right")
	_expect(jump_min_y < jump_start_y - 20.0, "%s cannot jump from its configured spawn" % expected_map_id)

	player.global_position = spawn
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(18):
		await physics_frame
	var sprint_position := player.global_position
	var sprint_velocity := player.velocity.x
	var sprint_started: bool = player.is_sprinting
	player.request_jump()
	for _frame in range(4):
		await physics_frame
	var inherited_sprint_momentum: bool = player.launched_from_sprint and absf(player.velocity.x) > Tuning.PLAYER_MAX_SPEED
	Input.action_release("sprint")
	Input.action_release("move_right")
	_expect(sprint_started and sprint_position.x > spawn.x + 35.0, "%s cannot sprint from its configured spawn" % expected_map_id)
	_expect(inherited_sprint_momentum, "%s sprint jump did not inherit momentum (launch velocity %s)" % [expected_map_id, sprint_velocity])

	player.cancel_transient_actions()
	player.global_position = spawn
	player.velocity = Vector2.ZERO
	player.roll_cooldown_remaining = 0.0
	await physics_frame
	await physics_frame
	var roll_start_x := player.global_position.x
	player._register_direction_tap(1)
	player._register_direction_tap(1)
	var roll_started: bool = player.is_rolling
	for _frame in range(5):
		await physics_frame
	_expect(roll_started and player.global_position.x > roll_start_x + 20.0, "%s cannot execute DD roll from its configured spawn" % expected_map_id)
	player.cancel_transient_actions()
	print("SURVIVAL_MAP_MOBILITY map=%s spawn=%s right=%s left=%s jump_min_y=%.2f sprint_x=%.2f sprint_velocity=%.2f roll_x=%.2f validation=%s" % [expected_map_id, spawn, right_position, left_position, jump_min_y, sprint_position.x, sprint_velocity, player.global_position.x, validation])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	Input.action_release("move_right")
	if failures.is_empty():
		print("SURVIVAL_MAPS_PASS two configured maps share one WaveManager, complete ten waves, preserve upgrades/Boss, and isolate the steam hazard")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
