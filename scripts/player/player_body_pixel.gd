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
	if pose == &"roll":
		_draw_roll()
		return
	if pose in [&"sprint_start", &"sprint", &"sprint_stop"]:
		_draw_sprint()
		return
	if pose in [&"sprint_jump", &"sprint_fall", &"sprint_land"]:
		_draw_sprint_air()
		return
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


func _draw_roll() -> void:
	_pixel_rect(-17, -17, 34, 34, INK)
	_pixel_rect(-13, -13, 26, 26, SUIT_DARK)
	_pixel_rect(-9, -14, 18, 8, SUIT)
	_pixel_rect(-11, -5, 22, 8, GOLD)
	_pixel_rect(-9, 5, 18, 7, DEEP)
	_pixel_rect(4, -11, 8, 6, VISOR)


func _draw_sprint() -> void:
	var lean := 3 if pose == &"sprint_start" else (6 if pose == &"sprint" else 2)
	var stride := 7 if sin(phase * 1.15) >= 0.0 else -7
	# Feet remain on the same baseline while torso and head shift forward.
	_pixel_rect(-13 + stride, 13, 10, 16, INK)
	_pixel_rect(-11 + stride, 13, 6, 10, SUIT_DARK)
	_pixel_rect(-15 + stride, 24, 14, 5, DEEP)
	_pixel_rect(3 - stride, 13, 10, 16, INK)
	_pixel_rect(5 - stride, 13, 6, 10, SUIT_DARK)
	_pixel_rect(1 - stride, 24, 14, 5, DEEP)
	_pixel_rect(-14 + lean, -8, 30, 24, INK)
	_pixel_rect(-11 + lean, -6, 24, 18, SUIT)
	_pixel_rect(-9 + lean, 7, 20, 6, SUIT_DARK)
	_pixel_rect(-1 + lean, -6, 5, 18, GOLD)
	_pixel_rect(-13 + lean, -3, 7, 15, SUIT_LIGHT)
	_pixel_rect(8 + lean, -3, 6, 15, DEEP)
	_pixel_rect(-12 + lean * 2, -29, 28, 22, INK)
	_pixel_rect(-9 + lean * 2, -27, 22, 17, FACE)
	_pixel_rect(-14 + lean * 2, -33, 30, 10, INK)
	_pixel_rect(-11 + lean * 2, -31, 24, 7, SUIT)
	_pixel_rect(-6 + lean * 2, -22, 20, 7, INK)
	_pixel_rect(-4 + lean * 2, -20, 16, 4, VISOR)
	_pixel_rect(-13 + lean, -10, 26, 4, GOLD)
	_pixel_rect(-22, -8, 11, 4, GOLD)
	_pixel_rect(-27, -5, 9, 4, Color("f49a36"))
	if hurt_strength > 0.0:
		_draw_hurt_highlight(0)


func _draw_sprint_air() -> void:
	var lean := 7
	var body_y := -2 if pose == &"sprint_jump" else (2 if pose == &"sprint_fall" else 5)
	var rear_leg_y := 8 if pose == &"sprint_jump" else 13
	var front_leg_y := 13 if pose == &"sprint_jump" else 8
	if pose == &"sprint_land":
		rear_leg_y = 16
		front_leg_y = 16
	_pixel_rect(-18, rear_leg_y, 13, 8, INK)
	_pixel_rect(-15, rear_leg_y + 2, 10, 5, SUIT_DARK)
	_pixel_rect(4, front_leg_y, 16, 8, INK)
	_pixel_rect(6, front_leg_y + 2, 11, 5, DEEP)
	_pixel_rect(-14 + lean, -8 + body_y, 30, 24, INK)
	_pixel_rect(-11 + lean, -6 + body_y, 24, 18, SUIT)
	_pixel_rect(-9 + lean, 7 + body_y, 20, 6, SUIT_DARK)
	_pixel_rect(-1 + lean, -6 + body_y, 5, 18, GOLD)
	_pixel_rect(-13 + lean, -3 + body_y, 7, 15, SUIT_LIGHT)
	_pixel_rect(8 + lean, -3 + body_y, 6, 15, DEEP)
	_pixel_rect(-12 + lean * 2, -29 + body_y, 28, 22, INK)
	_pixel_rect(-9 + lean * 2, -27 + body_y, 22, 17, FACE)
	_pixel_rect(-14 + lean * 2, -33 + body_y, 30, 10, INK)
	_pixel_rect(-11 + lean * 2, -31 + body_y, 24, 7, SUIT)
	_pixel_rect(-6 + lean * 2, -22 + body_y, 20, 7, INK)
	_pixel_rect(-4 + lean * 2, -20 + body_y, 16, 4, VISOR)
	_pixel_rect(-13 + lean, -10 + body_y, 26, 4, GOLD)
	_pixel_rect(-23, -8 + body_y, 12, 4, GOLD)
	_pixel_rect(-28, -5 + body_y, 9, 4, Color("f49a36"))
	if hurt_strength > 0.0:
		_draw_hurt_highlight(body_y)


func _pixel_rect(x: int, y: int, width: int, height: int, color: Color) -> void:
	var draw_x := x if facing > 0 else -x - width
	draw_rect(Rect2(draw_x, y, width, height), color, true)
