extends SceneTree

const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")
const ProjectileScript := preload("res://scripts/combat/projectile.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_contract()
	var game := await _create_game()
	if game == null:
		_finish()
		return
	var player: CharacterBody2D = game.player
	for enemy in game.enemies.get_children():
		enemy.set_physics_process(false)
	_test_initial_state(game, player)
	await _test_input_switching(game, player)
	await _test_hold_fire_switch(player)
	await _test_shotgun_volley(player)
	await _test_pistol(player)
	game.queue_free()
	await process_frame

	var shotgun_game := await _create_game()
	if shotgun_game != null:
		await _test_shotgun_damage_and_single_death(shotgun_game)
		shotgun_game.queue_free()
		await process_frame

	var sniper_game := await _create_game()
	if sniper_game != null:
		await _test_sniper_penetration(sniper_game)
		sniper_game.queue_free()
		await process_frame
	_finish()


func _create_game() -> Node:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene failed to load for weapon tests")
	if packed == null:
		return null
	var game := packed.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await physics_frame
	return game


func _test_catalog_contract() -> void:
	_expect(WeaponData.ORDER == [&"rifle", &"shotgun", &"sniper", &"pistol"], "weapon slot order is not 1 rifle, 2 shotgun, 3 sniper, 4 pistol")
	var rifle := WeaponData.get_weapon(&"rifle")
	var shotgun := WeaponData.get_weapon(&"shotgun")
	var sniper := WeaponData.get_weapon(&"sniper")
	var pistol := WeaponData.get_weapon(&"pistol")
	for data in [rifle, shotgun, sniper, pistol]:
		for field in ["damage", "fire_rate", "projectile_speed", "projectile_count", "spread_angle", "recoil", "camera_shake", "knockback", "max_range", "damage_falloff", "penetration_count", "automatic_fire", "movement_accuracy", "airborne_accuracy"]:
			_expect(data.has(field), "%s is missing centralized field %s" % [data["display_name"], field])
	_expect(bool(rifle["automatic_fire"]) and not bool(shotgun["automatic_fire"]) and not bool(sniper["automatic_fire"]) and not bool(pistol["automatic_fire"]), "automatic/semi-auto fire modes are incorrect")
	_expect(int(shotgun["projectile_count"]) == 7 and float(shotgun["spread_angle"]) >= 14.0, "shotgun pellet count or cone is incorrect")
	_expect(int(sniper["penetration_count"]) == 2 and not bool(sniper["penetrate_heavy"]), "sniper penetration rule is incorrect")
	_expect(float(rifle["fire_rate"]) < float(pistol["fire_rate"]) and float(pistol["fire_rate"]) < float(sniper["fire_rate"]), "weapon fire-rate ordering is incorrect")


func _test_initial_state(game: Node, player: CharacterBody2D) -> void:
	for index in range(1, 5):
		_expect(InputMap.has_action("weapon_%d" % index), "weapon_%d input action is missing" % index)
	_expect(player.current_weapon_id == &"rifle", "player did not initialize with rifle")
	_expect(game.hud.weapon_slots.size() == 4, "HUD does not keep four weapon slots visible")
	_expect("AUTO RIFLE" in game.hud.weapon_name_label.text, "HUD initial weapon is incorrect")


func _test_input_switching(game: Node, player: CharacterBody2D) -> void:
	var ids: Array[StringName] = [&"shotgun", &"sniper", &"pistol", &"rifle"]
	for index in range(ids.size()):
		await _tap_action("weapon_%d" % (index + 2 if index < 3 else 1), 5)
		_expect(player.current_weapon_id == ids[index], "number-key switch failed for %s" % ids[index])
		_expect(String(player.weapon_inventory.get_current_data()["display_name"]) in game.hud.weapon_name_label.text, "HUD did not immediately follow %s" % ids[index])
		_expect(player.weapon.color == player.weapon_inventory.get_current_data()["color"], "held-weapon visual did not follow %s" % ids[index])
	var inventory_id: int = player.weapon_inventory.get_instance_id()
	var rifle_ammo: int = player.weapon_inventory.get_ammo()
	await _tap_action("weapon_1", 2)
	_expect(player.weapon_inventory.get_instance_id() == inventory_id and player.weapon_inventory.get_ammo() == rifle_ammo, "reselecting current weapon rebuilt or reset state")
	for press_index in range(20):
		await _tap_action("weapon_%d" % (press_index % 4 + 1), 0)
	_expect(WeaponData.ORDER.has(player.current_weapon_id) and player.weapon_inventory.get_instance_id() == inventory_id, "rapid 1-4 switching left an invalid or rebuilt weapon state")
	await _tap_action("weapon_1", 5)


func _test_hold_fire_switch(player: CharacterBody2D) -> void:
	if player.current_weapon_id != &"rifle":
		await _tap_action("weapon_1", 5)
	var weapon_ids: Array[StringName] = []
	player.volley_requested.connect(func(_origin: Vector2, _directions: Array[Vector2], _team: StringName, data: Dictionary, _damage: int) -> void:
		weapon_ids.append(data["id"])
	)
	player._using_mouse_aim = false
	player.aim_direction = Vector2.UP
	Input.action_press("fire")
	for _frame in range(12):
		await physics_frame
	Input.action_press("weapon_2")
	await physics_frame
	Input.action_release("weapon_2")
	for _frame in range(10):
		await physics_frame
	Input.action_release("fire")
	await physics_frame
	_expect(weapon_ids.count(&"rifle") >= 2, "rifle did not continue automatic fire before switch")
	_expect(weapon_ids.count(&"shotgun") == 0, "held fire leaked into semi-auto shotgun after switch")
	_expect(player.current_weapon_id == &"shotgun", "held-fire switch did not finish on shotgun")
	player.aim_direction = Vector2.RIGHT


func _test_shotgun_volley(player: CharacterBody2D) -> void:
	var volleys: Array[Array] = []
	player.volley_requested.connect(func(_origin: Vector2, directions: Array[Vector2], _team: StringName, data: Dictionary, _damage: int) -> void:
		if data["id"] == &"shotgun":
			volleys.append(directions.duplicate())
	)
	await _tap_action("fire", 40)
	_expect(volleys.size() == 1, "one shotgun trigger press did not create exactly one volley")
	if not volleys.is_empty():
		_expect(volleys[0].size() == 7, "shotgun volley did not create seven pellets")
		var first_angle: float = (volleys[0][0] as Vector2).angle()
		var last_angle: float = (volleys[0][-1] as Vector2).angle()
		_expect(rad_to_deg(absf(last_angle - first_angle)) >= 14.0, "shotgun pellet cone is narrower than configured")
		_expect(player.get_debug_snapshot()["last_pattern"].size() == 7, "shotgun debug directions were not recorded")


func _test_pistol(player: CharacterBody2D) -> void:
	await _tap_action("weapon_4", 5)
	var pistol_patterns: Array[Array] = []
	player.volley_requested.connect(func(_origin: Vector2, directions: Array[Vector2], _team: StringName, data: Dictionary, _damage: int) -> void:
		if data["id"] == &"pistol":
			pistol_patterns.append(directions.duplicate())
	)
	for _shot in range(3):
		await _tap_action("fire", 16)
	_expect(pistol_patterns.size() == 3, "pistol did not produce three responsive semi-auto shots")
	for directions in pistol_patterns:
		_expect(directions.size() == 1 and absf(rad_to_deg((directions[0] as Vector2).angle())) < 0.5, "pistol shot exceeded precision contract")


func _test_shotgun_damage_and_single_death(game: Node) -> void:
	var target := game._spawn_enemy("assault", Vector2(800.0, 552.0), 0.0, false, false) as CharacterBody2D
	target.set_physics_process(false)
	target.collision_layer = 4
	target.global_position = Vector2(800.0, 552.0)
	var death_count := [0]
	target.died.connect(func(_enemy: Node, _points: int) -> void: death_count[0] += 1)
	var data := WeaponData.get_weapon(&"shotgun")
	var close_damage := ProjectileScript.calculate_damage_at_distance(int(data["damage"]), 100.0, 220.0, 720.0, 0.25)
	var far_damage := ProjectileScript.calculate_damage_at_distance(int(data["damage"]), 700.0, 220.0, 720.0, 0.25)
	_expect(close_damage >= far_damage * 3, "shotgun close damage is not clearly above far damage: %d vs %d" % [close_damage, far_damage])
	var directions: Array[Vector2] = []
	for pellet in range(7):
		directions.append(Vector2.RIGHT.rotated(deg_to_rad(lerpf(-7.0, 7.0, float(pellet) / 6.0))))
	game._spawn_player_volley(Vector2(700.0, 544.0), directions, &"player", data, int(data["damage"]))
	for _frame in range(14):
		await physics_frame
	_expect(not target.alive and death_count[0] == 1, "shotgun multi-hit caused missing or duplicate death: %d" % death_count[0])


func _test_sniper_penetration(game: Node) -> void:
	var targets: Array[CharacterBody2D] = []
	for index in range(3):
		var target := game._spawn_enemy(["gunner", "assault", "elite"][index], Vector2(900.0 + index * 250.0, 552.0), 0.0, false, false) as CharacterBody2D
		target.set_physics_process(false)
		target.collision_layer = 4
		target.global_position = Vector2(900.0 + index * 250.0, 552.0)
		targets.append(target)
	var data := WeaponData.get_weapon(&"sniper")
	var directions: Array[Vector2] = [Vector2.RIGHT]
	game._spawn_player_volley(Vector2(700.0, 544.0), directions, &"player", data, int(data["damage"]))
	for _frame in range(18):
		await physics_frame
	_expect(not targets[0].alive and not targets[1].alive, "sniper did not penetrate and kill two normal targets")
	_expect(targets[2].kind == "elite" and targets[2].health == targets[2].max_health - int(data["damage"]), "sniper elite stop rule or damage is incorrect")
	_expect(game.projectiles.get_child_count() == 0, "sniper projectile did not stop at non-penetrable elite target")
	var sniper_look: float = game.camera.calculate_desired_look_ahead(260.0, 1.0, float(data["camera_aim_bonus"]))
	var rifle_look: float = game.camera.calculate_desired_look_ahead(260.0, 1.0)
	_expect(sniper_look > rifle_look, "sniper did not increase forward camera view")


func _tap_action(action: StringName, wait_frames: int) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)
	for _frame in range(wait_frames):
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for action in ["fire", "weapon_1", "weapon_2", "weapon_3", "weapon_4"]:
		Input.action_release(action)
	if failures.is_empty():
		print("WEAPON_SYSTEM_PASS switching, hold-fire isolation, rifle auto, shotgun spread/falloff/single-death, sniper penetration/elite-stop, pistol precision, HUD")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
