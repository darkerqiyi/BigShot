extends StaticBody2D
class_name MissionGate

const INK := Color("10243a")
const DANGER := Color("ff5a62")
const HOT := Color("ffd35a")

var closed := false


func _ready() -> void:
	add_to_group("mission_gates")
	collision_mask = 6
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28.0, 720.0)
	shape_node.shape = shape
	add_child(shape_node)
	set_closed(false)


func set_closed(value: bool) -> void:
	closed = value
	collision_layer = 1 if closed else 0
	visible = closed
	queue_redraw()


func _draw() -> void:
	if not closed:
		return
	draw_rect(Rect2(-10, -280, 20, 504), INK, true)
	draw_rect(Rect2(-6, -280, 12, 504), Color(DANGER, 0.78), true)
	for y in range(-268, 220, 32):
		draw_rect(Rect2(-10, y, 20, 8), DANGER, true)
		draw_rect(Rect2(-4, y + 8, 8, 8), HOT, true)
