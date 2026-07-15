extends Node2D
class_name PixelMuzzleFlash

var profile: StringName = &"rifle"
var effect_color := Color("ffd35a")
var flash_scale := 1.0
var age := 0.0
var duration := 0.055


func play(next_profile: StringName, color: Color, scale_factor: float = 1.0, accent: bool = false) -> void:
	profile = next_profile
	effect_color = color
	flash_scale = scale_factor * (1.2 if accent else 1.0)
	duration = 0.078 if profile == &"shotgun" else (0.065 if profile == &"sniper" else (0.045 if profile == &"pistol" else 0.052))
	age = 0.0
	visible = true
	modulate = Color.WHITE
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	age += delta
	if age >= duration:
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - clampf(age / maxf(duration, 0.001), 0.0, 1.0)
	var core := Color(1.0, 0.98, 0.72, fade)
	var hot := Color(effect_color, fade * 0.95)
	var ember := Color(1.0, 0.34, 0.10, fade * 0.8)
	var size := maxf(flash_scale, 0.5)
	match profile:
		&"shotgun":
			_pixel_rect(0, -5, 12, 10, core, size)
			_pixel_rect(8, -9, 13, 5, hot, size)
			_pixel_rect(8, 4, 13, 5, hot, size)
			_pixel_rect(17, -13, 10, 5, ember, size)
			_pixel_rect(17, 8, 10, 5, ember, size)
			_pixel_rect(20, -3, 12, 6, core, size)
		&"sniper":
			_pixel_rect(0, -3, 15, 6, core, size)
			_pixel_rect(12, -2, 26, 4, hot, size)
			_pixel_rect(33, -1, 18, 2, core, size)
			_pixel_rect(10, -6, 9, 3, ember, size)
			_pixel_rect(10, 3, 9, 3, ember, size)
		&"pistol":
			_pixel_rect(0, -3, 9, 6, core, size)
			_pixel_rect(7, -5, 7, 3, hot, size)
			_pixel_rect(7, 2, 7, 3, hot, size)
			_pixel_rect(12, -1, 6, 2, core, size)
		&"enemy":
			_pixel_rect(0, -4, 10, 8, core, size)
			_pixel_rect(8, -7, 9, 4, ember, size)
			_pixel_rect(8, 3, 9, 4, ember, size)
			_pixel_rect(14, -2, 8, 4, hot, size)
		_:
			_pixel_rect(0, -4, 11, 8, core, size)
			_pixel_rect(8, -7, 9, 4, hot, size)
			_pixel_rect(8, 3, 9, 4, hot, size)
			_pixel_rect(15, -2, 9, 4, core, size)


func _pixel_rect(x: float, y: float, width: float, height: float, color: Color, scale_factor: float) -> void:
	var rect := Rect2(
		Vector2(roundf(x * scale_factor), roundf(y * scale_factor)),
		Vector2(maxf(roundf(width * scale_factor), 1.0), maxf(roundf(height * scale_factor), 1.0)),
	)
	draw_rect(rect, color, true)
