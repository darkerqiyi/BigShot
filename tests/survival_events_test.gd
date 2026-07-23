extends SceneTree

const IndustrialScene := preload("res://scenes/survival/survival.tscn")
const SublevelScene := preload("res://scenes/survival/survival_sublevel_09.tscn")
const EventData := preload("res://scripts/survival/survival_event_data.gd")
const EventDirectorScript := preload("res://scripts/survival/survival_event_director.gd")
const WeaponCatalog := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_director_contract()
	await _verify_supply_choice(IndustrialScene, &"industrial_district", &"medical", &"mouse", 1101)
	await _verify_supply_choice(IndustrialScene, &"industrial_district", &"weapon", &"number", 1102)
	await _verify_supply_choice(SublevelScene, &"sublevel_09", &"tactical", &"number", 1103)
	await _verify_full_resource_replacements()
	await _verify_pause_and_duplicate_guard()
	await _verify_event_death_reset()
	var industrial := await _complete_supply_run(IndustrialScene, &"industrial_district", 4301)
	var sublevel := await _complete_supply_run(SublevelScene, &"sublevel_09", 4302)
	await _verify_pve_isolation()
	_expect(bool(industrial.get("complete", false)) and bool(sublevel.get("complete", false)), "one supply-enabled map did not complete ten waves")
	_expect(int(industrial.get("events", 0)) == 1 and int(sublevel.get("events", 0)) == 1, "a map did not resolve exactly one supply event")
	_expect(not bool(industrial.get("overlap", true)) and not bool(sublevel.get("overlap", true)), "supply and upgrade UI overlapped")
	print("SURVIVAL_EVENTS_METRICS industrial=%s sublevel=%s" % [industrial, sublevel])
	_finish()


func _verify_director_contract() -> void:
	var definitions := EventData.all_events()
	_expect(definitions.size() == 1 and StringName(definitions[0].get("event_id", &"")) == &"supply_drop", "first-stage registry contains events other than supply_drop")
	if not definitions.is_empty():
		var definition: Dictionary = definitions[0]
		_expect(bool(definition.get("blocks_wave_start", false)) and bool(definition.get("pauses_combat", false)), "supply definition omitted blocking/combat flags")
		_expect(bool(definition.get("debug_force_enabled", false)), "supply definition cannot be forced in debug")
	var first := EventDirectorScript.new()
	var second := EventDirectorScript.new()
	root.add_child(first)
	root.add_child(second)
	first.configure(&"industrial_district", 9917, true)
	second.configure(&"industrial_district", 9917, true)
	_expect(first.schedule == second.schedule, "fixed event seed did not reproduce the schedule")
	_expect(first.schedule.size() == 1, "director did not schedule exactly one event")
	if not first.schedule.is_empty():
		var wave := int(first.schedule.keys()[0])
		var definition: Dictionary = first.schedule[wave]
		_expect(wave in [3, 5, 7], "event scheduled outside waves 3/5/7")
		_expect(StringName(definition.get("event_id", &"")) == &"supply_drop", "director scheduled an unregistered event")
	_expect(not first.debug_force_event(&"elite_bounty", 3), "excluded bounty event remained debug-triggerable")
	first.enabled = false
	first.reset_run()
	_expect(first.schedule.is_empty(), "disabled director retained a schedule")
	first.queue_free()
	second.queue_free()


func _new_game(scene: PackedScene, seed_value: int) -> Node:
	var game := scene.instantiate()
	game.set_meta("survival_test_mode", true)
	game.set_meta("survival_events_enabled", true)
	game.set_meta("survival_event_seed", seed_value)
	game.set_meta("survival_upgrade_seed", seed_value + 10)
	root.add_child(game)
	current_scene = game
	return game


func _force_supply(game: Node, wave: int = 3) -> void:
	game.event_director.debug_clear_schedule()
	_expect(game.debug_force_survival_event(&"supply_drop", wave), "could not force supply_drop on wave %d" % wave)


