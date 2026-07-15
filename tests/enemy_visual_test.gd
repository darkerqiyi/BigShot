extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await physics_frame
	var spawn_x: float = float(game.player.global_position.x) + 220.0
	for index in range(4):
		game._spawn_enemy(["assault", "gunner", "shield", "elite"][index], Vector2(spawn_x + index * 100.0, 552.0), 99999.0, false, false)
	var enemies: Dictionary = {}
	for enemy in game.enemies.get_children():
		enemy.set_physics_process(false)
		if not enemies.has(enemy.kind):
			enemies[enemy.kind] = enemy
	_test_structure_scale_and_palette(game, enemies)
	_test_assault_visual(enemies["assault"], game.player)
	_test_gunner_muzzle(enemies["gunner"], game.player)
	_test_shield_states(enemies["shield"])
	_test_elite_states(enemies["elite"], game.player)
	_test_death_priority(enemies["assault"])
	game.queue_free()
	await process_frame
	_finish()


func _test_structure_scale_and_palette(game: Node, enemies: Dictionary) -> void:
	var player_shape := game.player.get_node("CollisionShape2D").shape as RectangleShape2D
	_expect(player_shape.size == Vector2(34, 64) and game.player.visual.scale == Vector2(1.25, 1.25), "player calibration changed physics or lost its 125% visual scale")
	var role_colors: Array[Color] = []
	for kind in ["assault", "gunner", "shield", "elite"]:
		var enemy: CharacterBody2D = enemies[kind]
		var shape := enemy.get_node("CollisionShape2D").shape as RectangleShape2D
		_expect(shape.size == Vector2(38, 58) and enemy.floor_snap_length == 8.0, "%s collision/floor baseline changed" % kind)
		_expect(enemy.has_node("EnemyVisual/MuzzlePoint") and enemy.has_node("EnemyVisual/VisualEffects"), "%s lacks separated visual/muzzle structure" % kind)
		_expect(not enemy.has_node("Visual/Body") and enemy.visual.enemy_kind == kind, "%s still uses the old geometric Body placeholder" % kind)
		_expect(enemy.visual.scale.x > 0.0 and enemy.visual.scale.y > 0.0, "%s visual uses negative scale" % kind)
		role_colors.append(enemy.visual.color)
	_expect(role_colors[0] != role_colors[1] and role_colors[1] != role_colors[3], "enemy role palette does not distinguish light, ranged, and elite silhouettes")
	_expect(enemies["assault"].max_health == 44 and enemies["gunner"].max_health == 58 and enemies["shield"].max_health == 92 and enemies["elite"].max_health == 230, "enemy health values changed during visual work")
	_expect(enemies["assault"].move_speed == 175.0 and enemies["gunner"].move_speed == 82.0 and enemies["shield"].move_speed == 68.0 and enemies["elite"].move_speed == 52.0, "enemy movement values changed during visual work")
	_expect(enemies["elite"].scale == Vector2(1.28, 1.28), "elite physical scale changed from baseline")


func _test_assault_visual(assault: CharacterBody2D, player: CharacterBody2D) -> void:
	assault.activate()
	assault.target = player
	assault._facing = 1.0
	assault.state = &"pursue"
	assault.velocity.x = assault.move_speed
	assault._sync_visual(0.05)
	_expect(assault.visual.base_animation_state == &"run", "assault pursue did not map to run")
	assault._start_melee(17, 0.32, 0.82)
	_expect(assault.visual.base_animation_state == &"attack_telegraph" and assault.warning.visible, "assault warning pose is not synchronized with real telegraph")
	assault._finish_attack()
	_expect(assault.visual.attack_remaining > 0.0 and assault.visual.animation_state == &"attack" and assault.state == &"recover", "assault attack/recover visual did not follow logic timing")


