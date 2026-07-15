extends SceneTree

const Tuning := preload("res://scripts/config/game_tuning.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene failed to load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await physics_frame

	var player := game.get_node_or_null("World/Player") as CharacterBody2D
	var camera := game.get_node_or_null("Camera") as Camera2D
	var enemy_container := game.get_node_or_null("World/Enemies")
	var projectile_container := game.get_node_or_null("World/Projectiles")
	var hud := game.get_node_or_null("HUD")
	var sfx := game.get_node_or_null("SFX")
	var debug_overlay := game.get_node_or_null("DebugOverlay") as CanvasLayer
	_expect(player != null, "playable player is missing")
	_expect(camera != null and camera.enabled, "active follow camera is missing")
	_expect(hud != null, "HUD is missing")
	_expect(sfx != null and sfx.has_cue(&"shot") and sfx.has_cue(&"accent_hit") and sfx.has_cue(&"kill"), "procedural combat audio cues are missing")
	_expect(debug_overlay != null and not debug_overlay.visible, "debug overlay must start hidden to preserve combat visibility")
	_expect(enemy_container != null and enemy_container.get_child_count() == 0, "mission enemies must not spawn before their sector trigger")
	_expect(game.boss != null and not game.boss.active and not game.hud.boss_panel.visible, "boss and boss HUD must start inactive")
	_expect(InputMap.has_action("reload") and InputMap.has_action("restart"), "reload/restart actions are missing")
	if player == null or enemy_container == null or projectile_container == null:
		game.queue_free()
		_finish()
		return

	for index in range(4):
		var kind: String = ["assault", "gunner", "shield", "elite"][index]
		var sample: Node = game._spawn_enemy(kind, Vector2(900.0 + index * 170.0, 552.0), 0.0, false, false, 0)
		sample.activate()
		sample.set_physics_process(false)
	var kinds: Array[String] = []
	for enemy in enemy_container.get_children():
		if not kinds.has(enemy.kind):
			kinds.append(enemy.kind)
	_expect(kinds.has("assault") and kinds.has("gunner") and kinds.has("shield") and kinds.has("elite"), "encounter lacks assault, gunner, shield, or elite behaviors")

	await _test_full_jump(player)
	_test_camera_framing(camera)
	await _test_automatic_fire(player)
	await _test_weapon_hit(game, enemy_container.get_child(0), projectile_container)
	await _test_accent_hit(game, enemy_container.get_child(1), projectile_container)
	await _test_enemy_attack(enemy_container, projectile_container)
	_test_player_damage(player)
	_test_player_death_contract()
	await _test_complete_loop(game, enemy_container, player)
	game.queue_free()
	_finish()


func _test_full_jump(player: CharacterBody2D) -> void:
	var start_y := player.global_position.y
	var minimum_y := start_y
	var airborne := false
	var elapsed := 0.0
	var landing_counter := [0]
	player.landed.connect(func(_position: Vector2, _intensity: float) -> void: landing_counter[0] += 1, CONNECT_ONE_SHOT)
	player.request_jump()
	for _frame in range(90):
		await physics_frame
		elapsed += 1.0 / 60.0
		minimum_y = minf(minimum_y, player.global_position.y)
		if not player.is_on_floor():
			airborne = true
		if airborne and player.is_on_floor():
			break
	var apex_height := start_y - minimum_y
	_expect(airborne, "jump input never left the floor")
	_expect(apex_height >= 88.0 and apex_height <= 104.0, "full jump apex out of range: %.1fpx" % apex_height)
	_expect(elapsed >= 0.57 and elapsed <= 0.73, "full jump airtime out of range: %.3fs" % elapsed)
	_expect(landing_counter[0] == 1 and player._landing_feedback_remaining > 0.0, "landing did not emit one weighted feedback event")


func _test_weapon_hit(game: Node, enemy: CharacterBody2D, projectile_container: Node) -> void:
	var health_before: int = enemy.health
	var shot_origin := enemy.global_position + Vector2(-90.0, -4.0)
	game._spawn_projectile(shot_origin, Vector2.RIGHT, &"player", 24, 1050.0)
	_expect(projectile_container.get_child_count() >= 1, "weapon did not create a projectile")
	var projectile := projectile_container.get_child(projectile_container.get_child_count() - 1)
	var impact_strength := [0.0]
	projectile.impacted.connect(func(_position: Vector2, _color: Color, strength: float) -> void: impact_strength[0] = strength)
	_expect(game.camera._recoil_offset.length() > 0.0, "player shot did not add camera recoil")
	for _frame in range(12):
		await physics_frame
	_expect(enemy.health == health_before - 24, "projectile damage failed: health=%d expected=%d projectiles=%d" % [enemy.health, health_before - 24, projectile_container.get_child_count()])
	_expect(impact_strength[0] >= 0.5, "damaging hit did not produce strong impact feedback")


func _test_accent_hit(game: Node, enemy: CharacterBody2D, projectile_container: Node) -> void:
	var health_before: int = enemy.health
	game._spawn_projectile(enemy.global_position + Vector2(-90.0, -4.0), Vector2.RIGHT, &"player", Tuning.WEAPON_ACCENT_DAMAGE, Tuning.WEAPON_PROJECTILE_SPEED)
	var projectile := projectile_container.get_child(projectile_container.get_child_count() - 1)
	var impact_strength := [0.0]
	projectile.impacted.connect(func(_position: Vector2, _color: Color, strength: float) -> void: impact_strength[0] = strength)
	for _frame in range(12):
		await physics_frame
	_expect(enemy.health == health_before - Tuning.WEAPON_ACCENT_DAMAGE, "accent projectile damage contract failed")
	_expect(impact_strength[0] >= Tuning.ACCENT_HIT_STRENGTH, "accent hit was not stronger than a normal hit")


func _test_camera_framing(camera: Camera2D) -> void:
	var forward_target: float = camera.calculate_desired_look_ahead(260.0, 1.0)
	var reverse_aim_target: float = camera.calculate_desired_look_ahead(260.0, -1.0)
	_expect(forward_target >= 115.0 and forward_target <= Tuning.CAMERA_MAX_LOOK_AHEAD, "camera lacks forward movement/aim space: %.1f" % forward_target)
	_expect(reverse_aim_target > 0.0 and reverse_aim_target < forward_target, "reverse aim should reduce forward framing without snapping behind")
	var smoothed := 0.0
	for _frame in range(18):
		smoothed = camera.smooth_look_ahead(smoothed, forward_target, 1.0 / 60.0)
	_expect(smoothed > 90.0 and smoothed < forward_target, "camera look-ahead smoothing is too slow or snaps: %.1f" % smoothed)


func _test_automatic_fire(player: CharacterBody2D) -> void:
	var shot_counter := [0]
	var shot_damages: Array[int] = []
	player.volley_requested.connect(func(_origin: Vector2, directions: Array[Vector2], _team: StringName, _weapon_data: Dictionary, damage: int) -> void:
		shot_counter[0] += 1
		shot_damages.append(damage)
		_expect(directions.size() == 1, "automatic rifle emitted more than one projectile per shot")
	)
	player._using_mouse_aim = false
	player.aim_direction = Vector2.UP
	var ammo_before: int = player.ammo
	Input.action_press("fire")
	for _frame in range(20):
		await physics_frame
	Input.action_release("fire")
	_expect(shot_counter[0] >= 3, "holding fire did not produce automatic shots: %d" % shot_counter[0])
	_expect(player.ammo <= ammo_before - 3, "automatic fire did not consume ammunition")
	_expect(shot_damages.has(Tuning.WEAPON_ACCENT_DAMAGE), "automatic fire cadence did not emit an accent round")
	player.aim_direction = Vector2.RIGHT


func _test_enemy_attack(enemy_container: Node, projectile_container: Node) -> void:
	var rifle: Node
	for enemy in enemy_container.get_children():
		if enemy.kind == "gunner":
			rifle = enemy
			break
	var before := projectile_container.get_child_count()
	if rifle != null:
		rifle.activate()
		var telegraph_counter := [0]
		rifle.attack_telegraph_started.connect(func(_enemy: Node, _duration: float) -> void: telegraph_counter[0] += 1)
		rifle._start_attack(11, 680.0, 0.32, 0.88)
		_expect(telegraph_counter[0] == 1 and rifle.attack_windup_remaining >= 0.3, "rifle attack did not begin a readable telegraph")
		_expect(rifle.warning.visible and projectile_container.get_child_count() == before, "enemy projectile appeared before telegraph completed")
		rifle.set_physics_process(true)
		for _frame in range(24):
			await physics_frame
		rifle.set_physics_process(false)
	_expect(rifle != null and projectile_container.get_child_count() >= before + 1, "rifle enemy did not fire after telegraph")


func _test_player_damage(player: CharacterBody2D) -> void:
	var health_before: int = player.health
	player.take_damage(11, Vector2(-30, -10), player.global_position)
	_expect(player.health == health_before - 11, "player damage contract failed")


func _test_player_death_contract() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var test_player := packed.instantiate()
	root.add_child(test_player)
	var death_counter := [0]
	test_player.died.connect(func() -> void: death_counter[0] += 1)
	test_player.take_damage(9999, Vector2.ZERO, test_player.global_position)
	_expect(not test_player.alive and death_counter[0] == 1, "player death state or signal failed")
	test_player.queue_free()


func _test_complete_loop(game: Node, enemy_container: Node, player: CharacterBody2D) -> void:
	game._debug_unlock_boss_for_tests()
	_expect(game.enemies_remaining == 0 and game.run_state == "boss_ready", "eliminating regular enemies did not unlock the boss arena")
	player.global_position.x = 17850.0
	game._process(0.0)
	_expect(game.run_state == "boss" and game.boss.active and game.hud.boss_panel.visible, "entering the arena did not activate boss and HUD")
	game.boss.take_damage(9999, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper", "direction": Vector2.RIGHT})
	_expect(game.run_state == "boss_defeated", "boss lethal damage did not enter defeat settlement")
	await create_timer(1.0).timeout
	_expect(game.run_state == "complete", "boss defeat did not complete the run")
	_expect(not player.controls_enabled, "player controls remained enabled after mission complete")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PROTOTYPE_SMOKE_PASS movement, weighted landing, aim framing, automatic fire, procedural audio, feedback tiers, staged enemies, boss arena, settlement")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
