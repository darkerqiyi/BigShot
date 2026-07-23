extends SceneTree

const HUDScene := preload("res://scenes/ui/hud.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_render_settings()
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1080)]:
		await _test_layout(viewport_size)
	await _test_live_states()
	_finish()


func _test_render_settings() -> void:
	_expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280, "logical width is not 1280")
	_expect(ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "logical height is not 720")
	_expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "stretch mode changed from canvas_items")
	_expect(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "aspect ratio is not preserved")
	_expect(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "nearest texture filter is not active")
	_expect(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel") == true, "transform pixel snap is not active")
	_expect(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel") == true, "vertex pixel snap is not active")


func _test_layout(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var hud := HUDScene.instantiate()
	viewport.add_child(hud)
	await process_frame
	await process_frame
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
	for control in [hud.player_panel, hud.score_panel, hud.weapon_rack, hud.objective_label, hud.controls_label]:
		_expect(bounds.encloses(control.get_global_rect()), "%s escaped %dx%d viewport" % [control.name, viewport_size.x, viewport_size.y])
	hud.show_boss("THE IRON TEMPEST", 820)
	await process_frame
	_expect(bounds.encloses(hud.boss_panel.get_global_rect()), "BossPanel escaped %dx%d viewport" % [viewport_size.x, viewport_size.y])
	_expect(hud.player_panel.size.x <= 296.0 and hud.player_panel.size.y <= 96.0, "player HUD did not retain the compact footprint")
	_expect(hud.weapon_rack.size.x <= 252.0 and hud.weapon_rack.size.y <= 128.0, "weapon HUD did not retain the compact footprint")
	_expect(hud.score_panel.size.x <= 160.0 and hud.score_panel.size.y <= 36.0, "score HUD remained visually dominant")
	_expect(hud.boss_panel.size.y <= 78.0, "Boss HUD height was not reduced")
	_expect(not hud.boss_panel.get_global_rect().intersects(hud.player_panel.get_global_rect()), "Boss HUD overlaps player HUD at %dx%d" % [viewport_size.x, viewport_size.y])
	_expect(not hud.boss_panel.get_global_rect().intersects(hud.weapon_rack.get_global_rect()), "Boss HUD overlaps weapon rack at %dx%d" % [viewport_size.x, viewport_size.y])
	_expect(not hud.boss_panel.get_global_rect().intersects(hud.score_panel.get_global_rect()), "Boss HUD overlaps score at %dx%d" % [viewport_size.x, viewport_size.y])
	var markers: PackedFloat32Array = hud.boss_thresholds.get_marker_positions()
	_expect(markers.size() == 2 and is_equal_approx(markers[0], hud.boss_thresholds.size.x * 0.65) and is_equal_approx(markers[1], hud.boss_thresholds.size.x * 0.30), "Boss thresholds are not integrated at 65/30 percent")
	hud.set_ui_scale_percent(88)
	await process_frame
	_expect(hud.ui_scale_percent == 90 and bounds.encloses(hud.weapon_rack.get_global_rect()), "90 percent UI scale basis is invalid")
	hud.state_overlay.visible = true
	_expect(hud.state_overlay.get_rect().size == Vector2(viewport_size), "state overlay does not cover %dx%d" % [viewport_size.x, viewport_size.y])
	hud.audio_settings.visible = true
	await process_frame
	_expect(bounds.encloses(hud.state_panel.get_global_rect()) and bounds.encloses(hud.audio_settings.get_global_rect()), "pause audio controls escaped %dx%d viewport" % [viewport_size.x, viewport_size.y])
	viewport.queue_free()
	await process_frame


func _test_live_states() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await physics_frame
	var hud = game.hud
	_expect(hud.weapon_slots.size() == 4 and hud.weapon_icons.size() == 4, "four pixel weapon slots/icons are not present")
	hud.set_weapon(&"shotgun", WeaponData.get_weapon(&"shotgun"))
	hud.set_ammo(7, 8, false)
	hud.set_grenade_count(2, 3)
	_expect(hud._current_weapon_index == 1 and "SCATTERGUN" in hud.weapon_name_label.text, "weapon selection did not update pixel rack")
	_expect(hud.weapon_ammo_labels[1].text == "07/08" and hud.weapon_ammo_labels[0].text == "", "inactive weapon ammo was not simplified")
	_expect("GRENADES 2" in hud.ammo_label.text, "grenade inventory did not reach the compact player HUD")
	hud.set_health(70, 100)
	_expect(int(hud.health_bar.value) == 70 and hud.health_value.text == "070 / 100", "player pixel health HUD is inaccurate")
	for _frame in range(12):
		await physics_frame
	var player_rect_before: Rect2 = hud.player_panel.get_global_rect()
	var weapon_rect_before: Rect2 = hud.weapon_rack.get_global_rect()
	for enemy in game.enemies.get_children():
		enemy.set_physics_process(false)
		enemy.take_damage(9999)
	game.player.global_position.x = 3520.0
	game._process(0.0)
	game.boss.recovery_remaining = 10.0
	for _frame in range(90):
		await physics_frame
	_expect(hud.player_panel.get_global_rect().is_equal_approx(player_rect_before), "player HUD moved with world camera")
	_expect(hud.weapon_rack.get_global_rect().is_equal_approx(weapon_rect_before), "weapon rack moved with world camera")
	_expect(hud.player_panel.visible and hud.player_panel.modulate.a > 0.99, "player HUD became invisible during Boss entry")
	hud.show_boss("THE IRON TEMPEST", 820)
	hud.set_boss_health(500, 820, 2)
	_expect(int(hud.boss_actual_bar.value) == 500 and hud.boss_delayed_bar.value >= 500.0 and "PHASE II" in hud.boss_phase_label.text, "Boss pixel health or phase UI is inaccurate")
	hud.toggle_pause()
	_expect(paused and hud.state_overlay.visible and hud.audio_settings.visible and hud.settings_button.visible and hud.controls_button.visible and hud.main_menu_button.visible and hud._overlay_mode == &"pause", "pause overlay did not expose audio and product navigation")
	hud._on_settings_pressed()
	await process_frame
	_expect(hud._overlay_mode == &"settings" and is_instance_valid(hud._settings_menu) and not hud.state_overlay.visible, "pause settings page did not open the unified settings view")
	hud._close_settings_menu()
	_expect(hud._overlay_mode == &"pause" and hud.audio_settings.visible, "settings page did not return to pause")
	hud.toggle_pause()
	_expect(not paused and not hud.state_overlay.visible and not hud.audio_settings.visible, "resume did not restore game and hide audio settings")
	hud.show_death()
	_expect(hud.state_overlay.visible and hud._overlay_mode == &"death" and "OPERATIVE DOWN" in hud.state_title.text, "death overlay is not configured")
	hud.show_settlement(1250, 64, {"elapsed": 367.0, "kills": 29, "accuracy": 58, "damage_events": 7, "rank": "A"})
	_expect(hud._overlay_mode == &"settlement" and "TIME 06:07" in hud.state_subtitle.text and "SCORE 001250" in hud.state_subtitle.text and "KILLS 29" in hud.state_subtitle.text and "ACCURACY 058%" in hud.state_subtitle.text and "HITS TAKEN 07" in hud.state_subtitle.text and "HP 064" in hud.state_subtitle.text, "settlement summary does not use the available mission statistics")
	_expect(hud.primary_button.visible and hud.main_menu_button.visible and not hud.secondary_button.visible, "settlement does not provide replay and main-menu choices")
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	paused = false
	if failures.is_empty():
		print("PIXEL_UI_PASS nearest/snap baseline, responsive anchors, combat HUD, pause settings/controls and product settlement navigation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
