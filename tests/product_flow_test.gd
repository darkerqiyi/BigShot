extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := root.get_node_or_null("SceneFlow")
	_expect(flow != null, "SceneFlow autoload is missing")
	if flow == null:
		_finish()
		return
	change_scene_to_file("res://scenes/menu/mode_select.tscn")
	await process_frame
	await process_frame
	var menu := current_scene
	_expect(menu != null and menu.title_center.visible, "cold start did not show the title screen")
	menu._dismiss_title()
	_expect(menu.get_node("Center").visible and menu.pve_button.has_focus(), "title did not hand focus to the main menu")
	menu._show_settings()
	await process_frame
	_expect(is_instance_valid(menu._settings_menu) and not menu.get_node("Center").visible, "main-menu settings page did not open")
	menu._close_settings()
	await process_frame

	var pve_changed: bool = await flow.change_scene("res://scenes/main/main.tscn", {
		"product_intro": true,
		"map_name": "FLOW TEST",
		"objective": "VERIFY DEPLOYMENT LOCK",
		"countdown": 0.01,
	})
	_expect(pve_changed and current_scene != null and current_scene.has_method("begin_product_intro"), "PVE transition failed")
	if current_scene != null and current_scene.get("player") != null:
		_expect(not current_scene.player.controls_enabled, "deployment intro did not lock PVE controls")
	await create_timer(1.05).timeout
	_expect(current_scene != null and current_scene.player.controls_enabled, "deployment intro did not restore PVE controls")

	var menu_changed: bool = await flow.change_scene("res://scenes/menu/mode_select.tscn", {"show_map_select": true})
	_expect(menu_changed and current_scene != null and current_scene.map_center.visible, "return-to-map-selection context was not applied (map=%s title=%s center=%s)" % [
		str(current_scene.map_center.visible),
		str(current_scene.title_center.visible),
		str(current_scene.get_node("Center").visible),
	])
	var sublevel_path := "res://scenes/survival/survival_sublevel_09.tscn"
	var survival_changed: bool = await flow.change_scene(sublevel_path, {
		"product_intro": true,
		"map_name": "SUBLEVEL-09",
		"objective": "SURVIVE",
		"countdown": 0.01,
	})
	_expect(survival_changed and current_scene != null and StringName(current_scene.map_id) == &"sublevel_09", "Sublevel transition did not load the selected map")
	if current_scene != null:
		_expect(current_scene._control_locks.has(&"product_intro"), "survival deployment did not acquire the shared control lock")
	await create_timer(1.05).timeout
	if current_scene != null:
		_expect(not current_scene._control_locks.has(&"product_intro") and current_scene.player.controls_enabled, "survival deployment did not release controls")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	paused = false
	if failures.is_empty():
		print("PRODUCT_FLOW_PASS title/menu, fade transitions, deployment locks and map-selection return")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
