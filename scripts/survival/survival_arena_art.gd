extends Node2D
class_name SurvivalArenaArt

var theme_id: StringName = &"industrial"
var arena_bounds := Rect2(0.0, 0.0, 1280.0, 720.0)
var platforms: Array = []


func _ready() -> void:
	z_index = -4
	queue_redraw()


func configure(map_theme: StringName, bounds: Rect2, platform_definitions: Array) -> void:
	theme_id = map_theme
	arena_bounds = bounds
	platforms = platform_definitions.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if theme_id == &"sublevel_09":
		_draw_sublevel()
	else:
		_draw_industrial()


func _draw_industrial() -> void:
	var left := arena_bounds.position.x
	var width := arena_bounds.size.x
	draw_rect(Rect2(left, 300, width, 284), Color("112a3b"), true)
	for x in range(int(left + 40), int(left + width - 40), 80):
		draw_rect(Rect2(x, 334, 44, 190), Color("173c4a"), true)
		draw_rect(Rect2(x + 6, 344, 32, 8), Color("3d8b88"), true)
		draw_rect(Rect2(x + 12, 478, 20, 5), Color("ffd35a"), true)
	draw_rect(Rect2(left, 530, width, 54), Color("173447"), true)
	draw_rect(Rect2(left, 530, width, 8), Color("55d8c4"), true)
	for x in range(int(left), int(left + width), 64):
		draw_rect(Rect2(x + 8, 548, 40, 5), Color("2c6370"), true)
		draw_rect(Rect2(x + 24, 564, 8, 8), Color("ffb347"), true)


func _draw_sublevel() -> void:
	var left := arena_bounds.position.x
	var width := arena_bounds.size.x
	draw_rect(Rect2(left, 0, width, 584), Color("08141f"), true)
	# Tunnel rings and pipe runs establish the enclosed station silhouette.
	for x in range(int(left + 20), int(left + width), 96):
		draw_rect(Rect2(x, 92, 58, 438), Color("20213a"), true)
		draw_rect(Rect2(x + 8, 106, 42, 404), Color("102b35"), true)
		draw_rect(Rect2(x + 14, 120, 30, 6), Color("40635e"), true)
	for y in [150, 198, 246]:
		draw_rect(Rect2(left, y, width, 12), Color("173b3d"), true)
		draw_rect(Rect2(left, y + 3, width, 3), Color("3d6660"), true)
	# An abandoned train sits behind the play plane.
	draw_rect(Rect2(left + 170, 350, width - 340, 158), Color("142a3b"), true)
	draw_rect(Rect2(left + 194, 368, width - 388, 96), Color("243147"), true)
	for x in range(int(left + 220), int(left + width - 230), 112):
		draw_rect(Rect2(x, 384, 74, 48), Color("0b1b29"), true)
		draw_rect(Rect2(x + 5, 389, 64, 5), Color("507671"), true)
	draw_rect(Rect2(left + 170, 468, width - 340, 8), Color("d28b38"), true)
	# Floor, safety stripe and rail bed.
	draw_rect(Rect2(left, 530, width, 54), Color("1d303b"), true)
	draw_rect(Rect2(left, 530, width, 7), Color("cb8336"), true)
	for x in range(int(left), int(left + width), 48):
		draw_rect(Rect2(x, 540, 26, 5), Color("694d35"), true)
		draw_rect(Rect2(x + 28, 540, 16, 5), Color("d79b43"), true)
	# Signal lights use the same danger language as telegraphs.
	for x in [left + 104.0, left + width - 126.0]:
		draw_rect(Rect2(x, 292, 22, 54), Color("172532"), true)
		draw_rect(Rect2(x + 6, 300, 10, 10), Color("ffad3d"), true)
		draw_rect(Rect2(x + 6, 320, 10, 10), Color("315d58"), true)
	for platform_value in platforms:
		var platform: Dictionary = platform_value
		var position: Vector2 = platform.get("position", Vector2.ZERO)
		var size: Vector2 = platform.get("size", Vector2.ZERO)
		draw_rect(Rect2(position - size * 0.5, size), Color("263b47"), true)
		draw_rect(Rect2(position.x - size.x * 0.5, position.y - size.y * 0.5, size.x, 5), Color("659288"), true)
		for brace_x in range(int(position.x - size.x * 0.5 + 20.0), int(position.x + size.x * 0.5), 48):
			draw_rect(Rect2(brace_x, position.y + size.y * 0.5, 8, 22), Color("172630"), true)
