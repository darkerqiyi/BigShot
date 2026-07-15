extends Node2D
class_name PlayerPixelVisual

const Tuning := preload("res://scripts/config/game_tuning.gd")

@onready var shadow: Polygon2D = $Shadow
@onready var body_sprite = $BodySprite
@onready var weapon_pivot = $WeaponPivot

var animation_state: StringName = &"idle"
var base_animation_state: StringName = &"idle"
var facing_direction := 1
var animation_phase := 0.0
var hurt_remaining := 0.0
var death_elapsed := 0.0
var is_dead := false
var roll_progress := 0.0
var roll_direction := 1
var roll_ready_flash := 0.0
var grenade_charge_value := 0.0
var grenade_charging := false
var sprinting := false
var sprint_start_remaining := 0.0
var sprint_stop_remaining := 0.0
var exhausted_feedback_remaining := 0.0
var _was_sprinting := false


func configure_weapon(weapon_id: StringName, data: Dictionary) -> void:
	weapon_pivot.configure(weapon_id, data)


func set_aim_direction(aim_direction: Vector2, facing: int) -> void:
	facing_direction = 1 if facing >= 0 else -1
	weapon_pivot.set_aim(aim_direction, facing_direction)


func update_pose(delta: float, player_velocity: Vector2, grounded: bool, movement_intent: float, aim_direction: Vector2, landing_remaining: float, rolling: bool = false, current_roll_progress: float = 0.0, charging_grenade: bool = false, grenade_throw_remaining: float = 0.0, current_grenade_charge: float = 0.0, current_sprinting: bool = false) -> void:
	animation_phase += delta * (4.0 + absf(player_velocity.x) * 0.035)
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	exhausted_feedback_remaining = maxf(exhausted_feedback_remaining - delta, 0.0)
	if current_sprinting and not _was_sprinting:
		sprint_start_remaining = Tuning.PLAYER_SPRINT_START_TIME
		sprint_stop_remaining = 0.0
	elif not current_sprinting and _was_sprinting:
		sprint_stop_remaining = Tuning.PLAYER_SPRINT_STOP_TIME
	sprint_start_remaining = maxf(sprint_start_remaining - delta, 0.0)
	sprint_stop_remaining = maxf(sprint_stop_remaining - delta, 0.0)
	sprinting = current_sprinting
	_was_sprinting = current_sprinting
	weapon_pivot.update_animation(delta)
	set_aim_direction(aim_direction, facing_direction)
	roll_ready_flash = maxf(roll_ready_flash - delta, 0.0)
	roll_progress = current_roll_progress if rolling else 0.0
	roll_direction = facing_direction
	grenade_charging = charging_grenade
	grenade_charge_value = current_grenade_charge

	if is_dead:
		death_elapsed += delta
		base_animation_state = &"death"
		animation_state = &"death"
		weapon_pivot.visible = false
	elif rolling:
		base_animation_state = &"roll"
		animation_state = &"roll_start" if roll_progress < 0.18 else (&"roll_end" if roll_progress > 0.78 else &"roll")
		weapon_pivot.visible = false
	elif grenade_throw_remaining > 0.0:
		base_animation_state = &"grenade_throw"
		animation_state = &"grenade_throw"
		weapon_pivot.visible = false
	elif charging_grenade:
		base_animation_state = &"grenade_charge"
		animation_state = &"grenade_charge"
		weapon_pivot.visible = false
	else:
		if landing_remaining > 0.0:
			base_animation_state = &"land"
		elif not grounded:
			base_animation_state = &"jump" if player_velocity.y < 0.0 else &"fall"
		elif sprinting:
			base_animation_state = &"sprint_start" if sprint_start_remaining > 0.0 else &"sprint"
		elif sprint_stop_remaining > 0.0 and absf(player_velocity.x) > Tuning.PLAYER_MAX_SPEED and weapon_pivot.recoil_remaining <= 0.0:
			base_animation_state = &"sprint_stop"
		elif absf(player_velocity.x) > 28.0 or absf(movement_intent) > 0.2:
			base_animation_state = &"run"
		else:
			base_animation_state = &"idle"
		if hurt_remaining > 0.0:
			animation_state = &"hurt"
		elif weapon_pivot.recoil_remaining > 0.0:
			animation_state = &"shoot"
		elif base_animation_state == &"sprint":
			animation_state = &"sprint_loop"
		else:
			animation_state = base_animation_state
		weapon_pivot.visible = base_animation_state not in [&"sprint_start", &"sprint", &"sprint_stop"] or animation_state in [&"hurt", &"shoot"]

	var bob := _body_bob()
	body_sprite.position = Vector2(0, 9) if rolling else Vector2.ZERO
	body_sprite.rotation = roll_progress * TAU * float(roll_direction) if rolling else (lerpf(0.0, -1.18 * facing_direction, clampf(death_elapsed / 0.42, 0.0, 1.0)) if is_dead else 0.0)
	weapon_pivot.position = Vector2(2 * facing_direction, -11 + bob).round()
	var air_distance := clampf(absf(player_velocity.y) / 850.0, 0.0, 1.0)
	shadow.scale.x = lerpf(1.0, 0.72, air_distance)
	shadow.modulate.a = lerpf(0.34, 0.18, air_distance)
	body_sprite.set_pose(base_animation_state, animation_phase, facing_direction, hurt_remaining / 0.18, clampf(death_elapsed / 0.42, 0.0, 1.0))
	body_sprite.modulate = Color(1.0, 0.68, 0.58, 1.0) if exhausted_feedback_remaining > 0.0 and int(exhausted_feedback_remaining * 22.0) % 2 == 0 else Color.WHITE
	queue_redraw()


