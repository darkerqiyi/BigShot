extends Node2D
class_name GrenadeChargeIndicator

const INK := Color("10243a")
const LOW := Color("55e39a")
const MID := Color("ffd35a")
const HIGH := Color("ff6c3a")
const WHITE := Color("fff4d2")

var charge := 0.0
var facing := 1


func _ready() -> void:
	visible = false
	z_index = 20


func show_charge(value: float, direction: int) -> void:
	charge = clampf(value, 0.0, 1.0)
	facing = 1 if direction >= 0 else -1
	# Keep the meter centered and upright so changing aim direction cannot make it jump.
	position = Vector2(0.0, -70.0)
	visible = true
	queue_redraw()


func hide_charge() -> void:
	visible = false
	charge = 0.0


func _draw() -> void:
	draw_rect(Rect2(-35, -7, 70, 14), INK, true)
	draw_rect(Rect2(-31, -3, 20, 6), LOW, true)
	draw_rect(Rect2(-9, -3, 20, 6), MID, true)
	draw_rect(Rect2(13, -3, 18, 6), HIGH, true)
	var pointer_x := roundf(lerpf(-31.0, 29.0, charge))
	draw_rect(Rect2(pointer_x - 2, -6, 4, 12), WHITE, true)
