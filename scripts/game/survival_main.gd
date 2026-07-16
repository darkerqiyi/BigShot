extends "res://scripts/game/main.gd"

const SurvivalWaveManagerScript := preload("res://scripts/survival/wave_manager.gd")
const SurvivalWaveData := preload("res://scripts/survival/survival_wave_data.gd")
const SpawnWarningScript := preload("res://scripts/survival/spawn_warning.gd")
const SurvivalArenaArtScript := preload("res://scripts/survival/survival_arena_art.gd")
const SurvivalBalanceTelemetryScript := preload("res://scripts/debug/survival_balance_telemetry.gd")

const ARENA_LEFT := 16.0
const ARENA_RIGHT := 1264.0
const ARENA_CENTER := 640.0
const PLAYER_START := Vector2(640.0, 552.0)
const SPAWN_PROTECTION_TIME := 0.48

var wave_manager: SurvivalWaveManager
var highest_combo := 0
var current_combo := 0
var combo_remaining := 0.0
var weapon_kills := {
	&"rifle": 0,
	&"shotgun": 0,
	&"sniper": 0,
	&"pistol": 0,
}
var grenade_kills := 0
var survival_balance_telemetry: Node
var best_score := 0
var best_time := 0.0
var _spawn_positions: Dictionary = {}
var _last_counter_snapshot := {
	"wave": 0,
	"total": 3,
	"alive": 0,
	"pending": 0,
	"countdown": 0.0,
	"state": &"idle",
}


func _setup_mission() -> void:
	# Survival deliberately does not create mission gates, hazards, pickups, or
	# the authored PVE encounter flow.
	mission_gate = null


func _ready() -> void:
	super._ready()
	run_state = "survival_countdown"
	player.global_position = PLAYER_START
	player.velocity = Vector2.ZERO
	camera.level_width = 1280.0
	camera.global_position = Vector2(ARENA_CENTER, camera.fixed_y)
	boss.global_position = Vector2(1010.0, 520.0)
	boss.arena_left = 110.0
	boss.arena_right = 1170.0
	boss.phase_two_summon_positions = PackedVector2Array([
		Vector2(280.0, 552.0),
		Vector2(1000.0, 552.0),
	])
	boss_gate.collision_layer = 0
	boss_gate_visual.visible = false
	_create_arena_boundaries()
	_create_arena_art()
	wave_manager = SurvivalWaveManagerScript.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	var waves := SurvivalWaveData.phase_a_waves() if bool(get_meta("survival_phase_a_test", false)) else SurvivalWaveData.full_waves()
	wave_manager.configure(waves, 6)
	if bool(get_meta("survival_test_mode", false)):
		wave_manager.set_debug_timings(0.03, 0.04, 0.02, 0.01)
	wave_manager.wave_started.connect(_on_survival_wave_started)
	wave_manager.spawn_warning_requested.connect(_on_spawn_warning_requested)
	wave_manager.spawn_requested.connect(_on_survival_spawn_requested)
	wave_manager.counters_changed.connect(_on_survival_counters_changed)
	wave_manager.rest_started.connect(_on_survival_rest_started)
	wave_manager.wave_completed.connect(_on_survival_wave_completed)
	wave_manager.boss_requested.connect(_on_survival_boss_requested)
	wave_manager.run_completed.connect(_on_survival_run_completed)
	if OS.is_debug_build() and not bool(get_meta("survival_test_mode", false)):
		survival_balance_telemetry = SurvivalBalanceTelemetryScript.new()
		survival_balance_telemetry.name = "SurvivalBalanceTelemetry"
		add_child(survival_balance_telemetry)
		survival_balance_telemetry.configure(player, telemetry, _run_elapsed)
	_load_survival_records()
	hud.set_survival_mode(true)
	hud.hide_objective(true)
	hud.show_banner("SURVIVAL PROTOCOL ONLINE", Color("55e39a"), false, 1.0)
	sfx.play_music(&"level", 0.28)
	wave_manager.start_run()


func _process(delta: float) -> void:
	super._process(delta)
	if wave_manager != null and run_state not in ["dead", "complete"]:
		combo_remaining = maxf(combo_remaining - delta, 0.0)
		if is_zero_approx(combo_remaining):
			current_combo = 0
		_recover_survival_enemies()
		_refresh_survival_hud()
		if survival_balance_telemetry != null:
			var active_count := 0
			var attacking_count := 0
			for enemy in enemies.get_children():
				if bool(enemy.get("alive")) and bool(enemy.get("active")):
					active_count += 1
					if StringName(enemy.get("state")) in [&"telegraph", &"attack"]:
						attacking_count += 1
			survival_balance_telemetry.sample(
				_run_elapsed,
				active_count,
				maxi(attacking_count, combat_pacing.active_attack_count()),
				projectiles.get_child_count(),
				effects.get_child_count(),
			)