func play_shot() -> void:
	if not is_dead:
		weapon_pivot.play_shot()


func play_hurt() -> void:
	if not is_dead:
		hurt_remaining = 0.18


func play_exhausted() -> void:
	if not is_dead:
		exhausted_feedback_remaining = Tuning.PLAYER_EXHAUSTED_FEEDBACK_TIME


func play_death(facing: int) -> void:
	is_dead = true
	facing_direction = 1 if facing >= 0 else -1
	death_elapsed = 0.0
	animation_state = &"death"


func reset_visual() -> void:
	is_dead = false
	death_elapsed = 0.0
	hurt_remaining = 0.0
	animation_state = &"idle"
	base_animation_state = &"idle"
	roll_progress = 0.0
	grenade_charging = false
	grenade_charge_value = 0.0
	sprinting = false
	_was_sprinting = false
	sprint_start_remaining = 0.0
	sprint_stop_remaining = 0.0
	exhausted_feedback_remaining = 0.0
	weapon_pivot.visible = true
	body_sprite.position = Vector2.ZERO
	body_sprite.rotation = 0.0
	body_sprite.modulate = Color.WHITE
	queue_redraw()


func play_roll_ready() -> void:
	roll_ready_flash = 0.12
	queue_redraw()


func get_muzzle_global_position() -> Vector2:
	return weapon_pivot.get_muzzle_global_position()


func get_muzzle_point() -> Marker2D:
	return weapon_pivot.muzzle_point


func _body_bob() -> float:
	match base_animation_state:
		&"idle":
			return 1.0 if sin(animation_phase * 1.25) > 0.65 else 0.0
		&"run":
			return round(absf(sin(animation_phase * 1.7)))
		&"sprint_start", &"sprint", &"sprint_stop":
			return round(absf(sin(animation_phase * 2.35)))
		&"jump":
			return -1.0
		&"fall":
			return 1.0
		&"land":
			return 2.0
	return 0.0


func _draw() -> void:
	if sprinting:
		var behind := -1.0 if facing_direction > 0 else 1.0
		var drift := fposmod(animation_phase * 5.0, 10.0)
		for index in range(3):
			var x := behind * (20.0 + index * 9.0 + drift)
			draw_rect(Rect2(x - (5.0 if behind < 0.0 else 0.0), 25.0 + index * 2.0, 5.0, 3.0), Color(0.52, 0.91, 1.0, 0.52 - index * 0.12), true)
	if roll_progress > 0.0:
		var behind := -1.0 if roll_direction > 0 else 1.0
		for index in range(3):
			var width := 18.0 - index * 4.0
			draw_rect(Rect2(behind * (30.0 + index * 12.0) - (width if behind < 0 else 0.0), 8.0 + index * 6.0, width, 4.0), Color(0.52, 0.91, 1.0, 0.55 - index * 0.12), true)
		draw_rect(Rect2(-18, 28, 36, 4), Color(1.0, 0.83, 0.35, 0.55), true)
	if roll_ready_flash > 0.0:
		draw_rect(Rect2(-19, -36, 38, 4), Color(0.52, 1.0, 0.72, roll_ready_flash / 0.12), true)
	if grenade_charging:
		var grenade_x := 18.0 * float(facing_direction)
		draw_rect(Rect2(grenade_x - 7, -28, 14, 14), Color("10243a"), true)
		draw_rect(Rect2(grenade_x - 4, -25, 8, 8), Color("f49a36").lerp(Color("ffd35a"), grenade_charge_value), true)
