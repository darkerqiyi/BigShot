extends Control
class_name SurvivalMapPreview

@export_enum("industrial", "sublevel_09") var theme_id := "industrial"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color("07131f"), true)
	if theme_id == "sublevel_09":
		_draw_sublevel(area)
	else:
		_draw_industrial(area)
	draw_rect(area.grow(-2.0), Color("77e1cf"), false, 2.0)


func _draw_industrial(area: Rect2) -> void:
	draw_rect(Rect2(0, area.size.y * 0.34, area.size.x, area.size.y * 0.66), Color("133448"), true)
	for x in range(8, int(area.size.x), 34):
		draw_rect(Rect2(x, 25, 22, area.size.y - 43), Color("1c5260"), true)
		draw_rect(Rect2(x + 4, 30, 14, 4), Color("55d8c4"), true)
	draw_rect(Rect2(0, area.size.y - 20, area.size.x, 20), Color("244c58"), true)
	draw_rect(Rect2(0, area.size.y - 20, area.size.x, 4), Color("ffd35a"), true)


func _draw_sublevel(area: Rect2) -> void:
	draw_rect(Rect2(0, 0, area.size.x, area.size.y), Color("0a1722"), true)
	for y in [18, 42, 66]:
		draw_rect(Rect2(0, y, area.size.x, 6), Color("163a3e"), true)
	for x in range(14, int(area.size.x), 42):
		draw_rect(Rect2(x, 12, 8, area.size.y - 30), Color("292743"), true)
	draw_rect(Rect2(18, area.size.y - 38, area.size.x - 36, 20), Color("132b3a"), true)
	draw_rect(Rect2(32, area.size.y - 34, area.size.x - 64, 4), Color("5f7775"), true)
	draw_rect(Rect2(area.size.x * 0.47, area.size.y - 30, 16, 12), Color("ffad3d"), true)
	draw_rect(Rect2(0, area.size.y - 18, area.size.x, 18), Color("24333f"), true)
	for x in range(0, int(area.size.x), 24):
		draw_rect(Rect2(x, area.size.y - 17, 12, 3), Color("c47b35"), true)
