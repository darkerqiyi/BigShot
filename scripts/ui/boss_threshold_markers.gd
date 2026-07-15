extends Control
class_name BossThresholdMarkers

const INK := Color("10243a")
const GOLD := Color("ffd35a")
const LIGHT := Color("fff4d2")
const THRESHOLDS := [0.65, 0.30]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	for threshold in THRESHOLDS:
		var x := roundf(size.x * threshold)
		draw_rect(Rect2(x - 3.0, 1.0, 6.0, maxf(size.y - 2.0, 1.0)), INK, true)
		draw_rect(Rect2(x - 1.0, 3.0, 2.0, maxf(size.y - 6.0, 1.0)), GOLD, true)
		draw_rect(Rect2(x - 2.0, 1.0, 4.0, 2.0), LIGHT, true)


func get_marker_positions() -> PackedFloat32Array:
	return PackedFloat32Array([size.x * 0.65, size.x * 0.30])
