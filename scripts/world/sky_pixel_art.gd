extends Node2D
class_name SkyPixelArt

const SKY_TOP := Color("10243a")
const SKY_MID := Color("183852")
const SKY_GLOW := Color("245273")
const HORIZON := Color("2b6670")
const CLOUD_DARK := Color("327680")
const CLOUD_LIGHT := Color("5fb3ad")
const SUN_EDGE := Color("f49a36")
const SUN_CORE := Color("ffd35a")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Fixed screen-space pixel bands preserve the 1280x720 authored viewport.
	draw_rect(Rect2(0, 0, 1280, 112), SKY_TOP, true)
	draw_rect(Rect2(0, 112, 1280, 112), SKY_MID, true)
	draw_rect(Rect2(0, 224, 1280, 106), SKY_GLOW, true)
	draw_rect(Rect2(0, 330, 1280, 254), HORIZON, true)
	_draw_pixel_sun(Vector2(1080, 146))
	_draw_cloud(Vector2(96, 172), 1.0)
	_draw_cloud(Vector2(498, 120), 0.75)
	_draw_cloud(Vector2(850, 244), 0.9)
	for star in [Vector2(82, 70), Vector2(214, 130), Vector2(356, 54), Vector2(634, 82), Vector2(760, 150), Vector2(934, 72), Vector2(1192, 238)]:
		draw_rect(Rect2(star, Vector2(4, 4)), Color("86e7c5", 0.58), true)
		draw_rect(Rect2(star + Vector2(4, 4), Vector2(4, 4)), Color("ffd35a", 0.32), true)


func _draw_pixel_sun(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-44, -28), Vector2(88, 56)), Color(SUN_EDGE, 0.28), true)
	draw_rect(Rect2(center + Vector2(-36, -36), Vector2(72, 72)), Color(SUN_EDGE, 0.34), true)
	draw_rect(Rect2(center + Vector2(-28, -36), Vector2(56, 72)), SUN_CORE, true)
	draw_rect(Rect2(center + Vector2(-36, -28), Vector2(72, 56)), SUN_CORE, true)
	draw_rect(Rect2(center + Vector2(-20, -20), Vector2(40, 40)), Color("fff0a0"), true)


func _draw_cloud(origin: Vector2, scale_factor: float) -> void:
	var unit := maxf(roundf(8.0 * scale_factor), 4.0)
	draw_rect(Rect2(origin + Vector2(0, unit), Vector2(unit * 8, unit * 2)), Color(CLOUD_DARK, 0.48), true)
	draw_rect(Rect2(origin + Vector2(unit * 2, 0), Vector2(unit * 3, unit * 3)), Color(CLOUD_DARK, 0.48), true)
	draw_rect(Rect2(origin + Vector2(unit * 5, unit), Vector2(unit * 2, unit * 2)), Color(CLOUD_DARK, 0.48), true)
	draw_rect(Rect2(origin + Vector2(unit, unit), Vector2(unit * 5, unit)), Color(CLOUD_LIGHT, 0.34), true)
	draw_rect(Rect2(origin + Vector2(unit * 3, 0), Vector2(unit * 2, unit)), Color(CLOUD_LIGHT, 0.28), true)


func get_visual_contract() -> Dictionary:
	return {
		"logical_size": Vector2i(1280, 720),
		"grid": 4,
		"danger_color_reserved": true,
		"uses_screen_space": true,
	}
