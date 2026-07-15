extends Node2D
class_name PlayerBodyPixel

const INK := Color("10243a")
const DEEP := Color("183852")
const SUIT_DARK := Color("17666d")
const SUIT := Color("2fc7ae")
const SUIT_LIGHT := Color("6ce9d2")
const GOLD := Color("ffd35a")
const FACE := Color("b9f5e7")
const VISOR := Color("82e8ff")
const WHITE := Color("fff4d2")
const HURT := Color("ffb6ad")

var pose: StringName = &"idle"
var phase := 0.0
var facing := 1
var hurt_strength := 0.0
var death_progress := 0.0


func set_pose(next_pose: StringName, next_phase: float, next_facing: int, next_hurt: float, next_death: float) -> void:
	pose = next_pose
	phase = next_phase
	facing = 1 if next_facing >= 0 else -1
	hurt_strength = next_hurt
	death_progress = next_death
	queue_redraw()


func _draw() -> void:
	var body_bob := 0
	if pose == &"idle":
		body_bob = 1 if sin(phase * 2.2) > 0.55 else 0
	elif pose == &"run":
		body_bob = int(round(absf(sin(phase * 2.0))))
	elif pose == &"jump":
		body_bob = -1
	elif pose == &"fall":
		body_bob = 1
	elif pose == &"land":
		body_bob = 2

	var death_drop := int(round(death_progress * 9.0))
	body_bob += death_drop
	_draw_legs(body_bob)
	_draw_torso(body_bob)
	_draw_head(body_bob)
	_draw_scarf(body_bob)
	if hurt_strength > 0.0:
		_draw_hurt_highlight(body_bob)


func _draw_legs(body_bob: int) -> void:
	if pose == &"idle":
		body_bob = 0
	var left_leg_x := -12
	var right_leg_x := 2
	var left_y := 12 + body_bob
	var right_y := 12 + body_bob
	if pose == &"run":
		var stride := 5 if sin(phase) >= 0.0 else -5
		left_leg_x += stride
		right_leg_x -= stride
		left_y += 1 if stride > 0 else -2
		right_y += -2 if stride > 0 else 1
	elif pose == &"jump":
		left_leg_x -= 2
		right_leg_x += 3
		left_y -= 4
		right_y += 1
	elif pose == &"fall":
		left_leg_x += 2
		right_leg_x -= 2
		left_y += 1
		right_y -= 3
	elif pose == &"land":
		left_leg_x -= 3
		right_leg_x += 3
		left_y += 2
		right_y += 2

	_pixel_rect(left_leg_x, left_y, 10, 17, INK)
	_pixel_rect(left_leg_x + 2, left_y, 6, 11, SUIT_DARK)
	_pixel_rect(left_leg_x - 2, left_y + 12, 13, 6, DEEP)
	_pixel_rect(right_leg_x, right_y, 10, 17, INK)
	_pixel_rect(right_leg_x + 2, right_y, 6, 11, SUIT_DARK)
	_pixel_rect(right_leg_x - 1, right_y + 12, 13, 6, DEEP)


func _draw_torso(body_bob: int) -> void:
	_pixel_rect(-15, -8 + body_bob, 30, 25, INK)
	_pixel_rect(-12, -6 + body_bob, 24, 19, SUIT)
	_pixel_rect(-12, 6 + body_bob, 24, 7, SUIT_DARK)
	_pixel_rect(-2, -6 + body_bob, 5, 19, GOLD)
	_pixel_rect(-10, 8 + body_bob, 7, 5, DEEP)
	_pixel_rect(5, 8 + body_bob, 5, 5, DEEP)
	_pixel_rect(-15, -4 + body_bob, 4, 12, SUIT_LIGHT)


func _draw_head(body_bob: int) -> void:
	_pixel_rect(-14, -29 + body_bob, 28, 23, INK)
	_pixel_rect(-11, -27 + body_bob, 22, 18, FACE)
	_pixel_rect(-16, -33 + body_bob, 30, 10, INK)
	_pixel_rect(-13, -31 + body_bob, 24, 7, SUIT)
	_pixel_rect(-9, -29 + body_bob, 18, 4, SUIT_LIGHT)
	_pixel_rect(-8, -23 + body_bob, 20, 8, INK)
	_pixel_rect(-6, -21 + body_bob, 16, 4, VISOR)
	_pixel_rect(7, -20 + body_bob, 3, 3, WHITE)
	_pixel_rect(-11, -10 + body_bob, 7, 3, GOLD)


func _draw_scarf(body_bob: int) -> void:
	_pixel_rect(-14, -10 + body_bob, 26, 4, GOLD)
	if facing > 0:
		_pixel_rect(-19, -7 + body_bob, 8, 4, GOLD)
		_pixel_rect(-22, -4 + body_bob, 7, 4, Color("f49a36"))
	else:
		_pixel_rect(11, -7 + body_bob, 8, 4, GOLD)
		_pixel_rect(15, -4 + body_bob, 7, 4, Color("f49a36"))


func _draw_hurt_highlight(body_bob: int) -> void:
	var color := HURT if hurt_strength > 0.45 else WHITE
	_pixel_rect(-16, -31 + body_bob, 3, 20, color)
	_pixel_rect(-16, -8 + body_bob, 3, 21, color)
	_pixel_rect(-13, 14 + body_bob, 3, 12, color)


func _pixel_rect(x: int, y: int, width: int, height: int, color: Color) -> void:
	var draw_x := x if facing > 0 else -x - width
	draw_rect(Rect2(draw_x, y, width, height), color, true)