func _verify_supply_choice(scene: PackedScene, expected_map: StringName, option_id: StringName, input_method: StringName, seed_value: int) -> void:
	var game := _new_game(scene, seed_value)
	_force_supply(game)
	_prepare_resource_need(game, option_id)
	var opened := await _advance_to_supply(game)
	_expect(opened, "%s supply did not open on %s" % [option_id, expected_map])
	if opened:
		_expect(game.event_director.get_state_name() == &"active", "supply director did not enter ACTIVE")
		_expect(game.wave_manager.get_state_name() == &"event_resolution", "supply did not hold the next wave")
		_expect(not game.player.controls_enabled and game._control_locks.has(&"supply_drop"), "supply did not acquire its control lock")
		var before := _resource_snapshot(game)
		var option_index := _find_option_index(game._pending_supply_options, option_id)
		_expect(option_index >= 0, "%s option was replaced despite having real value" % option_id)
		if option_index >= 0:
			if input_method == &"mouse":
				game.event_overlay.supply_cards[option_index].pressed.emit()
			else:
				var input := InputEventAction.new()
				input.action = [&"weapon_1", &"weapon_2", &"weapon_3"][option_index]
				input.pressed = true
				game.event_overlay._unhandled_input(input)
			await create_timer(0.05).timeout
			_verify_resource_result(game, option_id, before)
			_expect(not game.event_overlay.is_supply_open(), "supply UI did not close")
			_expect(game.player.controls_enabled and game._control_locks.is_empty(), "supply control lock did not release")
			_expect(game.wave_manager.get_state_name() == &"rest", "supply did not resume rest countdown")
			var history: Array = game.event_director.get_history()
			_expect(history.size() == 1 and StringName(history[0].get("status", &"")) == &"success", "supply result was not recorded once")
			if expected_map == &"sublevel_09":
				await _verify_post_supply_mobility(game)
	game.queue_free()
	await process_frame
	await process_frame


func _prepare_resource_need(game: Node, option_id: StringName) -> void:
	match option_id:
		&"medical":
			game.player.health = 40
		&"weapon":
			for weapon_id in WeaponCatalog.ORDER:
				game.player.weapon_inventory._ammo[weapon_id] = maxi(int(WeaponCatalog.get_weapon(weapon_id)["magazine_size"]) - 2, 0)
			game.player.weapon_inventory._emit_current_state()
		&"tactical":
			game.player.grenade_count = maxi(game.player.runtime_grenade_capacity - 2, 0)
			game.player.current_stamina = 20.0


func _resource_snapshot(game: Node) -> Dictionary:
	var ammo := {}
	for weapon_id in WeaponCatalog.ORDER:
		ammo[weapon_id] = game.player.weapon_inventory.get_ammo_for(weapon_id)
	return {
		"health": game.player.health,
		"ammo": ammo,
		"grenades": game.player.grenade_count,
		"stamina": game.player.current_stamina,
	}


func _verify_resource_result(game: Node, option_id: StringName, before: Dictionary) -> void:
	var summary: Dictionary = game.event_director.get_summary()
	match option_id:
		&"medical":
			var expected := mini(int(before["health"]) + int(ceil(game.player.runtime_max_health * 0.30)), game.player.runtime_max_health)
			_expect(game.player.health == expected, "medical supply did not restore exactly 30% max health")
			_expect(int(summary.get("supply_health_restored", 0)) == expected - int(before["health"]), "medical statistic is inaccurate")
		&"weapon":
			var refilled := 0
			for weapon_id in WeaponCatalog.ORDER:
				var maximum := int(WeaponCatalog.get_weapon(weapon_id)["magazine_size"])
				_expect(game.player.weapon_inventory.get_ammo_for(weapon_id) == maximum, "%s magazine did not refill" % weapon_id)
				if int((before["ammo"] as Dictionary)[weapon_id]) < maximum:
					refilled += 1
			_expect(int(summary.get("supply_magazines_refilled", 0)) == refilled, "refilled-magazine statistic is inaccurate")
		&"tactical":
			var expected_grenades := mini(int(before["grenades"]) + 1, game.player.runtime_grenade_capacity)
			_expect(game.player.grenade_count == expected_grenades, "tactical supply did not add one bounded grenade")
			_expect(is_equal_approx(game.player.current_stamina, game.player.runtime_max_stamina), "tactical supply did not restore full stamina")
			_expect(int(summary.get("supply_grenades_added", 0)) == expected_grenades - int(before["grenades"]), "grenade statistic is inaccurate")