func _test_gunner_muzzle(gunner: CharacterBody2D, player: CharacterBody2D) -> void:
	gunner.activate()
	gunner.target = player
	gunner.global_position = player.global_position + Vector2(300, 0)
	gunner._facing = -1.0
	gunner.visual.set_facing(-1)
	var muzzle_before: Vector2 = gunner.visual.get_muzzle_global_position()
	var emitted_origins: Array[Vector2] = []
	gunner.shot_requested.connect(func(origin: Vector2, _direction: Vector2, _team: StringName, _damage: int, _speed: float) -> void: emitted_origins.append(origin))
	gunner._start_attack(12, 700.0, 0.38, 0.92)
	_expect(gunner.visual.base_animation_state == &"attack_telegraph", "gunner did not visibly raise weapon during real aim warning")
	gunner._finish_attack()
	_expect(emitted_origins.size() == 1 and emitted_origins[0].distance_to(muzzle_before) < 0.1, "gunner projectile origin does not equal visual muzzle")
	_expect(gunner.visual.muzzle_flash.visible and gunner.visual.scale.x > 0.0, "gunner shot lacks muzzle flash or left aim introduced negative scale")
	gunner.visual.set_facing(1)
	_expect(gunner.visual.muzzle_point.position.x == 24.0, "gunner right-facing muzzle did not restore")


func _test_shield_states(shield: CharacterBody2D) -> void:
	shield.activate()
	shield._facing = -1.0
	shield.visual.set_facing(-1)
	var before: int = shield.health
	shield.take_damage(40, Vector2.RIGHT * 100.0, shield.global_position, {"weapon_id": &"rifle", "direction": Vector2.RIGHT})
	_expect(before - shield.health <= 12 and shield.visual.animation_state == &"block" and shield.visual.block_remaining > 0.0, "real front block did not produce dedicated shield reaction")
	shield.visual.block_remaining = 0.0
	shield.guard_open_remaining = 0.0
	shield.take_damage(17, Vector2.RIGHT * 330.0, shield.global_position, {"weapon_id": &"shotgun", "direction": Vector2.RIGHT})
	shield.visual.block_remaining = 0.0
	shield._sync_visual(0.0)
	_expect(shield.guard_open_remaining >= 0.7 and shield.visual.guard_open and shield.visual.base_animation_state == &"guard_break", "shield break silhouette does not match real opening window")
	shield.visual.set_facing(1)
	_expect(shield.visual.scale.x > 0.0, "shield facing change uses negative scale")


func _test_elite_states(elite: CharacterBody2D, player: CharacterBody2D) -> void:
	elite.activate()
	elite.target = player
	elite._facing = -1.0
	elite._start_hazard(92.0, 22, 0.72, 1.1)
	_expect(elite.visual.enemy_kind == "elite" and elite.visual.base_animation_state == &"attack_telegraph" and elite.visual.pending_attack == &"hazard", "elite secondary attack lacks distinct heavy telegraph state")
	elite.take_damage(30, Vector2.ZERO, elite.global_position, {"weapon_id": &"sniper", "direction": Vector2.RIGHT})
	_expect(elite.stagger_remaining >= 0.14 and elite.visual.animation_state == &"hurt", "elite heavy hit did not produce hurt/stagger visual priority")


func _test_death_priority(enemy: CharacterBody2D) -> void:
	var death_count := [0]
	enemy.died.connect(func(_node: Node, _points: int) -> void: death_count[0] += 1)
	enemy.take_damage(9999)
	var state_after_death: StringName = enemy.visual.animation_state
	enemy.visual.update_from_logic(0.2, &"idle", Vector2.ZERO, 0.0, 0.0, 0.0, 0.0, &"projectile", true, false)
	_expect(death_count[0] == 1 and state_after_death == &"death" and enemy.visual.animation_state == &"death", "death was not highest visual priority")
	_expect(not enemy.is_physics_processing() and enemy.collision_layer == 0 and enemy.collision_mask == 0, "dead enemy retained AI or collision")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ENEMY_VISUAL_PASS player 125% calibration, four role silhouettes, logic-driven locomotion/telegraph/attack/recover, gunner muzzle sync, shield block/break, elite stagger, death priority")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
