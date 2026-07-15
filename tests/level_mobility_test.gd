extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var platform_game := await _create_game()
	await _test_platform_jump(platform_game)
	platform_game.queue_free()
	await process_frame
	for hazard_index in range(3):
		var hazard_game := await _create_game()
		await _test_hazard_jump(hazard_game, hazard_index)
		hazard_game.queue_free()
		await process_frame
	_finish()


func _create_game() -> Node:
	var game := MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(5):
		await physics_frame
	return game


func _test_platform_jump(game: Node) -> void:
	var player = game.player
	player.global_position = Vector2(1300, 552)
	Input.action_press("move_right")
	for _frame in range(22):
		await physics_frame
	player.request_jump()
	var landed_above_ground := false
	for _frame in range(65):
		await physics_frame
		if player.is_on_floor() and player.global_position.y < 500.0:
			landed_above_ground = true
			break
	Input.action_release("move_right")
	_expect(landed_above_ground and player.global_position.y <= 465.0, "player could not reach and land on the corrected elevated platform")


func _test_hazard_jump(game: Node, hazard_index: int) -> void:
	var hazards := game.get_tree().get_nodes_in_group("mission_hazards")
	var hazard: Node2D = hazards[hazard_index]
	var player = game.player
	player.global_position = Vector2(hazard.global_position.x - float(hazard.strip_width) * 0.5 - 120.0, 552.0)
	Input.action_press("move_right")
	for _frame in range(18):
		await physics_frame
	var health_before: int = player.health
	player.request_jump()
	for _frame in range(48):
		await physics_frame
	Input.action_release("move_right")
	var cleared_x := hazard.global_position.x + float(hazard.strip_width) * 0.5 + 20.0
	_expect(player.global_position.x >= cleared_x, "player did not travel beyond hazard strip %d during a normal running jump" % (hazard_index + 1))
	_expect(player.health == health_before, "hazard strip %d still forces unavoidable damage" % (hazard_index + 1))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	Input.action_release("move_right")
	if failures.is_empty():
		print("LEVEL_MOBILITY_PASS 10-second opening contract, reachable elevated platform, three normally jumpable road hazards")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
