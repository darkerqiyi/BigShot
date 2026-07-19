extends "res://scripts/game/main.gd"

const SurvivalWaveManagerScript := preload("res://scripts/survival/wave_manager.gd")
const SurvivalWaveData := preload("res://scripts/survival/survival_wave_data.gd")
const SurvivalMapConfigScript := preload("res://scripts/survival/survival_map_config.gd")
const SpawnWarningScript := preload("res://scripts/survival/spawn_warning.gd")
const SurvivalArenaArtScript := preload("res://scripts/survival/survival_arena_art.gd")
const SteamVentScript := preload("res://scripts/survival/steam_vent.gd")
const SurvivalBalanceTelemetryScript := preload("res://scripts/debug/survival_balance_telemetry.gd")
const RunUpgradeManagerScript := preload("res://scripts/survival/run_upgrade_manager.gd")
const SurvivalUpgradeOverlayScript := preload("res://scripts/ui/survival_upgrade_overlay.gd")

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
var upgrade_manager: RunUpgradeManager
var upgrade_overlay: SurvivalUpgradeOverlay
var upgrade_layer: CanvasLayer
var best_score := 0
var best_time := 0.0
var map_id: StringName = SurvivalMapConfigScript.INDUSTRIAL_ID
var map_config: Dictionary = {}
var map_hazard_root: Node2D
var map_hazards: Array[Node] = []
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
	map_id = StringName(get_meta("survival_map_id", SurvivalMapConfigScript.INDUSTRIAL_ID))
	map_config = SurvivalMapConfigScript.get_map(map_id)
	enemy_balance_mode = &"survival"
	super._ready()
	run_state = "survival_countdown"
	_prepare_survival_world()
	player.global_position = map_config.get("player_spawn", Vector2(640.0, 552.0))
	player.velocity = Vector2.ZERO
	var camera_bounds: Rect2 = map_config.get("camera_bounds", Rect2(0.0, 0.0, 1280.0, 720.0))
	camera.configure_bounds(camera_bounds)
	boss.global_position = map_config.get("boss_spawn", Vector2(1010.0, 520.0))
	var boss_arena: Vector2 = map_config.get("boss_arena", Vector2(110.0, 1170.0))
	boss.arena_left = boss_arena.x
	boss.arena_right = boss_arena.y
	boss.phase_two_summon_positions = map_config.get("boss_summons", PackedVector2Array())
	boss_gate.collision_layer = 0
	boss_gate_visual.visible = false
	_create_arena_boundaries()
	_create_arena_art()
	_create_map_platforms()
	_create_map_hazards()
	wave_manager = SurvivalWaveManagerScript.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	var waves := SurvivalWaveData.phase_a_waves() if bool(get_meta("survival_phase_a_test", false)) else SurvivalWaveData.full_waves()
	waves = _adapt_waves_for_map(waves)
	wave_manager.configure(waves, maxi(6 + int(map_config.get("active_limit_offset", 0)), 1))
	if not bool(get_meta("survival_phase_a_test", false)):
		wave_manager.configure_upgrades([2, 4, 6, 8])
	if bool(get_meta("survival_test_mode", false)):
		wave_manager.set_debug_timings(0.03, 0.04, 0.02, 0.01)
	wave_manager.wave_started.connect(_on_survival_wave_started)
	wave_manager.spawn_warning_requested.connect(_on_spawn_warning_requested)
	wave_manager.spawn_requested.connect(_on_survival_spawn_requested)
	wave_manager.counters_changed.connect(_on_survival_counters_changed)
	wave_manager.rest_started.connect(_on_survival_rest_started)
	wave_manager.upgrade_requested.connect(_on_survival_upgrade_requested)
	wave_manager.wave_completed.connect(_on_survival_wave_completed)
	wave_manager.boss_requested.connect(_on_survival_boss_requested)
	wave_manager.run_completed.connect(_on_survival_run_completed)
	wave_manager.state_changed.connect(_on_wave_state_changed)
	upgrade_manager = RunUpgradeManagerScript.new()
	upgrade_manager.name = "RunUpgradeManager"
	add_child(upgrade_manager)
	var upgrade_seed := int(get_meta("survival_upgrade_seed", 0))
	upgrade_manager.configure(player, upgrade_seed)
	upgrade_manager.upgrade_applied.connect(_on_survival_upgrade_applied)
	upgrade_layer = CanvasLayer.new()
	upgrade_layer.name = "UpgradeLayer"
	# Keep the cards above the world but below the existing HUD pause layer.
	upgrade_layer.layer = 9
	add_child(upgrade_layer)
	upgrade_overlay = SurvivalUpgradeOverlayScript.new()
	upgrade_overlay.name = "SurvivalUpgradeOverlay"
	upgrade_layer.add_child(upgrade_overlay)
	upgrade_overlay.upgrade_chosen.connect(_on_survival_upgrade_chosen)
	if OS.is_debug_build() and not bool(get_meta("survival_test_mode", false)):
		survival_balance_telemetry = SurvivalBalanceTelemetryScript.new()
		survival_balance_telemetry.name = "SurvivalBalanceTelemetry"
		add_child(survival_balance_telemetry)
		survival_balance_telemetry.configure(player, telemetry, _run_elapsed)
	_load_survival_records()
	hud.set_survival_mode(true)
	hud.hide_objective(true)
	hud.show_banner(str(map_config.get("display_name", "SURVIVAL PROTOCOL ONLINE")), Color("55e39a"), false, 1.35)
	sfx.play_music(StringName(map_config.get("music", &"level")), 0.28)
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


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or wave_manager == null:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		if wave_manager.request_fast_start():
			hud.show_banner("NEXT WAVE // FAST START", Color("62d8ff"), false, 0.7)
			sfx.play_cue(&"ui_confirm")
			get_viewport().set_input_as_handled()


