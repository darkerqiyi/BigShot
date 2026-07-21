extends SceneTree

const IndustrialScene := preload("res://scenes/survival/survival.tscn")
const SublevelScene := preload("res://scenes/survival/survival_sublevel_09.tscn")
const EventDirectorScript := preload("res://scripts/survival/survival_event_director.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_director_schedule()
	await _verify_supply_drop()
	await _verify_bounty(true)
	await _verify_bounty(false)
	await _verify_reinforcements()
	var industrial := await _complete_event_run(IndustrialScene, &"industrial_district", 4301)
	var sublevel := await _complete_event_run(SublevelScene, &"sublevel_09", 4302)
	await _verify_event_death_reset()
	await _verify_pve_isolation()
	_expect(bool(industrial.get("complete", false)) and bool(sublevel.get("complete", false)), "one event-enabled map did not complete ten waves")
	_expect(int(industrial.get("events", 0)) == 2 and int(sublevel.get("events", 0)) == 2, "a map did not resolve exactly two random events")
	_expect(int(industrial.get("unique_events", 0)) == 2 and int(sublevel.get("unique_events", 0)) == 2, "a random run repeated the same event")
	_expect(not bool(industrial.get("overlap", true)) and not bool(sublevel.get("overlap", true)), "event and upgrade UI overlapped")
	print("SURVIVAL_EVENTS_METRICS industrial=%s sublevel=%s" % [industrial, sublevel])
	_finish()


func _verify_director_schedule() -> void:
	var director := EventDirectorScript.new()
	root.add_child(director)
	director.configure(&"industrial_district", 9917, true)
	var schedule: Dictionary = director.schedule
	var ids: Dictionary = {}
	for wave_value in schedule:
		var wave := int(wave_value)
		var definition: Dictionary = schedule[wave]
		ids[StringName(definition.get("event_id", &""))] = true
		_expect(wave in [3, 5, 7], "event scheduled outside waves 3/5/7")
	_expect(schedule.size() == 2 and ids.size() == 2, "director did not schedule two distinct events")
	director.enabled = false
	director.reset_run()
	_expect(director.schedule.is_empty(), "disabled director retained a schedule")
	director.queue_free()


func _new_game(scene: PackedScene, seed_value: int) -> Node:
	var game := scene.instantiate()
	game.set_meta("survival_test_mode", true)
	game.set_meta("survival_events_enabled", true)
	game.set_meta("survival_event_seed", seed_value)
	game.set_meta("survival_upgrade_seed", seed_value + 10)
	root.add_child(game)
	current_scene = game
	return game


func _force_only(game: Node, event_id: StringName, wave: int) -> void:
	game.event_director.debug_clear_schedule()
	_expect(game.debug_force_survival_event(event_id, wave), "could not force %s on wave %d" % [event_id, wave])


func _verify_supply_drop() -> void:
	var game := _new_game(IndustrialScene, 1001)
	_force_only(game, &"supply_drop", 3)
	game.player.health = 40
	game.player.grenade_count = 1
	var opened := false
	for _frame in range(1800):
		_handle_upgrade(game)
		_kill_all_hostiles(game)
		if game.event_overlay.is_supply_open():
			opened = true
			break
		await physics_frame
	_expect(opened, "supply drop did not pause wave flow and open its selection")
	if opened:
		_expect(game.wave_manager.get_state_name() == &"event_resolution" and not game.player.controls_enabled, "supply selection did not hold the wave and controls")
		var before_health: int = game.player.health
		game._on_supply_chosen(&"medical")
		await create_timer(0.05).timeout
		_expect(game.player.health > before_health and game.player.health <= game.player.runtime_max_health, "medical supply did not restore bounded health")
		_expect(not game.event_overlay.is_supply_open() and game.wave_manager.get_state_name() == &"rest", "supply selection did not resume rest")
		var history: Array = game.event_director.get_history()
		_expect(history.size() == 1 and StringName(history[0].get("status", &"")) == &"success", "supply result was not recorded once")
		_expect((game.event_director.get_summary().get("supplies", []) as Array).has(&"medical"), "supply type was omitted from run statistics")
	game.queue_free()
	await process_frame


func _verify_bounty(expect_success: bool) -> void:
	var game := _new_game(SublevelScene if not expect_success else IndustrialScene, 1002 if expect_success else 1003)
	_force_only(game, &"elite_bounty", 3)
	var target: Node
	for _frame in range(1800):
		_handle_upgrade(game)
		for enemy in game.enemies.get_children():
			if bool(enemy.get_meta("survival_bounty_target", false)):
				target = enemy
				break
			if bool(enemy.get("alive")):
				enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {"weapon_id": &"rifle", "damage_kind": &"projectile"})
		if target != null:
			break
		await physics_frame
	_expect(target != null and game.event_director.is_active(&"elite_bounty"), "bounty target did not become active")
	if target != null:
		if expect_success:
			target.take_damage(9999, Vector2.ZERO, target.global_position, {"weapon_id": &"environment", "damage_kind": &"environment"})
		else:
			game.debug_expire_survival_event()
		await process_frame
		_expect(not bool(target.get_meta("survival_bounty_target", false)), "resolved bounty retained target metadata")
		_expect(not expect_success or not bool(target.get("alive")), "successful bounty did not kill its target")
		_expect(expect_success or bool(target.get("alive")), "failed bounty incorrectly killed its target")
	var history: Array = game.event_director.get_history()
	var expected_status := &"success" if expect_success else &"failed"
	_expect(history.size() == 1 and StringName(history[0].get("status", &"")) == expected_status, "bounty result was not unique and stable")
	_expect(int(game.event_director.get_summary().get("bounty_successes", 0)) == (1 if expect_success else 0), "bounty success count is inaccurate")
	game.queue_free()
	await process_frame


