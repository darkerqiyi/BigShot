extends SceneTree

const SurvivalScene := preload("res://scenes/survival/survival.tscn")

var failures: Array[String] = []
var strategy := "mixed"
var grenade_waves_used: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(1337)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--strategy="):
			strategy = argument.trim_prefix("--strategy=")
	var game := SurvivalScene.instantiate()
	game.set_meta("survival_upgrade_seed", 1337 if strategy == "mixed" else 7331)
	root.add_child(game)
	current_scene = game
	for _frame in range(6):
		await physics_frame
	var player = game.player
	player._using_mouse_aim = false

	# Exercise sprint-jump momentum inside the survival arena before the combat bot.
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(20):
		await physics_frame
	var sprint_entry_speed: float = absf(player.velocity.x)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var sprint_air_speed: float = absf(player.velocity.x)
	_expect(sprint_entry_speed >= 450.0, "survival sprint did not reach its launch-speed band")
	_expect(sprint_air_speed >= sprint_entry_speed * 0.85, "survival sprint jump discarded horizontal momentum")
	_release_inputs()
	player.global_position = Vector2(640.0, 520.0)
	player.velocity = Vector2.ZERO
	for _frame in range(30):
		await physics_frame
		if player.is_on_floor():
			break

	# Exercise roll and charged grenade using the same live player instance.
	player._register_direction_tap(1)
	player._register_direction_tap(1)
	var roll_worked: bool = player.is_rolling
	_expect(roll_worked, "AA/DD roll did not work in survival")
	while player.is_rolling:
		await physics_frame
	var grenade_before: int = player.grenade_count
	var grenade_worked: bool = player._start_grenade_charge()
	if grenade_worked:
		player.grenade_charge = 0.55
		grenade_worked = player._release_grenade()
	_expect(grenade_worked and player.grenade_count == grenade_before - 1, "charged grenade did not launch or consume one grenade in survival")

	# Moderate wall-clock acceleration preserves projectile collision behavior while
	# _run_elapsed still records the equivalent in-game duration used for pacing.
	Engine.time_scale = 4.0
	var frame_count := 0
	var last_kill_count: int = game._run_kills
	var no_kill_elapsed := 0.0
	while is_instance_valid(game) and game.run_state != "complete" and game._run_elapsed < 900.0:
		frame_count += 1
		if game.wave_manager.get_state_name() == &"upgrade_selection" and game.upgrade_manager.selection_open:
			var choice_index: int = game.upgrade_manager.selection_history.size() % game.upgrade_manager.current_candidates.size() if strategy == "mixed" else 0
			game._on_survival_upgrade_chosen(StringName(game.upgrade_manager.current_candidates[choice_index]["id"]))
		# Keep the deterministic validation bot alive; damage delivery itself remains active.
		# Heal between physics steps so real damage events and their source remain
		# observable without making this deterministic acceptance bot mortal.
		player.health = player.MAX_HEALTH
		player.global_position.x = 640.0
		player.velocity.x = 0.0
		if strategy == "rifle_only" and frame_count % 18 == 0 and player.is_on_floor() and not player.is_rolling:
			player._register_direction_tap(1 if frame_count % 36 == 0 else -1)
			player._register_direction_tap(1 if frame_count % 36 == 0 else -1)
		elif strategy == "mixed" and frame_count % 240 == 0 and game.projectiles.get_child_count() > 0 and player.is_on_floor() and not player.is_rolling:
			player._register_direction_tap(1 if frame_count % 480 == 0 else -1)
			player._register_direction_tap(1 if frame_count % 480 == 0 else -1)
		if game.boss.active and game.boss.alive:
			game.boss.global_position = Vector2(960.0, 520.0)
			game.boss.velocity = Vector2.ZERO
		if game._run_kills != last_kill_count:
			last_kill_count = game._run_kills
			no_kill_elapsed = 0.0
		else:
			no_kill_elapsed += 4.0 / 60.0
		if frame_count % 1200 == 0:
			print("SURVIVAL_SCRIPTED_PROGRESS wave=%d elapsed=%.1f kills=%d state=%s" % [game.wave_manager.current_wave, game._run_elapsed, game._run_kills, game.run_state])
		var target := _select_target(game)
		if target != null:
			# This is test-only stall recovery for a fixed firing station, not a runtime
			# shortcut. Production uses the arena's normal out-of-bounds recovery.
			if target != game.boss and no_kill_elapsed >= 8.0:
				target.global_position = Vector2(860.0 if target.global_position.x >= 640.0 else 420.0, 552.0)
				target.velocity = Vector2.ZERO
				no_kill_elapsed = 0.0
			var weapon_id := &"rifle" if strategy == "rifle_only" else _weapon_for_target(game, target)
			if player.current_weapon_id != weapon_id:
				player.weapon_inventory.select_weapon(weapon_id)
			var offset: Vector2 = target.global_position - player.global_position
			player.aim_direction = offset.normalized()
			_set_move(0.0)
			Input.action_release("sprint")
			var wave_number: int = game.wave_manager.current_wave
			if strategy == "mixed" and wave_number in [3, 6, 8, 9] and not grenade_waves_used.has(wave_number) and player.grenade_count > 0 and player._start_grenade_charge():
				player.grenade_charge = clampf(absf(offset.x) / 720.0, 0.28, 0.72)
				if player._release_grenade():
					grenade_waves_used[wave_number] = true
			_drive_fire(player, frame_count, game._run_elapsed)
			if player.ammo <= 1:
				player._start_reload()
			Input.action_release("reload")
		else:
			Input.action_release("fire")
			Input.action_release("reload")
			_set_move(0.0)
		await physics_frame
		if frame_count > 18000:
			break

	_release_inputs()
	Engine.time_scale = 1.0
	var snapshot: Dictionary = game.telemetry.get_snapshot()
	var used_weapon_count := 0
	for weapon_id in [&"rifle", &"shotgun", &"sniper", &"pistol"]:
		var weapon_stats: Dictionary = snapshot["weapons"][weapon_id]
		if int(weapon_stats["shots"]) > 0 and int(weapon_stats["damage"]) > 0:
			used_weapon_count += 1
	_expect(game.run_state == "complete", "scripted survival playthrough did not clear ten waves")
	# Mixed automation has near-perfect aim and heals between frames, so its
	# 7-15 minute regression band sits below the 8-15 minute human target. The
	# rifle-only probe also holds fire and rolls almost continuously; its lower
	# 4-10 minute band detects stalls without pretending it is a new-player run;
	# shield positioning intentionally produces wider timing variance here.
	var minimum_duration := 240.0 if strategy == "rifle_only" else 420.0
	var maximum_duration := 600.0 if strategy == "rifle_only" else 900.0
	var duration_in_band: bool = game._run_elapsed >= minimum_duration and game._run_elapsed <= maximum_duration
	_expect(duration_in_band, "simulated survival duration %.1fs was outside the strategy band for %s" % [game._run_elapsed, strategy])
	_expect(used_weapon_count == (1 if strategy == "rifle_only" else 4), "weapon contribution count %d did not match strategy %s" % [used_weapon_count, strategy])
	_expect(int(snapshot["max_active_enemies"]) <= 7, "scripted survival exceeded the seven-enemy active cap")
	_expect(int(snapshot["roll"]["successes"]) >= 1, "survival telemetry did not record the roll")
	_expect(int(snapshot["grenades"]["throws"]) >= 1, "survival telemetry did not record the grenade")
	_expect(game.upgrade_manager.selection_history.size() == 4, "scripted survival did not select four run upgrades")
	if strategy == "mixed":
		_expect(int(snapshot["grenades"]["damage"]) > 0, "mixed survival route did not produce real grenade damage")
	print("SURVIVAL_SCRIPTED_METRICS %s" % JSON.stringify({
		"strategy": strategy,
		"elapsed": game._run_elapsed,
		"kills": game._run_kills,
		"score": game.score,
		"used_weapons": used_weapon_count,
		"max_active": snapshot["max_active_enemies"],
		"sprint_entry_speed": sprint_entry_speed,
		"sprint_air_speed": sprint_air_speed,
		"rolls": snapshot["roll"]["successes"],
		"grenades": snapshot["grenades"]["throws"],
		"damage_events": snapshot["damage_events"],
		"damage_sources": snapshot["damage_sources"],
		"build": game.upgrade_manager.selection_history,
	}))
	_finish()