func _create_arena_boundaries() -> void:
	var bounds: Rect2 = map_config.get("camera_bounds", Rect2(0.0, 0.0, 1280.0, 720.0))
	var right_wall := StaticBody2D.new()
	right_wall.name = "SurvivalRightWall"
	right_wall.position = Vector2(bounds.end.x, bounds.position.y + bounds.size.y * 0.5)
	right_wall.collision_layer = 1
	right_wall.collision_mask = 6
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32.0, bounds.size.y)
	shape_node.shape = shape
	right_wall.add_child(shape_node)
	world.add_child(right_wall)


func _create_arena_art() -> void:
	var art := SurvivalArenaArtScript.new()
	art.name = "SurvivalArenaArt"
	world.add_child(art)
	art.configure(
		StringName(map_config.get("art_theme", &"industrial")),
		map_config.get("camera_bounds", Rect2(0.0, 0.0, 1280.0, 720.0)),
		map_config.get("platforms", []) as Array,
	)


func _prepare_survival_world() -> void:
	# The inherited PVE level remains the gameplay/system source, but authored
	# mission platforms must not leak into map-specific survival geometry.
	for child in world.get_children():
		if child.name.to_lower().begins_with("platform"):
			child.visible = false
			if child is CollisionObject2D:
				child.collision_layer = 0
	if map_id == SurvivalMapConfigScript.SUBLEVEL_ID:
		for node_name in ["FarArt", "MidArt", "LevelArt", "FrontArt"]:
			var inherited_art := world.get_node_or_null(node_name)
			if inherited_art != null:
				inherited_art.visible = false
		$Sky/Base.color = Color("08141f")
		$Sky/Horizon.color = Color("102732")
		$Sky/GlowBand.color = Color("234f4a")
		$Sky/GlowBand.modulate.a = 0.32


func _create_map_platforms() -> void:
	for platform_value in map_config.get("platforms", []) as Array:
		var definition: Dictionary = platform_value
		var platform := StaticBody2D.new()
		platform.name = str(definition.get("name", "SurvivalPlatform"))
		platform.position = definition.get("position", Vector2.ZERO)
		platform.collision_layer = 1
		platform.collision_mask = 6
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = definition.get("size", Vector2(200.0, 22.0))
		collision.shape = shape
		platform.add_child(collision)
		world.add_child(platform)


func _create_map_hazards() -> void:
	map_hazard_root = Node2D.new()
	map_hazard_root.name = "MapHazards"
	world.add_child(map_hazard_root)
	for hazard_value in map_config.get("hazards", []) as Array:
		var definition: Dictionary = hazard_value
		if StringName(definition.get("kind", &"")) != &"steam_vent":
			continue
		var vent := SteamVentScript.new()
		vent.name = "SteamVent"
		map_hazard_root.add_child(vent)
		vent.configure(definition, player, enemies)
		vent.cue_requested.connect(_on_map_hazard_cue_requested)
		map_hazards.append(vent)


