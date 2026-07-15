extends Node2D
class_name ParallaxPixelArt

@export_range(0.0, 1.5, 0.05) var parallax_factor := 0.3
@export_enum("far", "mid", "front") var layer_kind := "far"

const FAR_COVERAGE := Vector2(-1800, 22500)
const MID_COVERAGE := Vector2(-1500, 22600)
const FRONT_TOP_Y := 568.0

const FAR_INK := Color("183852")
const FAR_BLUE := Color("244766")
const FAR_LIT := Color("326a78")
const MID_INK := Color("102b40")
const MID_BODY := Color("173f55")
const MID_FACE := Color("20566a")
const MID_LIGHT := Color("45a99f")
const WINDOW_CYAN := Color("45d8d0")
const WINDOW_GOLD := Color("f49a36")
const FRONT_INK := Color("0c2532")


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		position.x = roundf(camera.global_position.x * (1.0 - parallax_factor))


func _draw() -> void:
	match layer_kind:
		"far":
			_draw_far()
		"mid":
			_draw_mid()
		"front":
			_draw_front()


func _draw_far() -> void:
	# Two stepped ridge bands avoid smooth triangle placeholders and hide joins.
	for index in range(-4, 46):
		var x := float(index) * 520.0
		var peak := 342.0 + float(posmod(index * 37, 92))
		_draw_stepped_ridge(x, peak, FAR_INK, 1.0)
	for index in range(-4, 51):
		var x := float(index) * 460.0 + 120.0
		var peak := 402.0 + float(posmod(index * 53, 72))
		_draw_stepped_ridge(x, peak, FAR_BLUE, 0.78)
	for index in range(-3, 38):
		var x := float(index) * 610.0 + 84.0
		draw_rect(Rect2(x, 492, 84, 8), Color(FAR_LIT, 0.58), true)
		draw_rect(Rect2(x + 20, 484, 40, 8), Color(FAR_LIT, 0.36), true)


func _draw_stepped_ridge(origin_x: float, peak_y: float, color: Color, width_scale: float) -> void:
	var width := 360.0 * width_scale
	var points := PackedVector2Array([
		Vector2(origin_x - width, 560),
		Vector2(origin_x - width * 0.72, 520),
		Vector2(origin_x - width * 0.52, 520),
		Vector2(origin_x - width * 0.52, 480),
		Vector2(origin_x - width * 0.30, 480),
		Vector2(origin_x - width * 0.30, peak_y + 40),
		Vector2(origin_x - width * 0.10, peak_y + 40),
		Vector2(origin_x - width * 0.10, peak_y),
		Vector2(origin_x + width * 0.10, peak_y),
		Vector2(origin_x + width * 0.10, peak_y + 44),
		Vector2(origin_x + width * 0.34, peak_y + 44),
		Vector2(origin_x + width * 0.34, 490),
		Vector2(origin_x + width * 0.62, 490),
		Vector2(origin_x + width * 0.62, 530),
		Vector2(origin_x + width, 530),
		Vector2(origin_x + width, 560),
	])
	draw_polygon(points, PackedColorArray([color]))


func _draw_mid() -> void:
	for index in range(-6, 88):
		var x := float(index) * 252.0
		var width := 148.0 + float(posmod(index * 29, 3)) * 24.0
		var height := 112.0 + float(posmod(index * 67, 5)) * 28.0
		_draw_building(x, 584.0 - height, width, height, index)
	for index in range(-3, 44):
		var x := float(index) * 520.0 + 96.0
		_draw_energy_bridge(x, 438.0 + float(posmod(index, 3)) * 28.0)


func _draw_building(x: float, top: float, width: float, height: float, index: int) -> void:
	draw_rect(Rect2(x - 8, top - 8, width + 16, height + 8), MID_INK, true)
	draw_rect(Rect2(x, top, width, height), MID_BODY, true)
	draw_rect(Rect2(x + 12, top + 14, width - 24, height - 14), MID_FACE, true)
	var roof_step := 16.0 + float(posmod(index, 3)) * 8.0
	draw_rect(Rect2(x + roof_step, top - 20, width - roof_step * 2.0, 12), MID_INK, true)
	draw_rect(Rect2(x + roof_step + 8, top - 16, width - roof_step * 2.0 - 16, 8), Color(MID_LIGHT, 0.7), true)
	for row in range(2):
		for column in range(maxi(int((width - 30.0) / 36.0), 1)):
			var window_pos := Vector2(x + 18 + column * 36, top + 28 + row * 36)
			var light := WINDOW_CYAN if posmod(index + row + column, 3) != 0 else WINDOW_GOLD
			draw_rect(Rect2(window_pos, Vector2(12, 8)), Color(light, 0.72), true)
			draw_rect(Rect2(window_pos + Vector2(12, 4), Vector2(8, 4)), Color(light, 0.32), true)
	# Vertical tech spine and foot vents make each module readable at speed.
	draw_rect(Rect2(x + width - 20, top + 18, 8, height - 30), MID_INK, true)
	for vent_y in range(int(top + 28), int(top + height - 18), 24):
		draw_rect(Rect2(x + width - 18, vent_y, 4, 10), Color(MID_LIGHT, 0.55), true)


func _draw_energy_bridge(x: float, y: float) -> void:
	draw_rect(Rect2(x, y, 164, 8), MID_INK, true)
	draw_rect(Rect2(x + 12, y + 8, 8, 54), MID_INK, true)
	draw_rect(Rect2(x + 144, y + 8, 8, 54), MID_INK, true)
	for segment in range(5):
		draw_rect(Rect2(x + 12 + segment * 28, y + 2, 18, 4), Color(WINDOW_CYAN, 0.5), true)


func _draw_front() -> void:
	# Foreground stays below the character torso and uses sparse clusters only.
	for index in range(-3, 44):
		var x := float(index) * 520.0 + 42.0
		draw_rect(Rect2(x, FRONT_TOP_Y + 32, 112, 8), Color(FRONT_INK, 0.38), true)
		_draw_crystal_grass(Vector2(x + 14, FRONT_TOP_Y + 32), index)
		_draw_crystal_grass(Vector2(x + 82, FRONT_TOP_Y + 32), index + 3)


func _draw_crystal_grass(origin: Vector2, seed: int) -> void:
	var height := 12.0 + float(posmod(seed * 7, 3)) * 4.0
	var color := Color("245c65", 0.48)
	draw_polygon(PackedVector2Array([
		origin,
		origin + Vector2(4, -height),
		origin + Vector2(8, 0),
	]), PackedColorArray([color]))
	draw_polygon(PackedVector2Array([
		origin + Vector2(8, 0),
		origin + Vector2(14, -height * 0.7),
		origin + Vector2(17, 0),
	]), PackedColorArray([Color("327f78", 0.38)]))


func get_visual_contract() -> Dictionary:
	return {
		"layer": layer_kind,
		"parallax": parallax_factor,
		"far_coverage": FAR_COVERAGE,
		"mid_coverage": MID_COVERAGE,
		"front_top_y": FRONT_TOP_Y,
		"pixel_grid": 4,
	}
