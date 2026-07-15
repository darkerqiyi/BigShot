extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const CameraRig := preload("res://scripts/camera/camera_rig.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var right_game := await _create_game()
	await _test_sprint_jump_trace(right_game.player, 1)
	right_game.queue_free()
	await process_frame
	var left_game := await _create_game()
	await _test_sprint_jump_trace(left_game.player, -1)
	left_game.queue_free()
	await process_frame
	var control_game := await _create_game()
	await _test_air_control_and_stamina(control_game.player)
	control_game.queue_free()
	await process_frame
	var ledge_game := await _create_game()
	await _test_sprint_off_platform(ledge_game.player)
	ledge_game.queue_free()
	await process_frame
	var landing_game := await _create_game()
	await _test_landing_blend_and_actions(landing_game.player)
	landing_game.queue_free()
	await process_frame
	var gate_game := await _create_game()
	await _test_closed_gate_collision(gate_game)
	gate_game.queue_free()
	await process_frame
	var resume_game := await _create_game()
	await _test_landing_sprint_intent_and_exhaustion(resume_game.player)
	resume_game.queue_free()
	await process_frame
	_release_actions()
	if failures.is_empty():
		print("SPRINT_JUMP_MOMENTUM_PASS true launch speed, ten-frame preservation, drag/reverse control, ledge inheritance, landing intent/exhaustion blend, action momentum, camera contract and gate collision")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _create_game() -> Node:
	_release_actions()
	var game := MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	for _frame in range(5):
		await physics_frame
	return game


func _test_sprint_jump_trace(player: Node, direction: int) -> void:
	player.global_position.x = 1100.0
	player.velocity = Vector2.ZERO
	for _frame in range(3):
		await physics_frame
	var move_action := &"move_right" if direction > 0 else &"move_left"
	Input.action_press(move_action)
	Input.action_press("sprint")
	for _frame in range(24):
		await physics_frame
	var pre_jump: Vector2 = player.velocity
	var jump_frame: Vector2 = await _jump_and_wait_for_takeoff(player)
	var airborne_frames: Array[Dictionary] = []
	for index in range(10):
		await physics_frame
		airborne_frames.append({
			"frame": index + 1,
			"vx": snappedf(player.velocity.x, 0.1),
			"vy": snappedf(player.velocity.y, 0.1),
			"state": str(player.visual.base_animation_state),
			"input": snappedf(player.movement_intent, 0.1),
			"sprinting": player.is_sprinting,
			"grounded": player.is_on_floor(),
		})
	print("SPRINT_JUMP_TRACE dir=%d pre=(%.1f,%.1f) launch=(%.1f,%.1f) air=%s" % [direction, pre_jump.x, pre_jump.y, jump_frame.x, jump_frame.y, JSON.stringify(airborne_frames)])
	_expect(absf(pre_jump.x) >= Tuning.PLAYER_SPRINT_SPEED - 1.0, "sprint did not reach authored speed before jump")
	_expect(signf(jump_frame.x) == float(direction), "sprint jump lost its horizontal direction")
	_expect(absf(jump_frame.x) >= absf(pre_jump.x) - 1.0, "jump frame did not inherit true current sprint speed")
	_expect(absf(float(airborne_frames[0]["vx"])) >= absf(jump_frame.x) * 0.97, "first airborne frame dropped sprint momentum")
	_expect(absf(float(airborne_frames[9]["vx"])) >= absf(jump_frame.x) * 0.94, "same-direction input pulled sprint jump back to normal speed")
	_expect(player.launched_from_sprint and player.airborne_speed_cap >= absf(jump_frame.x) - 0.1, "airborne sprint metadata does not reflect physical launch speed")
	_expect(player.visual.base_animation_state in [&"sprint_jump", &"sprint_fall"], "sprint jump has no distinct airborne silhouette")
	_release_actions()


func _test_air_control_and_stamina(player: Node) -> void:
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(24):
		await physics_frame
	var launch_velocity: Vector2 = await _jump_and_wait_for_takeoff(player)
	var launch_speed: float = launch_velocity.x
	var airborne_stamina: float = player.current_stamina
	Input.action_release("move_right")
	Input.action_release("sprint")
	for _frame in range(10):
		await physics_frame
	var released_speed: float = player.velocity.x
	_expect(released_speed < launch_speed and released_speed > launch_speed - 55.0, "sprint-jump air drag is abrupt or absent")
	_expect(player.current_stamina >= airborne_stamina, "airborne sprint momentum continued consuming stamina")
	Input.action_press("move_left")
	for _frame in range(10):
		await physics_frame
	var reversed_speed: float = player.velocity.x
	print("SPRINT_JUMP_CONTROL launch=%.1f release_10f=%.1f reverse_10f=%.1f stamina_air_start=%.1f stamina_air_end=%.1f" % [launch_speed, released_speed, reversed_speed, airborne_stamina, player.current_stamina])
	_expect(player.velocity.x > 0.0, "reverse air input flipped sprint momentum too quickly")
	_release_actions()
	while not player.is_on_floor():
		await physics_frame
	for _frame in range(12):
		await physics_frame
	Input.action_press("move_right")
	for _frame in range(20):
		await physics_frame
	var normal_launch_velocity: Vector2 = await _jump_and_wait_for_takeoff(player)
	var normal_launch: float = absf(normal_launch_velocity.x)
	Input.action_press("sprint")
	for _frame in range(8):
		await physics_frame
	_expect(normal_launch <= Tuning.PLAYER_MAX_SPEED + 0.1 and absf(player.velocity.x) <= Tuning.PLAYER_MAX_SPEED + 0.1, "airborne Shift accelerated a normal jump to sprint speed")
	_expect(not player.launched_from_sprint, "normal jump was mislabeled as sprint launch")
	_release_actions()


func _test_sprint_off_platform(player: Node) -> void:
	player.global_position = Vector2(1490.0, 464.0)
	player.velocity = Vector2.ZERO
	for _frame in range(5):
		await physics_frame
	Input.action_press("move_right")
	Input.action_press("sprint")
	var last_grounded_speed := 0.0
	var left_platform := false
	for _frame in range(90):
		await physics_frame
		if player.is_on_floor():
			last_grounded_speed = absf(player.velocity.x)
		elif player.launched_from_sprint:
			left_platform = true
			break
	_expect(left_platform, "running off a platform did not initialize sprint airborne state")
	_expect(last_grounded_speed > Tuning.PLAYER_MAX_SPEED + 20.0, "platform exit did not occur at sprint speed")
	_expect(absf(player.velocity.x) >= last_grounded_speed - 1.0, "running off a platform dropped sprint momentum")
	_expect(player.velocity.y >= 0.0, "running off a platform incorrectly applied jump vertical velocity")
	print("SPRINT_LEDGE_TRACE grounded=%.1f airborne=%.1f vertical=%.1f" % [last_grounded_speed, player.velocity.x, player.velocity.y])
	_release_actions()


func _test_landing_blend_and_actions(player: Node) -> void:
	player.global_position = Vector2(1100.0, 552.0)
	player.velocity = Vector2.ZERO
	for _frame in range(4):
		await physics_frame
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(24):
		await physics_frame
	var launch_velocity: Vector2 = await _jump_and_wait_for_takeoff(player)
	Input.action_press("fire")
	for _frame in range(2):
		await physics_frame
	_expect(player.velocity.x >= launch_velocity.x - 1.0, "airborne fire cleared sprint-jump physical momentum")
	_expect(not player.sprint_air_visual, "airborne fire did not return to the ordinary armed-air visual")
	Input.action_release("fire")
	Input.action_press("throw_grenade")
	for _frame in range(2):
		await physics_frame
	_expect(player.grenade_charging and player.velocity.x >= launch_velocity.x - 1.0, "airborne grenade charge cleared horizontal momentum")
	_expect(not player._try_start_roll(1), "ground roll started while airborne")
	Input.action_release("throw_grenade")
	Input.action_release("sprint")
	player._cancel_grenade_charge()
	var landing_speed := 0.0
	for _frame in range(120):
		await physics_frame
		if player.is_on_floor():
			landing_speed = absf(player.velocity.x)
			break
	_expect(landing_speed > Tuning.PLAYER_MAX_SPEED + 10.0, "sprint jump lost all landing momentum before ground contact")
	await physics_frame
	var first_ground_speed: float = absf(player.velocity.x)
	_expect(first_ground_speed < landing_speed and first_ground_speed > Tuning.PLAYER_MAX_SPEED, "landing without Shift did not begin a smooth speed blend")
	for _frame in range(12):
		await physics_frame
	print("SPRINT_LAND_TRACE contact=%.1f first_ground=%.1f settled=%.1f" % [landing_speed, first_ground_speed, absf(player.velocity.x)])
	_expect(absf(player.velocity.x) <= Tuning.PLAYER_MAX_SPEED + 0.1, "landing speed did not settle to the normal cap within the authored blend window")
	_expect(not player.launched_from_sprint and player.sprint_land_remaining <= Tuning.PLAYER_SPRINT_LAND_VISUAL_TIME, "landing left stale sprint-air metadata")
	var normal_camera := absf(CameraRig.calculate_desired_look_ahead(Tuning.PLAYER_MAX_SPEED, 0.0, 0.0, false))
	var sprint_air_camera := absf(CameraRig.calculate_desired_look_ahead(Tuning.PLAYER_SPRINT_SPEED, 0.0, 0.0, true))
	_expect(sprint_air_camera > normal_camera, "camera does not reserve extra forward view for sprint-air speed")
	_release_actions()


func _test_closed_gate_collision(game: Node) -> void:
	var player = game.player
	game._start_mission_encounter(0)
	player.global_position = Vector2(5000.0, 552.0)
	player.velocity = Vector2.ZERO
	for _frame in range(4):
		await physics_frame
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(18):
		await physics_frame
	await _jump_and_wait_for_takeoff(player)
	for _frame in range(45):
		await physics_frame
	_expect(player.global_position.x <= 5169.1, "sprint jump crossed a closed encounter gate")
	_release_actions()


func _test_landing_sprint_intent_and_exhaustion(player: Node) -> void:
	player.global_position = Vector2(1100.0, 552.0)
	player.velocity = Vector2.ZERO
	for _frame in range(4):
		await physics_frame
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(24):
		await physics_frame
	await _jump_and_wait_for_takeoff(player)
	for _frame in range(120):
		await physics_frame
		if player.is_on_floor():
			break
	await physics_frame
	_expect(player.is_sprinting and player.velocity.x > Tuning.PLAYER_MAX_SPEED, "held Shift and direction did not smoothly resume sprint after landing")
	await _jump_and_wait_for_takeoff(player)
	player.current_stamina = 0.0
	player.exhausted = true
	for _frame in range(120):
		await physics_frame
		if player.is_on_floor():
			break
	await physics_frame
	_expect(not player.is_sprinting and player.sprint_block_reason == &"exhausted", "exhausted landing incorrectly resumed sprint")
	for _frame in range(12):
		await physics_frame
	_expect(absf(player.velocity.x) <= Tuning.PLAYER_MAX_SPEED + 0.1, "exhausted landing did not blend back to normal speed")
	_release_actions()


func _jump_and_wait_for_takeoff(player: Node) -> Vector2:
	Input.action_press("jump")
	for _frame in range(4):
		await physics_frame
		if not player.is_on_floor() and player.velocity.y < 0.0:
			Input.action_release("jump")
			return player.velocity
	Input.action_release("jump")
	_expect(false, "jump did not leave the ground within four physics frames")
	return player.velocity


func _release_actions() -> void:
	for action in [&"move_left", &"move_right", &"sprint", &"jump", &"fire", &"throw_grenade"]:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