func _create_arena_boundaries() -> void:
	var right_wall := StaticBody2D.new()
	right_wall.name = "SurvivalRightWall"
	right_wall.position = Vector2(1280.0, 360.0)
	right_wall.collision_layer = 1
	right_wall.collision_mask = 6
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32.0, 720.0)
	shape_node.shape = shape
	right_wall.add_child(shape_node)
	world.add_child(right_wall)


func _create_arena_art() -> void:
	var art := SurvivalArenaArtScript.new()
	art.name = "SurvivalArenaArt"
	world.add_child(art)


func _on_survival_wave_started(wave_number: int, total: int, title: String) -> void:
	run_state = "boss" if wave_manager.is_boss_wave(wave_number) else "survival_combat"
	combat_pacing.set_normal_attack_slots(1 if wave_number <= 2 else 2)
	hud.show_banner("WAVE %02d // %s" % [wave_number, title], Color("ffb347"), false, 0.72)
	sfx.play_cue(&"mission_start")
	if survival_balance_telemetry != null:
		survival_balance_telemetry.begin_wave(wave_number, title, _run_elapsed)


func _on_spawn_warning_requested(ticket: int, _kind: String, side: String, warning_time: float) -> void:
	var spawn_position := _choose_spawn_position(side, ticket)
	_spawn_positions[ticket] = spawn_position
	var warning := SpawnWarningScript.new()
	warning.global_position = spawn_position
	warning.configure(warning_time)
	effects.add_child(warning)


func _on_survival_spawn_requested(ticket: int, kind: String, side: String) -> void:
	if run_state in ["dead", "complete", "survival_dead", "survival_complete"]:
		return
	var spawn_position: Vector2 = _spawn_positions.get(ticket, _choose_spawn_position(side, ticket))
	_spawn_positions.erase(ticket)
	var enemy := _spawn_enemy(kind, spawn_position, 0.0, false, false, wave_manager.current_wave)
	wave_manager.register_spawned(ticket, enemy)
	if survival_balance_telemetry != null:
		survival_balance_telemetry.record_spawn(kind)
	var timer := get_tree().create_timer(SPAWN_PROTECTION_TIME)
	timer.timeout.connect(_activate_spawned_enemy.bind(enemy.get_instance_id()))


func _activate_spawned_enemy(instance_id: int) -> void:
	var enemy := instance_from_id(instance_id)
	if enemy != null and bool(enemy.get("alive")) and run_state not in ["dead", "complete", "survival_dead", "survival_complete"]:
		enemy.activate()


func _choose_spawn_position(side: String, ticket: int) -> Vector2:
	var left_positions := [Vector2(120.0, 552.0), Vector2(270.0, 552.0)]
	var right_positions := [Vector2(1010.0, 552.0), Vector2(1160.0, 552.0)]
	var candidates: Array = []
	if side == "left":
		candidates = left_positions
	elif side == "right":
		candidates = right_positions
	elif side == "far":
		candidates = left_positions if player.global_position.x >= ARENA_CENTER else right_positions
	elif side in ["split", "edges"]:
		candidates = left_positions if ticket % 2 == 0 else right_positions
	else:
		candidates = left_positions + right_positions
	var safe: Array[Vector2] = []
	for candidate_value in candidates:
		var candidate: Vector2 = candidate_value
		var clear_of_enemy := true
		for enemy in enemies.get_children():
			if bool(enemy.get("alive")) and candidate.distance_to(enemy.global_position) < 96.0:
				clear_of_enemy = false
				break
		if candidate.distance_to(player.global_position) >= 360.0 and clear_of_enemy:
			safe.append(candidate)
	if safe.is_empty():
		safe = [Vector2(120.0, 552.0) if player.global_position.x > ARENA_CENTER else Vector2(1160.0, 552.0)]
	return safe[absi(ticket) % safe.size()]


