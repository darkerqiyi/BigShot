extends Node2D
class_name IronTempestPixelLayer

const INK := Color("172238")
const INK_PURPLE := Color("2d2545")
const ARMOR_DARK := Color("4b315f")
const ARMOR := Color("74466f")
const ARMOR_LIGHT := Color("a65b7d")
const RED_DARK := Color("7d3048")
const CORE_RED := Color("f04d5e")
const CORE_LIGHT := Color("ff8a72")
const ORANGE := Color("f49a36")
const GOLD := Color("ffd35a")
const STEEL := Color("66798d")
const STEEL_LIGHT := Color("a9bbc6")
const CYAN := Color("65c8ff")
const CYAN_LIGHT := Color("d3f4ff")
const SMOKE := Color("53647a")
const SHADOW := Color(0.04, 0.09, 0.15, 0.58)

@export_enum("shadow", "lower", "main", "armor", "core", "left_weapon", "right_weapon", "damage", "contacts") var layer_kind := "main"


func _draw() -> void:
	var visual := get_parent() as IronTempestVisual
	if visual == null:
		return
	match layer_kind:
		"shadow":
			_draw_shadow(visual)
		"lower":
			_draw_lower(visual)
		"main":
			_draw_main(visual)
		"armor":
			_draw_armor(visual)
		"core":
			_draw_core(visual)
		"left_weapon":
			_draw_ram_arm(visual)
		"right_weapon":
			_draw_cannon(visual)
		"damage":
			_draw_damage(visual)
		"contacts":
			_draw_contacts(visual)


func _draw_shadow(visual: IronTempestVisual) -> void:
	var width := 132 if visual.animation_state != &"charge_active" else 150
	_r(visual, -int(width / 2), 56, width, 8, SHADOW, false)
	_r(visual, -52, 53, 104, 5, Color(0.06, 0.14, 0.20, 0.4), false)


func _draw_lower(visual: IronTempestVisual) -> void:
	var y := int(round(visual.pose_offset.y))
	var spread := 5 if visual.animation_state == &"charge_telegraph" else 0
	# Wide articulated feet keep the machine grounded without enlarging collision.
	_r(visual, -48 - spread, 39 + y, 38, 18, INK_PURPLE)
	_r(visual, -43 - spread, 41 + y, 28, 10, ARMOR_DARK)
	_r(visual, -53 - spread, 52 + y, 45, 9, INK)
	_r(visual, 10 + spread, 39 + y, 38, 18, INK_PURPLE)
	_r(visual, 15 + spread, 41 + y, 28, 10, ARMOR_DARK)
	_r(visual, 8 + spread, 52 + y, 45, 9, INK)
	_r(visual, -37, 28 + y, 24, 17, INK)
	_r(visual, -32, 30 + y, 15, 12, STEEL)
	_r(visual, 13, 28 + y, 24, 17, INK)
	_r(visual, 17, 30 + y, 15, 12, STEEL)
	_r(visual, -39, 19 + y, 78, 15, INK_PURPLE)
	_r(visual, -33, 21 + y, 66, 9, ARMOR_DARK)
	for x in [-27, -9, 9, 27]:
		_r(visual, x - 3, 23 + y, 6, 5, STEEL_LIGHT)


func _draw_main(visual: IronTempestVisual) -> void:
	var y := int(round(visual.pose_offset.y + visual.body_compression))
	# Main reactor hull.
	_poly(visual, [Vector2(-52, -54 + y), Vector2(-36, -70 + y), Vector2(34, -70 + y), Vector2(52, -52 + y), Vector2(48, 23 + y), Vector2(34, 34 + y), Vector2(-36, 34 + y), Vector2(-50, 20 + y)], INK_PURPLE)
	_poly(visual, [Vector2(-44, -50 + y), Vector2(-30, -62 + y), Vector2(28, -62 + y), Vector2(44, -47 + y), Vector2(40, 17 + y), Vector2(29, 25 + y), Vector2(-30, 25 + y), Vector2(-41, 15 + y)], ARMOR_DARK)
	_r(visual, -32, -48 + y, 64, 58, RED_DARK)
	_r(visual, -27, -43 + y, 54, 47, ARMOR)
	_r(visual, -23, -39 + y, 46, 8, ARMOR_LIGHT)
	# Head and sensor crown establish a readable front/top.
	_r(visual, -29, -82 + y, 58, 16, INK)
	_r(visual, -23, -79 + y, 46, 10, ARMOR_DARK)
	_r(visual, -17, -76 + y, 34, 5, STEEL)
	_r(visual, -10, -75 + y, 20, 3, GOLD if visual.animation_state.ends_with("telegraph") else CORE_LIGHT)
	_r(visual, -4, -96 + y, 8, 15, INK)
	_r(visual, -2, -101 + y, 4, 8, ORANGE if visual.phase_visual >= 2 else STEEL_LIGHT)
	# Structural ribs and exposed machinery.
	_r(visual, -48, -18 + y, 8, 34, INK)
	_r(visual, 40, -18 + y, 8, 34, INK)
	_r(visual, -36, 10 + y, 72, 8, INK)
	for x in [-31, -21, 21, 31]:
		_r(visual, x - 2, -25 + y, 4, 25, STEEL)