func _adapt_waves_for_map(source_waves: Array[Dictionary]) -> Array[Dictionary]:
	var adapted := source_waves.duplicate(true)
	var active_offset := int(map_config.get("active_limit_offset", 0))
	var interval_scale := float(map_config.get("spawn_interval_scale", 1.0))
	for wave in adapted:
		if bool(wave.get("boss", false)):
			continue
		wave["active_limit"] = maxi(int(wave.get("active_limit", 6)) + active_offset, 1)
		wave["spawn_interval"] = maxf(float(wave.get("spawn_interval", 0.42)) * interval_scale, 0.1)
	return adapted


func _on_survival_wave_started(wave_number: int, total: int, title: String) -> void:
	run_state = "boss" if wave_manager.is_boss_wave(wave_number) else "survival_combat"
	combat_pacing.set_normal_attack_slots(1 if wave_number <= 2 else 2)
	hud.show_banner("WAVE %02d // %s" % [wave_number, title], Color("ffb347"), false, 0.72)
	sfx.play_cue(&"mission_start")
	if survival_balance_telemetry != null:
		survival_balance_telemetry.begin_wave(wave_number, title, _run_elapsed)


func _on_spawn_warning_requested(ticket: int, kind: String, side: String, warning_time: float) -> void:
	var spawn_position := _choose_spawn_position(side, ticket, kind)
	_spawn_positions[ticket] = spawn_position
	var warning := SpawnWarningScript.new()
	warning.global_position = spawn_position
	warning.configure(warning_time)
	effects.add_child(warning)


func _on_survival_spawn_requested(ticket: int, kind: String, side: String) -> void:
	if run_state in ["dead", "complete", "survival_dead", "survival_complete"]:
		return
	var spawn_position: Vector2 = _spawn_positions.get(ticket, _choose_spawn_position(side, ticket, kind))
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


func _choose_spawn_position(side: String, ticket: int, kind: String = "assault") -> Vector2:
	var groups: Dictionary = map_config.get("spawn_groups", {})
	var left_ground: Array = groups.get("left_ground", []) as Array
	var right_ground: Array = groups.get("right_ground", []) as Array
	var left_positions: Array = left_ground.duplicate()
	var right_positions: Array = right_ground.duplicate()
	# Ranged units can use the authored upper lanes. Melee/heavy roles remain on
	# ground routes so they can always reach the player without new navigation.
	if kind == "gunner":
		left_positions.append_array(groups.get("left_upper", []) as Array)
		right_positions.append_array(groups.get("right_upper", []) as Array)
	var bounds: Rect2 = map_config.get("camera_bounds", Rect2(0.0, 0.0, 1280.0, 720.0))
	var arena_center := bounds.position.x + bounds.size.x * 0.5
	var candidates: Array = []
	if side == "left":
		candidates = left_positions
	elif side == "right":
		candidates = right_positions
	elif side == "far":
		candidates = left_positions if player.global_position.x >= arena_center else right_positions
	elif side in ["split", "edges"]:
		candidates = left_positions if ticket % 2 == 0 else right_positions
	else:
		candidates = left_positions + right_positions
	var safe: Array[Vector2] = []
	for candidate_value in candidates:
		var candidate: Vector2 = candidate_value
		if candidate.distance_to(player.global_position) >= 340.0 and _spawn_position_is_clear(candidate):
			safe.append(candidate)
	if safe.is_empty():
		var fallback_group: Array = left_ground if player.global_position.x > arena_center else right_ground
		for fallback_value in fallback_group:
			var fallback: Vector2 = fallback_value
			if _spawn_position_is_clear(fallback):
				safe.append(fallback)
	if safe.is_empty():
		# Authored ground points are guaranteed valid; choosing the farthest one is
		# safer than stalling the wave if every point is momentarily occupied.
		for fallback_value in left_ground + right_ground:
			safe.append(Vector2(fallback_value))
		safe.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.distance_squared_to(player.global_position) > b.distance_squared_to(player.global_position)
		)
	return safe[absi(ticket) % safe.size()]


func _spawn_position_is_clear(candidate: Vector2) -> bool:
	for enemy in enemies.get_children():
		if bool(enemy.get("alive")) and candidate.distance_to(enemy.global_position) < 96.0:
			return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = candidate
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


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


func _on_survival_upgrade_requested(completed_wave: int) -> void:
	run_state = "upgrade_selection"
	_clear_hostile_dangers()
	for grenade in grenades.get_children():
		grenade.queue_free()
	player.cancel_transient_actions()
	player.controls_enabled = false
	var candidates := upgrade_manager.generate_candidates(3)
	if candidates.is_empty():
		player.controls_enabled = true
		wave_manager.resume_after_upgrade()
		return
	upgrade_overlay.open(candidates)
	hud.crosshair.visible = false
	hud.set_survival_build_summary(upgrade_manager.get_build_summary(), upgrade_manager.calculate_final_modifiers())
	hud.show_banner("WAVE %02d CLEAR // SELECT UPGRADE" % completed_wave, Color("62d8ff"), false, 0.75)
	sfx.play_cue(&"ui_adjust")


