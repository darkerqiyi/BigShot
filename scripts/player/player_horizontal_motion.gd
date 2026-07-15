extends RefCounted
class_name PlayerHorizontalMotion

const Tuning := preload("res://scripts/config/game_tuning.gd")
const MAX_SPEED := Tuning.PLAYER_MAX_SPEED
const ACCELERATION := Tuning.PLAYER_GROUND_ACCELERATION
const DECELERATION := Tuning.PLAYER_GROUND_DECELERATION
const TURN_ACCELERATION := Tuning.PLAYER_GROUND_TURN_ACCELERATION


static func advance_velocity(current_velocity: float, input_axis: float, delta: float) -> float:
	return _advance(current_velocity, input_axis, delta, ACCELERATION, DECELERATION, TURN_ACCELERATION)


static func advance_air_velocity(current_velocity: float, input_axis: float, delta: float) -> float:
	return _advance(
		current_velocity,
		input_axis,
		delta,
		Tuning.PLAYER_AIR_ACCELERATION,
		Tuning.PLAYER_AIR_DECELERATION,
		Tuning.PLAYER_AIR_TURN_ACCELERATION,
	)


static func _advance(current_velocity: float, input_axis: float, delta: float, acceleration: float, deceleration: float, turn_acceleration: float) -> float:
	var clamped_axis := clampf(input_axis, -1.0, 1.0)
	var target_velocity := clamped_axis * MAX_SPEED
	var rate := acceleration
	if is_zero_approx(clamped_axis):
		rate = deceleration
	elif current_velocity * clamped_axis < 0.0:
		rate = turn_acceleration
	return move_toward(current_velocity, target_velocity, rate * delta)
