extends Node2D
class_name SurvivalBountyMarker

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(elapsed * 6.0) * 0.10
	draw_circle(Vector2.ZERO, 14.0 * pulse, Color(1.0, 0.72, 0.22, 0.12), true)
	draw_arc(Vector2.ZERO, 12.0 * pulse, 0.0, TAU, 12, Color("ffd35a"), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0),
	]), Color("ff9f43"))
	draw_circle(Vector2.ZERO, 2.5, Color("fff4b8"), true)
