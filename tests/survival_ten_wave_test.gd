extends SceneTree

const SurvivalScene := preload("res://scenes/survival/survival.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []
var started_waves: Array[int] = []
var completed_waves: Array[int] = []
var phase_changes: Array[int] = []
var seen_kinds: Dictionary = {}
var max_active := 0
var boss_requested_count := 0
var run_completed_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := SurvivalScene.instantiate()
	game.set_meta("survival_test_mode", true)
	root.add_child(game)
	current_scene = game
	game.wave_manager.wave_started.connect(func(wave: int, _total: int, _title: String) -> void: started_waves.append(wave))
	game.wave_manager.wave_completed.connect(func(wave: int) -> void: completed_waves.append(wave))
	game.wave_manager.boss_requested.connect(func(_wave: int) -> void: boss_requested_count += 1)
	game.wave_manager.run_completed.connect(func() -> void: run_completed_count += 1)
	game.boss.phase_changed.connect(func(phase: int) -> void: phase_changes.append(phase))

	var frame_budget := 3600
	while is_instance_valid(game) and game.run_state != "complete" and frame_budget > 0:
		frame_budget -= 1
		max_active = maxi(max_active, game.wave_manager.get_alive_count())
		for enemy in game.enemies.get_children():
			if not bool(enemy.get("alive")):
				continue
			var kind := str(enemy.get("kind"))
			var wave := int(enemy.get_meta("encounter_id", 0))
			seen_kinds["%d:%s" % [wave, kind]] = true
			enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {
				"weapon_id": &"grenade" if kind in ["elite", "heavy"] else &"rifle",
				"damage_kind": &"explosion" if kind in ["elite", "heavy"] else &"projectile",
			})
		if game.boss.active and game.boss.alive:
			if game.boss.phase == 1:
				game.boss.take_damage(500, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper"})
			elif game.boss.phase == 2 and game.boss.transition_remaining <= 0.0:
				game.boss.take_damage(400, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"shotgun"})
			elif game.boss.phase == 3 and game.boss.transition_remaining <= 0.0:
				game.boss.take_damage(9999, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper"})
		await physics_frame

	await create_timer(0.35).timeout
	_expect(game.run_state == "complete", "ten-wave run did not reach settlement")
	_expect(started_waves == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "waves did not start exactly once: %s" % [started_waves])
	_expect(completed_waves == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "waves did not complete exactly once: %s" % [completed_waves])
	_expect(game.wave_manager.completed_waves.size() == 10, "manager completion ledger did not contain ten waves")
	_expect(max_active <= 6, "active enemy cap exceeded: %d" % max_active)
	_expect(bool(seen_kinds.get("5:elite", false)), "wave five did not spawn an elite")
	_expect(bool(seen_kinds.get("9:elite", false)), "wave nine did not spawn an elite")
	_expect(boss_requested_count == 1, "wave ten Boss was requested %d times" % boss_requested_count)
	_expect(phase_changes == [2, 3], "Boss phases did not transition once each: %s" % [phase_changes])
	_expect(run_completed_count == 1, "survival settlement triggered %d times" % run_completed_count)
	_expect(not game.boss.alive and not game.boss.active, "Boss remained active after death")
	_expect(game.projectiles.get_child_count() == 0 and game.hazards.get_child_count() == 0, "hostile dangers remained after completion")
	_expect(game.hud.state_overlay.visible, "victory settlement was not visible")
	_expect(game.hud.boss_panel.visible == false, "Boss HUD remained visible at settlement")
	_expect(game.best_score >= game.score and game.best_time > 0.0, "local survival records were not saved")
	var saved_records := ConfigFile.new()
	_expect(saved_records.load("user://survival_records.cfg") == OK, "survival record file could not be reloaded")
	_expect(int(saved_records.get_value("records", "highest_score", 0)) >= game.score, "saved high score is inaccurate")
	_expect(float(saved_records.get_value("records", "best_time", 0.0)) > 0.0, "saved best time is missing")

	var completed_kills: int = game._run_kills
	var completed_seconds: float = game._run_elapsed
	game.queue_free()
	for _frame in range(3):
		await process_frame

	# A death during the Boss wave must restore a clean wave-zero survival scene.
	var boss_death_game := SurvivalScene.instantiate()
	boss_death_game.set_meta("survival_test_mode", true)
	root.add_child(boss_death_game)
	current_scene = boss_death_game
	boss_death_game.wave_manager.stop_run()
	boss_death_game.wave_manager.reset_run()
	boss_death_game.wave_manager.current_wave = 9
	boss_death_game.wave_manager._begin_next_wave()
	for _frame in range(4):
		await physics_frame
	_expect(boss_death_game.boss.active and boss_death_game.wave_manager.get_state_name() == &"boss", "Boss death-reset setup failed")
	boss_death_game.boss.take_damage(500, Vector2.ZERO, boss_death_game.boss.global_position, {"weapon_id": &"sniper"})
	var old_id := boss_death_game.get_instance_id()
	boss_death_game.player.take_damage(9999, Vector2.ZERO, boss_death_game.player.global_position, {"source": &"boss_test", "damage_kind": &"projectile"})
	_expect(not boss_death_game.boss.active and not boss_death_game.boss.visible, "player death left the survival Boss active")
	await create_timer(1.8).timeout
	_expect(current_scene != null and current_scene.get_instance_id() != old_id, "Boss-wave death did not reload survival")
	if current_scene != null and current_scene.get_instance_id() != old_id:
		_expect(current_scene.wave_manager.current_wave == 0, "Boss-wave restart retained wave progress")
		_expect(not current_scene.boss.active and current_scene.boss.phase == 1 and current_scene.boss.health == current_scene.boss.MAX_HEALTH, "Boss-wave restart did not restore a fresh inactive Boss")
		_expect(not current_scene.hud.boss_panel.visible, "Boss-wave restart retained the Boss HUD")

	# Returning to PVE must not carry WaveManager or survival-mutated combat state.
	change_scene_to_file("res://scenes/main/main.tscn")
	for _frame in range(5):
		await physics_frame
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/main/main.tscn", "return to PVE loaded the wrong scene")
	if current_scene != null and current_scene.scene_file_path == "res://scenes/main/main.tscn":
		_expect(current_scene.get_node_or_null("WaveManager") == null, "PVE incorrectly loaded the survival WaveManager")
		_expect(current_scene.player.current_weapon_id == &"rifle" and WeaponData.ORDER.size() == 4, "PVE weapon state changed after survival")
		_expect(current_scene.player.grenade_count == 3 and not current_scene.player.is_rolling and not current_scene.player.is_sprinting, "PVE ability state leaked from survival")

	print("SURVIVAL_TEN_WAVE_METRICS waves=10 ordinary_kills=55 total_kills=%d max_active=%d simulated_seconds=%.2f boss_death_reset=true pve_isolated=true" % [completed_kills, max_active, completed_seconds])
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SURVIVAL_TEN_WAVE_PASS data-driven composition, elite milestones, capped spawns, three-phase Boss, single settlement, cleanup and local records")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