func _on_survival_counters_changed(wave_number: int, total: int, alive_count: int, pending_count: int, countdown: float, state: StringName) -> void:
	_last_counter_snapshot = {
		"wave": wave_number,
		"total": total,
		"alive": alive_count,
		"pending": pending_count,
		"countdown": countdown,
		"state": state,
	}
	_refresh_survival_hud()


func _refresh_survival_hud() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	hud.set_survival_status(
		int(_last_counter_snapshot["wave"]),
		int(_last_counter_snapshot["total"]),
		int(_last_counter_snapshot["alive"]),
		int(_last_counter_snapshot["pending"]),
		float(_last_counter_snapshot["countdown"]),
		StringName(_last_counter_snapshot["state"]),
		_run_elapsed,
		_run_kills,
	)


func _on_survival_rest_started(completed_wave: int, duration: float) -> void:
	run_state = "survival_rest"
	_clear_hostile_dangers()
	for grenade in grenades.get_children():
		grenade.queue_free()
	if completed_wave in [3, 5, 7, 9]:
		var health_supply := int({3: 12, 5: 24, 7: 18, 9: 30}[completed_wave])
		var ammo_floor := float({3: 0.50, 5: 0.70, 7: 0.60, 9: 0.82}[completed_wave])
		var grenades_supply := int({3: 1, 5: 2, 7: 1, 9: 3}[completed_wave])
		player.apply_field_resupply(health_supply, ammo_floor, grenades_supply)
		if survival_balance_telemetry != null:
			survival_balance_telemetry.record_supply(health_supply, ammo_floor, grenades_supply)
		var cache_name := "BOSS CACHE" if completed_wave == 9 else "FIELD CACHE"
		var cache_message := "%s // HP +%d  •  AMMO %d%%  •  GRENADE +%d" % [
			cache_name, health_supply, int(ammo_floor * 100.0), grenades_supply,
		]
		hud.show_banner(cache_message, Color("55e39a"), false, 1.1)
	else:
		hud.show_banner("WAVE CLEAR // REST %.0f SEC" % duration, Color("55e39a"), false, 0.9)


func _on_survival_wave_completed(wave_number: int) -> void:
	_clear_hostile_dangers()
	if survival_balance_telemetry != null:
		survival_balance_telemetry.complete_wave(wave_number, _run_elapsed)


func _on_survival_boss_requested(_wave_number: int) -> void:
	_clear_hostile_dangers()
	combat_pacing.set_boss_mode(true)
	boss_summons_alive = 0
	_boss_defeat_pending = false
	boss.global_position = Vector2(1010.0, 520.0)
	boss.activate(player)
	if telemetry != null:
		telemetry.boss_started()
	hud.begin_boss_intro(boss.boss_name, boss.MAX_HEALTH)
	combat_feedback.request_shake(&"boss_intro", &"survival_boss_intro")
	sfx.play_cue(&"boss_intro")
	sfx.play_music(&"boss", 0.45)


func _on_boss_died(_defeated_boss: Node) -> void:
	if _boss_defeat_pending or wave_manager == null or wave_manager.get_state_name() != &"boss":
		return
	_boss_defeat_pending = true
	_run_kills += 1
	score += 1500
	hud.set_score(score)
	combat_pacing.set_boss_mode(false)
	run_state = "survival_boss_defeated"
	_clear_hostile_dangers()
	for grenade in grenades.get_children():
		grenade.queue_free()
	for enemy in enemies.get_children():
		if bool(enemy.get_meta("boss_summon", false)):
			enemy.queue_free()
	boss_summons_alive = 0
	hud.set_boss_health(0, boss.MAX_HEALTH, 3)
	hud.show_boss_defeated()
	sfx.stop_bus_cues(&"Boss")
	sfx.play_world_cue(&"boss_failure", boss.global_position, player.global_position, true)
	combat_feedback.request_shake(&"boss_death", &"survival_boss_death")
	await get_tree().create_timer(0.18).timeout
	sfx.play_world_cue(&"boss_explosion", boss.global_position, player.global_position, true)
	await get_tree().create_timer(0.35).timeout
	sfx.play_world_cue(&"boss_death", boss.global_position, player.global_position, true)
	hud.hide_boss()
	wave_manager.boss_defeated()


