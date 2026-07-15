extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const HorizontalMotion := preload("res://scripts/player/player_horizontal_motion.gd")
const CameraRig := preload("res://scripts/camera/camera_rig.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tuning_and_input_contract()
	var movement_game := await _create_game()
	await _test_ground_sprint_stamina_and_bar(movement_game)
	movement_game.queue_free()
	await process_frame
	var action_game := await _create_game()
	await _test_action_priorities(action_game)
	action_game.queue_free()
	await process_frame
	var safety_game := await _create_game()
	await _test_jump_damage_pause_and_wall(safety_game)
	safety_game.queue_free()
	await process_frame
	_release_actions()
	if failures.is_empty():
		print("PLAYER_SPRINT_STAMINA_PASS Shift A/D ground sprint, actual-movement drain, exhaustion gate/regen, action priorities, jump inheritance, world bar, camera look and pause/death safety")
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


func _test_tuning_and_input_contract() -> void:
	_expect(InputMap.has_action("sprint"), "InputMap is missing sprint")
	_expect(_has_shift(KEY_LOCATION_LEFT) and _has_shift(KEY_LOCATION_RIGHT), "sprint is not bound to both Shift keys")
	_expect(is_equal_approx(Tuning.PLAYER_SPRINT_SPEED_MULTIPLIER, 1.8), "sprint multiplier is not centralized at 1.80")
	_expect(is_equal_approx(HorizontalMotion.SPRINT_MAX_SPEED, 468.0), "sprint max speed is not 468 px/s")
	_expect(is_equal_approx(Tuning.PLAYER_MAX_STAMINA / Tuning.PLAYER_STAMINA_DRAIN_PER_SECOND, 3.5714285), "full sprint duration changed")
	_expect(is_equal_approx(Tuning.PLAYER_MAX_STAMINA / Tuning.PLAYER_STAMINA_REGEN_PER_SECOND, 4.5454545), "full stamina recovery duration changed")
	var normal_look := absf(CameraRig.calculate_desired_look_ahead(Tuning.PLAYER_MAX_SPEED, 0.0))
	var sprint_look := absf(CameraRig.calculate_desired_look_ahead(Tuning.PLAYER_SPRINT_SPEED, 0.0, 0.0, true))
	_expect(sprint_look > normal_look and sprint_look <= Tuning.CAMERA_MAX_LOOK_AHEAD + Tuning.CAMERA_SPRINT_LOOK_AHEAD, "sprint camera look-ahead is missing or unbounded")


func _test_ground_sprint_stamina_and_bar(game: Node) -> void:
	var player = game.player
	var bar = player.stamina_bar
	var full: float = player.current_stamina
	Input.action_press("sprint")
	for _frame in range(12):
		await physics_frame
	_expect(not player.is_sprinting and is_equal_approx(player.current_stamina, full), "standing Shift consumed stamina")
	Input.action_press("move_left")
	Input.action_press("move_right")
	for _frame in range(8):
		await physics_frame
	_expect(not player.is_sprinting and is_equal_approx(player.current_stamina, full), "opposite movement inputs consumed stamina at zero intent")
	Input.action_release("move_left")
	for _frame in range(24):
		await physics_frame
	_expect(player.is_sprinting and player.velocity.x > Tuning.PLAYER_MAX_SPEED * 1.65, "Shift+D did not reach a clearly faster sprint")
	_expect(player.current_stamina < full - 8.0, "real ground sprint did not drain stamina")
	_expect(player.visual.base_animation_state in [&"sprint_start", &"sprint"] and player.visual.animation_state in [&"sprint_start", &"sprint_loop"], "sprint start/loop visual state is missing")
	_expect(not player.weapon.visible and player.get_node("CollisionShape2D").rotation == 0.0, "sprint did not stow the weapon or rotated the physics body")
	_expect(bar.get_parent() == player and bar.global_rotation == 0.0 and bar.scale.x > 0.0, "stamina bar is not independent world-space UI")
	bar.set_state(100.0, 100.0, false, false, false)
	var full_rect: Rect2 = bar.get_fill_rect()
	bar.set_state(50.0, 100.0, false, false, true)
	var half_rect: Rect2 = bar.get_fill_rect()
	_expect(full_rect.position.x == half_rect.position.x and half_rect.end.x < full_rect.end.x, "stamina fill does not retract from right to left")
	Input.action_release("sprint")
	await physics_frame
	_expect(not player.is_sprinting and player.visual.base_animation_state in [&"sprint_stop", &"run"], "releasing Shift did not enter sprint stop/run")
	for _frame in range(10):
		await physics_frame
	_expect(absf(player.velocity.x) <= Tuning.PLAYER_MAX_SPEED + 0.1, "sprint speed did not smoothly return to normal maximum")
	Input.action_release("move_right")
	player.current_stamina = 1.0
	player.stamina_regen_delay_remaining = 0.0
	Input.action_press("move_left")
	Input.action_press("sprint")
	for _frame in range(10):
		await physics_frame
	_expect(player.exhausted and is_zero_approx(player.current_stamina) and not player.is_sprinting, "stamina depletion did not force exhausted exit")
	Input.action_release("sprint")
	Input.action_release("move_left")
	player.stamina_regen_delay_remaining = Tuning.PLAYER_STAMINA_REGEN_DELAY
	for _frame in range(30):
		await physics_frame
	_expect(is_zero_approx(player.current_stamina), "stamina regenerated before the 0.60s delay")
	for _frame in range(8):
		await physics_frame
	_expect(player.current_stamina > 0.0, "stamina did not begin regenerating after the delay")
	while player.current_stamina < Tuning.PLAYER_STAMINA_RESTART_THRESHOLD - 0.2:
		await physics_frame
	_expect(player.exhausted, "exhausted gate cleared below 20 percent")
	while player.exhausted:
		await physics_frame
	_expect(player.current_stamina >= Tuning.PLAYER_STAMINA_RESTART_THRESHOLD, "exhausted gate did not clear at 20 percent")
	Input.action_press("move_right")
	Input.action_press("sprint")
	await physics_frame
	_expect(player.is_sprinting, "sprint did not restart after the 20 percent threshold")
	_release_actions()


func _test_action_priorities(game: Node) -> void:
	var player = game.player
	await _start_sprint(player, 1)
	var ammo_before: int = player.ammo
	Input.action_press("fire")
	await physics_frame
	_expect(not player.is_sprinting and player.ammo < ammo_before, "fire did not immediately exit sprint and shoot")
	Input.action_release("fire")
	await _start_sprint(player, 1)
	var weapon_before: StringName = player.current_weapon_id
	Input.action_press("weapon_2")
	await physics_frame
	Input.action_release("weapon_2")
	_expect(player.current_weapon_id == weapon_before, "weapon switched during sprint")
	Input.action_release("sprint")
	Input.action_release("move_right")
	await physics_frame
	player.weapon_inventory._ammo[player.current_weapon_id] -= 2
	var reload_ammo: int = player.ammo
	player.weapon_inventory.start_reload()
	await _start_sprint(player, 1)
	_expect(not player.weapon_inventory.is_reloading() and player.ammo == reload_ammo, "sprint did not safely cancel reload without changing ammo")
	Input.action_press("throw_grenade")
	for _frame in range(2):
		await physics_frame
	_expect(not player.is_sprinting and player.grenade_charging and player.grenade_charge_indicator.visible, "grenade charge did not override sprint cleanly")
	Input.action_release("throw_grenade")
	for _frame in range(2):
		await physics_frame
	_expect(player.grenade_throw_remaining > 0.0 and not player.is_sprinting, "grenade throw animation allowed an early sprint restart")
	while player.grenade_throw_remaining > 0.0:
		await physics_frame
	await physics_frame
	_expect(player.is_sprinting, "held Shift+direction did not resume after grenade throw completed")
	var stamina_before_roll: float = player.current_stamina
	var roll_started: bool = player._try_start_roll(1)
	_expect(roll_started and player.is_rolling and not player.is_sprinting, "roll did not take priority over sprint")
	for _frame in range(5):
		await physics_frame
	_expect(is_equal_approx(player.current_stamina, stamina_before_roll), "roll consumed or regenerated sprint stamina")
	while player.is_rolling:
		await physics_frame
	await physics_frame
	_expect(player.is_sprinting, "eligible held sprint did not resume after roll")
	_release_actions()
	Input.action_press("fire")
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(3):
		await physics_frame
	_expect(not player.is_sprinting and player.sprint_block_reason == &"fire", "held fire incorrectly allowed sprint")
	_release_actions()


func _test_jump_damage_pause_and_wall(game: Node) -> void:
	var player = game.player
	await _start_sprint(player, 1)
	var sprint_speed_before_jump: float = absf(player.velocity.x)
	Input.action_press("jump")
	for _frame in range(4):
		await physics_frame
		if not player.is_on_floor() and player.velocity.y < 0.0:
			break
	Input.action_release("jump")
	var stamina_in_air: float = player.current_stamina
	_expect(not player.is_sprinting and not player.is_on_floor(), "sprint jump did not enter the airborne state")
	_expect(absf(player.velocity.x) >= sprint_speed_before_jump - 1.0, "sprint jump did not inherit its true horizontal speed")
	_expect(absf(player.velocity.x) <= Tuning.PLAYER_SPRINT_JUMP_SPEED_CAP + 0.1, "sprint jump exceeded its configured airborne speed cap")
	for _frame in range(8):
		await physics_frame
	_expect(player.current_stamina >= stamina_in_air, "airborne Shift continued draining stamina")
	while not player.is_on_floor():
		await physics_frame
	await physics_frame
	_expect(player.is_sprinting, "held sprint did not resume after landing")
	var health_before: int = player.health
	player._invulnerability_remaining = 0.0
	player.take_damage(9, Vector2.ZERO, player.global_position, {"source": &"test", "damage_kind": &"projectile"})
	_expect(player.health == health_before - 9 and not player.is_sprinting, "sprint incorrectly granted projectile invulnerability")
	player._invulnerability_remaining = 0.0
	player.roll_cooldown_remaining = 0.0
	player._try_start_roll(1)
	var rolling_health: int = player.health
	player.take_damage(9, Vector2.ZERO, player.global_position, {"source": &"test", "damage_kind": &"projectile"})
	_expect(player.health == rolling_health and player.is_rolling, "existing roll projectile evade regressed")
	player._end_roll(false)
	player._hurt_sprint_block_remaining = 0.0
	await _start_sprint(player, 1)
	var paused_stamina: float = player.current_stamina
	paused = true
	for _frame in range(8):
		await physics_frame
	paused = false
	_expect(is_equal_approx(player.current_stamina, paused_stamina), "pause consumed stamina")
	player.controls_enabled = false
	await physics_frame
	_expect(not player.is_sprinting and player.sprint_block_reason == &"controls_disabled", "disabled controls left sprint active")
	player.controls_enabled = true
	_release_actions()
	player.global_position = Vector2(19982.0, 552.0)
	player.velocity = Vector2.ZERO
	for _frame in range(3):
		await physics_frame
	var wall_stamina: float = player.current_stamina
	Input.action_press("move_right")
	Input.action_press("sprint")
	for _frame in range(16):
		await physics_frame
	_expect(wall_stamina - player.current_stamina < 1.0 and not player.is_sprinting, "wall contact caused sustained meaningless stamina drain")
	_release_actions()
	player.current_stamina = 4.0
	player.exhausted = false
	await _start_sprint(player, -1)
	var death_handler := Callable(game, "_on_player_died")
	if player.died.is_connected(death_handler):
		player.died.disconnect(death_handler)
	player.take_damage(9999, Vector2.ZERO, player.global_position, {"source": &"test", "damage_kind": &"environment"})
	_expect(not player.alive and not player.is_sprinting, "death left sprint active")
	_release_actions()
	var replacement := MainScene.instantiate()
	root.add_child(replacement)
	for _frame in range(3):
		await physics_frame
	_expect(replacement.player.current_stamina == Tuning.PLAYER_MAX_STAMINA and not replacement.player.exhausted, "restart/checkpoint player did not restore full stamina")
	replacement.queue_free()
	await process_frame


func _start_sprint(player: Node, direction: int) -> void:
	_release_actions()
	Input.action_press("move_left" if direction < 0 else "move_right")
	Input.action_press("sprint")
	for _frame in range(4):
		await physics_frame


func _has_shift(location: KeyLocation) -> bool:
	for event in InputMap.action_get_events("sprint"):
		if event is InputEventKey and event.physical_keycode == KEY_SHIFT and event.location == location:
			return true
	return false


func _release_actions() -> void:
	for action in [&"move_left", &"move_right", &"sprint", &"jump", &"fire", &"reload", &"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4", &"throw_grenade"]:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