func _draw_armor(visual: IronTempestVisual) -> void:
	var y := int(round(visual.pose_offset.y + visual.body_compression))
	# Shoulder armor has persistent silhouette changes at each threshold.
	if visual.phase_visual == 1:
		_poly(visual, [Vector2(-72, -63 + y), Vector2(-49, -72 + y), Vector2(-35, -57 + y), Vector2(-39, -31 + y), Vector2(-67, -33 + y), Vector2(-79, -47 + y)], INK_PURPLE)
		_poly(visual, [Vector2(-68, -59 + y), Vector2(-51, -65 + y), Vector2(-42, -55 + y), Vector2(-45, -39 + y), Vector2(-63, -40 + y), Vector2(-71, -48 + y)], ARMOR_LIGHT)
		_poly(visual, [Vector2(72, -63 + y), Vector2(49, -72 + y), Vector2(35, -57 + y), Vector2(39, -31 + y), Vector2(67, -33 + y), Vector2(79, -47 + y)], INK_PURPLE)
		_poly(visual, [Vector2(68, -59 + y), Vector2(51, -65 + y), Vector2(42, -55 + y), Vector2(45, -39 + y), Vector2(63, -40 + y), Vector2(71, -48 + y)], ARMOR_LIGHT)
	elif visual.phase_visual == 2:
		# Left plate is gone; right plate has a visible fracture.
		_r(visual, -61, -55 + y, 15, 8, INK)
		_r(visual, -57, -51 + y, 7, 16, STEEL)
		_poly(visual, [Vector2(72, -62 + y), Vector2(50, -70 + y), Vector2(37, -55 + y), Vector2(42, -33 + y), Vector2(65, -35 + y), Vector2(77, -47 + y)], INK_PURPLE)
		_poly(visual, [Vector2(67, -57 + y), Vector2(52, -63 + y), Vector2(44, -54 + y), Vector2(48, -41 + y), Vector2(61, -42 + y)], ARMOR)
		_r(visual, 54, -61 + y, 4, 12, CORE_LIGHT)
	else:
		# Phase III leaves only asymmetrical armor stubs and exposed braces.
		_r(visual, -61, -53 + y, 13, 7, INK)
		_r(visual, -57, -49 + y, 6, 18, STEEL)
		_r(visual, 48, -52 + y, 19, 10, INK_PURPLE)
		_r(visual, 51, -49 + y, 11, 5, ARMOR_LIGHT)
		_r(visual, 53, -38 + y, 7, 17, STEEL)
	# Core protection brackets visibly open as phases advance.
	var bracket_x := 27 if visual.phase_visual == 1 else (32 if visual.phase_visual == 2 else 38)
	var bracket_h := 39 if visual.phase_visual == 1 else 30
	_r(visual, -bracket_x, -29 + y, 7, bracket_h, INK)
	_r(visual, bracket_x - 7, -29 + y, 7, bracket_h, INK)
	if visual.phase_visual == 1:
		_r(visual, -20, -34 + y, 40, 7, INK)
		_r(visual, -16, 7 + y, 32, 7, INK)


