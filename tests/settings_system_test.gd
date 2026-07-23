extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := root.get_node_or_null("SettingsManager")
	_expect(settings != null, "SettingsManager autoload is missing")
	if settings == null:
		_finish()
		return
	settings.reset_defaults()
	_expect(str(settings.get_value(&"display", &"resolution", "")) == "1280x720", "default resolution is incorrect")
	_expect(int(settings.get_value(&"audio", &"music", 0)) == 72, "default Music volume is incorrect")
	settings.set_value(&"display", &"resolution", "1920x1080")
	settings.set_value(&"display", &"vsync", false)
	settings.set_value(&"display", &"integer_scaling", true)
	settings.set_value(&"audio", &"ui", 55)
	settings.set_value(&"experience", &"camera_shake", 50)
	settings.set_value(&"experience", &"damage_numbers", false)
	settings.set_value(&"experience", &"screen_flash", 25)
	settings.set_value(&"experience", &"show_control_hints", false)
	_expect(settings.rebind_action(&"jump", KEY_Q), "valid jump rebind was rejected")
	_expect(not settings.rebind_action(&"move_left", KEY_Q), "duplicate critical keybind was accepted")
	_expect(_action_has_key(&"jump", KEY_Q), "runtime InputMap did not receive the rebound jump key")
	_expect(settings.save_settings(), "settings file could not be saved")
	settings.load_settings()
	_expect(str(settings.get_value(&"display", &"resolution", "")) == "1920x1080", "resolution did not persist")
	_expect(int(settings.get_value(&"audio", &"ui", 0)) == 55, "UI volume did not persist")
	_expect(settings.get_keycode(&"jump") == KEY_Q, "keybind did not persist")

	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(is_equal_approx(game.combat_feedback.shake_scale, 0.5), "camera shake setting was not applied to combat feedback")
	_expect(not game.damage_numbers.display_enabled, "damage-number setting was not applied")
	_expect(is_equal_approx(game.impact_effects.flash_scale, 0.25), "flash-intensity setting was not applied")
	_expect(not game.hud.controls_label.visible, "disabled control hints remained visible")
	_expect(AudioServer.get_bus_index("UI") >= 0, "UI audio bus is missing")
	var mix: Dictionary = game.sfx.get_mix_snapshot()
	_expect(int((mix.get(&"UI", {}) as Dictionary).get("percent", 0)) == 55, "persistent UI volume did not reach the runtime mixer")
	game.queue_free()
	await process_frame

	var corrupt := ConfigFile.new()
	corrupt.set_value("display", "resolution", "999x111")
	corrupt.set_value("audio", "music", 900)
	corrupt.set_value("experience", "camera_shake", -40)
	corrupt.save("user://settings.cfg")
	settings.load_settings()
	_expect(str(settings.get_value(&"display", &"resolution", "")) == "1280x720", "invalid resolution did not fall back safely")
	_expect(int(settings.get_value(&"audio", &"music", 0)) == 100, "invalid volume was not clamped")
	_expect(int(settings.get_value(&"experience", &"camera_shake", -1)) == 0, "invalid shake value was not clamped")
	settings.reset_defaults()
	_expect(_action_has_key(&"move_left", KEY_A) and _action_has_key(&"move_right", KEY_D), "restored movement actions no longer use configurable A/D defaults")
	_finish()


func _action_has_key(action: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SETTINGS_SYSTEM_PASS persistent display/audio/experience/keybinds, duplicate rejection, runtime application and corrupt-config fallback")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
