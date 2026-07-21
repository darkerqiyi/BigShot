extends CanvasLayer

@export var player_path: NodePath
@onready var readout: Label = $Panel/Margin/Rows/Readout
@onready var player: Node = get_node_or_null(player_path)

var _last_input_kind := "keyboard/mouse"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		visible = false
		set_process(false)
		return
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_kind = "gamepad"
	elif event is InputEventKey or event is InputEventMouse:
		_last_input_kind = "keyboard/mouse"

	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		if player != null and player.has_method("set_aim_debug_enabled"):
			player.set_aim_debug_enabled(visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_readout()


func _update_readout() -> void:
	if readout == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var active_actions: Array[String] = []
	for action in [&"move_left", &"move_right", &"sprint", &"jump", &"fire", &"reload", &"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4", &"restart"]:
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
		"is_sprinting": false,
		"current_stamina": 0.0,
		"max_stamina": 0.0,
		"drain_rate": 0.0,
		"regen_delay_remaining": 0.0,
		"regen_rate": 0.0,
		"exhausted": false,
		"current_move_speed": 0.0,
		"sprint_block_reason": &"unknown",
		"aim_target_world": Vector2.ZERO,
		"last_shot_origin": Vector2.ZERO,
		"last_shot_direction": Vector2.RIGHT,
		"aim_debug_enabled": false,
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
	readout.text += "\n\nSPRINT: %s  exhausted %s\nStamina: %.1f / %.1f  drain %.1f/s\nRegen delay: %.3fs  rate %.1f/s\nMove speed: %.1f  grounded %s\nBlock: %s" % [
		"ACTIVE" if player_snapshot["is_sprinting"] else "idle",
		"yes" if player_snapshot["exhausted"] else "no",
		float(player_snapshot["current_stamina"]),
		float(player_snapshot["max_stamina"]),
		float(player_snapshot["drain_rate"]),
		float(player_snapshot["regen_delay_remaining"]),
		float(player_snapshot["regen_rate"]),
		float(player_snapshot["current_move_speed"]),
		"yes" if player_snapshot["grounded"] else "no",
		str(player_snapshot["sprint_block_reason"]),
	]
	var shot_origin: Vector2 = player_snapshot["last_shot_origin"]
	var shot_direction: Vector2 = player_snapshot["last_shot_direction"]
	readout.text += "\n\nAIM RAY: %s\nMuzzle: (%.1f, %.1f)  Target: %s\nShot dir: (%.4f, %.4f)" % [
		"DRAW" if bool(player_snapshot["aim_debug_enabled"]) else "hidden",
		shot_origin.x,
		shot_origin.y,
		str(player_snapshot["aim_target_world"]),
		shot_direction.x,
		shot_direction.y,
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
	var upgrade_manager := get_node_or_null("../RunUpgradeManager")
	if upgrade_manager != null and upgrade_manager.has_method("get_debug_snapshot"):
		var upgrade_snapshot: Dictionary = upgrade_manager.get_debug_snapshot()
		readout.text += "\n\nUPGRADES: %s  seed %d  pool %d\nCandidates: %s\nStacks: %s" % [
			"SELECTING" if bool(upgrade_snapshot.get("selection_open", false)) else "runtime",
			int(upgrade_snapshot.get("random_seed", 0)),
			int(upgrade_snapshot.get("remaining_pool", 0)),
			", ".join(upgrade_snapshot.get("candidate_ids", []) as Array),
			JSON.stringify(upgrade_snapshot.get("stacks", {})),
		]
	var event_director := get_node_or_null("../EventDirector")
	if event_director != null and event_director.has_method("get_debug_snapshot"):
		var event_snapshot: Dictionary = event_director.get_debug_snapshot()
		readout.text += "\n\nEVENTS: %s  seed %d  wave %d  %.1fs\nSchedule: %s\nHistory: %s" % [
			str(event_snapshot.get("active_event", &"none")),
			int(event_snapshot.get("seed", 0)),
			int(event_snapshot.get("active_wave", 0)),
			float(event_snapshot.get("remaining", 0.0)),
			JSON.stringify(event_snapshot.get("schedule", {})),
			JSON.stringify(event_snapshot.get("history", [])),
		]
	var nearest_enemy: Node2D = null
	var nearest_distance := INF
	if player is Node2D:
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if not candidate is Node2D or not is_instance_valid(candidate):
				continue
			var distance := (candidate as Node2D).global_position.distance_squared_to((player as Node2D).global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = candidate as Node2D
	if nearest_enemy != null and nearest_enemy.has_method("get_debug_combat_snapshot"):
		var enemy_snapshot: Dictionary = nearest_enemy.get_debug_combat_snapshot()
		var last_hit: Dictionary = enemy_snapshot.get("last_damage", {})
		readout.text += "\n\nTARGET: %s  HP %d/%d\nHead pos/size: %s / %s\nLast: %s  base %d  x%.1f  mitigation %.2f  final %d" % [
			str(enemy_snapshot.get("kind", &"enemy")),
			int(enemy_snapshot.get("health", 0)),
			int(enemy_snapshot.get("max_health", 0)),
			str(enemy_snapshot.get("head_position", Vector2.ZERO)),
			str(enemy_snapshot.get("head_size", Vector2.ZERO)),
			str(last_hit.get("hit_zone", &"none")),
			int(last_hit.get("base_damage", 0)),
			float(last_hit.get("headshot_multiplier", 1.0)),
			float(last_hit.get("mitigation", 0.0)),
			int(last_hit.get("final_damage", 0)),
		]
	var damage_number_manager := get_node_or_null("../World/Effects/DamageNumbers")
	if damage_number_manager != null and damage_number_manager.has_method("get_debug_snapshot"):
		var number_snapshot: Dictionary = damage_number_manager.get_debug_snapshot()
		readout.text += "\nDamage numbers: %d/%d  free %d  dropped %d" % [
			int(number_snapshot.get("visible", 0)),
			int(number_snapshot.get("pool_total", 0)),
			int(number_snapshot.get("pool_free", 0)),
			int(number_snapshot.get("dropped_visuals", 0)),
		]
	var wave_manager := get_node_or_null("../WaveManager")
	if wave_manager != null and wave_manager.has_method("get_debug_snapshot"):
		var wave_snapshot: Dictionary = wave_manager.get_debug_snapshot()
		readout.text += "\nWAVE %d: total %d  cap %d\nRest %.1fs  spawn %.2fs  quick %s" % [
			int(wave_snapshot.get("wave", 0)),
			int(wave_snapshot.get("wave_total_enemies", 0)),
			int(wave_snapshot.get("active_limit", 0)),
			float(wave_snapshot.get("rest_remaining", 0.0)),
			float(wave_snapshot.get("spawn_interval", 0.0)),
			"yes" if bool(wave_snapshot.get("fast_start_requested", false)) else "no",
		]
