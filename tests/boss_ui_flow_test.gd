extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(4):
		await physics_frame
	var hud = game.hud
	_test_initial_hierarchy(hud)
	await _test_controls_auto_hide(hud)
	await _enter_and_test_boss_intro(game, hud)
	await _test_phase_flow(game, hud)
	await _test_defeat_flow(game, hud)
	game.queue_free()
	await process_frame
	_finish()


func _test_initial_hierarchy(hud: CanvasLayer) -> void:
	_expect(hud.boss_ui_state == hud.BossUIState.HIDDEN and not hud.boss_panel.visible, "Boss UI did not initialize hidden")
	_expect(hud.controls_label.visible and hud.objective_label.visible, "initial onboarding hints did not appear")
	_expect(hud.player_panel.size == Vector2(296, 96), "player panel compact baseline changed")
	_expect(hud.weapon_rack.size == Vector2(252, 128), "weapon rack compact baseline changed")
	_expect(hud.score_panel.size == Vector2(160, 36), "score panel compact baseline changed")


func _test_controls_auto_hide(hud: CanvasLayer) -> void:
	hud._process(4.1)
	# The authored fade is 0.20 s; leave enough headroom for one slow headless frame.
	await create_timer(0.35).timeout
	_expect(not hud.controls_label.visible, "full control guide did not auto-hide")
	hud.set_controls_persistent(true)
	_expect(hud.controls_label.visible and not hud.controls_auto_hide_enabled, "persistent control-guide configuration did not work")
	hud.set_controls_persistent(false)
	hud.hide_controls(true)


func _enter_and_test_boss_intro(game: Node, hud: CanvasLayer) -> void:
	game._debug_unlock_boss_for_tests()
	game.player.global_position.x = 17850.0
	game._process(0.0)
	_expect(game.run_state == "boss" and hud.boss_ui_state == hud.BossUIState.INTRO, "Boss entry did not enter the dedicated Intro UI state")
	_expect(hud.banner.visible and hud.banner.text == "BOSS // THE IRON TEMPEST", "Boss intro title is missing or inaccurate")
	_expect(not hud.objective_label.visible and not hud.controls_label.visible, "nonessential hints remained during Boss intro")
	_expect(hud.boss_panel.visible and hud.boss_panel.modulate.a < 0.01, "Boss health appeared before the intro title cleared")
	await create_timer(0.20).timeout
	var alpha_before_pause: float = hud.banner.modulate.a
	hud.toggle_pause()
	for _frame in range(12):
		await process_frame
	_expect(paused and is_equal_approx(hud.banner.modulate.a, alpha_before_pause), "Boss intro fade advanced while paused")
	hud.toggle_pause()
	await create_timer(0.72).timeout
	_expect(hud.boss_ui_state == hud.BossUIState.ACTIVE, "Boss intro did not settle into Active state")
	_expect(not hud.banner.visible and hud.boss_panel.modulate.a > 0.99, "central Boss title remained after combat activation")
	_expect(not hud.objective_label.visible and not hud.controls_label.visible, "Boss active state restored redundant text")
	_expect(hud.boss_phase_label.text == "PHASE I // ARMORED", "Phase I is not represented only in the Boss panel")
	game._update_objective()
	_expect(not hud.objective_label.visible, "generic objective refresh restored BREAK THE IRON TEMPEST during Boss combat")


func _test_phase_flow(game: Node, hud: CanvasLayer) -> void:
	var phase_two_damage: int = game.boss.health - int(game.boss.MAX_HEALTH * 0.62)
	game.boss.take_damage(phase_two_damage, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"rifle"})
	_expect(game.boss.phase == 2 and hud.boss_ui_state == hud.BossUIState.PHASE_TRANSITION, "Phase II did not enter the UI transition state")
	_expect(hud.boss_phase_toast.visible and "ARMOR BREAK" in hud.boss_phase_toast.text, "Phase II compact toast is missing")
	_expect(not hud.banner.visible and "CORE EXPOSED" in hud.boss_phase_label.text, "Phase II reused the central Boss title or desynced the panel")
	await create_timer(1.05).timeout
	_expect(hud.boss_ui_state == hud.BossUIState.ACTIVE and not hud.boss_phase_toast.visible, "Phase II toast did not clear exactly once")
	game.boss._update_transition(1.0)
	var phase_three_damage: int = game.boss.health - int(game.boss.MAX_HEALTH * 0.28)
	game.boss.take_damage(phase_three_damage, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper", "impact_strength": 1.0})
	_expect(game.boss.phase == 3 and hud.boss_ui_state == hud.BossUIState.PHASE_TRANSITION, "Phase III did not enter the UI transition state")
	_expect("OVERLOAD" in hud.boss_phase_toast.text and not hud.banner.visible, "Phase III did not use the compact transition label")
	await create_timer(1.05).timeout
	_expect(hud.boss_ui_state == hud.BossUIState.ACTIVE and not hud.boss_phase_toast.visible, "Phase III toast did not clear")
	var positions: PackedFloat32Array = hud.boss_thresholds.get_marker_positions()
	_expect(positions.size() == 2 and positions[0] > positions[1], "Boss health threshold markers are missing or reversed")


func _test_defeat_flow(game: Node, hud: CanvasLayer) -> void:
	game.boss._update_transition(1.0)
	game.boss.take_damage(9999, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"shotgun", "impact_strength": 1.0})
	_expect(hud.boss_ui_state == hud.BossUIState.DEFEATED and hud.banner.visible and hud.banner.text == "IRON TEMPEST DOWN", "Boss defeat did not enter the dedicated Defeated UI state")
	_expect(int(hud.boss_actual_bar.value) == 0 and not hud.objective_label.visible, "Boss defeat left health or task UI stale")
	await create_timer(1.25).timeout
	_expect(hud.boss_ui_state == hud.BossUIState.HIDDEN and not hud.boss_panel.visible, "Boss panel did not exit after defeat")
	_expect(hud._overlay_mode == &"settlement" and hud.state_overlay.visible, "settlement did not replace temporary Boss messaging")
	_expect(not hud.banner.visible and not hud.boss_phase_toast.visible, "Boss transient labels remained over settlement")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	paused = false
	if failures.is_empty():
		print("BOSS_UI_FLOW_PASS intro/title timing, pause-safe fade, active hierarchy, one-shot phase toasts, integrated thresholds, defeat exit, compact HUD, control auto-hide")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
