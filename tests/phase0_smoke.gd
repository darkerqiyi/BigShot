extends SceneTree

const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"sprint",
	&"aim_up",
	&"aim_down",
	&"jump",
	&"crouch",
	&"fire",
	&"weapon_1",
	&"weapon_2",
	&"weapon_3",
	&"weapon_4",
	&"throw_grenade",
	&"pause",
	&"debug_toggle",
]


func _init() -> void:
	var failures: Array[String] = []
	var version := Engine.get_version_info()
	if int(version.get("major", 0)) != 4:
		failures.append("Godot major version must be 4")

	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("missing input action: %s" % action)
		elif InputMap.action_get_events(action).is_empty():
			failures.append("input action has no binding: %s" % action)

	for action in REQUIRED_ACTIONS:
		if not _has_keyboard_or_mouse_binding(action):
			failures.append("input action has no keyboard/mouse binding: %s" % action)
	for action in REQUIRED_ACTIONS.filter(func(action: StringName) -> bool: return action not in [&"sprint", &"debug_toggle", &"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4"]):
		if not _has_gamepad_binding(action):
			failures.append("input action has no gamepad binding: %s" % action)
	if not _has_physical_key(&"debug_toggle", KEY_F3):
		failures.append("debug_toggle must be bound to F3")
	if not _has_key_location(&"sprint", KEY_SHIFT, KEY_LOCATION_LEFT) or not _has_key_location(&"sprint", KEY_SHIFT, KEY_LOCATION_RIGHT):
		failures.append("sprint must be bound to Left Shift and Right Shift")
	if int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1)) != 0:
		failures.append("canvas texture filtering must use nearest")
	if not bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)):
		failures.append("2D transforms must snap to logical pixels")
	if not bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", false)):
		failures.append("2D vertices must snap to logical pixels")
	if String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) != "keep":
		failures.append("window scaling must preserve aspect ratio")

	var packed_scene := load("res://scenes/main/main.tscn") as PackedScene
	if packed_scene == null:
		failures.append("main scene could not be loaded")
	else:
		var instance := packed_scene.instantiate()
		if instance.get_node_or_null("DebugOverlay/Panel/Margin/Rows/Readout") == null:
			failures.append("debug readout node is missing")
		instance.free()

	if failures.is_empty():
		print("PHASE0_SMOKE_PASS Godot %s; %d input actions; main scene and debug overlay loaded" % [
			Engine.get_version_info().get("string", "unknown"),
			REQUIRED_ACTIONS.size(),
		])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _has_keyboard_or_mouse_binding(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return true
	return false


func _has_gamepad_binding(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false


func _has_physical_key(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


func _has_key_location(action: StringName, key: Key, location: KeyLocation) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key and event.location == location:
			return true
	return false
