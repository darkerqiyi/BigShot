extends Node

signal setting_changed(section: StringName, key: StringName, value: Variant)
signal keybind_changed(action: StringName, keycode: int)
signal settings_reset

const CONFIG_PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const BINDABLE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"jump", &"sprint", &"reload",
	&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4", &"pause",
]
const DEFAULT_KEYS := {
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"jump": KEY_SPACE,
	&"sprint": KEY_SHIFT,
	&"reload": KEY_R,
	&"weapon_1": KEY_1,
	&"weapon_2": KEY_2,
	&"weapon_3": KEY_3,
	&"weapon_4": KEY_4,
	&"pause": KEY_ESCAPE,
}
const DEFAULTS := {
	"display": {
		"window_mode": "windowed",
		"resolution": "1280x720",
		"vsync": true,
		"integer_scaling": false,
	},
	"audio": {
		"master": 100,
		"music": 72,
		"sfx": 86,
		"ui": 80,
		"master_muted": false,
		"music_muted": false,
		"sfx_muted": false,
		"ui_muted": false,
	},
	"experience": {
		"camera_shake": 100,
		"damage_numbers": true,
		"screen_flash": 100,
		"show_control_hints": true,
		"tutorial_complete": false,
	},
}

var _values: Dictionary = {}
var _keycodes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	_values = DEFAULTS.duplicate(true)
	_keycodes = DEFAULT_KEYS.duplicate(true)
	var config := ConfigFile.new()
	var error := config.load(CONFIG_PATH)
	if error == OK:
		for section in DEFAULTS:
			var defaults: Dictionary = DEFAULTS[section]
			for key in defaults:
				var loaded: Variant = config.get_value(section, key, defaults[key])
				_values[section][key] = _sanitize(StringName(section), StringName(key), loaded)
		for action in BINDABLE_ACTIONS:
			var loaded_key := int(config.get_value("keybinds", String(action), DEFAULT_KEYS[action]))
			if loaded_key > 0:
				_keycodes[action] = loaded_key
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Settings file could not be read; defaults restored (error %d)" % error)
	_apply_display()
	_apply_keybinds()
	call_deferred("_apply_audio")


func save_settings() -> bool:
	var config := ConfigFile.new()
	for section in _values:
		for key in (_values[section] as Dictionary):
			config.set_value(section, key, _values[section][key])
	for action in BINDABLE_ACTIONS:
		config.set_value("keybinds", String(action), int(_keycodes[action]))
	var error := config.save(CONFIG_PATH)
	if error != OK:
		push_error("Failed to save settings (error %d)" % error)
	return error == OK


func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	if not _values.has(section):
		return fallback
	return (_values[section] as Dictionary).get(key, fallback)


func set_value(section: StringName, key: StringName, value: Variant, persist: bool = true) -> Variant:
	if not DEFAULTS.has(section) or not (DEFAULTS[section] as Dictionary).has(key):
		return null
	var sanitized: Variant = _sanitize(section, key, value)
	_values[section][key] = sanitized
	if section == &"display":
		_apply_display()
	elif section == &"audio":
		_apply_audio()
	if persist:
		save_settings()
	setting_changed.emit(section, key, sanitized)
	return sanitized


func reset_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	_keycodes = DEFAULT_KEYS.duplicate(true)
	_apply_display()
	_apply_keybinds()
	_apply_audio()
	save_settings()
	settings_reset.emit()
	for section in _values:
		for key in (_values[section] as Dictionary):
			setting_changed.emit(StringName(section), StringName(key), _values[section][key])


func rebind_action(action: StringName, keycode: int) -> bool:
	if action not in BINDABLE_ACTIONS or keycode <= 0:
		return false
	for other_action in BINDABLE_ACTIONS:
		if other_action != action and int(_keycodes.get(other_action, 0)) == keycode:
			return false
	_keycodes[action] = keycode
	_apply_action_key(action, keycode)
	save_settings()
	keybind_changed.emit(action, keycode)
	return true


func get_keycode(action: StringName) -> int:
	return int(_keycodes.get(action, DEFAULT_KEYS.get(action, 0)))


func get_key_label(action: StringName) -> String:
	return OS.get_keycode_string(get_keycode(action))


func get_snapshot() -> Dictionary:
	return {
		"values": _values.duplicate(true),
		"keybinds": _keycodes.duplicate(true),
	}


func _sanitize(section: StringName, key: StringName, value: Variant) -> Variant:
	if section == &"display":
		if key == &"window_mode":
			return str(value) if str(value) in ["windowed", "fullscreen"] else "windowed"
		if key == &"resolution":
			var text := str(value)
			for resolution in RESOLUTIONS:
				if text == "%dx%d" % [resolution.x, resolution.y]:
					return text
			return "1280x720"
		return bool(value)
	if section == &"audio":
		if str(key).ends_with("_muted"):
			return bool(value)
		return clampi(int(value), 0, 100)
	if section == &"experience":
		if key in [&"camera_shake", &"screen_flash"]:
			return clampi(int(value), 0, 100)
		return bool(value)
	return value


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := str(get_value(&"display", &"window_mode", "windowed"))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED)
	var resolution_text := str(get_value(&"display", &"resolution", "1280x720")).split("x")
	if resolution_text.size() == 2 and mode == "windowed":
		DisplayServer.window_set_size(Vector2i(int(resolution_text[0]), int(resolution_text[1])))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value(&"display", &"vsync", true)) else DisplayServer.VSYNC_DISABLED)
	var window := get_tree().root
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if bool(get_value(&"display", &"integer_scaling", false)) else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


func _apply_audio() -> void:
	var mapping := {
		&"master": &"Master",
		&"music": &"Music",
		&"sfx": &"SFX",
		&"ui": &"UI",
	}
	for key in mapping:
		var bus_name: StringName = mapping[key]
		var index := AudioServer.get_bus_index(String(bus_name))
		if index < 0:
			continue
		var percent := int(get_value(&"audio", key, DEFAULTS["audio"][key]))
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(percent) / 100.0, 0.0001)))
		AudioServer.set_bus_mute(index, bool(get_value(&"audio", StringName("%s_muted" % key), false)))


func _apply_keybinds() -> void:
	for action in BINDABLE_ACTIONS:
		_apply_action_key(action, int(_keycodes[action]))


func _apply_action_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	if action == &"sprint" and keycode == KEY_SHIFT:
		for location in [KeyLocation.KEY_LOCATION_LEFT, KeyLocation.KEY_LOCATION_RIGHT]:
			var shift_event := InputEventKey.new()
			shift_event.physical_keycode = keycode
			shift_event.location = location
			InputMap.action_add_event(action, shift_event)
	else:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action, key_event)
