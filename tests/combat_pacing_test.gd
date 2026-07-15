extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pressure_game := await _create_game()
	_test_visibility_and_concurrency(pressure_game)
	pressure_game.queue_free()
	await process_frame
	var sequence_game := await _create_game()
	_test_encounter_sequence_and_resupply(sequence_game)
	sequence_game.queue_free()
	for _frame in range(3):
		await process_frame
	_finish()


func _create_game() -> Node:
	var game = MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(4):
		await physics_frame
	return game


func _test_visibility_and_concurrency(game: Node) -> void:
	var player = game.player
	game._start_mission_encounter(0)
	for index in range(5):
		var extra: Node = game._spawn_enemy("assault" if index % 2 == 0 else "gunner", player.global_position + Vector2(180.0 + index * 45.0, 0), 0.0, false, false, 0)
		extra.activate()
	var gunner: Node
	for enemy in game.enemies.get_children():
		if enemy.kind == "gunner" and gunner == null:
			gunner = enemy
		enemy.activate()
		enemy.attack_cooldown = 0.0
		enemy.global_position = player.global_position + Vector2(80.0 if enemy.kind in ["assault", "shield"] else 350.0, 0.0)
	for enemy in game.enemies.get_children():
		var distance := absf(enemy.global_position.x - player.global_position.x)
		if enemy.kind == "assault":
			enemy._update_assault(distance)
		elif enemy.kind == "shield":
			enemy._update_shield(distance)
		elif enemy.kind == "elite":
			enemy._update_elite(distance)
		else:
			enemy._update_gunner(distance)
	var telegraphs := 0
	for enemy in game.enemies.get_children():
		if enemy.state == &"telegraph":
			telegraphs += 1
	_expect(telegraphs == 2 and game.combat_pacing.active_attack_count() == 2, "dense pressure was not capped to two simultaneous telegraphs")
	for enemy in game.enemies.get_children():
		if enemy.state == &"telegraph":
			enemy._finish_attack()
	gunner.attack_cooldown = 0.0
	gunner.global_position = player.global_position + Vector2(560.0, 0.0)
	gunner._update_gunner(560.0)
	_expect(gunner.state != &"telegraph", "gunner began an attack outside the 520px readable range")
	gunner.global_position = player.global_position + Vector2(500.0, 0.0)
	gunner.attack_cooldown = 0.0
	gunner.attack_windup_remaining = 0.0
	gunner._update_gunner(500.0)
	_expect(gunner.state == &"telegraph", "gunner failed to attack after entering readable range")


func _test_encounter_sequence_and_resupply(game: Node) -> void:
	game.player.global_position.x = 5400.0
	game._process(0.0)
	_expect(game._active_mission_encounter == 0 and game.mission_gate.closed and game.mission_gate.collision_layer == 1, "first major encounter did not lock its forward boundary")
	var gate_shape := game.mission_gate.get_child(0) as CollisionShape2D
	_expect((game.player.collision_mask & 1) != 0 and gate_shape != null and gate_shape.shape.size.y >= 700.0, "closed encounter gate does not physically block the player route")
	_expect(game.enemies_remaining == 2 and game._active_wave_index == 0, "first encounter did not begin with its authored teaching wave")
	game.player.global_position.x = game.BOSS_ENTRY_X + 20.0
	game._process(0.0)
	_expect(game.run_state == "combat" and not game.boss.active, "player could start the Boss before clearing the gated mission")
	game.player.global_position.x = 5400.0
	var stranded: Node = game.enemies.get_child(0)
	stranded.global_position = Vector2(1200, 760)
	game._encounter_stall_elapsed = game.ENCOUNTER_STALL_REPOSITION_TIME
	game._process(0.0)
	_expect(stranded.global_position.x >= 5320.0 and stranded.global_position.y == 552.0, "offscreen encounter recovery did not return a stranded enemy to the combat sector")
	_clear_active_wave(game)
	_expect(game._next_wave_delay > 0.6 and game.mission_gate.closed, "next wave was not queued while the route remained locked")
	game._process(0.69)
	_expect(game.enemies_remaining == 3 and game._active_wave_index == 1, "second wave did not spawn after the short buffer")
	_clear_active_wave(game)
	game._process(0.69)
	_expect(game.enemies_remaining == 2 and game._active_wave_index == 2, "final first-sector wave is incorrect")
	_clear_active_wave(game)
	_expect(game._mission_encounter_cursor == 1 and not game.mission_gate.closed, "clearing a major encounter did not immediately reopen the route")
	game.player.health = 18
	for weapon_id in WeaponData.ORDER:
		game.player.weapon_inventory._ammo[weapon_id] = 0
	while game._mission_encounter_cursor < game.MISSION_ENCOUNTERS.size():
		var encounter: Dictionary = game.MISSION_ENCOUNTERS[game._mission_encounter_cursor]
		game.player.global_position.x = float(encounter["trigger_x"]) + 20.0
		game._process(0.0)
		while game._active_mission_encounter >= 0:
			_clear_active_wave(game)
			if game._active_mission_encounter >= 0:
				game._process(0.69)
	_expect(game.run_state == "boss_ready" and game.player.health == 63, "limited Boss cache did not add the configured 45 health")
	for weapon_id in WeaponData.ORDER:
		var data := WeaponData.get_weapon(weapon_id)
		var expected_floor := int(ceil(float(data["magazine_size"]) * 0.60))
		_expect(game.player.weapon_inventory.get_ammo_for(weapon_id) == expected_floor, "%s did not receive the 60%% Boss ammo floor" % weapon_id)


func _clear_active_wave(game: Node) -> void:
	var victims: Array[Node] = []
	for enemy in game.enemies.get_children():
		if bool(enemy.get("alive")) and bool(enemy.get_meta("counts_for_progress", false)):
			victims.append(enemy)
	for enemy in victims:
		enemy.take_damage(9999)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("COMBAT_PACING_PASS four gated multi-wave sectors, immediate unlock, stall recovery, two-telegraph cap, 520px readability, limited Boss cache")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
