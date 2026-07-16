extends Node2D
class_name SurvivalSpawnWarning

var duration := 0.55
var remaining := 0.55


func configure(warning_duration: float) -> void:
	duration = maxf(warning_duration, 0.05)
	remaining = duration


func _process(delta: float) -> void:
	remaining = maxf(remaining - delta, 0.0)
	queue_redraw()
	if is_zero_approx(remaining):
		queue_free()


func _draw() -> void:
	var progress := 1.0 - remaining / maxf(duration, 0.001)
	var radius := roundf(26.0 + progress * 14.0)
	var pulse := 0.55 + sin(progress * TAU * 4.0) * 0.2
	draw_arc(Vector2(0, 24), radius, 0.0, TAU, 20, Color(1.0, 0.35, 0.16, pulse), 4.0)
	draw_rect(Rect2(-18, 20, 36, 7), Color(1.0, 0.82, 0.3, 0.72), true)
	for index in range(3):
		draw_rect(Rect2(-14 + index * 12, 10, 5, 7), Color(1.0, 0.35, 0.16, 0.9), true)