func _draw_core(visual: IronTempestVisual) -> void:
	var y := int(round(visual.pose_offset.y + visual.body_compression))
	var size := 15 if visual.phase_visual == 1 else (20 if visual.phase_visual == 2 else 24)
	var pulse := 0
	if visual.phase_visual == 3:
		pulse = 2 if sin(visual.animation_time * 10.0) > 0.2 else 0
	var core_color := CORE_RED
	if visual.animation_state.ends_with("telegraph"):
		core_color = ORANGE if visual.telegraph_progress < 0.72 else GOLD
	if visual.hurt_remaining > 0.0:
		core_color = CYAN_LIGHT if visual.heavy_hurt else CORE_LIGHT
	if visual.death_elapsed >= 0.0:
		core_color = CYAN_LIGHT if int(visual.death_elapsed * 18.0) % 2 == 0 else RED_DARK
	_poly(visual, [Vector2(0, -size - 12 + y), Vector2(size + pulse, -12 + y), Vector2(0, size - 12 + y), Vector2(-size - pulse, -12 + y)], INK)
	var inner := size - 5
	_poly(visual, [Vector2(0, -inner - 12 + y), Vector2(inner + pulse, -12 + y), Vector2(0, inner - 12 + y), Vector2(-inner - pulse, -12 + y)], core_color)
	_r(visual, -3, -20 + y, 6, 9, CORE_LIGHT if core_color != CYAN_LIGHT else Color.WHITE)
	if visual.phase_visual >= 2:
		_r(visual, -size - 5, -14 + y, 4, 5, CORE_LIGHT)
		_r(visual, size + 1, -14 + y, 4, 5, CORE_LIGHT)


func _draw_ram_arm(visual: IronTempestVisual) -> void:
	var y := int(round(visual.pose_offset.y + visual.body_compression))
	var extend := 10 if visual.animation_state in [&"charge_telegraph", &"charge_active"] else 0
	var x := -71 - extend
	_r(visual, x, -25 + y, 30 + extend, 18, INK)
	_r(visual, x + 4, -22 + y, 22 + extend, 11, STEEL)
	_poly(visual, [Vector2(x - 16, -26 + y), Vector2(x + 2, -21 + y), Vector2(x + 2, -12 + y), Vector2(x - 20, -5 + y), Vector2(x - 13, -15 + y)], INK_PURPLE)
	_poly(visual, [Vector2(x - 11, -22 + y), Vector2(x - 1, -19 + y), Vector2(x - 1, -14 + y), Vector2(x - 13, -10 + y)], ARMOR_LIGHT)
	if visual.animation_state == &"charge_telegraph":
		_r(visual, x - 25, -30 + y, 7, 4, GOLD)
		_r(visual, x - 31, -23 + y, 10, 4, ORANGE)


func _draw_cannon(visual: IronTempestVisual) -> void:
	var y := int(round(visual.pose_offset.y + visual.body_compression))
	var recoil := int(round(visual.recoil_offset))
	var x := 39 + recoil
	_r(visual, x, -37 + y, 41, 24, INK)
	_r(visual, x + 4, -33 + y, 31, 16, ARMOR_DARK)
	_r(visual, x + 17, -29 + y, 23, 8, STEEL)
	_r(visual, x + 37, -27 + y, 11, 5, STEEL_LIGHT)
	_r(visual, x + 3, -43 + y, 18, 8, INK_PURPLE)
	_r(visual, x + 7, -41 + y, 10, 4, ARMOR_LIGHT)
	if visual.animation_state == &"volley_telegraph":
		var glow := GOLD if visual.telegraph_progress > 0.65 else ORANGE
		_r(visual, x + 46, -31 + y, 5 + int(visual.telegraph_progress * 8.0), 12, glow)
		for index in range(3):
			_r(visual, x + 51 + index * 9, -27 + y, 5, 4, glow)
	elif visual.attack_fx_remaining > 0.0 and visual.attack_kind == &"volley":
		_poly(visual, [Vector2(x + 47, -32 + y), Vector2(x + 72, -25 + y), Vector2(x + 47, -17 + y)], GOLD)
		_r(visual, x + 48, -28 + y, 15, 6, Color("fff0a0"))


