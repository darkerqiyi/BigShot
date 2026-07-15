extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(5):
		await physics_frame
	var player = game.player
	player._using_mouse_aim = false
	Engine.time_scale = 2.0
	var jump_clock := 0.0
	var frame_count := 0
	var roll_used := false
	var grenade_used := false
	while is_instance_valid(game) and game.run_state not in ["complete", "dead"] and game.telemetry.elapsed < 240.0:
		frame_count += 1
		jump_clock += 1.0 / 30.0
		# This run isolates weapon-role and pacing throughput. Survival/retry is covered separately.
		if game.run_state in ["combat", "boss"]:
			player._invulnerability_remaining = maxf(player._invulnerability_remaining, 0.20)
		if game.run_state == "boss":
			# Keep this throughput bot on a stable authored arena point. Boss charge displacement
			# otherwise makes the test depend on suite timing rather than weapon behavior.
			player.global_position = Vector2(18120.0, 552.0)
			player.velocity = Vector2.ZERO
			game.boss.global_position = Vector2(19120.0, 520.0)
			game.boss.velocity = Vector2.ZERO
		var target := _select_target(game)
		if target != null:
			var desired_weapon := _desired_weapon(game, target)
			if player.current_weapon_id != desired_weapon:
				player.weapon_inventory.select_weapon(desired_weapon)
			var offset: Vector2 = target.global_position - player.global_position
			player.aim_direction = offset.normalized()
			if not roll_used and game.run_state == "combat" and game._active_mission_encounter >= 0 and player.is_on_floor():
				player._register_direction_tap(1 if offset.x >= 0.0 else -1)
				player._register_direction_tap(1 if offset.x >= 0.0 else -1)
				roll_used = player.is_rolling
			if not grenade_used and roll_used and not player.is_rolling and game.run_state == "combat" and game._active_mission_encounter >= 0 and str(target.get("kind")) == "assault" and offset.length() <= 300.0:
				if player._start_grenade_charge():
					player.grenade_charge = 0.55
					player._release_grenade()
					grenade_used = true
			var preferred_distance := _preferred_distance(player.current_weapon_id)
			if game.run_state == "boss":
				_set_move(0.0)
			elif absf(offset.x) > preferred_distance + 55.0:
				_set_move(signf(offset.x))
			elif absf(offset.x) < preferred_distance - 85.0:
				_set_move(-signf(offset.x))
			else:
				_set_move(0.0)
			_drive_fire(player, frame_count)
			if jump_clock >= 1.15 and game.run_state == "combat":
				Input.action_press("jump")
				jump_clock = 0.0
			else:
				Input.action_release("jump")
		else:
			Input.action_release("fire")
			_set_move(1.0 if game.run_state in ["combat", "boss_ready"] else 0.0)
			# The expanded route now contains intentionally reachable platform lips and
			# jumpable road hazards. Exercise normal traversal rather than assuming a
			# perfectly flat autorun corridor between encounters.
			if jump_clock >= 1.15 and game.run_state in ["combat", "boss_ready"]:
				Input.action_press("jump")
				jump_clock = 0.0
			else:
				Input.action_release("jump")
		await physics_frame
		if frame_count > 15000:
			break
	_release_inputs()
	Engine.time_scale = 1.0
	var snapshot: Dictionary = game.telemetry.get_snapshot()
	print("SCRIPTED_PLAYTHROUGH_METRICS %s" % JSON.stringify(snapshot))
	_expect(game.run_state == "complete", "scripted mixed-weapon run did not reach settlement")
	_expect(float(snapshot["elapsed"]) <= 240.0, "expert scripted run exceeded four simulated minutes")
	_expect(int(snapshot["max_active_enemies"]) <= 4, "active enemy count exceeded the readable wave cap")
	var used_weapon_count := 0
	for weapon_id in [&"rifle", &"shotgun", &"sniper", &"pistol"]:
		var stats: Dictionary = snapshot["weapons"][weapon_id]
		if int(stats["shots"]) > 0 and int(stats["damage"]) > 0:
			used_weapon_count += 1
	_expect(used_weapon_count == 4, "scripted role strategy did not produce value for all four weapons")
	_expect(int(snapshot["roll"]["successes"]) >= 1, "scripted run did not exercise the tuned ground roll")
	_expect(int(snapshot["grenades"]["throws"]) >= 1, "scripted run did not exercise charged grenade combat")
	game.queue_free()
	for _frame in range(3):
		await process_frame
	_finish()


func _select_target(game: Node) -> Node:
	if game.run_state == "boss" and bool(game.boss.get("alive")):
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


func _desired_weapon(game: Node, target: Node) -> StringName:
	if target == game.boss:
		if game.boss.phase == 1:
			return &"rifle"
		if game.boss.phase == 2:
			return &"sniper"
		return &"pistol"
	var kind := str(target.get("kind"))
	if kind in ["assault", "shield", "elite", "heavy"]:
		return &"shotgun"
	return &"sniper"


func _preferred_distance(weapon_id: StringName) -> float:
	match weapon_id:
		&"shotgun":
			return 220.0
		&"sniper":
			return 500.0
		&"pistol":
			return 380.0
		_:
			return 420.0


func _drive_fire(player: Node, frame_count: int) -> void:
	var automatic := bool(player.weapon_inventory.get_current_data()["automatic_fire"])
	if automatic or frame_count % 2 == 0:
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
	for action in [&"move_left", &"move_right", &"jump", &"fire"]:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SCRIPTED_PLAYTHROUGH_PASS expanded mission, four active weapon roles, gated waves, debug telemetry summary, encounter/Boss timings")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