func _on_survival_upgrade_chosen(upgrade_id: StringName) -> void:
	if run_state != "upgrade_selection" or not upgrade_manager.apply_candidate(upgrade_id):
		return
	upgrade_overlay.confirm_selection(upgrade_id)
	sfx.play_cue(&"ui_confirm")
	var delay := 0.01 if bool(get_meta("survival_test_mode", false)) else 0.18
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(upgrade_overlay) or run_state != "upgrade_selection":
		return
	upgrade_overlay.close()
	hud.crosshair.visible = true
	player.controls_enabled = true
	wave_manager.resume_after_upgrade()


func _on_survival_upgrade_applied(upgrade_id: StringName, stack_count: int, _final_modifiers: Dictionary) -> void:
	var definition = upgrade_manager.get_definition(upgrade_id)
	var upgrade_name: String = str(upgrade_id).to_upper() if definition == null else str(definition.display_name)
	hud.set_survival_build_summary(upgrade_manager.get_build_summary(), upgrade_manager.calculate_final_modifiers())
	hud.show_banner("%s // STACK %d" % [upgrade_name, stack_count], Color("fff4b8"), false, 0.8)
	if survival_balance_telemetry != null:
		survival_balance_telemetry.record_upgrade(wave_manager.current_wave, upgrade_id, stack_count, _run_elapsed)


func debug_open_upgrade_selection() -> bool:
	if not OS.is_debug_build() or run_state in ["dead", "complete", "upgrade_selection"]:
		return false
	return wave_manager.debug_request_upgrade()


func debug_add_upgrade(upgrade_id: StringName) -> bool:
	return OS.is_debug_build() and upgrade_manager.apply_debug_upgrade(upgrade_id)


func debug_clear_upgrades() -> void:
	if OS.is_debug_build():
		upgrade_manager.reset_run()
		hud.set_survival_build_summary([], upgrade_manager.calculate_final_modifiers())


func debug_set_upgrade_seed(seed_value: int) -> void:
	if OS.is_debug_build():
		upgrade_manager.set_random_seed(seed_value)


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
	_set_map_hazards_suspended(true)
	combat_pacing.set_boss_mode(true)
	boss_summons_alive = 0
	_boss_defeat_pending = false
	boss.global_position = map_config.get("boss_spawn", Vector2(1010.0, 520.0))
	boss.activate(player)
	if telemetry != null:
		telemetry.boss_started()
	hud.begin_boss_intro(boss.boss_name, boss.MAX_HEALTH)
	combat_feedback.request_shake(&"boss_intro", &"survival_boss_intro")
	sfx.play_cue(&"boss_intro")
	sfx.play_music(&"boss", 0.45)
	_release_hazards_after_boss_intro()


func _on_boss_died(_defeated_boss: Node) -> void:
	if _boss_defeat_pending or wave_manager == null or wave_manager.get_state_name() != &"boss":
		return
	_boss_defeat_pending = true
	_run_kills += 1
	score += 1500
	hud.set_score(score)
	combat_pacing.set_boss_mode(false)
	run_state = "survival_boss_defeated"
	_set_map_hazards_suspended(true)
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
	if telemetry != null:
		telemetry.record_death(player.global_position)
	if survival_balance_telemetry != null:
		survival_balance_telemetry.finish(&"death", _run_elapsed)
	var failure_summary := _build_survival_summary(wave_manager.current_wave)
	if upgrade_manager != null:
		upgrade_manager.reset_run()
	if upgrade_overlay != null:
		upgrade_overlay.close()
	_clear_survival_runtime(true)
	sfx.stop_bus_cues(&"Boss")
	combat_feedback.request_shake(&"player_death", &"player_death")
	sfx.play_cue(&"player_death")
	sfx.duck_music(0.55, 5.0)
	hud.show_survival_failure(failure_summary, player.last_damage_source)
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
	hud.show_survival_settlement(_build_survival_summary(10))
	sfx.stop_music(0.45)
	sfx.play_cue(&"mission_complete")


