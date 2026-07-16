extends Node2D
class_name SurvivalArenaArt


func _ready() -> void:
	z_index = -4
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 300, 1280, 284), Color("112a3b"), true)
	for x in range(40, 1240, 80):
		draw_rect(Rect2(x, 334, 44, 190), Color("173c4a"), true)
		draw_rect(Rect2(x + 6, 344, 32, 8), Color("3d8b88"), true)
		draw_rect(Rect2(x + 12, 478, 20, 5), Color("ffd35a"), true)
	draw_rect(Rect2(0, 530, 1280, 54), Color("173447"), true)
	draw_rect(Rect2(0, 530, 1280, 8), Color("55d8c4"), true)
	for x in range(0, 1280, 64):
		draw_rect(Rect2(x + 8, 548, 40, 5), Color("2c6370"), true)
		draw_rect(Rect2(x + 24, 564, 8, 8), Color("ffb347"), true)
