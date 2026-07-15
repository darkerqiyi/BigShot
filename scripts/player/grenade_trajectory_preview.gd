extends Node2D
class_name GrenadeTrajectoryPreview

var predicted_velocity := Vector2.ZERO
var gravity := 1200.0
var local_origin := Vector2.ZERO
var predicted_points: Array[Vector2] = []


func _ready() -> void:
	visible = false
	z_index = 18


func show_prediction(origin: Vector2, initial_velocity: Vector2, gravity_value: float) -> void:
	local_origin = origin
	predicted_velocity = initial_velocity
	gravity = gravity_value
	_rebuild_points()
	visible = true
	queue_redraw()


func hide_prediction() -> void:
	visible = false
	predicted_velocity = Vector2.ZERO
	predicted_points.clear()


func _rebuild_points() -> void:
	predicted_points.clear()
	var previous := local_origin
	for index in range(1, 9):
		var t := float(index) * 0.105
		var point := local_origin + predicted_velocity * t + Vector2(0, 0.5 * gravity * t * t)
		var query := PhysicsRayQueryParameters2D.create(to_global(previous), to_global(point), 1)
		var collision := get_world_2d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			predicted_points.append(to_local(collision["position"] as Vector2))
			break
		predicted_points.append(point)
		previous = point


func _draw() -> void:
	for index in range(predicted_points.size()):
		var point := predicted_points[index]
		var color := Color(1.0, 0.83, 0.35, 0.82 - index * 0.065)
		draw_rect(Rect2(point.round() - Vector2(2, 2), Vector2(4, 4)), color, true)
