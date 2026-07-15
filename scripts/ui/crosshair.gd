extends Node2D


func _draw() -> void:
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20, Color(0.35, 1.0, 0.78, 0.9), 2.0)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(direction * 14.0, direction * 20.0, Color(1.0, 0.78, 0.28, 0.9), 2.0)
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

