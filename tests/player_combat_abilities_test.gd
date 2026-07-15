extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const GrenadeScript := preload("res://scripts/combat/player_grenade.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var input_game := await _create_game()
	await _test_double_tap_contract(input_game)
	input_game.queue_free()
	await process_frame
	var state_game := await _create_game()
	await _test_roll_state_damage_and_cooldown(state_game)
	state_game.queue_free()
	await process_frame
	var collision_game := await _create_game()
	await _test_roll_collision(collision_game)
	collision_game.queue_free()
	await process_frame
	var grenade_input_game := await _create_game()
	await _test_grenade_charge_and_state_contract(grenade_input_game)
	grenade_input_game.queue_free()
	await process_frame
	var grenade_damage_game := await _create_game()
	await _test_grenade_physics_and_damage(grenade_damage_game)
	grenade_damage_game.queue_free()
	await process_frame
	_finish()


func _create_game() -> Node:
	var game := MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(5):
		await physics_frame
	return game


func _test_double_tap_contract(game: Node) -> void:
	var player = game.player
	_tap(player, &"move_left")
	for _frame in range(4):
		await physics_frame
	_tap(player, &"move_right")
	_expect(not player.is_rolling, "A then D incorrectly triggered a roll")
	player._clear_double_tap_cache()
	_tap(player, &"move_right")
	for _frame in range(4):
		await physics_frame
	_tap(player, &"move_left")
	_expect(not player.is_rolling, "D then A incorrectly triggered a roll")
	player._clear_double_tap_cache()
	_tap(player, &"move_left")
	for _frame in range(16):
		await physics_frame
	_tap(player, &"move_left")
	_expect(not player.is_rolling, "tap outside the 0.25s window triggered a roll")
	player._clear_double_tap_cache()
	_tap(player, &"move_right")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_D
	echo.pressed = true
	echo.echo = true
	player._input(echo)
	_expect(not player.is_rolling, "keyboard repeat was mistaken for the second tap")
	player._clear_double_tap_cache()
	_tap(player, &"move_left")
	for _frame in range(3):
		await physics_frame
	_tap(player, &"move_left")
	_expect(player.is_rolling and player.roll_direction == -1, "AA did not start a left ground roll")


func _test_roll_state_damage_and_cooldown(game: Node) -> void:
	var player = game.player
	player.weapon_inventory._ammo[player.current_weapon_id] -= 1
	player.weapon_inventory.start_reload()
	_start_roll(player, 1)
	await physics_frame
	_expect(player.is_rolling and not player.weapon_inventory.is_reloading(), "roll did not start or cancel the active reload")
	_expect(player.visual.animation_state in [&"roll_start", &"roll", &"roll_end"] and not player.visual.weapon_pivot.visible, "roll visual did not stow the weapon")
	var volleys := [0]
	player.volley_requested.connect(func(_origin: Vector2, _directions: Array[Vector2], _team: StringName, _data: Dictionary, _damage: int) -> void: volleys[0] += 1)
	Input.action_press("fire")
	for _frame in range(5):
		await physics_frame
	Input.action_release("fire")
	_expect(volleys[0] == 0, "player fired a weapon during a roll")
	var health_before: int = player.health
	player.take_damage(20, Vector2.ZERO, player.global_position, {"source": &"gunner", "damage_kind": &"projectile"})
	_expect(player.health == health_before and player.projectile_dodges == 1 and player.is_rolling, "roll failed to evade projectile damage cleanly")
	player.take_damage(14, Vector2.ZERO, player.global_position, {"source": &"spikes", "damage_kind": &"environment"})
	_expect(player.health == health_before - 14 and not player.is_rolling, "roll incorrectly evaded environment damage")
	player._invulnerability_remaining = 0.0
	player.roll_cooldown_remaining = 0.0
	_start_roll(player, 1)
	for _frame in range(25):
		await physics_frame
	_expect(not player.is_rolling and player.roll_cooldown_remaining > 0.45, "0.5s cooldown did not begin after roll completion")
	var velocity_after_roll: float = absf(player.velocity.x)
	_expect(velocity_after_roll <= Tuning.PLAYER_MAX_SPEED + 0.1, "roll permanently retained boosted movement speed")
	_start_roll(player, 1)
	_expect(not player.is_rolling, "roll restarted during cooldown")
	for _frame in range(31):
		await physics_frame
	_start_roll(player, 1)
	_expect(player.is_rolling, "roll was not ready after its 0.5s cooldown")


func _test_roll_collision(game: Node) -> void:
	var player = game.player
	game._start_mission_encounter(0)
	player.global_position = Vector2(5158.0, 552.0)
	for _frame in range(3):
		await physics_frame
	_start_roll(player, 1)
	for _frame in range(25):
		await physics_frame
	_expect(player.global_position.x <= 5169.1, "roll passed through the closed encounter gate")
	player.roll_cooldown_remaining = 0.0
	player.global_position = Vector2(22.0, 552.0)
	for _frame in range(3):
		await physics_frame
	_start_roll(player, -1)
	for _frame in range(25):
		await physics_frame
	_expect(player.global_position.x >= 16.9, "roll passed through the world boundary")


func _test_grenade_charge_and_state_contract(game: Node) -> void:
	var player = game.player
	var initial_count: int = player.grenade_count
	Input.action_press("throw_grenade")
	for _frame in range(2):
		await physics_frame
	_expect(player.grenade_charging and player.grenade_charge_indicator.visible and player.grenade_trajectory_preview.visible, "right-button charge did not show the world-space meter and trajectory")
	var charge_before: float = float(player.grenade_charge)
	for _frame in range(75):
		await physics_frame
	_expect(player.grenade_charge >= 0.0 and player.grenade_charge <= 1.0 and not is_equal_approx(player.grenade_charge, charge_before), "grenade charge did not move through its bounded ping-pong cycle")
	var low_velocity: Vector2
	player.grenade_charge = 0.0
	low_velocity = player._calculate_grenade_velocity()
	player.grenade_charge = 1.0
	var high_velocity: Vector2 = player._calculate_grenade_velocity()
	_expect(high_velocity.length() > low_velocity.length() * 2.2, "high grenade charge is not clearly stronger than a quick throw")
	Input.action_release("throw_grenade")
	for _frame in range(2):
		await physics_frame
	_expect(not player.grenade_charging and not player.grenade_charge_indicator.visible and not player.grenade_trajectory_preview.visible, "release did not hide grenade charge presentation")
	_expect(player.grenade_count == initial_count - 1 and game.grenades.get_child_count() == 1, "successful grenade throw did not consume exactly one grenade")
	player.grenade_throw_remaining = 0.0
	player._start_grenade_charge()
	player._cancel_grenade_charge()
	_expect(player.grenade_count == initial_count - 1, "canceling grenade charge consumed inventory")
	player.weapon_inventory._ammo[player.current_weapon_id] -= 1
	player.weapon_inventory.start_reload()
	player._start_grenade_charge()
	_expect(not player.weapon_inventory.is_reloading(), "grenade charge did not cancel reload")
	var volleys := [0]
	player.volley_requested.connect(func(_origin: Vector2, _directions: Array[Vector2], _team: StringName, _data: Dictionary, _damage: int) -> void: volleys[0] += 1)
	Input.action_press("fire")
	for _frame in range(4):
		await physics_frame
	Input.action_release("fire")
	_expect(volleys[0] == 0, "player fired while charging a grenade")
	_expect(not player._try_start_roll(1), "grenade charge allowed a simultaneous roll")
	game._on_pause_changed(true)
	_expect(not player.grenade_charging and not player.grenade_charge_indicator.visible, "pause did not cancel grenade charge")
	game._on_pause_changed(false)
	player.roll_cooldown_remaining = 0.0
	_start_roll(player, 1)
	_expect(not player._start_grenade_charge(), "roll allowed grenade charge to begin")
	player._end_roll(false)
	player.grenade_count = 0
	var empty_events := [0]
	player.grenade_empty.connect(func() -> void: empty_events[0] += 1)
	Input.action_press("throw_grenade")
	await physics_frame
	Input.action_release("throw_grenade")
	await physics_frame
	_expect(not player.grenade_charging and empty_events[0] == 1, "zero grenade inventory did not reject charge with one empty event")


func _test_grenade_physics_and_damage(game: Node) -> void:
	var player = game.player
	game._spawn_player_grenade(Vector2(900, 500), Vector2(420, -120))
	var grenade = game.grenades.get_child(0)
	var bounce_events := [0]
	var explosion_events := [0]
	grenade.bounced.connect(func(_position: Vector2, _strength: float) -> void: bounce_events[0] += 1)
	grenade.exploded.connect(func(_position: Vector2, _radius: float, _damage: int, _knockback: float) -> void: explosion_events[0] += 1)
	var start_position: Vector2 = grenade.global_position
	for _frame in range(12):
		await physics_frame
	_expect(grenade.global_position.distance_to(start_position) > 30.0 and grenade.velocity.y > -120.0, "grenade did not follow gravity-driven physical motion")
	var fuse_before_pause: float = grenade.fuse_remaining
	paused = true
	for _frame in range(5):
		await process_frame
	_expect(is_equal_approx(grenade.fuse_remaining, fuse_before_pause), "grenade fuse continued during pause")
	paused = false
	for _frame in range(110):
		await physics_frame
		if not is_instance_valid(grenade):
			break
	_expect(bounce_events[0] >= 1 and bounce_events[0] <= 5, "grenade did not perform a finite number of physical bounces")
	_expect(explosion_events[0] == 1 and game.get_tree().get_nodes_in_group("grenade_effects").size() == 1, "grenade fuse did not produce exactly one explosion and visual")
	var elite: Node = game._spawn_enemy("elite", Vector2(1200, 552), 0.0, false, false)
	elite.activate()
	elite.set_physics_process(false)
	var shield: Node = game._spawn_enemy("shield", Vector2(1270, 552), 0.0, false, false)
	shield.activate()
	shield.set_physics_process(false)
	shield._facing = -1.0
	for _frame in range(2):
		await physics_frame
	var player_health: int = player.health
	game._on_player_grenade_exploded(Vector2(1210, 545), 110.0, 80, 360.0)
	_expect(elite.health == elite.max_health - 80, "one grenade explosion did not damage the elite exactly once")
	_expect(shield.health == shield.max_health - 62 and shield.guard_open_remaining >= 0.99, "grenade did not produce the configured shield break")
	_expect(player.health == player_health, "player grenade incorrectly damaged its owner")
	game._debug_unlock_boss_for_tests()
	player.global_position = Vector2(17850, 552)
	game._process(0.0)
	var boss: Node = game.boss
	boss.health = 800
	var phase_events: Array[int] = []
	boss.phase_changed.connect(func(value: int) -> void: phase_events.append(value))
	game._on_player_grenade_exploded(boss.global_position, 110.0, 80, 360.0)
	_expect(boss.health == 720 and phase_events == [2], "one grenade caused missing, duplicate, or incorrect Boss threshold damage")
	var cleanup_grenade = GrenadeScript.new()
	game.grenades.add_child(cleanup_grenade)
	cleanup_grenade.configure(player.global_position, Vector2.ZERO, {"fuse": 1.7})
	player._invulnerability_remaining = 0.0
	player.take_damage(9999, Vector2.ZERO, player.global_position, {"source": &"test", "damage_kind": &"environment"})
	await process_frame
	_expect(game.grenades.get_child_count() == 0, "player death left live grenades in the scene")


func _start_roll(player: Node, direction: int) -> void:
	player._clear_double_tap_cache()
	_tap(player, &"move_left" if direction < 0 else &"move_right")
	_tap(player, &"move_left" if direction < 0 else &"move_right")


func _tap(player: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	player._input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	Input.action_release("fire")
	Input.action_release("throw_grenade")
	if failures.is_empty():
		print("PLAYER_ABILITIES_PASS roll input/collision/projectile evade/cooldown plus grenade charge/ping-pong/trajectory/physics/single-hit damage/inventory/pause/death cleanup")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
