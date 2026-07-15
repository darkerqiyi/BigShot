extends CharacterBody2D

signal volley_requested(origin: Vector2, directions: Array[Vector2], team: StringName, weapon_data: Dictionary, damage: int)
signal health_changed(current: int, maximum: int)
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal weapon_changed(weapon_id: StringName, weapon_data: Dictionary)
signal reload_started
signal reload_stage(stage: StringName, weapon_id: StringName)
signal magazine_empty(weapon_id: StringName)
signal hurt(amount: int)
signal damage_received(amount: int, context: Dictionary)
signal landed(position: Vector2, intensity: float)
signal jumped(position: Vector2)
signal footstep(position: Vector2, intensity: float, side: int)
signal low_health
signal died

const HorizontalMotion := preload("res://scripts/player/player_horizontal_motion.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")
const GRAVITY := Tuning.PLAYER_GRAVITY
const MAX_FALL_SPEED := Tuning.PLAYER_MAX_FALL_SPEED
const JUMP_SPEED := Tuning.PLAYER_JUMP_SPEED
const JUMP_CUT_SPEED := Tuning.PLAYER_JUMP_CUT_SPEED
const JUMP_BUFFER_TIME := Tuning.PLAYER_JUMP_BUFFER
const COYOTE_TIME := Tuning.PLAYER_COYOTE_TIME
const FIRE_INTERVAL := Tuning.WEAPON_FIRE_INTERVAL
const MAGAZINE_SIZE := Tuning.WEAPON_MAGAZINE_SIZE
const RELOAD_TIME := Tuning.WEAPON_RELOAD_TIME
const MAX_HEALTH := Tuning.PLAYER_MAX_HEALTH

@onready var visual = $PlayerVisual
@onready var muzzle_flash: Node2D = $PlayerVisual/WeaponPivot/MuzzleFlash
@onready var weapon = $PlayerVisual/WeaponPivot
@onready var weapon_inventory: Node = $WeaponInventory

var movement_intent := 0.0
var facing_direction := 1
var aim_direction := Vector2.RIGHT
var health := MAX_HEALTH
var alive := true
var controls_enabled := true
var jump_buffer_remaining := 0.0
var coyote_remaining := 0.0
var _invulnerability_remaining := 0.0
var _using_mouse_aim := true
var _run_time := 0.0
var _landing_feedback_remaining := 0.0
var _landing_intensity := 0.0
var _jump_stretch_remaining := 0.0
var _rifle_bloom := 0.0
var _last_pattern_degrees: Array[float] = []
var weapon_camera_aim_bonus := 0.0
var _footstep_distance := 0.0
var _footstep_side := 0
var _low_health_announced := false
var last_damage_source := "unknown"

var ammo: int:
	get:
		return weapon_inventory.get_ammo() if weapon_inventory != null else MAGAZINE_SIZE

var current_weapon_id: StringName:
	get:
		return weapon_inventory.current_weapon_id if weapon_inventory != null else &"rifle"


