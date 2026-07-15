extends SceneTree

const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy_game := await _create_game()
	if enemy_game != null:
		await _test_enemy_archetypes(enemy_game)
		enemy_game.queue_free()
		await process_frame
	var boss_game := await _create_game()
	if boss_game != null:
		await _test_boss_flow(boss_game)
		boss_game.queue_free()
		await process_frame
	_finish()


func _create_game() -> Node:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene failed to load")
	if packed == null:
		return null
	var game := packed.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await physics_frame
	return game


func _find_kind(game: Node, kind: String) -> CharacterBody2D:
	for enemy in game.enemies.get_children():
		if enemy.kind == kind:
			return enemy as CharacterBody2D
	return null


func _test_enemy_archetypes(game: Node) -> void:
	var player: CharacterBody2D = game.player
	# Mission enemies are now authored as gated waves instead of being resident at
	# scene load. Spawn one dormant representative of each existing archetype so
	# this focused contract test remains independent of mission pacing.
	game._spawn_enemy("assault", player.global_position + Vector2(180, 0), 99999.0, false, false)
	game._spawn_enemy("gunner", player.global_position + Vector2(360, 0), 99999.0, false, false)
	game._spawn_enemy("shield", player.global_position + Vector2(240, 0), 99999.0, false, false)
	game._spawn_enemy("elite", player.global_position + Vector2(420, -12), 99999.0, false, false)
	var assault := _find_kind(game, "assault")
	var gunner := _find_kind(game, "gunner")
	var shield := _find_kind(game, "shield")
	var elite := _find_kind(game, "elite")
	_expect(assault != null and gunner != null and shield != null and elite != null, "representative enemy setup lacks one or more required archetypes")
	if assault == null or gunner == null or shield == null or elite == null:
		return
	_expect(not assault.active and not gunner.active and not shield.active and not elite.active, "off-screen enemies did not start dormant")

	# Assault: readable windup before one bounded melee hit.
	assault.activate()
	assault.global_position = player.global_position + Vector2(80, 0)
	assault._facing = -1.0
	var hp_before: int = player.health
	assault._start_melee(17, 0.32, 0.82)
	_expect(assault.state == &"telegraph" and assault.warning.visible and is_equal_approx(assault.attack_windup_remaining, 0.32), "assault attack lacks its 0.32s warning")
	_expect(player.health == hp_before, "assault dealt damage before warning completed")
	assault._finish_attack()
	_expect(player.health == hp_before - 17 and assault.recovery_remaining >= 0.8, "assault melee or recovery window failed")

	# Gunner: repositions at close range, then emits only after telegraph.
	player._invulnerability_remaining = 0.0
	gunner.activate()
	gunner.global_position = player.global_position + Vector2(360, 0)
	gunner._facing = -1.0
	var projectile_before: int = game.projectiles.get_child_count()
	gunner._start_attack(12, 700.0, 0.38, 0.92)
	_expect(gunner.warning.visible and game.projectiles.get_child_count() == projectile_before, "gunner projectile appeared before aim warning")
	gunner._finish_attack()
	_expect(game.projectiles.get_child_count() == projectile_before + 1, "gunner did not fire after warning")
	game._clear_hostile_dangers()

	# Shield: front rifle damage is reduced, rear damage is normal, heavy hits open guard.
	shield.activate()
	shield._facing = -1.0
	var shield_start: int = shield.health
	shield.take_damage(40, Vector2.RIGHT * 100.0, shield.global_position, {"weapon_id": &"rifle", "direction": Vector2.RIGHT})
	var front_loss: int = shield_start - shield.health
	var before_rear: int = shield.health
	shield.take_damage(40, Vector2.LEFT * 100.0, shield.global_position, {"weapon_id": &"rifle", "direction": Vector2.LEFT})
	var rear_loss: int = before_rear - shield.health
	_expect(front_loss <= 12 and rear_loss == 40, "shield front/rear damage rule failed: %d / %d" % [front_loss, rear_loss])
	shield.take_damage(17, Vector2.RIGHT * 330.0, shield.global_position, {"weapon_id": &"shotgun", "direction": Vector2.RIGHT})
	_expect(shield.guard_open_remaining >= 0.7 and shield.stagger_remaining > 0.0, "shotgun did not create a shield opening")
	shield.guard_open_remaining = 0.0
	shield.take_damage(92, Vector2.RIGHT * 420.0, shield.global_position, {"weapon_id": &"sniper", "direction": Vector2.RIGHT})
	_expect(shield.guard_open_remaining >= 1.0 and shield.stagger_remaining >= 0.3, "sniper did not create a strong shield opening")

	# Elite: unique silhouette/high health and telegraphed area attack.
	elite.activate()
	_expect(elite.max_health >= 220 and elite.visual.enemy_kind == "elite" and elite.scale.x > 1.2, "elite is only a normal enemy without distinct profile")
	var hazard_before: int = game.hazards.get_child_count()
	elite._start_hazard(92.0, 22, 0.72, 1.1)
	_expect(elite.warning.visible and game.hazards.get_child_count() == hazard_before, "elite hazard lacked charge warning")
	elite._finish_attack()
	_expect(game.hazards.get_child_count() == hazard_before + 1, "elite hazard was not created after warning")
	game._clear_hostile_dangers()

	# Death is idempotent and stops AI, collision and further attacks.
	var death_count := [0]
	assault.died.connect(func(_enemy: Node, _points: int) -> void: death_count[0] += 1)
	assault.take_damage(9999)
	assault.take_damage(9999)
	_expect(death_count[0] == 1 and not assault.alive and not assault.active and assault.collision_layer == 0 and not assault.is_physics_processing(), "enemy death lifecycle was not idempotent")