func _verify_reinforcements() -> void:
	var game := _new_game(IndustrialScene, 1004)
	_force_only(game, &"emergency_reinforcements", 3)
	var active_seen := false
	var modifier_seen := false
	var elite_seen := false
	for _frame in range(2200):
		_handle_upgrade(game)
		if game.event_director.is_active(&"emergency_reinforcements"):
			active_seen = true
			modifier_seen = modifier_seen or game.wave_manager._event_modifiers_active
		for enemy in game.enemies.get_children():
			elite_seen = elite_seen or str(enemy.get("kind")) == "elite"
			if bool(enemy.get("alive")):
				enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {"weapon_id": &"rifle", "damage_kind": &"projectile"})
		if not game.event_director.get_history().is_empty():
			break
		await physics_frame
	_expect(active_seen and modifier_seen and elite_seen, "reinforcement event did not add bounded pressure and one elite")
	var history: Array = game.event_director.get_history()
	_expect(history.size() == 1 and StringName(history[0].get("status", &"")) == &"success", "reinforcement event did not settle")
	_expect(int(game.event_director.get_summary().get("reinforcement_successes", 0)) == 1, "reinforcement success count is inaccurate")
	_expect(not game.wave_manager._event_modifiers_active, "reinforcement modifiers remained after resolution")
	game.queue_free()
	await process_frame


func _complete_event_run(scene: PackedScene, expected_map: StringName, seed_value: int) -> Dictionary:
	var game := _new_game(scene, seed_value)
	var scheduled_ids: Dictionary = {}
	for definition_value in game.event_director.schedule.values():
		var definition: Dictionary = definition_value
		scheduled_ids[StringName(definition.get("event_id", &""))] = true
	var overlap := false
	var max_active := 0
	for _frame in range(5200):
		if game.run_state == "complete":
			break
		max_active = maxi(max_active, game.wave_manager.get_alive_count())
		overlap = overlap or (game.upgrade_overlay.visible and (game.event_overlay.event_panel.visible or game.event_overlay.is_supply_open()))
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
		"unique_events": scheduled_ids.size(),
		"overlap": overlap,
		"max_active": max_active,
		"boss_clean": not game.boss.active and game.projectiles.get_child_count() == 0,
	}
	_expect(game.map_id == expected_map, "%s event run loaded the wrong map" % expected_map)
	_expect(bool(result["boss_clean"]), "%s retained Boss or projectile state" % expected_map)
	_expect("EVENTS" in game.hud.state_subtitle.text, "%s settlement omitted event statistics" % expected_map)
	game.queue_free()
	await process_frame
	await process_frame
	return result


func _verify_event_death_reset() -> void:
	var game := _new_game(SublevelScene, 5501)
	_force_only(game, &"emergency_reinforcements", 3)
	for _frame in range(1800):
		_handle_upgrade(game)
		_kill_all_hostiles(game)
		if game.event_director.is_active():
			break
		await physics_frame
	_expect(game.event_director.is_active(), "death-reset setup did not reach an active event")
	var old_id := game.get_instance_id()
	game.player.take_damage(9999, Vector2.ZERO, game.player.global_position, {"source": &"event_reset_test", "damage_kind": &"environment"})
	await create_timer(1.8).timeout
	_expect(current_scene != null and current_scene.get_instance_id() != old_id, "death during event did not reload")
	if current_scene != null and current_scene.get_instance_id() != old_id:
		_expect(current_scene.event_director.get_history().is_empty() and not current_scene.event_director.is_active(), "restart retained event state")
		_expect(not current_scene.event_overlay.event_panel.visible and not current_scene.event_overlay.is_supply_open(), "restart retained event UI")
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
	var ordered: Array[Node] = []
	for enemy in game.enemies.get_children():
		if bool(enemy.get_meta("survival_bounty_target", false)):
			ordered.push_front(enemy)
		else:
			ordered.append(enemy)
	for enemy in ordered:
		if bool(enemy.get("alive")):
			enemy.take_damage(9999, Vector2.ZERO, enemy.global_position, {"weapon_id": &"rifle", "damage_kind": &"projectile"})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SURVIVAL_EVENTS_PASS scheduling, supply, bounty success/failure, reinforcements, two-map completion, reset and PVE isolation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
