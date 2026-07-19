extends Node2D
class_name SurvivalSteamVent

signal cue_requested(cue: StringName, world_position: Vector2, priority: bool)

enum State { INITIAL_DELAY, WARNING, ACTIVE, COOLDOWN }

var warning_time := 1.25
var active_time := 0.95
var cooldown_time := 6.2
var player_damage := 18
var enemy_damage := 24
var vent_width := 116.0
var state := State.INITIAL_DELAY
var remaining := 4.5
var suspended := true
var damage_cycles := 0

var _player: Node2D
var _enemies: Node2D
var _damage_applied := false


func configure(definition: Dictionary, player_target: Node2D, enemy_container: Node2D) -> void:
	global_position = definition.get("position", Vector2.ZERO)
	vent_width = float(definition.get("width", vent_width))
	warning_time = float(definition.get("warning_time", warning_time))
	active_time = float(definition.get("active_time", active_time))
	cooldown_time = float(definition.get("cooldown_time", cooldown_time))
	player_damage = int(definition.get("player_damage", player_damage))
	enemy_damage = int(definition.get("enemy_damage", enemy_damage))
	remaining = float(definition.get("initial_delay", remaining))
	_player = player_target
	_enemies = enemy_container
	queue_redraw()


func set_suspended(value: bool) -> void:
	suspended = value
	queue_redraw()


func _process(delta: float) -> void:
	if suspended:
		return
	remaining = maxf(remaining - delta, 0.0)
	if not is_zero_approx(remaining):
		queue_redraw()
		return
	match state:
		State.INITIAL_DELAY, State.COOLDOWN:
			state = State.WARNING
			remaining = warning_time
			_damage_applied = false
			cue_requested.emit(&"hazard", global_position, true)
		State.WARNING:
			state = State.ACTIVE
			remaining = active_time
			_apply_damage_once()
		State.ACTIVE:
			state = State.COOLDOWN
			remaining = cooldown_time
	queue_redraw()


func _apply_damage_once() -> void:
	if _damage_applied:
		return
	_damage_applied = true
	damage_cycles += 1
	if _is_in_column(_player) and bool(_player.get("alive")) and _player.has_method("take_damage"):
		_player.take_damage(player_damage, Vector2(0.0, -135.0), _player.global_position, {
			"source": &"steam_vent",
			"damage_kind": &"environment",
		})
	if _enemies == null or not is_instance_valid(_enemies):
		return
	for enemy in _enemies.get_children():
		if not bool(enemy.get("alive")) or not _is_in_column(enemy) or not enemy.has_method("take_damage"):
			continue
		enemy.take_damage(enemy_damage, Vector2(0.0, -90.0), enemy.global_position, {
			"source": &"steam_vent",
			"damage_kind": &"environment",
			"weapon_id": &"environment",
			"direction": Vector2.UP,
		})


func _is_in_column(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var offset := target.global_position - global_position
	return absf(offset.x) <= vent_width * 0.5 and offset.y <= 8.0 and offset.y >= -150.0


func get_debug_snapshot() -> Dictionary:
	return {
		"state": state,
		"remaining": remaining,
		"suspended": suspended,
		"damage_cycles": damage_cycles,
		"warning_time": warning_time,
		"active_time": active_time,
		"cooldown_time": cooldown_time,
		"player_damage": player_damage,
		"enemy_damage": enemy_damage,
	}


func _draw() -> void:
	var half_width := vent_width * 0.5
	draw_rect(Rect2(-half_width, -4, vent_width, 8), Color("263b47"), true)
	for x in range(int(-half_width + 8.0), int(half_width), 16):
		draw_rect(Rect2(x, -8, 8, 4), Color("d28b38"), true)
	if suspended:
		return
	if state == State.WARNING:
		var progress := 1.0 - remaining / maxf(warning_time, 0.001)
		var pulse := 0.48 + sin(progress * TAU * 4.0) * 0.22
		draw_rect(Rect2(-half_width, -12, vent_width, 10), Color(1.0, 0.64, 0.16, 0.18 + pulse * 0.20), true)
		for x in range(int(-half_width + 6.0), int(half_width), 20):
			draw_rect(Rect2(x, -18, 10, 12), Color(1.0, 0.72, 0.24, 0.56 + pulse * 0.34), false, 2.0)
	elif state == State.ACTIVE:
		var active_progress := 1.0 - remaining / maxf(active_time, 0.001)
		for index in range(7):
			var x := lerpf(-half_width + 8.0, half_width - 12.0, float(index) / 6.0)
			var height := 86.0 + float(index % 3) * 22.0 + sin(active_progress * TAU + index) * 7.0
			draw_rect(Rect2(roundf(x), -height, 12, height - 4), Color(0.72, 0.94, 0.90, 0.42), true)
			draw_rect(Rect2(roundf(x + 3.0), -height - 8, 6, 14), Color(0.92, 1.0, 0.88, 0.82), true)