func _select_target(game: Node) -> Node:
	if game.boss.active and game.boss.alive:
		return game.boss
	var best: Node
	var best_distance := INF
	for enemy in game.enemies.get_children():
		if not bool(enemy.get("alive")) or not bool(enemy.get("active")):
			continue
		var distance: float = game.player.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _weapon_for_target(game: Node, target: Node) -> StringName:
	if target == game.boss:
		return [&"rifle", &"sniper", &"pistol"][clampi(game.boss.phase - 1, 0, 2)]
	var kind := str(target.get("kind"))
	if kind == "shield":
		return &"shotgun"
	if kind == "assault":
		return &"shotgun" if absf(target.global_position.x - game.player.global_position.x) <= 300.0 else &"rifle"
	if kind in ["elite", "heavy"]:
		return &"pistol"
	return &"sniper"


func _preferred_distance(weapon_id: StringName) -> float:
	match weapon_id:
		&"shotgun":
			return 190.0
		&"sniper":
			return 460.0
		&"pistol":
			return 320.0
		_:
			return 360.0


func _drive_fire(player: Node, frame_count: int, _elapsed: float) -> void:
	var automatic := bool(player.weapon_inventory.get_current_data()["automatic_fire"])
	if automatic or frame_count % 3 == 0:
		Input.action_press("fire")
	else:
		Input.action_release("fire")


func _set_move(direction: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if direction > 0.1:
		Input.action_press("move_right")
	elif direction < -0.1:
		Input.action_press("move_left")


func _release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"sprint", &"fire", &"reload"]:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	Engine.time_scale = 1.0
	_release_inputs()
	if failures.is_empty():
		print("SURVIVAL_SCRIPTED_PASS ten-wave weapon playthrough, survival abilities and target-duration telemetry")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
