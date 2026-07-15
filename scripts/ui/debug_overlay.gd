extends CanvasLayer

@export var player_path: NodePath
@onready var readout: Label = $Panel/Margin/Rows/Readout
@onready var player: Node = get_node_or_null(player_path)

var _last_input_kind := "keyboard/mouse"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_kind = "gamepad"
	elif event is InputEventKey or event is InputEventMouse:
		_last_input_kind = "keyboard/mouse"

	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_readout()


func _update_readout() -> void:
	if readout == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var active_actions: Array[String] = []
	for action in [&"move_left", &"move_right", &"jump", &"fire", &"reload", &"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4", &"restart"]:
		if Input.is_action_pressed(action):
			active_actions.append(action)
	var player_snapshot := {
		"velocity": Vector2.ZERO,
		"movement_intent": 0.0,
		"facing_direction": 1,
		"grounded": false,
		"jump_buffer": 0.0,
		"coyote": 0.0,
		"health": 0,
		"ammo": 0,
		"weapon_name": "NONE",
		"weapon_damage": 0,
		"weapon_fire_rate": 0.0,
		"weapon_spread": 0.0,
		"weapon_projectiles": 0,
		"weapon_cooldown": 0.0,
		"weapon_reloading": false,
		"last_pattern": [],
		"is_rolling": false,
		"roll_direction": 0,
		"roll_cooldown": 0.0,
		"last_left_tap": 0.0,
		"last_right_tap": 0.0,
		"last_damage_kind": &"none",
		"projectile_dodges": 0,
		"roll_attempts": 0,
		"roll_successes": 0,
		"grenade_charging": false,
		"grenade_charge": 0.0,
		"grenade_count": 0,
		"grenade_throws": 0,
		"predicted_throw_velocity": Vector2.ZERO,
	}
	if player != null and player.has_method("get_debug_snapshot"):
		player_snapshot = player.get_debug_snapshot()
	var player_velocity: Vector2 = player_snapshot["velocity"]
	var pattern_text := "none"
	var pattern: Array = player_snapshot["last_pattern"]
	if not pattern.is_empty():
		var angles: Array[String] = []
		for angle in pattern:
			angles.append("%+.1f°" % float(angle))
		pattern_text = ", ".join(angles)
	readout.text = "FPS: %d\nFrame: %.2f ms\nViewport: %d x %d\nInput: %s\nGamepads: %d\nActions: %s\nVelocity: (%.1f, %.1f)\nIntent: %.2f\nFacing: %s\nGrounded: %s\nJump buffer: %.3f\nCoyote: %.3f\nHP / Ammo: %d / %d\n\nWEAPON: %s\nDamage / interval: %d / %.3fs\nSpread / projectiles: %.2f° / %d\nCooldown: %.3fs%s\nLast paths: %s" % [
		Engine.get_frames_per_second(),
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		int(viewport_size.x),
		int(viewport_size.y),
		_last_input_kind,
		Input.get_connected_joypads().size(),
		", ".join(active_actions) if not active_actions.is_empty() else "none",
		player_velocity.x,
		player_velocity.y,
		player_snapshot["movement_intent"],
		"right" if player_snapshot["facing_direction"] > 0 else "left",
		"yes" if player_snapshot["grounded"] else "no",
		player_snapshot["jump_buffer"],
		player_snapshot["coyote"],
		player_snapshot["health"],
		player_snapshot["ammo"],
		player_snapshot["weapon_name"],
		player_snapshot["weapon_damage"],
		player_snapshot["weapon_fire_rate"],
		player_snapshot["weapon_spread"],
		player_snapshot["weapon_projectiles"],
		player_snapshot["weapon_cooldown"],
		"  RELOADING" if player_snapshot["weapon_reloading"] else "",
		pattern_text,
	]
	readout.text += "\n\nROLL: %s  dir %d  CD %.3f\nTap L/R: %.3f / %.3f\nAttempts / success / dodges: %d / %d / %d\nLast damage: %s" % [
		"ACTIVE" if player_snapshot["is_rolling"] else "ready" if float(player_snapshot["roll_cooldown"]) <= 0.0 else "cooldown",
		int(player_snapshot["roll_direction"]),
		float(player_snapshot["roll_cooldown"]),
		float(player_snapshot["last_left_tap"]),
		float(player_snapshot["last_right_tap"]),
		int(player_snapshot["roll_attempts"]),
		int(player_snapshot["roll_successes"]),
		int(player_snapshot["projectile_dodges"]),
		str(player_snapshot["last_damage_kind"]),
	]
	var predicted_velocity: Vector2 = player_snapshot["predicted_throw_velocity"]
	readout.text += "\nGRENADE: %s  charge %.2f  count %d  throws %d\nThrow velocity: (%.1f, %.1f)" % [
		"CHARGING" if player_snapshot["grenade_charging"] else "idle",
		float(player_snapshot["grenade_charge"]),
		int(player_snapshot["grenade_count"]),
		int(player_snapshot["grenade_throws"]),
		predicted_velocity.x,
		predicted_velocity.y,
	]
	var telemetry := get_node_or_null("../RunTelemetry")
	if telemetry != null and telemetry.has_method("get_snapshot"):
		var run_snapshot: Dictionary = telemetry.get_snapshot()
		var grenade_stats: Dictionary = run_snapshot.get("grenades", {})
		readout.text += "\nRun charge avg %.2f  hits/kills %d/%d\nGrenade damage: %s" % [
			float(grenade_stats.get("average_charge", 0.0)),
			int(grenade_stats.get("hits", 0)),
			int(grenade_stats.get("kills", 0)),
			JSON.stringify(grenade_stats.get("damage_by_target", {})),
		]
	var feedback := get_node_or_null("../CombatFeedback")
	if feedback != null and feedback.has_method("get_debug_snapshot"):
		var feedback_snapshot: Dictionary = feedback.get_debug_snapshot()
		readout.text += "\n\nFX: shake %d%%  profile %s\nAccepted / merged: %d / %d\nF4 cycles 100%% / 50%% / OFF" % [
			int(round(float(feedback_snapshot["shake_scale"]) * 100.0)),
			str(feedback_snapshot["last_profile"]),
			int(feedback_snapshot["accepted_shakes"]),
			int(feedback_snapshot["merged_requests"]),
		]