func _test_boss_flow(game: Node) -> void:
	var player: CharacterBody2D = game.player
	game._debug_unlock_boss_for_tests()
	_expect(game.run_state == "boss_ready", "regular encounter did not unlock boss arena")
	player.global_position.x = 17850.0
	game._process(0.0)
	var boss: CharacterBody2D = game.boss
	_expect(game.run_state == "boss" and boss.active and boss.phase == 1, "boss did not start in phase one")
	_expect(game.hud.boss_panel.visible and game.hud.boss_actual_bar.value == boss.MAX_HEALTH, "boss HUD did not show full total health")
	_expect(game.boss_gate.collision_layer == 1 and game.boss_gate_visual.visible, "boss arena boundary did not lock")

	# Phase-one attacks alternate and every attack starts with warning.
	boss.recovery_remaining = 0.0
	boss.attack_cooldown = 0.0
	boss._select_attack()
	var first_attack: StringName = boss._pending_attack
	_expect(boss.state == &"telegraph" and boss.warning.visible and boss.windup_remaining >= 0.5, "boss attack started without readable warning")
	boss.windup_remaining = 0.0
	boss._execute_attack()
	if boss.charge_remaining > 0.0:
		boss.charge_remaining = 0.0
		boss._finish_attack(0.1)
	game._clear_hostile_dangers()
	boss.recovery_remaining = 0.0
	boss.attack_cooldown = 0.0
	boss._select_attack()
	_expect(boss._pending_attack != first_attack, "boss repeated the same attack consecutively")
	boss.windup_remaining = 0.0
	boss.warning.visible = false
	boss.recovery_remaining = 0.0

	var phase_events: Array[int] = []
	boss.phase_changed.connect(func(value: int) -> void: phase_events.append(value))
	var phase_two_damage: int = boss.health - int(boss.MAX_HEALTH * 0.62)
	boss.take_damage(phase_two_damage, Vector2.ZERO, boss.global_position, {"weapon_id": &"rifle", "direction": Vector2.RIGHT})
	_expect(boss.phase == 2 and boss.invulnerable and phase_events == [2], "phase two did not trigger exactly once at 65% threshold")
	var transition_health: int = boss.health
	boss.take_damage(200, Vector2.ZERO, boss.global_position, {"weapon_id": &"sniper", "direction": Vector2.RIGHT})
	_expect(boss.health == transition_health, "boss transition invulnerability did not prevent threshold bypass")
	_expect(game.boss_summons_alive == 2, "phase-two summons did not respect the two-enemy cap")
	for _frame in range(56):
		await physics_frame
	_expect(not boss.invulnerable and boss.phase == 2, "phase-two transition did not end cleanly")

	# Area attack, delayed HUD and third threshold.
	var hazards_before: int = game.hazards.get_child_count()
	boss._begin_attack(&"area", 0.1)
	for _frame in range(8):
		await physics_frame
	_expect(game.hazards.get_child_count() >= hazards_before + 2, "phase-two area attack did not create warned zones")
	game._clear_hostile_dangers()
	var phase_three_target := int(boss.MAX_HEALTH * 0.28)
	boss.take_damage(boss.health - phase_three_target, Vector2.ZERO, boss.global_position, {"weapon_id": &"pistol", "direction": Vector2.RIGHT})
	_expect(boss.phase == 3 and phase_events == [2, 3], "phase three did not trigger exactly once at 30% threshold")
	_expect(int(game.hud.boss_actual_bar.value) == boss.health and game.hud.boss_delayed_bar.value >= game.hud.boss_actual_bar.value, "boss HUD real/delayed health layers are incorrect")
	for _frame in range(56):
		await physics_frame

	# Sniper hits once and cannot penetrate the boss body.
	boss.recovery_remaining = 1.0
	var sniper := WeaponData.get_weapon(&"sniper")
	var sniper_directions: Array[Vector2] = [Vector2.RIGHT]
	var sniper_health: int = boss.health
	game._spawn_player_volley(boss.global_position + Vector2(-180, -5), sniper_directions, &"player", sniper, int(sniper["damage"]))
	for _frame in range(8):
		await physics_frame
	_expect(boss.health == sniper_health - int(sniper["damage"]), "sniper did not deal exactly one boss hit")
	_expect(game.projectiles.get_child_count() == 0, "sniper incorrectly penetrated the boss")

	# Multi-pellet lethal damage emits one death, clears hazards/projectiles/summons and settles.
	var boss_deaths := [0]
	boss.died.connect(func(_node: Node) -> void: boss_deaths[0] += 1)
	boss.health = 34
	boss.invulnerable = false
	var shotgun := WeaponData.get_weapon(&"shotgun")
	var pellet_directions: Array[Vector2] = []
	for pellet in range(7):
		pellet_directions.append(Vector2.RIGHT.rotated(deg_to_rad(lerpf(-6.0, 6.0, float(pellet) / 6.0))))
	game._spawn_hazard(player.global_position + Vector2(0, 30), 60.0, 10, 2.0, &"boss")
	game._spawn_projectile(boss.global_position, Vector2.LEFT, &"enemy", 5, 400.0)
	game._spawn_player_volley(boss.global_position + Vector2(-100, -5), pellet_directions, &"player", shotgun, int(shotgun["damage"]))
	for _frame in range(10):
		await physics_frame
	_expect(boss_deaths[0] == 1 and not boss.alive and boss.state == &"dead", "shotgun caused missing or duplicate boss death")
	_expect(game.hazards.get_child_count() == 0 and _count_enemy_projectiles(game) == 0 and game.boss_summons_alive == 0, "boss death left hazards, projectiles, or summons")
	_expect(game.boss_gate.collision_layer == 0 and not game.boss_gate_visual.visible, "boss death did not release arena boundary")
	await create_timer(1.0).timeout
	_expect(game.run_state == "complete" and not player.controls_enabled, "boss defeat did not enter final settlement")


func _count_enemy_projectiles(game: Node) -> int:
	var count := 0
	for projectile in game.projectiles.get_children():
		if projectile.team == &"enemy":
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ENEMY_BOSS_PASS assault warning/recovery, gunner telegraph, shield front/opening, elite hazard, staged activation, boss phases/UI/attacks/summons/cleanup/settlement")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
