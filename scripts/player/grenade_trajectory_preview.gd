extends Node2D
class_name GrenadeTrajectoryPreview

var predicted_velocity := Vector2.ZERO
var gravity := 1200.0


func _ready() -> void:
	visible = false
	z_index = 18


func show_prediction(initial_velocity: Vector2, gravity_value: float) -> void:
	predicted_velocity = initial_velocity
	gravity = gravity_value
	visible = true
	queue_redraw()


func hide_prediction() -> void:
	visible = false
	predicted_velocity = Vector2.ZERO


func _draw() -> void:
	var origin := Vector2(0, -18)
	for index in range(1, 9):
		var t := float(index) * 0.105
		var point := origin + predicted_velocity * t + Vector2(0, 0.5 * gravity * t * t)
		if point.y > 40.0:
			break
		var color := Color(1.0, 0.83, 0.35, 0.82 - index * 0.065)
		draw_rect(Rect2(point.round() - Vector2(2, 2), Vector2(4, 4)), color, true)