func _ready() -> void:
	weapon_inventory.weapon_changed.connect(_on_weapon_changed)
	weapon_inventory.ammo_changed.connect(func(current: int, maximum: int, reloading: bool) -> void:
		ammo_changed.emit(current, maximum, reloading)
	)
	weapon_inventory.reload_started.connect(func() -> void:
		reload_started.emit()
	)
	weapon_inventory.reload_stage.connect(func(stage: StringName, weapon_id: StringName) -> void:
		reload_stage.emit(stage, weapon_id)
	)
	health_changed.emit(health, MAX_HEALTH)
	_on_weapon_changed(weapon_inventory.current_weapon_id, weapon_inventory.get_current_data())
	visual.reset_visual()
	visual.set_aim_direction(aim_direction, facing_direction)
	ammo_changed.emit(ammo, int(weapon_inventory.get_current_data()["magazine_size"]), false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_mouse_aim = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		_using_mouse_aim = false


func _physics_process(delta: float) -> void:
	var grounded_before_move := is_on_floor()
	weapon_inventory.tick(delta)
	_invulnerability_remaining = maxf(_invulnerability_remaining - delta, 0.0)
	jump_buffer_remaining = maxf(jump_buffer_remaining - delta, 0.0)
	coyote_remaining = COYOTE_TIME if is_on_floor() else maxf(coyote_remaining - delta, 0.0)

	if not alive:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		move_and_slide()
		_animate_visual(delta)
		return

	_update_aim()
	if controls_enabled:
		movement_intent = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			request_jump()
	else:
		movement_intent = 0.0

	velocity.x = HorizontalMotion.advance_velocity(velocity.x, movement_intent, delta) if grounded_before_move else HorizontalMotion.advance_air_velocity(velocity.x, movement_intent, delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0

	if jump_buffer_remaining > 0.0 and coyote_remaining > 0.0:
		velocity.y = -JUMP_SPEED
		_jump_stretch_remaining = 0.10
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0
		jumped.emit(global_position + Vector2(0, 30))
	if controls_enabled and Input.is_action_just_released("jump") and velocity.y < -JUMP_CUT_SPEED:
		velocity.y = -JUMP_CUT_SPEED

	if not is_zero_approx(aim_direction.x):
		facing_direction = 1 if aim_direction.x > 0.0 else -1
	elif not is_zero_approx(movement_intent):
		facing_direction = 1 if movement_intent > 0.0 else -1
	visual.set_aim_direction(aim_direction, facing_direction)

	_handle_weapon(delta)
	var fall_speed_before_move := velocity.y
	var x_before_move := global_position.x
	move_and_slide()
	_update_footsteps(absf(global_position.x - x_before_move))
	if not grounded_before_move and is_on_floor() and fall_speed_before_move >= Tuning.PLAYER_LANDING_MIN_SPEED:
		_on_landed(fall_speed_before_move)
	_animate_visual(delta)


func request_jump() -> void:
	if alive and controls_enabled:
		jump_buffer_remaining = JUMP_BUFFER_TIME


func _update_aim() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_stick_up", "aim_stick_down")
	if stick.length() > 0.25:
		aim_direction = stick.normalized()
		_using_mouse_aim = false
	elif _using_mouse_aim:
		var mouse_delta := get_global_mouse_position() - global_position
		if mouse_delta.length() > 8.0:
			aim_direction = mouse_delta.normalized()
	elif not is_zero_approx(movement_intent):
		aim_direction = Vector2(signf(movement_intent), 0.0)


func _handle_weapon(delta: float) -> void:
	_rifle_bloom = maxf(_rifle_bloom - 5.0 * delta, 0.0)
	_handle_weapon_selection()
	if weapon_inventory.is_reloading():
		return
	if controls_enabled and Input.is_action_just_pressed("reload"):
		_start_reload()
		return
	if not controls_enabled:
		return
	var trigger_pressed := Input.is_action_pressed("fire")
	var trigger_just_pressed := Input.is_action_just_pressed("fire")
	if ammo <= 0 and (trigger_pressed if bool(weapon_inventory.get_current_data()["automatic_fire"]) else trigger_just_pressed):
		magazine_empty.emit(current_weapon_id)
		_start_reload()
		return
	if not weapon_inventory.can_fire(trigger_pressed, trigger_just_pressed):
		return
	_fire_current_weapon()


func _handle_weapon_selection() -> void:
	if not controls_enabled:
		return
	var requested: StringName = &""
	if Input.is_action_just_pressed("weapon_1"):
		requested = &"rifle"
	elif Input.is_action_just_pressed("weapon_2"):
		requested = &"shotgun"
	elif Input.is_action_just_pressed("weapon_3"):
		requested = &"sniper"
	elif Input.is_action_just_pressed("weapon_4"):
		requested = &"pistol"
	if requested != &"":
		weapon_inventory.select_weapon(requested)


func _fire_current_weapon() -> void:
	var data: Dictionary = weapon_inventory.get_current_data()
	weapon_inventory.commit_shot()
	var shot_damage := int(data["damage"])
	if current_weapon_id == &"rifle" and weapon_inventory.shot_sequence % Tuning.WEAPON_ACCENT_EVERY == 0:
		shot_damage = Tuning.WEAPON_ACCENT_DAMAGE
		data["impact_strength"] = Tuning.ACCENT_HIT_STRENGTH
	var directions := _build_shot_directions(data)
	var muzzle_position: Vector2 = visual.get_muzzle_global_position()
	volley_requested.emit(muzzle_position, directions, &"player", data, shot_damage)
	_play_muzzle_flash(data)
	velocity.x -= aim_direction.x * float(data["recoil"])
	if current_weapon_id == &"rifle":
		_rifle_bloom = minf(_rifle_bloom + 0.42, 3.2)
	if ammo == 0:
		magazine_empty.emit(current_weapon_id)
		_start_reload()


func _build_shot_directions(data: Dictionary) -> Array[Vector2]:
	var count := int(data["projectile_count"])
	var cone_degrees := float(data["spread_angle"])
	if current_weapon_id == &"rifle":
		cone_degrees += _rifle_bloom
	if absf(velocity.x) > 55.0:
		cone_degrees += float(data["movement_accuracy"])
	if not is_on_floor():
		cone_degrees += float(data["airborne_accuracy"])
	var directions: Array[Vector2] = []
	_last_pattern_degrees.clear()
	if count <= 1:
		var pattern := [-0.38, 0.24, -0.12, 0.34, 0.0]
		var offset_degrees: float = cone_degrees * float(pattern[weapon_inventory.shot_sequence % pattern.size()])
		directions.append(aim_direction.rotated(deg_to_rad(offset_degrees)).normalized())
		_last_pattern_degrees.append(offset_degrees)
		return directions
	for pellet_index in range(count):
		var ratio := float(pellet_index) / float(maxi(count - 1, 1))
		var offset_degrees := lerpf(-cone_degrees * 0.5, cone_degrees * 0.5, ratio)
		var micro_variation := sin(float(weapon_inventory.shot_sequence * 7 + pellet_index * 11)) * 0.35
		offset_degrees += micro_variation
		directions.append(aim_direction.rotated(deg_to_rad(offset_degrees)).normalized())
		_last_pattern_degrees.append(offset_degrees)
	return directions


func _start_reload() -> void:
	weapon_inventory.start_reload()


func _play_muzzle_flash(data: Dictionary) -> void:
	visual.play_shot()
	muzzle_flash.rotation = -0.06 if weapon_inventory.shot_sequence % 2 == 0 else 0.06
	var flash_scale := float(data["muzzle_scale"])
	var accent: bool = current_weapon_id == &"rifle" and weapon_inventory.shot_sequence % Tuning.WEAPON_ACCENT_EVERY == 0
	muzzle_flash.call("play", current_weapon_id, data["color"], flash_scale, accent)


func _on_weapon_changed(weapon_id: StringName, data: Dictionary) -> void:
	_rifle_bloom = 0.0
	weapon_camera_aim_bonus = float(data["camera_aim_bonus"])
	visual.configure_weapon(weapon_id, data)
	visual.set_aim_direction(aim_direction, facing_direction)
	weapon_changed.emit(weapon_id, data)


func _animate_visual(delta: float) -> void:
	_landing_feedback_remaining = maxf(_landing_feedback_remaining - delta, 0.0)
	_jump_stretch_remaining = maxf(_jump_stretch_remaining - delta, 0.0)
	visual.facing_direction = facing_direction
	visual.update_pose(delta, velocity, is_on_floor(), movement_intent, aim_direction, _landing_feedback_remaining)


func _on_landed(fall_speed: float) -> void:
	_landing_intensity = clampf((fall_speed - Tuning.PLAYER_LANDING_MIN_SPEED) / 420.0 + 0.55, 0.55, 1.0)
	_landing_feedback_remaining = Tuning.PLAYER_LANDING_FEEDBACK_TIME
	landed.emit(global_position + Vector2(0, 30), _landing_intensity)


func _update_footsteps(distance_moved: float) -> void:
	if not is_on_floor() or absf(velocity.x) < 72.0 or not alive:
		_footstep_distance = 0.0
		return
	_footstep_distance += distance_moved
	if _footstep_distance < 52.0:
		return
	_footstep_distance = fmod(_footstep_distance, 52.0)
	_footstep_side = 1 - _footstep_side
	var intensity := clampf(absf(velocity.x) / maxf(Tuning.PLAYER_MAX_SPEED, 1.0), 0.35, 1.0)
	footstep.emit(global_position + Vector2(0, 30), intensity, _footstep_side)


func take_damage(amount: int, impulse: Vector2 = Vector2.ZERO, _hit_position: Vector2 = Vector2.ZERO, context: Dictionary = {}) -> void:
	if not alive or _invulnerability_remaining > 0.0:
		return
	health = maxi(health - amount, 0)
	last_damage_source = str(context.get("source", "unknown"))
	velocity += impulse
	_invulnerability_remaining = 0.48
	health_changed.emit(health, MAX_HEALTH)
	hurt.emit(amount)
	damage_received.emit(amount, context.duplicate(true))
	if health > 0 and health <= int(MAX_HEALTH * 0.25) and not _low_health_announced:
		_low_health_announced = true
		low_health.emit()
	_flash_hurt()
	if health <= 0:
		_die()


func apply_field_resupply(health_amount: int, ammo_floor_ratio: float) -> void:
	if not alive:
		return
	health = mini(health + maxi(health_amount, 0), MAX_HEALTH)
	_low_health_announced = health <= int(MAX_HEALTH * 0.25)
	weapon_inventory.refill_to_floor(ammo_floor_ratio)
	health_changed.emit(health, MAX_HEALTH)


func _flash_hurt() -> void:
	visual.play_hurt()


func _die() -> void:
	alive = false
	controls_enabled = false
	collision_layer = 0
	visual.play_death(facing_direction)
	died.emit()


func get_debug_snapshot() -> Dictionary:
	var weapon_data: Dictionary = weapon_inventory.get_current_data()
	return {
		"velocity": velocity,
		"movement_intent": movement_intent,
		"facing_direction": facing_direction,
		"grounded": is_on_floor(),
		"jump_buffer": jump_buffer_remaining,
		"coyote": coyote_remaining,
		"health": health,
		"ammo": ammo,
		"weapon_id": current_weapon_id,
		"weapon_name": weapon_data["display_name"],
		"weapon_damage": weapon_data["damage"],
		"weapon_fire_rate": weapon_data["fire_rate"],
		"weapon_spread": weapon_data["spread_angle"],
		"weapon_projectiles": weapon_data["projectile_count"],
		"weapon_cooldown": weapon_inventory.fire_cooldown,
		"weapon_reloading": weapon_inventory.is_reloading(),
		"visual_state": visual.animation_state,
		"base_visual_state": visual.base_animation_state,
		"muzzle_position": visual.get_muzzle_global_position(),
		"last_pattern": _last_pattern_degrees.duplicate(),
	}