func _verify_full_resource_replacements() -> void:
	var game := _new_game(IndustrialScene, 1201)
	game.player.health = game.player.runtime_max_health
	game.player.grenade_count = game.player.runtime_grenade_capacity
	game.player.current_stamina = game.player.runtime_max_stamina
	var options: Array[Dictionary] = game._build_supply_options()
	var effective := 0
	for option in options:
		if str(option.get("id", &"")).ends_with("_score") and int(option.get("score", 0)) > 0:
			effective += 1
	_expect(options.size() == 3 and effective == 3, "full resources did not convert all invalid cards to score benefits")
	game.queue_free()
	await process_frame


func _verify_pause_and_duplicate_guard() -> void:
	var game := _new_game(IndustrialScene, 1301)
	_force_supply(game)
	game.player.health = 30
	if await _advance_to_supply(game):
		paused = true
		var input := InputEventAction.new()
		input.action = &"weapon_1"
		input.pressed = true
		game.event_overlay._unhandled_input(input)
		_expect(game.event_director.get_history().is_empty(), "paused supply UI accepted a selection")
		paused = false
		game._on_supply_chosen(&"medical")
		game._on_supply_chosen(&"medical")
		await create_timer(0.05).timeout
		_expect(game.event_director.get_history().size() == 1, "mouse/key double path resolved supply more than once")
		_expect(game.player.controls_enabled, "pause/resume supply path left controls locked")
	game.queue_free()
	await process_frame


func _advance_to_supply(game: Node) -> bool:
	for _frame in range(2200):
		_handle_upgrade(game)
		_kill_all_hostiles(game)
		if game.event_overlay.is_supply_open():
			return true
		await physics_frame
	return false


func _verify_post_supply_mobility(game: Node) -> void:
	var start_x: float = game.player.global_position.x
	Input.action_press("move_right")
	for _frame in range(12):
		await physics_frame
	Input.action_release("move_right")
	_expect(game.player.global_position.x > start_x + 1.0, "Sublevel movement remained locked after supply")
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for _frame in range(4):
		await physics_frame
	_expect(game.player.velocity.y < 0.0, "Sublevel jump remained locked after supply")
	while not game.player.is_on_floor():
		await physics_frame
	Input.action_press("sprint")
	Input.action_press("move_right")
	for _frame in range(8):
		await physics_frame
	_expect(game.player.is_sprinting, "Sublevel sprint remained locked after supply")
	Input.action_release("sprint")
	Input.action_release("move_right")
	while not game.player.is_on_floor():
		await physics_frame
	game.player.roll_cooldown_remaining = 0.0
	var roll_started: bool = game.player._try_start_roll(1)
	_expect(roll_started and game.player.is_rolling, "Sublevel roll remained locked after supply")
	game.player._end_roll()
	var ammo_before: int = game.player.ammo
	game.player.weapon_inventory.fire_cooldown = 0.0
	Input.action_press("fire")
	for _frame in range(3):
		await physics_frame
	Input.action_release("fire")
	_expect(game.player.ammo < ammo_before, "Sublevel firing remained locked after supply")
	game.player.grenade_throw_remaining = 0.0
	var grenade_started: bool = game.player._start_grenade_charge()
	_expect(grenade_started and game.player.grenade_charging, "Sublevel grenade charge remained locked after supply")
	game.player._cancel_grenade_charge()


