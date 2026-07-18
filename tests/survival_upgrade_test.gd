extends SceneTree

const SurvivalScene := preload("res://scenes/survival/survival.tscn")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := SurvivalScene.instantiate()
	game.set_meta("survival_test_mode", true)
	game.set_meta("survival_upgrade_seed", 4242)
	root.add_child(game)
	current_scene = game
	var minimal_pool: Array[StringName] = [&"endurance_core", &"evasive_circuit", &"high_explosive"]
	game.upgrade_manager.set_debug_candidate_pool(minimal_pool)
	game.player.weapon_inventory.select_weapon(&"pistol")

	var budget := 1500
	while game.wave_manager.get_state_name() != &"upgrade_selection" and budget > 0:
		budget -= 1
		for enemy in game.enemies.get_children():
			if bool(enemy.get("alive")):
				enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {"weapon_id": &"rifle", "damage_kind": &"projectile"})
		await physics_frame
	_expect(game.wave_manager.current_wave == 2, "first upgrade did not trigger after wave two")
	_expect(game.wave_manager.get_state_name() == &"upgrade_selection", "wave manager did not enter upgrade selection")
	_expect(game.run_state == "upgrade_selection" and not game.player.controls_enabled, "combat controls were not locked during selection")
	_expect(game.upgrade_overlay.visible, "three-card overlay was not visible")
	var candidates: Array[Dictionary] = game.upgrade_manager.current_candidates
	_expect(candidates.size() == 3, "minimal loop did not provide three cards")
	var candidate_ids: Dictionary = {}
	var candidate_categories: Dictionary = {}
	var candidate_families: Dictionary = {}
	for card in candidates:
		candidate_ids[StringName(card["id"])] = true
		candidate_categories[StringName(card["category"])] = true
		candidate_families[StringName(card.get("family", &""))] = true
		_expect(" -> " in str(card.get("value_preview", "")), "upgrade card omitted its before/after value preview")
	_expect(candidate_ids.size() == 3, "candidate cards contained duplicates")
	_expect(candidate_categories.size() >= 2, "candidate cards did not span two categories")
	_expect(candidate_families.size() == 3, "candidate cards did not span output, survival and mobility families")
	_expect(candidate_ids.has(&"endurance_core") and candidate_ids.has(&"evasive_circuit") and candidate_ids.has(&"high_explosive"), "minimal candidate pool was incorrect")
	for index in range(candidates.size()):
		_expect(game.upgrade_overlay.cards[index].text.contains("[%s]" % str(candidates[index]["icon"]).to_upper()), "upgrade card did not display its placeholder icon badge")
	game.hud.toggle_pause()
	_expect(paused and game.hud.state_overlay.visible, "pause menu did not open over upgrade selection")
	var paused_history_size: int = game.upgrade_manager.selection_history.size()
	var paused_event := InputEventAction.new()
	paused_event.action = &"weapon_1"
	paused_event.pressed = true
	game.upgrade_overlay._unhandled_input(paused_event)
	_expect(game.upgrade_manager.selection_history.size() == paused_history_size, "paused upgrade screen accepted a selection")
	game.hud.toggle_pause()
	_expect(not paused and game.upgrade_overlay.visible and not game.hud.crosshair.visible, "resume did not restore the upgrade selection presentation")

	var chosen_id := StringName(candidates[0]["id"])
	var numeric_event := InputEventAction.new()
	numeric_event.action = &"weapon_1"
	numeric_event.pressed = true
	game.upgrade_overlay._unhandled_input(numeric_event)
	for _frame in range(2):
		await physics_frame
	_expect(game.upgrade_manager.selection_history == [chosen_id], "numeric selection was not applied exactly once")
	_expect(game.player.current_weapon_id == &"pistol", "upgrade hotkey also switched the weapon")
	_expect(not game.upgrade_overlay.visible and game.player.controls_enabled, "selection did not return to rest controls")
	_expect(game.wave_manager.get_state_name() == &"rest", "selection did not resume the rest countdown")
	var stack_before_duplicate: int = game.upgrade_manager.get_stack_count(chosen_id)
	game._on_survival_upgrade_chosen(chosen_id)
	_expect(game.upgrade_manager.get_stack_count(chosen_id) == stack_before_duplicate, "duplicate selection applied twice")
	match chosen_id:
		&"endurance_core":
			_expect(is_equal_approx(game.player.runtime_max_stamina, 120.0), "endurance did not raise max stamina")
		&"evasive_circuit":
			_expect(is_equal_approx(game.player.runtime_roll_cooldown, 0.42), "evasive circuit did not reduce roll cooldown")
		&"high_explosive":
			_expect(game.player.runtime_grenade_damage == 92, "high explosive did not raise grenade damage")

	# Stack every definition to its cap and verify the bounded runtime result.
	game.upgrade_manager.reset_run()
	game.upgrade_manager.clear_debug_candidate_pool()
	for definition in game.upgrade_manager._definitions.values():
		for _stack in range(definition.max_stacks):
			_expect(game.upgrade_manager.apply_debug_upgrade(definition.id), "debug application failed for %s" % definition.id)
		_expect(not game.upgrade_manager.apply_debug_upgrade(definition.id), "%s exceeded max stacks" % definition.id)
	var final_modifiers: Dictionary = game.upgrade_manager.calculate_final_modifiers()
	_expect(game.upgrade_manager.selection_history.size() == 32, "complete stack ledger was inaccurate")
	_expect(game.upgrade_manager.generate_candidates(3).is_empty(), "maxed upgrades remained in the candidate pool")
	_expect(is_equal_approx(game.player.runtime_max_stamina, 160.0), "max stamina stack result was incorrect")
	_expect(game.player.runtime_stamina_drain >= Tuning.PLAYER_STAMINA_DRAIN_PER_SECOND * 0.60, "sprint drain crossed its lower bound")
	_expect(is_equal_approx(game.player.runtime_sprint_speed, Tuning.PLAYER_SPRINT_SPEED * 1.14), "sprint speed stack result was incorrect")
	_expect(game.player.runtime_roll_cooldown >= 0.25 and is_equal_approx(game.player.runtime_roll_cooldown, 0.26), "roll cooldown bound was incorrect")
	_expect(game.player.runtime_grenade_capacity == 5, "grenade capacity stack result was incorrect")
	_expect(is_equal_approx(game.player.runtime_grenade_radius, Tuning.GRENADE_RADIUS * 1.45), "grenade radius stack result was incorrect")
	_expect(game.player.runtime_grenade_damage == 116, "grenade damage stack result was incorrect")
	_expect(game.player.runtime_max_health == 145, "max health stack result was incorrect")
	var rifle: Dictionary = game.player.weapon_inventory._apply_runtime_modifiers(WeaponData.get_weapon(&"rifle"))
	var shotgun: Dictionary = game.player.weapon_inventory._apply_runtime_modifiers(WeaponData.get_weapon(&"shotgun"))
	var sniper: Dictionary = game.player.weapon_inventory._apply_runtime_modifiers(WeaponData.get_weapon(&"sniper"))
	_expect(float(rifle["fire_rate"]) >= 0.055 and float(rifle["fire_rate"]) < 0.085, "rifle overclock interval was outside bounds")
	_expect(int(shotgun["projectile_count"]) == 9, "scatter load did not cap at nine pellets")
	_expect(int(sniper["penetration_count"]) == 4, "lance penetration did not cap at four")
	game.player.is_sprinting = true
	game.player._begin_airborne(game.player.runtime_sprint_speed, true)
	_expect(is_equal_approx(game.player.airborne_speed_cap, game.player.runtime_sprint_speed), "sprint jump did not inherit upgraded speed")
	game._spawn_player_grenade(game.player.global_position, Vector2(300, -300), 0.5)
	var runtime_grenade = game.grenades.get_child(game.grenades.get_child_count() - 1)
	_expect(is_equal_approx(runtime_grenade.blast_radius, float(final_modifiers["grenade_radius"])), "grenade visual/physics radius did not use the runtime value")
	_expect(runtime_grenade.blast_damage == int(final_modifiers["grenade_damage"]), "grenade entity did not use runtime damage")

	# A reset must restore the shared PVE baseline rather than retaining a build.
	game.upgrade_manager.reset_run()
	_expect(game.upgrade_manager.selection_history.is_empty() and game.upgrade_manager.stacks.is_empty(), "run reset retained the build ledger")
	_expect(game.player.runtime_max_health == Tuning.PLAYER_MAX_HEALTH and is_equal_approx(game.player.runtime_max_stamina, Tuning.PLAYER_MAX_STAMINA), "run reset retained health or stamina upgrades")
	_expect(is_equal_approx(game.player.runtime_sprint_speed, Tuning.PLAYER_SPRINT_SPEED) and is_equal_approx(game.player.runtime_roll_cooldown, Tuning.PLAYER_ROLL_COOLDOWN), "run reset retained movement upgrades")
	_expect(game.player.runtime_grenade_capacity == Tuning.PLAYER_GRENADE_COUNT and is_equal_approx(game.player.runtime_grenade_radius, Tuning.GRENADE_RADIUS), "run reset retained grenade upgrades")
	_expect(is_equal_approx(float(game.player.weapon_inventory.get_runtime_modifiers()["reload_time_multiplier"]), 1.0), "run reset retained weapon modifiers")
	var ui_choices: Array[StringName] = []
	game.upgrade_overlay.upgrade_chosen.connect(func(upgrade_id: StringName) -> void: ui_choices.append(upgrade_id))
	var ui_candidates: Array[Dictionary] = game.upgrade_manager.generate_candidates(3)
	game.upgrade_overlay.open(ui_candidates)
	var right_event := InputEventAction.new()
	right_event.action = &"ui_right"
	right_event.pressed = true
	game.upgrade_overlay._unhandled_input(right_event)
	var accept_event := InputEventAction.new()
	accept_event.action = &"ui_accept"
	accept_event.pressed = true
	game.upgrade_overlay._unhandled_input(accept_event)
	_expect(ui_choices.size() == 1 and ui_choices[0] == StringName(ui_candidates[1]["id"]), "arrow and Enter selection did not choose the focused card")
	game.upgrade_overlay.close()
	game.upgrade_overlay.open(ui_candidates)
	game.upgrade_overlay.cards[2].pressed.emit()
	_expect(ui_choices.size() == 2 and ui_choices[1] == StringName(ui_candidates[2]["id"]), "mouse card selection did not emit the clicked upgrade")
	game.upgrade_overlay.close()

	print("SURVIVAL_UPGRADE_METRICS candidates=3 categories=%d definitions=12 stack_applications=32 roll_floor=%.2f grenade_radius=%.1f" % [candidate_categories.size(), float(final_modifiers["roll_cooldown"]), float(final_modifiers["grenade_radius"])])
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SURVIVAL_UPGRADE_PASS wave-two three-card loop, input isolation, twelve bounded upgrades, runtime reset and grenade synchronization")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
