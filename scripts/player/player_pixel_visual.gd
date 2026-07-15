extends Node2D
class_name PlayerPixelVisual

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


func configure_weapon(weapon_id: StringName, data: Dictionary) -> void:
	weapon_pivot.configure(weapon_id, data)


func set_aim_direction(aim_direction: Vector2, facing: int) -> void:
	facing_direction = 1 if facing >= 0 else -1
	weapon_pivot.set_aim(aim_direction, facing_direction)


func update_pose(delta: float, player_velocity: Vector2, grounded: bool, movement_intent: float, aim_direction: Vector2, landing_remaining: float) -> void:
	animation_phase += delta * (4.0 + absf(player_velocity.x) * 0.035)
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	weapon_pivot.update_animation(delta)
	set_aim_direction(aim_direction, facing_direction)

	if is_dead:
		death_elapsed += delta
		base_animation_state = &"death"
		animation_state = &"death"
		weapon_pivot.visible = false
	else:
		if landing_remaining > 0.0:
			base_animation_state = &"land"
		elif not grounded:
			base_animation_state = &"jump" if player_velocity.y < 0.0 else &"fall"
		elif absf(player_velocity.x) > 28.0 or absf(movement_intent) > 0.2:
			base_animation_state = &"run"
		else:
			base_animation_state = &"idle"
		if hurt_remaining > 0.0:
			animation_state = &"hurt"
		elif weapon_pivot.recoil_remaining > 0.0:
			animation_state = &"shoot"
		else:
			animation_state = base_animation_state
		weapon_pivot.visible = true

	var bob := _body_bob()
	body_sprite.position = Vector2.ZERO
	body_sprite.rotation = lerpf(0.0, -1.18 * facing_direction, clampf(death_elapsed / 0.42, 0.0, 1.0)) if is_dead else 0.0
	weapon_pivot.position = Vector2(2 * facing_direction, -11 + bob).round()
	var air_distance := clampf(absf(player_velocity.y) / 850.0, 0.0, 1.0)
	shadow.scale.x = lerpf(1.0, 0.72, air_distance)
	shadow.modulate.a = lerpf(0.34, 0.18, air_distance)
	body_sprite.set_pose(base_animation_state, animation_phase, facing_direction, hurt_remaining / 0.18, clampf(death_elapsed / 0.42, 0.0, 1.0))


func play_shot() -> void:
	if not is_dead:
		weapon_pivot.play_shot()


func play_hurt() -> void:
	if not is_dead:
		hurt_remaining = 0.18


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
	weapon_pivot.visible = true


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
		&"jump":
			return -1.0
		&"fall":
			return 1.0
		&"land":
			return 2.0
	return 0.0
