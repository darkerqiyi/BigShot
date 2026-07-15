extends Node2D
class_name LevelPixelArt

const GROUND_TOP := 584.0
const LEVEL_WIDTH := 20000.0
const PLATFORM_RECTS := [
	Rect2(1470, 470, 260, 22),
	Rect2(2850, 425, 300, 22),
	Rect2(4375, 475, 250, 22),
	Rect2(6060, 410, 280, 22),
	Rect2(8070, 470, 260, 22),
	Rect2(9250, 425, 300, 22),
	Rect2(11475, 475, 250, 22),
	Rect2(14360, 410, 280, 22),
	Rect2(16470, 470, 260, 22),
	Rect2(18250, 425, 300, 22),
]
const COVER_POSITIONS := [900.0, 3600.0, 6500.0, 9200.0, 12100.0, 15100.0, 16900.0]
const BOSS_ARENA := Rect2(17800, 80, 2200, 504)

const INK := Color("10243a")
const DEEP := Color("12333f")
const GROUND := Color("194852")
const GROUND_LIGHT := Color("24636a")
const SURFACE := Color("55e39a")
const CYAN := Color("45d8d0")
const CYAN_LIGHT := Color("86e7c5")
const GOLD := Color("ffd35a")
const ORANGE := Color("f49a36")
const PURPLE := Color("72426f")
const PURPLE_LIGHT := Color("b95d8d")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_ground()
	for index in range(PLATFORM_RECTS.size()):
		_draw_platform(PLATFORM_RECTS[index], index)
	for index in range(COVER_POSITIONS.size()):
		_draw_supply_console(COVER_POSITIONS[index], index)
	_draw_route_markers()
	_draw_boss_arena()
	_draw_exit_beacon()


func _draw_ground() -> void:
	draw_rect(Rect2(0, GROUND_TOP, LEVEL_WIDTH, 180), INK, true)
	draw_rect(Rect2(0, GROUND_TOP + 8, LEVEL_WIDTH, 172), DEEP, true)
	draw_rect(Rect2(0, GROUND_TOP + 16, LEVEL_WIDTH, 164), GROUND, true)
	draw_rect(Rect2(0, GROUND_TOP, LEVEL_WIDTH, 8), SURFACE, true)
	draw_rect(Rect2(0, GROUND_TOP + 8, LEVEL_WIDTH, 4), Color(CYAN, 0.48), true)
	for index in range(200):
		var x := float(index) * 100.0
		_draw_floor_panel(x, index)
	for section_x in [5200.0, 7800.0, 10800.0, 13600.0, 16200.0, 17800.0]:
		draw_rect(Rect2(section_x, GROUND_TOP + 12, 12, 168), INK, true)
		draw_rect(Rect2(section_x + 4, GROUND_TOP + 28, 4, 48), Color(GOLD, 0.55), true)


func _draw_floor_panel(x: float, index: int) -> void:
	draw_rect(Rect2(x + 4, GROUND_TOP + 24, 88, 52), GROUND_LIGHT if index % 2 == 0 else GROUND, true)
	draw_rect(Rect2(x + 8, GROUND_TOP + 28, 80, 4), Color(CYAN_LIGHT, 0.28), true)
	draw_rect(Rect2(x + 14, GROUND_TOP + 42, 40, 4), Color(CYAN, 0.44), true)
	draw_rect(Rect2(x + 62, GROUND_TOP + 42, 20, 4), Color(GOLD, 0.34), true)
	draw_rect(Rect2(x + 12, GROUND_TOP + 86, 28, 8), INK, true)
	draw_rect(Rect2(x + 52, GROUND_TOP + 86, 36, 8), INK, true)
	for bolt_x in [12.0, 80.0]:
		draw_rect(Rect2(x + bolt_x, GROUND_TOP + 60, 4, 4), Color("718395"), true)


func _draw_platform(rect: Rect2, index: int) -> void:
	# Outer dimensions stay identical to the collision-authored platform rectangle.
	draw_rect(rect, INK, true)
	draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size - Vector2(8, 9)), GROUND_LIGHT, true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), CYAN_LIGHT, true)
	draw_rect(Rect2(rect.position + Vector2(12, 5), Vector2(rect.size.x - 24, 4)), CYAN, true)
	draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 5), Vector2(rect.size.x - 16, 5)), DEEP, true)
	for x in range(int(rect.position.x) + 20, int(rect.end.x) - 12, 40):
		draw_rect(Rect2(x, rect.position.y + 10, 16, 4), INK, true)
		draw_rect(Rect2(x + 12, rect.position.y + 14, 16, 4), INK, true)
	# Small endpoints clarify collision edges without using danger red.
	draw_rect(Rect2(rect.position + Vector2(4, 3), Vector2(8, 6)), GOLD, true)
	draw_rect(Rect2(rect.end - Vector2(12, rect.size.y - 3), Vector2(8, 6)), GOLD, true)
	var support_x := rect.position.x + 28.0 + float(index % 2) * 18.0
	for support in range(2):
		var x := support_x + support * (rect.size.x - 72.0)
		draw_rect(Rect2(x, rect.end.y, 12, 42), INK, true)
		draw_rect(Rect2(x + 4, rect.end.y, 4, 34), Color(GROUND_LIGHT, 0.72), true)


