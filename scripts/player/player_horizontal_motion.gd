extends RefCounted
class_name PlayerHorizontalMotion

const Tuning := preload("res://scripts/config/game_tuning.gd")
const MAX_SPEED := Tuning.PLAYER_MAX_SPEED
const ACCELERATION := Tuning.PLAYER_GROUND_ACCELERATION
const DECELERATION := Tuning.PLAYER_GROUND_DECELERATION
const TURN_ACCELERATION := Tuning.PLAYER_GROUND_TURN_ACCELERATION
const SPRINT_MAX_SPEED := Tuning.PLAYER_SPRINT_SPEED


static func advance_velocity(current_velocity: float, input_axis: float, delta: float) -> float:
	return _advance(current_velocity, input_axis, delta, MAX_SPEED, ACCELERATION, DECELERATION, TURN_ACCELERATION)


static func advance_sprint_velocity(current_velocity: float, input_axis: float, delta: float) -> float:
	return _advance(
		current_velocity,
		input_axis,
		delta,
		SPRINT_MAX_SPEED,
		Tuning.PLAYER_SPRINT_ACCELERATION,
		Tuning.PLAYER_SPRINT_DECELERATION,
		Tuning.PLAYER_SPRINT_ACCELERATION,
	)


static func advance_after_sprint_velocity(current_velocity: float, input_axis: float, delta: float) -> float:
	return _advance(
		current_velocity,
		input_axis,
		delta,
		MAX_SPEED,
		Tuning.PLAYER_SPRINT_LAND_DECELERATION,
		Tuning.PLAYER_SPRINT_LAND_DECELERATION,
		Tuning.PLAYER_SPRINT_ACCELERATION,
	)


static func advance_air_velocity(current_velocity: float, input_axis: float, delta: float) -> float:
	return _advance(
		current_velocity,
		input_axis,
		delta,
		MAX_SPEED,
		Tuning.PLAYER_AIR_ACCELERATION,
		Tuning.PLAYER_NORMAL_JUMP_AIR_DRAG,
		Tuning.PLAYER_AIR_TURN_ACCELERATION,
	)


static func advance_airborne_velocity(current_velocity: float, input_axis: float, delta: float, speed_cap: float, sprint_launch: bool) -> float:
	if not sprint_launch:
		return advance_air_velocity(current_velocity, input_axis, delta)
	var clamped_axis := clampf(input_axis, -1.0, 1.0)
	if is_zero_approx(clamped_axis):
		return move_toward(current_velocity, 0.0, Tuning.PLAYER_SPRINT_JUMP_AIR_DRAG * delta)
	var cap := clampf(absf(speed_cap), MAX_SPEED, Tuning.PLAYER_SPRINT_JUMP_SPEED_CAP)
	var rate := Tuning.PLAYER_SPRINT_JUMP_AIR_ACCELERATION
	if current_velocity * clamped_axis < 0.0:
		rate = Tuning.PLAYER_SPRINT_JUMP_AIR_REVERSE_ACCELERATION
	return move_toward(current_velocity, clamped_axis * cap, rate * delta)


static func _advance(current_velocity: float, input_axis: float, delta: float, max_speed: float, acceleration: float, deceleration: float, turn_acceleration: float) -> float:
	var clamped_axis := clampf(input_axis, -1.0, 1.0)
	var target_velocity := clamped_axis * max_speed
	var rate := acceleration
	if is_zero_approx(clamped_axis):
		rate = deceleration
	elif current_velocity * clamped_axis < 0.0:
		rate = turn_acceleration
	return move_toward(current_velocity, target_velocity, rate * delta)
