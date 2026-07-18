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
signal roll_started(position: Vector2, direction: int)
signal roll_finished(position: Vector2)
signal roll_attempted(success: bool)
signal projectile_evaded(position: Vector2, direction: Vector2)
signal grenade_requested(origin: Vector2, initial_velocity: Vector2, charge: float)
signal grenade_count_changed(current: int, maximum: int)
signal grenade_empty
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
@onready var grenade_charge_indicator: Node2D = $GrenadeChargeIndicator
@onready var grenade_trajectory_preview: Node2D = $GrenadeTrajectoryPreview
@onready var stamina_bar: Node2D = $StaminaBar

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
var aim_target_world := Vector2.ZERO
var last_shot_origin := Vector2.ZERO
var last_shot_direction := Vector2.RIGHT
var aim_debug_enabled := false
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
var last_damage_kind: StringName = &"none"
var is_rolling := false
var roll_direction := 0
var roll_remaining := 0.0
var roll_cooldown_remaining := 0.0
var last_left_tap_remaining := 0.0
var last_right_tap_remaining := 0.0
var projectile_dodges := 0
var roll_attempts := 0
var roll_successes := 0
var grenade_throws := 0
var grenade_count := Tuning.PLAYER_GRENADE_COUNT
var grenade_charging := false
var grenade_charge := 0.0
var grenade_charge_elapsed := 0.0
var grenade_throw_remaining := 0.0
var predicted_throw_velocity := Vector2.ZERO
var is_sprinting := false
var current_stamina := Tuning.PLAYER_MAX_STAMINA
var stamina_regen_delay_remaining := 0.0
var exhausted := false
var sprint_block_reason: StringName = &"input_released"
var current_move_speed := Tuning.PLAYER_MAX_SPEED
var _sprint_decelerating := false
var _hurt_sprint_block_remaining := 0.0
var _window_focused := true
var launched_from_sprint := false
var airborne_entry_speed := 0.0
var airborne_speed_cap := Tuning.PLAYER_MAX_SPEED
var sprint_air_visual := false
var sprint_land_remaining := 0.0
var _airborne_initialized := false
var runtime_max_health := Tuning.PLAYER_MAX_HEALTH
var runtime_max_stamina := Tuning.PLAYER_MAX_STAMINA
var runtime_stamina_drain := Tuning.PLAYER_STAMINA_DRAIN_PER_SECOND
var runtime_sprint_speed := Tuning.PLAYER_SPRINT_SPEED
var runtime_roll_cooldown := Tuning.PLAYER_ROLL_COOLDOWN
var runtime_grenade_capacity := Tuning.PLAYER_GRENADE_COUNT
var runtime_grenade_radius := Tuning.GRENADE_RADIUS
var runtime_grenade_damage := Tuning.GRENADE_DAMAGE

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
	health_changed.emit(health, runtime_max_health)
	_on_weapon_changed(weapon_inventory.current_weapon_id, weapon_inventory.get_current_data())
	visual.reset_visual()
	visual.set_aim_direction(aim_direction, facing_direction)
	ammo_changed.emit(ammo, int(weapon_inventory.get_current_data()["magazine_size"]), false)
	grenade_count_changed.emit(grenade_count, runtime_grenade_capacity)
	stamina_bar.reset_full()
	aim_target_world = global_position + aim_direction * 1000.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_mouse_aim = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		_using_mouse_aim = false
	if event is InputEventKey and event.echo:
		return
	if not alive or not controls_enabled or get_tree().paused:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner.is_visible_in_tree():
		return
	if event.is_action_pressed("move_left"):
		_register_direction_tap(-1)
	elif event.is_action_pressed("move_right"):
		_register_direction_tap(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_clear_double_tap_cache()
		_cancel_grenade_charge()
		_stop_sprint(&"window_focus")
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true


func _physics_process(delta: float) -> void:
	var grounded_before_move := is_on_floor()
	weapon_inventory.tick(delta)
	_invulnerability_remaining = maxf(_invulnerability_remaining - delta, 0.0)
	var roll_cooldown_before := roll_cooldown_remaining
	roll_cooldown_remaining = maxf(roll_cooldown_remaining - delta, 0.0)
	if roll_cooldown_before > 0.0 and is_zero_approx(roll_cooldown_remaining):
		visual.play_roll_ready()
	last_left_tap_remaining = maxf(last_left_tap_remaining - delta, 0.0)
	last_right_tap_remaining = maxf(last_right_tap_remaining - delta, 0.0)
	jump_buffer_remaining = maxf(jump_buffer_remaining - delta, 0.0)
	grenade_throw_remaining = maxf(grenade_throw_remaining - delta, 0.0)
	_hurt_sprint_block_remaining = maxf(_hurt_sprint_block_remaining - delta, 0.0)
	sprint_land_remaining = maxf(sprint_land_remaining - delta, 0.0)
	coyote_remaining = COYOTE_TIME if is_on_floor() else maxf(coyote_remaining - delta, 0.0)

	if not alive:
		_stop_sprint(&"dead")
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		move_and_slide()
		_animate_visual(delta)
		return

	if is_rolling:
		_update_roll(delta)
		return

	_update_aim()
	_handle_grenade(delta)
	if controls_enabled:
		movement_intent = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			request_jump()
	else:
		movement_intent = 0.0
	_update_sprint_request(grounded_before_move)

	if grounded_before_move and is_sprinting:
		velocity.x = HorizontalMotion.advance_sprint_velocity(velocity.x, movement_intent, delta, runtime_sprint_speed)
	elif grounded_before_move and _sprint_decelerating:
		velocity.x = HorizontalMotion.advance_after_sprint_velocity(velocity.x, movement_intent, delta)
		if absf(velocity.x) <= Tuning.PLAYER_MAX_SPEED + 0.1 or velocity.x * movement_intent <= 0.0:
			_sprint_decelerating = false
	elif grounded_before_move:
		velocity.x = HorizontalMotion.advance_velocity(velocity.x, movement_intent, delta)
	else:
		velocity.x = HorizontalMotion.advance_airborne_velocity(velocity.x, movement_intent, delta, airborne_speed_cap, launched_from_sprint, runtime_sprint_speed)
	current_move_speed = absf(velocity.x)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0

	if jump_buffer_remaining > 0.0 and coyote_remaining > 0.0:
		_begin_airborne(velocity.x, is_sprinting)
		velocity.y = -JUMP_SPEED
		_jump_stretch_remaining = 0.10
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0
		jumped.emit(global_position + Vector2(0, 30))
	if controls_enabled and Input.is_action_just_released("jump") and velocity.y < -JUMP_CUT_SPEED:
		velocity.y = -JUMP_CUT_SPEED

	if is_sprinting and not is_zero_approx(movement_intent):
		facing_direction = 1 if movement_intent > 0.0 else -1
	elif not is_zero_approx(aim_direction.x):
		facing_direction = 1 if aim_direction.x > 0.0 else -1
	elif not is_zero_approx(movement_intent):
		facing_direction = 1 if movement_intent > 0.0 else -1
	visual.set_aim_direction(aim_direction, facing_direction)

	_handle_weapon(delta)
	var fall_speed_before_move := velocity.y
	var x_before_move := global_position.x
	move_and_slide()
	var actual_x_distance := absf(global_position.x - x_before_move)
	if grounded_before_move and not is_on_floor() and not _airborne_initialized:
		_begin_airborne(velocity.x, is_sprinting)
	_update_footsteps(actual_x_distance)
	_update_stamina(delta, actual_x_distance, grounded_before_move)
	if not grounded_before_move and is_on_floor():
		_finish_airborne()
		if fall_speed_before_move >= Tuning.PLAYER_LANDING_MIN_SPEED:
			_on_landed(fall_speed_before_move)
	_animate_visual(delta)


func request_jump() -> void:
	if alive and controls_enabled and not is_rolling:
		jump_buffer_remaining = JUMP_BUFFER_TIME


func _begin_airborne(horizontal_speed: float, sprint_launch: bool) -> void:
	_airborne_initialized = true
	launched_from_sprint = sprint_launch
	airborne_entry_speed = horizontal_speed
	airborne_speed_cap = clampf(absf(horizontal_speed), Tuning.PLAYER_MAX_SPEED, runtime_sprint_speed) if sprint_launch else Tuning.PLAYER_MAX_SPEED
	sprint_air_visual = sprint_launch
	if sprint_launch:
		_stop_sprint(&"airborne", true)


func _finish_airborne() -> void:
	var landed_from_sprint := launched_from_sprint
	_airborne_initialized = false
	launched_from_sprint = false
	airborne_entry_speed = 0.0
	airborne_speed_cap = Tuning.PLAYER_MAX_SPEED
	sprint_air_visual = false
	if landed_from_sprint and absf(velocity.x) > Tuning.PLAYER_MAX_SPEED:
		_sprint_decelerating = true
		sprint_land_remaining = Tuning.PLAYER_SPRINT_LAND_VISUAL_TIME


func _update_sprint_request(grounded: bool) -> void:
	var reason := _get_sprint_block_reason(grounded)
	sprint_block_reason = reason
	if reason == &"none":
		if not is_sprinting:
			is_sprinting = true
			_sprint_decelerating = false
			muzzle_flash.visible = false
		weapon_inventory.cancel_reload()
		return
	_stop_sprint(reason)


func _get_sprint_block_reason(grounded: bool) -> StringName:
	if not alive:
		return &"dead"
	if not controls_enabled:
		return &"controls_disabled"
	if not _window_focused:
		return &"window_focus"
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner.is_visible_in_tree():
		return &"ui_focus"
	if not Input.is_action_pressed("sprint"):
		return &"input_released"
	if absf(movement_intent) <= 0.1:
		return &"no_horizontal_input"
	if not grounded:
		return &"airborne"
	if is_rolling:
		return &"rolling"
	if grenade_charging or grenade_throw_remaining > 0.0:
		return &"grenade"
	if _hurt_sprint_block_remaining > 0.0:
		return &"hurt"
	if Input.is_action_pressed("fire"):
		return &"fire"
	if weapon_inventory.switch_cooldown > 0.0:
		return &"weapon_switch"
	if exhausted:
		return &"exhausted"
	if not is_sprinting and current_stamina < Tuning.PLAYER_STAMINA_MIN_START:
		return &"stamina_low"
	if is_on_wall() and movement_intent * get_wall_normal().x < -0.1:
		return &"wall"
	return &"none"


func _stop_sprint(reason: StringName, preserve_momentum: bool = false) -> void:
	if is_sprinting:
		is_sprinting = false
		_sprint_decelerating = not preserve_momentum and absf(velocity.x) > Tuning.PLAYER_MAX_SPEED
	if reason != &"none":
		sprint_block_reason = reason


func _update_stamina(delta: float, actual_x_distance: float, grounded_before_move: bool) -> void:
	if is_sprinting and grounded_before_move:
		if actual_x_distance > Tuning.PLAYER_SPRINT_WALL_DISTANCE_EPSILON:
			current_stamina = maxf(current_stamina - runtime_stamina_drain * delta, 0.0)
			stamina_regen_delay_remaining = Tuning.PLAYER_STAMINA_REGEN_DELAY
			if is_zero_approx(current_stamina):
				exhausted = true
				_stop_sprint(&"exhausted")
				visual.play_exhausted()
		elif is_on_wall() and movement_intent * get_wall_normal().x < -0.1:
			_stop_sprint(&"wall")
		return
	if current_stamina >= runtime_max_stamina:
		current_stamina = runtime_max_stamina
		stamina_regen_delay_remaining = 0.0
		return
	if not alive or not controls_enabled or is_rolling or _hurt_sprint_block_remaining > 0.0:
		return
	stamina_regen_delay_remaining = maxf(stamina_regen_delay_remaining - delta, 0.0)
	if stamina_regen_delay_remaining > 0.0:
		return
	var regen_multiplier := Tuning.PLAYER_STAMINA_AIR_REGEN_MULTIPLIER if not is_on_floor() else 1.0
	if grenade_charging:
		regen_multiplier *= Tuning.PLAYER_STAMINA_GRENADE_REGEN_MULTIPLIER
	current_stamina = minf(current_stamina + Tuning.PLAYER_STAMINA_REGEN_PER_SECOND * regen_multiplier * delta, runtime_max_stamina)
	if exhausted and current_stamina >= Tuning.PLAYER_STAMINA_RESTART_THRESHOLD:
		exhausted = false


func _register_direction_tap(direction: int) -> void:
	if is_rolling or grenade_throw_remaining > 0.0 or roll_cooldown_remaining > 0.0 or not is_on_floor():
		_clear_double_tap_cache()
		return
	if direction < 0:
		if last_left_tap_remaining > 0.0:
			roll_attempts += 1
			var started := _try_start_roll(-1)
			roll_attempted.emit(started)
			_clear_double_tap_cache()
		else:
			last_left_tap_remaining = Tuning.PLAYER_DOUBLE_TAP_WINDOW
			last_right_tap_remaining = 0.0
	else:
		if last_right_tap_remaining > 0.0:
			roll_attempts += 1
			var started := _try_start_roll(1)
			roll_attempted.emit(started)
			_clear_double_tap_cache()
		else:
			last_right_tap_remaining = Tuning.PLAYER_DOUBLE_TAP_WINDOW
			last_left_tap_remaining = 0.0


func _try_start_roll(direction: int) -> bool:
	if not alive or not controls_enabled or is_rolling or grenade_throw_remaining > 0.0 or roll_cooldown_remaining > 0.0 or not is_on_floor():
		return false
	if grenade_charging:
		_cancel_grenade_charge()
	_stop_sprint(&"rolling")
	is_rolling = true
	roll_successes += 1
	roll_direction = -1 if direction < 0 else 1
	roll_remaining = Tuning.PLAYER_ROLL_DURATION
	movement_intent = float(roll_direction)
	facing_direction = roll_direction
	velocity.x = Tuning.PLAYER_ROLL_SPEED * roll_direction
	current_move_speed = absf(velocity.x)
	weapon_inventory.cancel_reload()
	muzzle_flash.visible = false
	roll_started.emit(global_position + Vector2(0, 30), roll_direction)
	return true


func _update_roll(delta: float) -> void:
	sprint_block_reason = &"rolling"
	roll_remaining = maxf(roll_remaining - delta, 0.0)
	if not is_on_floor():
		_end_roll()
		return
	velocity.x = Tuning.PLAYER_ROLL_SPEED * roll_direction
	current_move_speed = absf(velocity.x)
	velocity.y = 0.0
	var x_before_move := global_position.x
	move_and_slide()
	_update_footsteps(absf(global_position.x - x_before_move))
	_animate_visual(delta)
	if roll_remaining <= 0.0:
		_end_roll()


func _end_roll(start_cooldown: bool = true) -> void:
	if not is_rolling:
		return
	is_rolling = false
	roll_remaining = 0.0
	velocity.x = clampf(velocity.x, -Tuning.PLAYER_MAX_SPEED, Tuning.PLAYER_MAX_SPEED)
	if start_cooldown:
		roll_cooldown_remaining = runtime_roll_cooldown
	roll_finished.emit(global_position + Vector2(0, 30))


func _clear_double_tap_cache() -> void:
	last_left_tap_remaining = 0.0
	last_right_tap_remaining = 0.0


func _handle_grenade(delta: float) -> void:
	if not alive or not controls_enabled or is_rolling:
		_cancel_grenade_charge()
		return
	if grenade_charging:
		if Input.is_action_just_released("throw_grenade"):
			_release_grenade()
			return
		grenade_charge_elapsed += delta
		grenade_charge = pingpong(grenade_charge_elapsed / maxf(Tuning.GRENADE_CHARGE_CYCLE, 0.01), 1.0)
		predicted_throw_velocity = _calculate_grenade_velocity()
		grenade_charge_indicator.show_charge(grenade_charge, facing_direction)
		grenade_trajectory_preview.show_prediction(_grenade_local_origin(), predicted_throw_velocity, Tuning.GRENADE_GRAVITY)
		return
	if grenade_throw_remaining > 0.0 or not Input.is_action_just_pressed("throw_grenade"):
		return
	if grenade_count <= 0:
		grenade_empty.emit()
		return
	_start_grenade_charge()


func _start_grenade_charge() -> bool:
	if not alive or not controls_enabled or is_rolling or grenade_throw_remaining > 0.0 or grenade_count <= 0:
		return false
	_stop_sprint(&"grenade")
	sprint_air_visual = false
	grenade_charging = true
	grenade_charge = 0.0
	grenade_charge_elapsed = 0.0
	predicted_throw_velocity = _calculate_grenade_velocity()
	weapon_inventory.cancel_reload()
	muzzle_flash.visible = false
	grenade_charge_indicator.show_charge(grenade_charge, facing_direction)
	grenade_trajectory_preview.show_prediction(_grenade_local_origin(), predicted_throw_velocity, Tuning.GRENADE_GRAVITY)
	return true


func _release_grenade() -> bool:
	if not grenade_charging or grenade_count <= 0:
		_cancel_grenade_charge()
		return false
	predicted_throw_velocity = _calculate_grenade_velocity()
	var release_charge := grenade_charge
	var origin := _safe_grenade_origin()
	grenade_count -= 1
	grenade_throws += 1
	grenade_charging = false
	grenade_throw_remaining = 0.18
	grenade_charge_indicator.hide_charge()
	grenade_trajectory_preview.hide_prediction()
	grenade_count_changed.emit(grenade_count, runtime_grenade_capacity)
	grenade_requested.emit(origin, predicted_throw_velocity, release_charge)
	return true


func _cancel_grenade_charge() -> void:
	grenade_charging = false
	grenade_charge = 0.0
	grenade_charge_elapsed = 0.0
	predicted_throw_velocity = Vector2.ZERO
	if grenade_charge_indicator != null:
		grenade_charge_indicator.hide_charge()
	if grenade_trajectory_preview != null:
		grenade_trajectory_preview.hide_prediction()


func _calculate_grenade_velocity() -> Vector2:
	var direction := aim_direction.normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2(float(facing_direction), -0.35)
	if direction.y > -0.18:
		direction.y = -0.35
	if absf(direction.x) < 0.18:
		direction.x = 0.18 * float(facing_direction)
	direction = direction.normalized()
	var speed := lerpf(Tuning.GRENADE_MIN_THROW_SPEED, Tuning.GRENADE_MAX_THROW_SPEED, grenade_charge)
	return direction * speed + Vector2(velocity.x * Tuning.GRENADE_HORIZONTAL_VELOCITY_INHERIT, 0.0)


func _grenade_local_origin() -> Vector2:
	return Vector2(20.0 * facing_direction, -18.0)


func _safe_grenade_origin() -> Vector2:
	var start := global_position + Vector2(0.0, -18.0)
	var intended := global_position + _grenade_local_origin()
	var query := PhysicsRayQueryParameters2D.create(start, intended, 1)
	query.exclude = [get_rid()]
	var collision := get_world_2d().direct_space_state.intersect_ray(query)
	if collision.is_empty():
		return intended
	return (collision["position"] as Vector2) - Vector2(8.0 * facing_direction, 0.0)


func cancel_transient_actions() -> void:
	_clear_double_tap_cache()
	_stop_sprint(&"controls_disabled")
	_sprint_decelerating = false
	_airborne_initialized = false
	launched_from_sprint = false
	airborne_entry_speed = 0.0
	airborne_speed_cap = Tuning.PLAYER_MAX_SPEED
	sprint_air_visual = false
	sprint_land_remaining = 0.0
	_end_roll(false)
	roll_cooldown_remaining = 0.0
	grenade_throw_remaining = 0.0
	_cancel_grenade_charge()


func apply_run_upgrade_modifiers(modifiers: Dictionary = {}, selection_effects: Dictionary = {}) -> void:
	var previous_max_health := runtime_max_health
	var previous_max_stamina := runtime_max_stamina
	runtime_max_health = clampi(int(modifiers.get("max_health", Tuning.PLAYER_MAX_HEALTH)), Tuning.PLAYER_MAX_HEALTH, Tuning.PLAYER_MAX_HEALTH + 45)
	runtime_max_stamina = clampf(float(modifiers.get("max_stamina", Tuning.PLAYER_MAX_STAMINA)), Tuning.PLAYER_MAX_STAMINA, Tuning.PLAYER_MAX_STAMINA + 60.0)
	runtime_stamina_drain = clampf(float(modifiers.get("stamina_drain", Tuning.PLAYER_STAMINA_DRAIN_PER_SECOND)), Tuning.PLAYER_STAMINA_DRAIN_PER_SECOND * 0.60, Tuning.PLAYER_STAMINA_DRAIN_PER_SECOND)
	runtime_sprint_speed = clampf(float(modifiers.get("sprint_speed", Tuning.PLAYER_SPRINT_SPEED)), Tuning.PLAYER_SPRINT_SPEED, Tuning.PLAYER_SPRINT_SPEED * 1.14)
	runtime_roll_cooldown = clampf(float(modifiers.get("roll_cooldown", Tuning.PLAYER_ROLL_COOLDOWN)), 0.25, Tuning.PLAYER_ROLL_COOLDOWN)
	runtime_grenade_capacity = clampi(int(modifiers.get("grenade_capacity", Tuning.PLAYER_GRENADE_COUNT)), Tuning.PLAYER_GRENADE_COUNT, Tuning.PLAYER_GRENADE_COUNT + 2)
	runtime_grenade_radius = clampf(float(modifiers.get("grenade_radius", Tuning.GRENADE_RADIUS)), Tuning.GRENADE_RADIUS, Tuning.GRENADE_RADIUS * 1.45)
	runtime_grenade_damage = clampi(int(modifiers.get("grenade_damage", Tuning.GRENADE_DAMAGE)), Tuning.GRENADE_DAMAGE, int(round(Tuning.GRENADE_DAMAGE * 1.45)))
	if previous_max_health != runtime_max_health:
		health = mini(health, runtime_max_health)
	if previous_max_stamina != runtime_max_stamina:
		current_stamina = minf(current_stamina, runtime_max_stamina)
	health = mini(health + int(selection_effects.get("health_restore", 0)), runtime_max_health)
	current_stamina = minf(current_stamina + float(selection_effects.get("stamina_restore", 0.0)), runtime_max_stamina)
	grenade_count = mini(grenade_count + int(selection_effects.get("grenade_restore", 0)), runtime_grenade_capacity)
	weapon_inventory.set_runtime_modifiers(modifiers.get("weapon_modifiers", {}) as Dictionary)
	health_changed.emit(health, runtime_max_health)
	grenade_count_changed.emit(grenade_count, runtime_grenade_capacity)


func get_grenade_runtime_data() -> Dictionary:
	return {"radius": runtime_grenade_radius, "damage": runtime_grenade_damage}


func _update_aim() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_stick_up", "aim_stick_down")
	if stick.length() > 0.25:
		aim_direction = stick.normalized()
		aim_target_world = global_position + aim_direction * 2000.0
		_using_mouse_aim = false
	elif _using_mouse_aim:
		aim_target_world = get_global_mouse_position()
		var mouse_delta := aim_target_world - global_position
		if mouse_delta.length() > 8.0:
			aim_direction = mouse_delta.normalized()
	elif not is_zero_approx(movement_intent):
		aim_direction = Vector2(signf(movement_intent), 0.0)
		aim_target_world = global_position + aim_direction * 2000.0
	if aim_debug_enabled:
		queue_redraw()


func _handle_weapon(delta: float) -> void:
	_rifle_bloom = maxf(_rifle_bloom - 5.0 * delta, 0.0)
	if sprint_air_visual and Input.is_action_pressed("fire"):
		sprint_air_visual = false
	if is_sprinting or is_rolling or grenade_charging or grenade_throw_remaining > 0.0:
		return
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
	var muzzle_position: Vector2 = visual.get_muzzle_global_position()
	var locked_direction := _lock_shot_direction(data, muzzle_position)
	var directions := _build_shot_directions(data, locked_direction)
	last_shot_origin = muzzle_position
	last_shot_direction = directions[0] if not directions.is_empty() else locked_direction
	volley_requested.emit(muzzle_position, directions, &"player", data, shot_damage)
	_play_muzzle_flash(data)
	velocity.x -= locked_direction.x * float(data["recoil"])
	if aim_debug_enabled:
		queue_redraw()
	if current_weapon_id == &"rifle":
		_rifle_bloom = minf(_rifle_bloom + 0.42, 3.2)
	if ammo == 0:
		magazine_empty.emit(current_weapon_id)
		_start_reload()


func _lock_shot_direction(data: Dictionary, muzzle_position: Vector2) -> Vector2:
	if StringName(data["id"]) == &"sniper" and _using_mouse_aim:
		var to_target := aim_target_world - muzzle_position
		if to_target.length_squared() > 1.0:
			return to_target.normalized()
	return aim_direction.normalized() if aim_direction.length_squared() > 0.01 else Vector2(float(facing_direction), 0.0)


func _build_shot_directions(data: Dictionary, base_direction: Vector2 = aim_direction) -> Array[Vector2]:
	var count := int(data["projectile_count"])
	var cone_degrees := float(data["spread_angle"])
	var directions: Array[Vector2] = []
	_last_pattern_degrees.clear()
	if StringName(data["id"]) == &"sniper":
		directions.append(base_direction.normalized())
		_last_pattern_degrees.append(0.0)
		return directions
	if current_weapon_id == &"rifle":
		cone_degrees += _rifle_bloom
	if absf(velocity.x) > 55.0:
		cone_degrees += float(data["movement_accuracy"])
	if not is_on_floor():
		cone_degrees += float(data["airborne_accuracy"])
	if count <= 1:
		var pattern := [-0.38, 0.24, -0.12, 0.34, 0.0]
		var offset_degrees: float = cone_degrees * float(pattern[weapon_inventory.shot_sequence % pattern.size()])
		directions.append(base_direction.rotated(deg_to_rad(offset_degrees)).normalized())
		_last_pattern_degrees.append(offset_degrees)
		return directions
	for pellet_index in range(count):
		var ratio := float(pellet_index) / float(maxi(count - 1, 1))
		var offset_degrees := lerpf(-cone_degrees * 0.5, cone_degrees * 0.5, ratio)
		var micro_variation := sin(float(weapon_inventory.shot_sequence * 7 + pellet_index * 11)) * 0.35
		offset_degrees += micro_variation
		directions.append(base_direction.rotated(deg_to_rad(offset_degrees)).normalized())
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
	var roll_progress := 1.0 - roll_remaining / maxf(Tuning.PLAYER_ROLL_DURATION, 0.001) if is_rolling else 0.0
	visual.update_pose(delta, velocity, is_on_floor(), movement_intent, aim_direction, _landing_feedback_remaining, is_rolling, roll_progress, grenade_charging, grenade_throw_remaining, grenade_charge, is_sprinting, sprint_air_visual, sprint_land_remaining > 0.0)
	var recovering := current_stamina < runtime_max_stamina and stamina_regen_delay_remaining <= 0.0 and not is_sprinting and not is_rolling and _hurt_sprint_block_remaining <= 0.0
	stamina_bar.set_state(current_stamina, runtime_max_stamina, is_sprinting, exhausted, recovering)


func _on_landed(fall_speed: float) -> void:
	_landing_intensity = clampf((fall_speed - Tuning.PLAYER_LANDING_MIN_SPEED) / 420.0 + 0.55, 0.55, 1.0)
	_landing_feedback_remaining = Tuning.PLAYER_LANDING_FEEDBACK_TIME
	landed.emit(global_position + Vector2(0, 30), _landing_intensity)


func _update_footsteps(distance_moved: float) -> void:
	if not is_on_floor() or absf(velocity.x) < 72.0 or not alive:
		_footstep_distance = 0.0
		return
	_footstep_distance += distance_moved
	var step_distance := 42.0 if is_sprinting else 52.0
	if _footstep_distance < step_distance:
		return
	_footstep_distance = fmod(_footstep_distance, step_distance)
	_footstep_side = 1 - _footstep_side
	var intensity := clampf(absf(velocity.x) / maxf(Tuning.PLAYER_MAX_SPEED, 1.0), 0.35, 1.0)
	footstep.emit(global_position + Vector2(0, 30), intensity, _footstep_side)


func take_damage(amount: int, impulse: Vector2 = Vector2.ZERO, hit_position: Vector2 = Vector2.ZERO, context: Dictionary = {}) -> void:
	if not alive or _invulnerability_remaining > 0.0:
		return
	last_damage_kind = StringName(context.get("damage_kind", &"contact"))
	if is_rolling and last_damage_kind == &"projectile":
		projectile_dodges += 1
		var dodge_direction: Vector2 = context.get("direction", Vector2(float(-roll_direction), 0.0))
		projectile_evaded.emit(hit_position if hit_position != Vector2.ZERO else global_position, dodge_direction)
		return
	if is_rolling:
		_end_roll()
	_stop_sprint(&"hurt")
	_hurt_sprint_block_remaining = Tuning.PLAYER_STAMINA_HURT_REGEN_PAUSE
	stamina_regen_delay_remaining = maxf(stamina_regen_delay_remaining, Tuning.PLAYER_STAMINA_HURT_REGEN_PAUSE)
	if grenade_charging:
		_cancel_grenade_charge()
	health = maxi(health - amount, 0)
	last_damage_source = str(context.get("source", "unknown"))
	velocity += impulse
	_invulnerability_remaining = 0.48
	health_changed.emit(health, runtime_max_health)
	hurt.emit(amount)
	damage_received.emit(amount, context.duplicate(true))
	if health > 0 and health <= int(runtime_max_health * 0.25) and not _low_health_announced:
		_low_health_announced = true
		low_health.emit()
	_flash_hurt()
	if health <= 0:
		_die()


func apply_field_resupply(health_amount: int, ammo_floor_ratio: float, grenade_amount: int = 0) -> void:
	if not alive:
		return
	health = mini(health + maxi(health_amount, 0), runtime_max_health)
	_low_health_announced = health <= int(runtime_max_health * 0.25)
	weapon_inventory.refill_to_floor(ammo_floor_ratio)
	add_grenades(grenade_amount)
	health_changed.emit(health, runtime_max_health)


func add_grenades(amount: int) -> void:
	if amount <= 0:
		return
	grenade_count = mini(grenade_count + amount, runtime_grenade_capacity)
	grenade_count_changed.emit(grenade_count, runtime_grenade_capacity)


func _flash_hurt() -> void:
	visual.play_hurt()


func _die() -> void:
	cancel_transient_actions()
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
		"aim_target_world": aim_target_world,
		"last_shot_origin": last_shot_origin,
		"last_shot_direction": last_shot_direction,
		"aim_debug_enabled": aim_debug_enabled,
		"last_pattern": _last_pattern_degrees.duplicate(),
		"is_rolling": is_rolling,
		"roll_direction": roll_direction,
		"roll_remaining": roll_remaining,
		"roll_cooldown": roll_cooldown_remaining,
		"last_left_tap": last_left_tap_remaining,
		"last_right_tap": last_right_tap_remaining,
		"last_damage_kind": last_damage_kind,
		"projectile_dodges": projectile_dodges,
		"roll_attempts": roll_attempts,
		"roll_successes": roll_successes,
		"grenade_throws": grenade_throws,
		"grenade_charging": grenade_charging,
		"grenade_charge": grenade_charge,
		"grenade_count": grenade_count,
		"predicted_throw_velocity": predicted_throw_velocity,
		"is_sprinting": is_sprinting,
		"current_stamina": current_stamina,
		"max_stamina": runtime_max_stamina,
		"drain_rate": runtime_stamina_drain,
		"regen_delay_remaining": stamina_regen_delay_remaining,
		"regen_rate": Tuning.PLAYER_STAMINA_REGEN_PER_SECOND,
		"exhausted": exhausted,
		"current_move_speed": current_move_speed,
		"sprint_block_reason": sprint_block_reason,
		"launched_from_sprint": launched_from_sprint,
		"airborne_entry_speed": airborne_entry_speed,
		"airborne_speed_cap": airborne_speed_cap,
		"sprint_air_visual": sprint_air_visual,
		"sprint_land_remaining": sprint_land_remaining,
		"runtime_max_health": runtime_max_health,
		"runtime_sprint_speed": runtime_sprint_speed,
		"runtime_roll_cooldown": runtime_roll_cooldown,
		"runtime_grenade_capacity": runtime_grenade_capacity,
		"runtime_grenade_radius": runtime_grenade_radius,
		"runtime_grenade_damage": runtime_grenade_damage,
	}


