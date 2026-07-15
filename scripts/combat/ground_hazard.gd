extends Node2D

signal resolved

var radius := 90.0
var damage := 20
var windup := 0.7
var active_time := 0.14
var age := 0.0
var target: Node2D
var source_tag: StringName = &"enemy"
var _applied := false


func configure(world_position: Vector2, hazard_radius: float, hazard_damage: int, warning_time: float, player_target: Node2D, source: StringName = &"enemy") -> void:
	global_position = world_position
	radius = hazard_radius
	damage = hazard_damage
	windup = warning_time
	target = player_target
	source_tag = source
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if not _applied and age >= windup:
		_applied = true
		_apply_damage()
		queue_redraw()
	if age >= windup + active_time:
		resolved.emit()
		queue_free()
	else:
		queue_redraw()


func _apply_damage() -> void:
	if target == null or not is_instance_valid(target) or not bool(target.get("alive")):
		return
	var horizontal_distance := absf(target.global_position.x - global_position.x)
	var vertical_distance := absf(target.global_position.y + 30.0 - global_position.y)
	if horizontal_distance <= radius and vertical_distance <= 95.0 and target.has_method("take_damage"):
		var push_direction := signf(target.global_position.x - global_position.x)
		target.take_damage(damage, Vector2(push_direction * 190.0, -170.0), target.global_position, {
			"source": source_tag,
			"damage_kind": &"area",
		})


func _draw() -> void:
	var warning_progress := clampf(age / maxf(windup, 0.001), 0.0, 1.0)
	if age < windup:
		var pulse := 0.72 + sin(age * 18.0) * 0.12
		draw_rect(Rect2(-radius, -5, radius * 2.0, 10), Color(1.0, 0.22, 0.08, 0.08 + warning_progress * 0.12), true)
		draw_rect(Rect2(-radius, -3, radius * 2.0, 6), Color(1.0, 0.36, 0.12, pulse * 0.26), true)
		for index in range(9):
			var x := roundf(lerpf(-radius, radius - 8.0, float(index) / 8.0))
			var height := 10.0 + float(index % 2) * 5.0
			draw_rect(Rect2(x, -height, 7, height * 2.0), Color(1.0, 0.62, 0.2, pulse), false, 3.0)
	else:
		draw_rect(Rect2(-radius, -16, radius * 2.0, 32), Color(1.0, 0.3, 0.08, 0.32), true)
		for index in range(11):
			var x := roundf(lerpf(-radius, radius - 8.0, float(index) / 10.0))
			var height := 24.0 + float(index % 3) * 10.0
			draw_rect(Rect2(x, -height, 8, height * 2.0), Color(1.0, 0.9, 0.5, 0.72), true)