func _on_enemy_died(enemy: Node, points: int) -> void:
	if bool(enemy.get_meta("survival_death_counted", false)):
		return
	enemy.set_meta("survival_death_counted", true)
	var instance_id := enemy.get_instance_id()
	var weapon_id: StringName = enemy.get("last_damage_weapon_id")
	super._on_enemy_died(enemy, points)
	if wave_manager != null:
		wave_manager.enemy_defeated(instance_id)
	current_combo = current_combo + 1 if combo_remaining > 0.0 else 1
	combo_remaining = 3.5
	highest_combo = maxi(highest_combo, current_combo)
	if weapon_id == &"grenade":
		grenade_kills += 1
	elif weapon_kills.has(weapon_id):
		weapon_kills[weapon_id] = int(weapon_kills[weapon_id]) + 1
	if survival_balance_telemetry != null:
		survival_balance_telemetry.record_defeat(str(enemy.get("kind")), weapon_id)


func _on_player_damage_received(amount: int, context: Dictionary) -> void:
	super._on_player_damage_received(amount, context)
	if survival_balance_telemetry != null:
		survival_balance_telemetry.record_player_damage(amount, context)
	current_combo = 0
	combo_remaining = 0.0


func _on_player_died() -> void:
	if _restart_pending:
		return
	_restart_pending = true
	run_state = "dead"
	wave_manager.stop_run()
	_clear_survival_runtime(true)
	sfx.stop_bus_cues(&"Boss")
	if telemetry != null:
		telemetry.record_death(player.global_position)
	if survival_balance_telemetry != null:
		survival_balance_telemetry.finish(&"death", _run_elapsed)
	combat_feedback.request_shake(&"player_death", &"player_death")
	sfx.play_cue(&"player_death")
	sfx.duck_music(0.55, 5.0)
	hud.show_survival_death(wave_manager.current_wave, _run_elapsed, _run_kills, player.last_damage_source)
	await get_tree().create_timer(Tuning.DEATH_RESTART_DELAY).timeout
	_restart_scene()


func _on_survival_run_completed() -> void:
	if run_state == "complete":
		return
	run_state = "complete"
	if telemetry != null:
		telemetry.finish(&"complete")
	if survival_balance_telemetry != null:
		survival_balance_telemetry.finish(&"complete", _run_elapsed)
	player.controls_enabled = false
	_clear_hostile_dangers()
	for grenade in grenades.get_children():
		grenade.queue_free()
	hud.set_survival_status(wave_manager.current_wave, wave_manager.total_waves, 0, 0, 0.0, &"complete", _run_elapsed, _run_kills)
	_save_survival_records()
	hud.show_survival_settlement({
		"score": score,
		"elapsed": _run_elapsed,
		"kills": _run_kills,
		"highest_combo": highest_combo,
		"weapon_kills": weapon_kills.duplicate(),
		"grenade_kills": grenade_kills,
		"roll_evades": player.projectile_dodges,
		"best_score": best_score,
		"best_time": best_time,
	})
	sfx.stop_music(0.45)
	sfx.play_cue(&"mission_complete")


func _clear_survival_runtime(include_boss: bool = true) -> void:
	for container in [enemies, projectiles, hazards, grenades]:
		for child in container.get_children():
			child.queue_free()
	if include_boss and boss.active:
		boss.active = false
		boss.alive = false
		boss.visible = false
		boss.collision_layer = 0


func _load_survival_records() -> void:
	var config := ConfigFile.new()
	if config.load("user://survival_records.cfg") == OK:
		best_score = int(config.get_value("records", "highest_score", 0))
		best_time = float(config.get_value("records", "best_time", 0.0))


func _save_survival_records() -> void:
	best_score = maxi(best_score, score)
	if best_time <= 0.0 or _run_elapsed < best_time:
		best_time = _run_elapsed
	var config := ConfigFile.new()
	config.set_value("records", "highest_score", best_score)
	config.set_value("records", "best_time", best_time)
	config.save("user://survival_records.cfg")


func _recover_survival_enemies() -> void:
	for enemy in enemies.get_children():
		if not bool(enemy.get("alive")):
			continue
		if enemy.global_position.y > 760.0 or enemy.global_position.x < ARENA_LEFT - 40.0 or enemy.global_position.x > ARENA_RIGHT + 40.0:
			enemy.global_position = Vector2(120.0 if player.global_position.x > ARENA_CENTER else 1160.0, 552.0)
			enemy.velocity = Vector2.ZERO


func _update_objective() -> void:
	if wave_manager != null:
		_refresh_survival_hud()


func _restart_scene() -> void:
	get_tree().paused = false
	if combat_feedback != null:
		combat_feedback.clear()
	get_tree().reload_current_scene()


func _on_quit_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/mode_select.tscn")