func set_aim_debug_enabled(enabled: bool) -> void:
	aim_debug_enabled = enabled and OS.is_debug_build()
	queue_redraw()


func _draw() -> void:
	if not aim_debug_enabled or current_weapon_id != &"sniper":
		return
	var muzzle_world: Vector2 = visual.get_muzzle_global_position()
	var muzzle_local: Vector2 = to_local(muzzle_world)
	var target_local: Vector2 = to_local(aim_target_world)
	var planned_direction: Vector2 = _lock_shot_direction(weapon_inventory.get_current_data(), muzzle_world)
	var planned_end: Vector2 = muzzle_local + planned_direction * minf(muzzle_world.distance_to(aim_target_world), 1800.0)
	var actual_origin_local: Vector2 = to_local(last_shot_origin)
	var actual_end: Vector2 = actual_origin_local + last_shot_direction * 360.0
	draw_line(muzzle_local, planned_end, Color(0.32, 0.95, 1.0, 0.78), 1.0)
	draw_line(actual_origin_local, actual_end, Color(1.0, 0.82, 0.30, 0.92), 2.0)
	draw_circle(muzzle_local, 3.0, Color(0.35, 1.0, 0.72, 1.0))
	draw_circle(target_local, 4.0, Color(1.0, 0.35, 0.32, 0.95), false, 1.0)
