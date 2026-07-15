extends Node2D

var effect_color := Color.WHITE
var strength := 1.0
var age := 0.0
var duration := 0.24
var spark_count := 8
var effect_kind: StringName = &"normal"
var impact_direction := Vector2.RIGHT
var hold_remaining := 0.0


func configure(
	color: Color,
	effect_strength: float = 1.0,
	large: bool = false,
	kind: StringName = &"normal",
	direction: Vector2 = Vector2.ZERO,
	visual_hold: float = 0.0,
) -> void:
	effect_color = color
	strength = effect_strength
	effect_kind = kind
	impact_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	hold_remaining = maxf(visual_hold, 0.0)
	match effect_kind:
		&"wall":
			spark_count = 4
			duration = 0.16
		&"block":
			spark_count = 8
			duration = 0.22
		&"guard_break":
			spark_count = 15
			duration = 0.38
		&"shotgun":
			spark_count = 10
			duration = 0.27
		&"heavy", &"sniper", &"boss_heavy":
			spark_count = 14
			duration = 0.34
		&"kill_heavy", &"player_death":
			spark_count = 18
			duration = 0.46
		&"kill_light":
			spark_count = 13
			duration = 0.34
		_:
			spark_count = 7
			duration = 0.22
	if large:
		duration = maxf(duration, 0.42)
		spark_count = maxi(spark_count, 16)
		strength *= 1.45
	queue_redraw()


func _process(delta: float) -> void:
	if hold_remaining > 0.0:
		hold_remaining = maxf(hold_remaining - delta, 0.0)
	else:
		age += delta
	queue_redraw()
	if age >= duration:
		queue_free()


func _draw() -> void:
	var progress := clampf(age / maxf(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - progress
	var scale_factor := maxf(strength, 0.25)
	var core_size := maxi(int(round(6.0 * scale_factor * fade)), 2)
	var core_color := Color(1.0, 1.0, 0.86, fade)
	draw_rect(Rect2(-core_size, -core_size, core_size * 2, core_size * 2), core_color, true)
	if effect_kind == &"block":
		draw_rect(Rect2(-3, -13, 6, 26), Color(Color("65c8ff"), fade), true)
		draw_rect(Rect2(-10, -3, 20, 6), Color(Color("d8fbff"), fade), true)
	elif effect_kind == &"guard_break":
		draw_rect(Rect2(-12, -4, 24, 8), Color(Color("ffd35a"), fade), true)
		draw_rect(Rect2(-4, -15, 8, 30), Color(Color("ff8b58"), fade), true)
	for index in range(spark_count):
		var angle := float(index) / float(maxi(spark_count, 1)) * TAU + sin(float(index) * 17.3) * 0.24
		var spread := Vector2.from_angle(angle)
		if effect_kind in [&"shotgun", &"sniper", &"heavy", &"boss_heavy"]:
			spread = (spread * 0.65 + impact_direction * 0.45).normalized()
		var travel := (7.0 + progress * (18.0 + float(index % 4) * 3.0)) * scale_factor
		var pixel_size := maxi(int(round((4.0 - progress * 2.0) * scale_factor)), 2)
		var point := (spread * travel).round()
		var spark_color := effect_color if index % 3 != 0 else core_color
		draw_rect(Rect2(point - Vector2(pixel_size, pixel_size) * 0.5, Vector2(pixel_size, pixel_size)), Color(spark_color, fade), true)