func _complete_supply_run(scene: PackedScene, expected_map: StringName, seed_value: int) -> Dictionary:
	var game := _new_game(scene, seed_value)
	var overlap := false
	var event_wave := int(game.event_director.schedule.keys()[0]) if not game.event_director.schedule.is_empty() else 0
	for _frame in range(5600):
		if game.run_state == "complete":
			break
		overlap = overlap or (game.upgrade_overlay.visible and game.event_overlay.is_supply_open())
		_handle_upgrade(game)
		if game.event_overlay.is_supply_open():
			game._on_supply_chosen(StringName(game._pending_supply_options[0].get("id", &"")))
		_kill_all_hostiles(game)
		if game.boss.active and game.boss.alive:
			if game.boss.phase == 1:
				game.boss.take_damage(500, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper"})
			elif game.boss.transition_remaining <= 0.0:
				game.boss.take_damage(9999, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper"})
		await physics_frame
	var summary: Dictionary = game._build_survival_summary(game.wave_manager.current_wave)
	var result := {
		"map": expected_map,
		"complete": game.run_state == "complete",
		"events": int(summary.get("event_count", 0)),
		"event_wave": int(summary.get("supply_wave", 0)),
		"scheduled_wave": event_wave,
		"overlap": overlap,
		"boss_clean": not game.boss.active and game.projectiles.get_child_count() == 0,
	}
	_expect(game.map_id == expected_map, "%s supply run loaded the wrong map" % expected_map)
	_expect(int(result["event_wave"]) == event_wave and event_wave in [3, 5, 7], "%s resolved supply on the wrong wave" % expected_map)
	_expect(bool(result["boss_clean"]), "%s retained Boss or projectile state" % expected_map)
	_expect("SUPPLY WAVE" in game.hud.state_subtitle.text, "%s settlement omitted supply statistics" % expected_map)
	game.queue_free()
	await process_frame
	await process_frame
	return result


func _verify_event_death_reset() -> void:
	var game := _new_game(SublevelScene, 5501)
	_force_supply(game)
	game.player.health = 50
	_expect(await _advance_to_supply(game), "death-reset setup did not open supply")
	var old_id := game.get_instance_id()
	game.player.take_damage(9999, Vector2.ZERO, game.player.global_position, {"source": &"event_reset_test", "damage_kind": &"environment"})
	await create_timer(1.8).timeout
	_expect(current_scene != null and current_scene.get_instance_id() != old_id, "death during supply did not reload")
	if current_scene != null and current_scene.get_instance_id() != old_id:
		_expect(current_scene.event_director.get_history().is_empty() and not current_scene.event_director.is_active(), "restart retained event state")
		_expect(not current_scene.event_overlay.is_supply_open(), "restart retained supply UI")
		_expect(current_scene.player.controls_enabled and current_scene._control_locks.is_empty(), "restart retained supply control lock")
		current_scene.queue_free()
		await process_frame


func _verify_pve_isolation() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	for _frame in range(5):
		await physics_frame
	_expect(current_scene != null and current_scene.get_node_or_null("EventDirector") == null, "PVE loaded EventDirector")
	if current_scene != null:
		current_scene.queue_free()
		await process_frame


func _handle_upgrade(game: Node) -> void:
	if game.wave_manager.get_state_name() == &"upgrade_selection" and game.upgrade_manager.selection_open:
		game._on_survival_upgrade_chosen(StringName(game.upgrade_manager.current_candidates[0].get("id", &"")))


func _kill_all_hostiles(game: Node) -> void:
	for enemy in game.enemies.get_children():
		if bool(enemy.get("alive")):
			enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {"weapon_id": &"rifle", "damage_kind": &"projectile"})


func _find_option_index(options: Array[Dictionary], option_id: StringName) -> int:
	for index in range(options.size()):
		if StringName(options[index].get("id", &"")) == option_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for action in ["move_left", "move_right", "jump", "sprint", "fire"]:
		Input.action_release(action)
	paused = false
	if failures.is_empty():
		print("SURVIVAL_EVENTS_PASS supply-only scheduling, resource choices, input cleanup, two-map completion and PVE isolation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