func _draw_supply_console(x: float, index: int) -> void:
	var rect := Rect2(x, 528, 54, 56)
	draw_rect(rect, INK, true)
	draw_rect(Rect2(x + 5, 533, 44, 51), GROUND_LIGHT, true)
	draw_rect(Rect2(x + 8, 536, 38, 9), GOLD if index % 2 == 0 else CYAN, true)
	draw_rect(Rect2(x + 12, 549, 30, 23), DEEP, true)
	for step in range(4):
		draw_rect(Rect2(x + 13 + step * 7, 568 - step * 5, 10, 4), Color(CYAN_LIGHT, 0.58), true)
	draw_rect(Rect2(x + 8, 576, 8, 4), ORANGE, true)
	draw_rect(Rect2(x + 38, 576, 8, 4), ORANGE, true)


func _draw_route_markers() -> void:
	for entry in [[5200.0, CYAN], [7800.0, GOLD], [10800.0, PURPLE_LIGHT], [13600.0, ORANGE], [16200.0, CYAN], [17800.0, PURPLE_LIGHT]]:
		var x: float = entry[0]
		var color: Color = entry[1]
		draw_rect(Rect2(x, 506, 12, 78), INK, true)
		draw_rect(Rect2(x + 4, 510, 4, 70), Color(color, 0.72), true)
		draw_rect(Rect2(x - 20, 506, 52, 8), INK, true)
		draw_rect(Rect2(x - 12, 508, 36, 4), color, true)
	_draw_low_crystal_cluster(Vector2(5360, GROUND_TOP), CYAN)
	_draw_low_crystal_cluster(Vector2(7980, GROUND_TOP), GOLD)
	_draw_low_crystal_cluster(Vector2(10960, GROUND_TOP), PURPLE_LIGHT)
	_draw_low_crystal_cluster(Vector2(13780, GROUND_TOP), ORANGE)
	_draw_low_crystal_cluster(Vector2(16420, GROUND_TOP), CYAN)


func _draw_low_crystal_cluster(origin: Vector2, color: Color) -> void:
	for index in range(3):
		var x := origin.x + index * 13.0
		var height := 12.0 + index * 6.0
		draw_polygon(PackedVector2Array([
			Vector2(x, origin.y),
			Vector2(x + 6, origin.y - height),
			Vector2(x + 12, origin.y),
		]), PackedColorArray([Color(color, 0.62)]))
		draw_rect(Rect2(x + 4, origin.y - height + 4, 4, height - 4), Color(CYAN_LIGHT, 0.42), true)


func _draw_boss_arena() -> void:
	# Arena identity is decorative only; its real bounds remain in Boss/Gate physics.
	draw_rect(Rect2(BOSS_ARENA.position.x, GROUND_TOP + 12, BOSS_ARENA.size.x, 10), PURPLE, true)
	for x in range(17830, 19980, 88):
		draw_rect(Rect2(x, GROUND_TOP + 26, 64, 42), Color(PURPLE, 0.34), true)
		draw_rect(Rect2(x + 8, GROUND_TOP + 34, 48, 6), Color(PURPLE_LIGHT, 0.46), true)
		draw_rect(Rect2(x + 18, GROUND_TOP + 50, 28, 6), Color(GOLD, 0.34), true)
	for pylon_x in [17850.0, 19920.0]:
		draw_rect(Rect2(pylon_x, 474, 34, 110), INK, true)
		draw_rect(Rect2(pylon_x + 6, 486, 22, 98), Color(PURPLE, 0.72), true)
		draw_rect(Rect2(pylon_x + 10, 500, 14, 38), Color(PURPLE_LIGHT, 0.58), true)
		draw_rect(Rect2(pylon_x + 8, 548, 18, 8), GOLD, true)
	# Central command sigil sits behind actors and uses no collision.
	draw_rect(Rect2(18840, 558, 110, 8), INK, true)
	draw_rect(Rect2(18860, 550, 70, 8), PURPLE_LIGHT, true)
	draw_rect(Rect2(18884, 542, 22, 8), GOLD, true)


func _draw_exit_beacon() -> void:
	var x := 19780.0
	draw_rect(Rect2(x, 436, 72, 148), INK, true)
	draw_rect(Rect2(x + 8, 448, 56, 136), Color("245c65"), true)
	draw_rect(Rect2(x + 16, 464, 40, 120), Color(CYAN, 0.18), true)
	# A stepped arch replaces the old smooth arc.
	draw_rect(Rect2(x + 12, 452, 8, 28), CYAN, true)
	draw_rect(Rect2(x + 52, 452, 8, 28), CYAN, true)
	draw_rect(Rect2(x + 20, 444, 32, 8), CYAN_LIGHT, true)
	draw_rect(Rect2(x + 24, 456, 24, 4), Color("fff0a0"), true)
	for step in range(4):
		draw_rect(Rect2(x + 20 + step * 8, 522 + step * 10, 8, 8), Color(CYAN_LIGHT, 0.58), true)


func get_visual_contract() -> Dictionary:
	return {
		"ground_top": GROUND_TOP,
		"level_width": LEVEL_WIDTH,
		"platform_rects": PLATFORM_RECTS.duplicate(),
		"cover_positions": COVER_POSITIONS.duplicate(),
		"boss_arena": BOSS_ARENA,
		"pixel_grid": 4,
	}
