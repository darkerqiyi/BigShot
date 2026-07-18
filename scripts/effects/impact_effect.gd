extends Node2D

signal completed(effect: Node2D)

var effect_color := Color.WHITE
var strength := 1.0
var age := 0.0
var duration := 0.24
var spark_count := 8
var effect_kind: StringName = &"normal"
var impact_direction := Vector2.RIGHT
var hold_remaining := 0.0
var target_material: StringName = &"terrain"
var _pool_managed := false


func configure(
	color: Color,
	effect_strength: float = 1.0,
	large: bool = false,
	kind: StringName = &"normal",
	direction: Vector2 = Vector2.ZERO,
	visual_hold: float = 0.0,
	material: StringName = &"terrain",
) -> void:
	age = 0.0
	visible = true
	set_process(true)
	effect_color = color
	strength = effect_strength
	effect_kind = kind
	target_material = material
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
		&"rifle_hit":
			spark_count = 5
			duration = 0.15
		&"pistol_hit":
			spark_count = 7
			duration = 0.19
		&"shotgun", &"shotgun_hit":
			spark_count = 9
			duration = 0.27
		&"heavy", &"sniper", &"sniper_hit", &"boss_heavy":
			spark_count = 14
			duration = 0.34
		&"headshot":
			spark_count = 11
			duration = 0.28
		&"headshot_kill":
			spark_count = 16
			duration = 0.38
		&"armor_hit", &"boss_armor_hit":
			spark_count = 8
			duration = 0.21
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


func set_pool_managed(enabled: bool) -> void:
	_pool_managed = enabled


func deactivate() -> void:
	visible = false
	set_process(false)
	age = 0.0
	hold_remaining = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if hold_remaining > 0.0:
		hold_remaining = maxf(hold_remaining - delta, 0.0)
	else:
		age += delta
	queue_redraw()
	if age >= duration:
		if _pool_managed:
			completed.emit(self)
		else:
			queue_free()


func _draw() -> void:
	var progress := clampf(age / maxf(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - progress
	var scale_factor := maxf(strength, 0.25)
	var core_size := maxi(int(round(6.0 * scale_factor * fade)), 2)
	var core_color := Color(1.0, 1.0, 0.86, fade)
	if target_material in [&"armor", &"boss_armor"]:
		core_color = Color(Color("d8fbff"), fade)
	elif target_material == &"shield":
		core_color = Color(Color("8ee8ff"), fade)
	draw_rect(Rect2(-core_size, -core_size, core_size * 2, core_size * 2), core_color, true)
	if effect_kind == &"block":
		draw_rect(Rect2(-3, -13, 6, 26), Color(Color("65c8ff"), fade), true)
		draw_rect(Rect2(-10, -3, 20, 6), Color(Color("d8fbff"), fade), true)
	elif effect_kind == &"guard_break":
		draw_rect(Rect2(-12, -4, 24, 8), Color(Color("ffd35a"), fade), true)
		draw_rect(Rect2(-4, -15, 8, 30), Color(Color("ff8b58"), fade), true)
	elif effect_kind in [&"shotgun", &"shotgun_hit"]:
		var blast_radius := maxi(int(round((8.0 + progress * 13.0) * scale_factor)), 5)
		draw_arc(Vector2.ZERO, blast_radius, -1.1, 1.1, 7, Color(Color("ffb45c"), fade * 0.72), 3.0)
		var smoke_origin := (-impact_direction * (5.0 + progress * 9.0)).round()
		draw_rect(Rect2(smoke_origin - Vector2(5, 3), Vector2(10, 6)), Color(Color("b5c7cf"), fade * 0.45), true)
	elif effect_kind in [&"sniper", &"sniper_hit"]:
		var lance_start := (-impact_direction * 15.0 * scale_factor).round()
		var lance_end := (impact_direction * 22.0 * scale_factor).round()
		draw_line(lance_start, lance_end, Color(Color("fff4b8"), fade), 4.0)
		draw_line(lance_start, lance_end, Color(effect_color, fade), 2.0)
	elif effect_kind in [&"headshot", &"headshot_kill"]:
		var ring_radius := maxi(int(round((7.0 + progress * 10.0) * scale_factor)), 4)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 8, Color(Color("ffd35a"), fade), 3.0)
		draw_rect(Rect2(-2, -13, 4, 26), Color(Color("fff4b8"), fade), true)
		draw_rect(Rect2(-13, -2, 26, 4), Color(Color("ff9f43"), fade), true)
	for index in range(spark_count):
		var angle := float(index) / float(maxi(spark_count, 1)) * TAU + sin(float(index) * 17.3) * 0.24
		var spread := Vector2.from_angle(angle)
		if effect_kind in [&"shotgun", &"shotgun_hit", &"sniper", &"sniper_hit", &"heavy", &"boss_heavy", &"headshot", &"headshot_kill"]:
			spread = (spread * 0.65 + impact_direction * 0.45).normalized()
		var travel := (7.0 + progress * (18.0 + float(index % 4) * 3.0)) * scale_factor
		var pixel_size := maxi(int(round((4.0 - progress * 2.0) * scale_factor)), 2)
		var point := (spread * travel).round()
		var spark_color := effect_color if index % 3 != 0 else core_color
		if target_material in [&"armor", &"boss_armor"] and index % 2 == 0:
			spark_color = Color("d8fbff")
		elif target_material == &"shield" and index % 2 == 0:
			spark_color = Color("65c8ff")
		draw_rect(Rect2(point - Vector2(pixel_size, pixel_size) * 0.5, Vector2(pixel_size, pixel_size)), Color(spark_color, fade), true)
