extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(5):
		await physics_frame
	var player = game.player
	player.global_position = Vector2(900, 552)
	for _frame in range(3):
		await physics_frame
	var roll_start_x: float = player.global_position.x
	player._register_direction_tap(1)
	player._register_direction_tap(1)
	var roll_frames := 0
	while player.is_rolling and roll_frames < 90:
		roll_frames += 1
		await physics_frame
	var roll_distance: float = player.global_position.x - roll_start_x
	var cooldown_frames := 0
	while player.roll_cooldown_remaining > 0.0 and cooldown_frames < 90:
		cooldown_frames += 1
		await physics_frame
	var throw_distances: Array[float] = []
	for charge in [0.0, 0.5, 1.0]:
		player.aim_direction = Vector2(1.0, -0.35).normalized()
		player.grenade_charge = charge
		var velocity: Vector2 = player._calculate_grenade_velocity()
		var grenade = preload("res://scripts/combat/player_grenade.gd").new()
		game.grenades.add_child(grenade)
		grenade.configure(Vector2(900, 500), velocity)
		var max_x: float = grenade.global_position.x
		while is_instance_valid(grenade):
			max_x = maxf(max_x, grenade.global_position.x)
			await physics_frame
		throw_distances.append(snappedf(max_x - 900.0, 0.1))
	var metrics := {
		"roll_duration": snappedf(float(roll_frames) / 60.0, 0.001),
		"roll_distance": snappedf(roll_distance, 0.1),
		"roll_cooldown": snappedf(float(cooldown_frames) / 60.0, 0.001),
		"throw_distances": throw_distances,
	}
	print("PLAYER_ABILITIES_METRICS %s" % JSON.stringify(metrics))
	var valid := (
		float(metrics["roll_duration"]) >= 0.28 and float(metrics["roll_duration"]) <= 0.34
		and float(metrics["roll_distance"]) >= 90.0 and float(metrics["roll_distance"]) <= 120.0
		and float(metrics["roll_cooldown"]) >= 0.48 and float(metrics["roll_cooldown"]) <= 0.54
		and throw_distances.size() == 3
		and throw_distances[0] >= 180.0 and throw_distances[0] <= 280.0
		and throw_distances[1] > throw_distances[0] * 1.6
		and throw_distances[2] > throw_distances[1] * 1.5 and throw_distances[2] <= 780.0
	)
	game.queue_free()
	for _frame in range(3):
		await process_frame
	if valid:
		print("PLAYER_ABILITIES_MEASUREMENT_PASS bounded 3-body roll and distinct low/medium/high grenade arcs")
		quit(0)
	else:
		push_error("player ability measurements escaped acceptance bounds")
		quit(1)
