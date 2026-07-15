extends Polygon2D
class_name BossGatePixel

const GATE_RECT := Rect2(17790, 80, 20, 504)
const INK := Color("30263b")
const DANGER := Color("ff5a62")
const HOT := Color("ffd35a")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_rect(GATE_RECT, INK, true)
	draw_rect(Rect2(GATE_RECT.position + Vector2(4, 0), Vector2(12, GATE_RECT.size.y)), Color(DANGER, 0.78), true)
	for y in range(92, 580, 32):
		draw_rect(Rect2(17790, y, 20, 8), DANGER, true)
		draw_rect(Rect2(17796, y + 8, 8, 8), HOT, true)


func get_visual_contract() -> Dictionary:
	return {"rect": GATE_RECT, "pixel_grid": 4, "collision_owner": false}