func _build_survival_summary(reached_wave: int) -> Dictionary:
	var telemetry_snapshot: Dictionary = telemetry.get_snapshot() if telemetry != null else {}
	var telemetry_weapons: Dictionary = telemetry_snapshot.get("weapons", {}) as Dictionary
	var total_damage := int((telemetry_snapshot.get("grenades", {}) as Dictionary).get("damage", 0))
	var total_hits := 0
	var total_headshots := 0
	var most_used_weapon: StringName = &"rifle"
	var most_used_seconds := -1.0
	for weapon_id in [&"rifle", &"shotgun", &"sniper", &"pistol"]:
		var stats: Dictionary = telemetry_weapons.get(weapon_id, {}) as Dictionary
		total_damage += int(stats.get("damage", 0))
		total_hits += int(stats.get("hits", 0))
		total_headshots += int(stats.get("headshots", 0))
		var active_seconds := float(stats.get("active_seconds", 0.0))
		if active_seconds > most_used_seconds:
			most_used_seconds = active_seconds
			most_used_weapon = weapon_id
	var total_damage_received := 0
	for amount in (telemetry_snapshot.get("damage_sources", {}) as Dictionary).values():
		total_damage_received += int(amount)
	var boss_time := 0.0
	var boss_started := float(telemetry_snapshot.get("boss_started_at", -1.0))
	if boss_started >= 0.0:
		boss_time = maxf(float(telemetry_snapshot.get("elapsed", _run_elapsed)) - boss_started, 0.0)
	return {
		"score": score,
		"elapsed": _run_elapsed,
		"reached_wave": reached_wave,
		"kills": _run_kills,
		"total_damage": total_damage,
		"damage_received": total_damage_received,
		"headshots": total_headshots,
		"headshot_rate": float(total_headshots) / float(maxi(total_hits, 1)),
		"most_used_weapon": most_used_weapon,
		"boss_time": boss_time,
		"highest_combo": highest_combo,
		"weapon_kills": weapon_kills.duplicate(),
		"grenade_kills": grenade_kills,
		"roll_evades": player.projectile_dodges,
		"best_score": best_score,
		"best_time": best_time,
		"upgrade_history": upgrade_manager.selection_history.duplicate(),
		"upgrade_build": upgrade_manager.get_build_summary(),
		"upgrade_final_modifiers": upgrade_manager.calculate_final_modifiers(),
	}


func _clear_survival_runtime(include_boss: bool = true) -> void:
	_set_map_hazards_suspended(true)
	if damage_numbers != null:
		damage_numbers.clear_all()
	if impact_effects != null:
		impact_effects.clear_all()
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
	var bounds: Rect2 = map_config.get("camera_bounds", Rect2(0.0, 0.0, 1280.0, 720.0))
	var recovery_points: Array = map_config.get("recovery_spawns", []) as Array
	for enemy in enemies.get_children():
		if not bool(enemy.get("alive")):
			continue
		if enemy.global_position.y > bounds.end.y + 40.0 or enemy.global_position.x < bounds.position.x - 40.0 or enemy.global_position.x > bounds.end.x + 40.0:
			var chosen: Vector2 = recovery_points[0] if player.global_position.x > bounds.position.x + bounds.size.x * 0.5 else recovery_points.back()
			enemy.global_position = chosen
			enemy.velocity = Vector2.ZERO


func _on_wave_state_changed(state_name: StringName) -> void:
	_set_map_hazards_suspended(state_name not in [&"spawning", &"active"])


func _set_map_hazards_suspended(value: bool) -> void:
	for hazard in map_hazards:
		if is_instance_valid(hazard) and hazard.has_method("set_suspended"):
			hazard.set_suspended(value)


func _release_hazards_after_boss_intro() -> void:
	var delay := 0.02 if bool(get_meta("survival_test_mode", false)) else 1.4
	await get_tree().create_timer(delay).timeout
	if wave_manager != null and wave_manager.get_state_name() == &"boss" and run_state == "boss":
		_set_map_hazards_suspended(false)


func _on_map_hazard_cue_requested(cue: StringName, world_position: Vector2, priority: bool) -> void:
	sfx.play_world_cue(cue, world_position, player.global_position, priority)


func _update_objective() -> void:
	if wave_manager != null:
		_refresh_survival_hud()


func _restart_scene() -> void:
	get_tree().paused = false
	if combat_feedback != null:
		combat_feedback.clear()
	get_tree().reload_current_scene()


func _on_quit_requested() -> void:
	if upgrade_manager != null:
		upgrade_manager.reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/mode_select.tscn")


func _on_pause_changed(paused: bool) -> void:
	super._on_pause_changed(paused)
	if not paused and run_state == "upgrade_selection":
		hud.crosshair.visible = false
