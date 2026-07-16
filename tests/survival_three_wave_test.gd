extends SceneTree

const SurvivalScene := preload("res://scenes/survival/survival.tscn")

var failures: Array[String] = []
var started_waves: Array[int] = []
var completed_waves: Array[int] = []
var max_active := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := SurvivalScene.instantiate()
	game.set_meta("survival_test_mode", true)
	game.set_meta("survival_phase_a_test", true)
	root.add_child(game)
	current_scene = game
	game.wave_manager.wave_started.connect(func(wave: int, _total: int, _title: String) -> void: started_waves.append(wave))
	game.wave_manager.wave_completed.connect(func(wave: int) -> void: completed_waves.append(wave))

	# Pausing must freeze the deployment countdown instead of advancing a wave.
	var before_pause: float = game.wave_manager.countdown_remaining
	paused = true
	for _frame in range(4):
		await process_frame
	var after_pause: float = game.wave_manager.countdown_remaining
	paused = false
	_expect(is_equal_approx(before_pause, after_pause), "pause advanced the wave countdown")

	var frame_budget := 1800
	while is_instance_valid(game) and game.run_state != "complete" and frame_budget > 0:
		frame_budget -= 1
		max_active = maxi(max_active, game.wave_manager.get_alive_count())
		for enemy in game.enemies.get_children():
			if bool(enemy.get("alive")):
				enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {
					"weapon_id": &"rifle",
					"damage_kind": &"projectile",
				})
		await physics_frame

	_expect(game.run_state == "complete", "three-wave run did not reach settlement")
	_expect(started_waves == [1, 2, 3], "waves did not start exactly once in order: %s" % [started_waves])
	_expect(completed_waves == [1, 2, 3], "waves did not complete exactly once in order: %s" % [completed_waves])
	_expect(game.wave_manager.completed_waves == [1, 2, 3], "manager completion ledger is inaccurate")
	_expect(max_active <= 6, "active enemy cap exceeded: %d" % max_active)
	_expect(game._run_kills == 13, "expected 13 unique enemy kills, got %d" % game._run_kills)
	_expect(game.hud.survival_panel.visible, "survival HUD was not visible")
	_expect(not game.hud.get_node("Objective").visible, "PVE objective HUD leaked into survival")

	game.queue_free()
	for _frame in range(3):
		await process_frame

	# Death must stop generation and reload a completely fresh survival run.
	var death_game := SurvivalScene.instantiate()
	death_game.set_meta("survival_test_mode", true)
	death_game.set_meta("survival_phase_a_test", true)
	root.add_child(death_game)
	current_scene = death_game
	for _frame in range(12):
		await physics_frame
	var old_id := death_game.get_instance_id()
	death_game.player.take_damage(9999, Vector2.ZERO, death_game.player.global_position, {
		"source": &"test_projectile",
		"damage_kind": &"projectile",
	})
	_expect(death_game.run_state == "dead", "player death did not stop the survival run")
	_expect(death_game.wave_manager.get_state_name() == &"stopped", "wave manager kept running after player death")
	await create_timer(1.8).timeout
	_expect(current_scene != null and current_scene.get_instance_id() != old_id, "survival death did not reload the scene")
	if current_scene != null and current_scene.get_instance_id() != old_id:
		_expect(current_scene.scene_file_path == "res://scenes/survival/survival.tscn", "death returned to the wrong mode")
		_expect(current_scene.player.alive and current_scene.player.health == current_scene.player.MAX_HEALTH, "restarted survival player was not fresh")
		_expect(current_scene.wave_manager.current_wave == 0, "restarted survival retained the old wave")
		_expect(current_scene.enemies.get_child_count() == 0, "restarted survival retained old enemies")
		_expect(current_scene.projectiles.get_child_count() == 0 and current_scene.grenades.get_child_count() == 0, "restarted survival retained combat objects")

	print("SURVIVAL_THREE_WAVE_METRICS waves=3 kills=13 max_active=%d death_reload=true" % max_active)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	paused = false
	if failures.is_empty():
		print("SURVIVAL_THREE_WAVE_PASS ordered waves, capped spawning, pause-safe countdown, unique kills, isolated HUD, death cleanup and restart")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