func _draw_damage(visual: IronTempestVisual) -> void:
	var y := int(round(visual.pose_offset.y))
	if visual.phase_visual >= 2 and visual.death_elapsed < 0.0:
		# Capped deterministic steam and short-circuit pixels.
		var drift := int(fposmod(visual.animation_time * 16.0, 12.0))
		_r(visual, -57, -69 - drift + y, 10, 5, SMOKE)
		_r(visual, -51, -79 - drift + y, 8, 4, Color(SMOKE, 0.78))
		_r(visual, -43, -47 + y, 8, 4, CYAN)
		_r(visual, -38, -43 + y, 4, 9, CYAN_LIGHT)
	if visual.phase_visual >= 3 and visual.death_elapsed < 0.0:
		var arc_side := 1 if sin(visual.animation_time * 13.0) > 0.0 else -1
		_r(visual, 29 * arc_side, -56 + y, 10, 4, CYAN)
		_r(visual, 35 * arc_side, -52 + y, 4, 9, CYAN_LIGHT)
		_r(visual, 31 * arc_side, -44 + y, 11, 4, CYAN)
	if visual.animation_state == &"area_telegraph":
		var spread := 22 + int(visual.telegraph_progress * 30.0)
		_r(visual, -spread, 32 + y, spread * 2, 5, ORANGE)
		_r(visual, -4, 27 + y, 8, 12, GOLD)
	if visual.animation_state == &"charge_telegraph":
		# Directional chevrons sit on the ground and point at the real charge side.
		for index in range(3):
			var arrow_x := 58 + index * 19
			_r(visual, arrow_x, 42 + y, 10, 4, ORANGE)
			_r(visual, arrow_x + 6, 38 + y, 4, 12, GOLD)
	if visual.animation_state == &"transition":
		var radius := 58 + int(visual.transition_progress * 32.0)
		var color := CORE_LIGHT if visual.phase_visual == 2 else CYAN
		_r(visual, -radius, -13 + y, 18, 5, color)
		_r(visual, radius - 18, -13 + y, 18, 5, color)
		_r(visual, -3, -72 - int(radius * 0.25) + y, 6, 15, color)
		_r(visual, -3, 42 + int(radius * 0.12) + y, 6, 12, color)
		for index in range(4):
			var sx := -48 + index * 31
			_r(visual, sx, -61 + ((index * 11) % 25) + y, 7, 5, STEEL_LIGHT)
	if visual.hurt_remaining > 0.0:
		var hx := int(round(visual.hit_local.x))
		var hy := int(round(visual.hit_local.y))
		var hit_color := CYAN_LIGHT if visual.heavy_hurt else CORE_LIGHT
		_r(visual, hx - 8, hy - 2, 16, 4, hit_color)
		_r(visual, hx - 2, hy - 8, 4, 16, hit_color)
		if visual.heavy_hurt:
			_r(visual, hx - 13, hy - 10, 5, 5, CYAN)
			_r(visual, hx + 9, hy + 7, 6, 5, CYAN)
	if visual.death_elapsed >= 0.0:
		_draw_death_sequence(visual)


func _draw_death_sequence(visual: IronTempestVisual) -> void:
	var elapsed := visual.death_elapsed
	var points := [Vector2(-33, -48), Vector2(39, -28), Vector2(-21, 19), Vector2(9, -12)]
	for index in range(points.size()):
		var start := 0.08 + index * 0.11
		var age := elapsed - start
		if age >= 0.0 and age < 0.24:
			var radius := 5 + int(age * 62.0)
			var p: Vector2 = points[index]
			_r(visual, int(p.x) - radius, int(p.y) - 3, radius * 2, 6, ORANGE)
			_r(visual, int(p.x) - 3, int(p.y) - radius, 6, radius * 2, GOLD)
	if elapsed > 0.52 and elapsed < 0.80:
		var final_radius := 12 + int((elapsed - 0.52) * 120.0)
		_r(visual, -final_radius, -16, final_radius * 2, 9, CYAN_LIGHT)
		_r(visual, -5, -16 - final_radius, 10, final_radius * 2, CORE_LIGHT)


func _draw_contacts(visual: IronTempestVisual) -> void:
	if visual.animation_state == &"intro" and visual.intro_remaining < 0.23:
		var amount := int((0.23 - visual.intro_remaining) * 55.0)
		_r(visual, -61 - amount, 54, 24, 6, SMOKE)
		_r(visual, 37 + amount, 54, 24, 6, SMOKE)
	if visual.animation_state == &"charge_active":
		var rear := -1 if visual.facing > 0 else 1
		for index in range(3):
			var x := rear * (55 + index * 14)
			_r(visual, x - 5, 50 - index * 3, 10, 5, SMOKE)


func _r(visual: IronTempestVisual, x: int, y: int, width: int, height: int, color: Color, mirror: bool = true) -> void:
	var draw_x := x
	if mirror and visual.facing < 0:
		draw_x = -x - width
	draw_rect(Rect2(draw_x, y, width, height), color, true)


func _poly(visual: IronTempestVisual, points: Array[Vector2], color: Color) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(Vector2(point.x if visual.facing > 0 else -point.x, point.y))
	draw_colored_polygon(transformed, color)
