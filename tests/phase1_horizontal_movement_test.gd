extends SceneTree

const HorizontalMotion := preload("res://scripts/player/player_horizontal_motion.gd")
const PHYSICS_DELTA := 1.0 / 60.0

var failures: Array[String] = []
var measured_acceleration_time := 0.0
var measured_stop_time := 0.0
var measured_reverse_zero_time := 0.0
var measured_reverse_ninety_time := 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_motion_model()
	_test_input_contract()
	await _test_scene_integration()

	if failures.is_empty():
		print("PHASE1_HORIZONTAL_PASS accel=%.3fs stop=%.3fs reverse_zero=%.3fs reverse_90=%.3fs max=%.0fpx/s" % [
			measured_acceleration_time,
			measured_stop_time,
			measured_reverse_zero_time,
			measured_reverse_ninety_time,
			HorizontalMotion.MAX_SPEED,
		])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_motion_model() -> void:
	var velocity := 0.0
	var acceleration_time := 0.0
	while velocity < HorizontalMotion.MAX_SPEED and acceleration_time < 1.0:
		velocity = HorizontalMotion.advance_velocity(velocity, 1.0, PHYSICS_DELTA)
		acceleration_time += PHYSICS_DELTA
	measured_acceleration_time = acceleration_time
	_expect(acceleration_time <= 0.18, "acceleration exceeded 0.18s: %.3f" % acceleration_time)
	_expect(is_equal_approx(velocity, 260.0), "max speed was %.2f instead of 260" % velocity)

	var stop_time := 0.0
	while absf(velocity) > 5.0 and stop_time < 1.0:
		velocity = HorizontalMotion.advance_velocity(velocity, 0.0, PHYSICS_DELTA)
		stop_time += PHYSICS_DELTA
	measured_stop_time = stop_time
	_expect(stop_time <= 0.14, "deceleration exceeded 0.14s: %.3f" % stop_time)

	velocity = HorizontalMotion.MAX_SPEED
	var reverse_time := 0.0
	var zero_cross_time := -1.0
	var opposite_ninety_time := -1.0
	while reverse_time < 0.3:
		velocity = HorizontalMotion.advance_velocity(velocity, -1.0, PHYSICS_DELTA)
		reverse_time += PHYSICS_DELTA
		if zero_cross_time < 0.0 and velocity <= 0.0:
			zero_cross_time = reverse_time
		if velocity <= -HorizontalMotion.MAX_SPEED * 0.9:
			opposite_ninety_time = reverse_time
			break
	_expect(zero_cross_time > 0.0 and zero_cross_time <= 0.12, "reverse zero-cross was %.3fs" % zero_cross_time)
	_expect(opposite_ninety_time > 0.0 and opposite_ninety_time <= 0.3, "reverse 90%% was %.3fs" % opposite_ninety_time)
	measured_reverse_zero_time = zero_cross_time
	measured_reverse_ninety_time = opposite_ninety_time

	velocity = 0.0
	for _tick in range(60):
		velocity = HorizontalMotion.advance_velocity(velocity, 2.0, PHYSICS_DELTA)
	_expect(is_equal_approx(velocity, HorizontalMotion.MAX_SPEED), "axis clamping failed: %.2f" % velocity)

	velocity = 0.0
	var air_acceleration_time := 0.0
	while velocity < HorizontalMotion.MAX_SPEED and air_acceleration_time < 1.0:
		velocity = HorizontalMotion.advance_air_velocity(velocity, 1.0, PHYSICS_DELTA)
		air_acceleration_time += PHYSICS_DELTA
	_expect(air_acceleration_time > measured_acceleration_time and air_acceleration_time <= 0.27, "air acceleration should be slower but responsive: %.3fs" % air_acceleration_time)


func _test_input_contract() -> void:
	_expect(Engine.physics_ticks_per_second == 60, "physics tick rate must be 60 Hz")
	_expect(is_equal_approx(InputMap.action_get_deadzone("move_left"), 0.25), "move_left deadzone must be 0.25")
	_expect(is_equal_approx(InputMap.action_get_deadzone("move_right"), 0.25), "move_right deadzone must be 0.25")
	Input.action_press("move_left")
	Input.action_press("move_right")
	_expect(is_zero_approx(Input.get_axis("move_left", "move_right")), "opposite inputs must resolve to zero")
	Input.action_release("move_left")
	Input.action_release("move_right")


func _test_scene_integration() -> void:
	var packed_scene := load("res://scenes/main/main.tscn") as PackedScene
	_expect(packed_scene != null, "main scene could not be loaded")
	if packed_scene == null:
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	await physics_frame

	var player := scene.get_node_or_null("World/Player") as CharacterBody2D
	_expect(player != null, "World/Player is missing or is not CharacterBody2D")
	if player == null:
		scene.queue_free()
		return
	_expect(player.is_on_floor(), "player did not settle on gray-box floor")

	var start_x := player.position.x
	Input.action_press("move_right")
	for _tick in range(10):
		await physics_frame
	Input.action_release("move_right")
	_expect(player.position.x > start_x + 15.0, "player did not visibly move right")
	_expect(player.velocity.x >= 255.0 and player.velocity.x <= 265.0, "integrated speed was %.2f" % player.velocity.x)

	await process_frame
	var readout := scene.get_node_or_null("DebugOverlay/Panel/Margin/Rows/Readout") as Label
	_expect(readout != null and readout.text.contains("Velocity:"), "debug overlay lacks velocity telemetry")
	_expect(readout != null and readout.text.contains("Grounded: yes"), "debug overlay lacks grounded telemetry")
	scene.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
