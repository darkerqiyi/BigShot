extends Node2D
class_name EnemyPixelVisual

const INK := Color("10243a")
const ENEMY_INK := Color("30263b")
const SHADOW := Color("533142")
const RED_DARK := Color("8f3440")
const RED := Color("e65345")
const RED_LIGHT := Color("ff7960")
const ORANGE := Color("f49a36")
const GOLD := Color("ffd35a")
const PURPLE := Color("72426f")
const PURPLE_LIGHT := Color("b95d8d")
const METAL := Color("718395")
const METAL_LIGHT := Color("b5c7cf")
const VISOR := Color("ffcc6a")
const HURT := Color("fff4d2")
const BLOCK := Color("65c8ff")

@onready var muzzle_point: Marker2D = $MuzzlePoint
@onready var muzzle_flash: Node2D = $MuzzleFlash

var enemy_kind := "gunner"
var facing := 1
var animation_state: StringName = &"idle"
var base_animation_state: StringName = &"idle"
var pending_attack: StringName = &"projectile"
var animation_phase := 0.0
var telegraph_progress := 0.0
var guard_open := false
var hurt_remaining := 0.0
var hit_reaction_duration := 0.0
var hit_pose_offset := Vector2.ZERO
var hit_pose_rotation := 0.0
var hit_material: StringName = &"trooper"
var hit_weapon: StringName = &"rifle"
var hit_was_headshot := false
var block_remaining := 0.0
var attack_remaining := 0.0
var dead := false
var color := RED


func configure(kind: String) -> void:
	enemy_kind = _normalized_kind(kind)
	color = PURPLE_LIGHT if enemy_kind == "elite" else (Color("d96a45") if enemy_kind == "gunner" else RED)
	reset_visual()


func reset_visual() -> void:
	dead = false
	hurt_remaining = 0.0
	hit_reaction_duration = 0.0
	hit_pose_offset = Vector2.ZERO
	hit_pose_rotation = 0.0
	hit_material = &"trooper"
	hit_weapon = &"rifle"
	hit_was_headshot = false
	block_remaining = 0.0
	attack_remaining = 0.0
	animation_state = &"idle"
	base_animation_state = &"idle"
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = true
	muzzle_flash.visible = false
	_update_muzzle()
	queue_redraw()


func set_facing(next_facing: int) -> void:
	facing = 1 if next_facing >= 0 else -1
	_update_muzzle()
	queue_redraw()


func update_from_logic(
	delta: float,
	logic_state: StringName,
	current_velocity: Vector2,
	windup_remaining: float,
	windup_duration: float,
	guard_open_remaining: float,
	stagger_remaining: float,
	next_attack: StringName,
	is_active: bool,
	is_alive: bool,
) -> void:
	if dead:
		return
	animation_phase += delta * (4.0 + absf(current_velocity.x) * 0.035)
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	block_remaining = maxf(block_remaining - delta, 0.0)
	attack_remaining = maxf(attack_remaining - delta, 0.0)
	pending_attack = next_attack
	guard_open = guard_open_remaining > 0.0
	telegraph_progress = 1.0 - windup_remaining / maxf(windup_duration, 0.001) if windup_remaining > 0.0 else 0.0
	base_animation_state = _map_logic_state(logic_state, current_velocity, is_active)
	if not is_alive:
		animation_state = &"death"
	elif hurt_remaining > 0.0:
		animation_state = &"hurt"
	elif block_remaining > 0.0:
		animation_state = &"block"
	elif attack_remaining > 0.0:
		animation_state = &"attack"
	elif stagger_remaining > 0.0:
		animation_state = &"stagger"
	else:
		animation_state = base_animation_state
	_update_muzzle()
	queue_redraw()


func play_attack(attack_kind: StringName) -> void:
	pending_attack = attack_kind
	attack_remaining = 0.16 if enemy_kind != "elite" else 0.20
	if attack_kind in [&"projectile", &"elite_volley"]:
		_show_muzzle_flash()
	queue_redraw()


func play_hurt(strength: float = 1.0) -> void:
	# Compatibility entry for non-projectile callers. New combat hits use the
	# weapon/material-aware visual-only reaction below.
	play_hit_reaction(&"sniper" if strength >= 0.95 else &"rifle", &"trooper", false, false, Vector2(facing, 0))


func play_hit_reaction(
	weapon_id: StringName,
	material: StringName,
	is_headshot: bool,
	is_lethal: bool,
	source_direction: Vector2,
) -> void:
	if dead:
		return
	hit_weapon = weapon_id
	hit_material = material
	hit_was_headshot = is_headshot
	var duration := 0.055
	var pose_strength := 1.0
	match weapon_id:
		&"pistol":
			duration = 0.075
			pose_strength = 1.25
		&"shotgun":
			duration = 0.12
			pose_strength = 2.6
		&"sniper":
			duration = 0.145
			pose_strength = 3.2
		_:
			duration = 0.055
			pose_strength = 0.8
	if material in [&"armor", &"boss_armor"]:
		pose_strength *= 0.48
	if is_headshot:
		duration += 0.018
		pose_strength *= 1.18
	if is_lethal:
		duration = minf(duration + 0.02, 0.17)
	var hit_sign := signf(source_direction.x) if absf(source_direction.x) > 0.01 else float(facing)
	hit_pose_offset = Vector2(hit_sign * pose_strength, -pose_strength * (0.45 if is_headshot else 0.15))
	hit_pose_rotation = hit_sign * deg_to_rad(1.8 * pose_strength)
	hit_reaction_duration = duration
	hurt_remaining = minf(maxf(hurt_remaining, duration), 0.17)
	queue_redraw()


func play_block(strength: float) -> void:
	if dead:
		return
	block_remaining = 0.10 + clampf(strength, 0.0, 1.0) * 0.07
	queue_redraw()


func play_death(
	weapon_id: StringName = &"unknown",
	is_headshot: bool = false,
	source_direction: Vector2 = Vector2.ZERO,
	_material: StringName = &"trooper",
) -> void:
	if dead:
		return
	dead = true
	animation_state = &"death"
	muzzle_flash.visible = false
	var fall_direction := signf(source_direction.x) if absf(source_direction.x) > 0.01 else float(facing)
	var target_rotation := 1.18 * fall_direction
	if enemy_kind == "shield":
		target_rotation = 0.82 * fall_direction
	elif enemy_kind == "elite":
		target_rotation = 0.42 * fall_direction
	if weapon_id == &"shotgun":
		target_rotation *= 1.18
	elif weapon_id == &"sniper":
		target_rotation *= 1.28
	elif is_headshot:
		target_rotation *= 1.12
	var fall_distance := 8.0 if weapon_id == &"shotgun" else (5.0 if weapon_id == &"sniper" else 2.0)
	var tween := create_tween().set_parallel(true)
	var death_duration := 0.25 if weapon_id == &"sniper" else (0.30 if weapon_id == &"shotgun" else 0.32)
	tween.tween_property(self, "rotation", target_rotation, death_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", fall_direction * fall_distance, death_duration)
	tween.tween_property(self, "position:y", 8.0 if enemy_kind != "elite" else 4.0, death_duration)
	queue_redraw()


func get_muzzle_global_position() -> Vector2:
	return muzzle_point.global_position


func get_head_local_position() -> Vector2:
	var bob := _move_bob()
	match enemy_kind:
		"assault":
			var lean := 3 if base_animation_state == &"run" else (-4 if base_animation_state == &"attack_telegraph" else (6 if animation_state == &"attack" else 0))
			return Vector2(lean, -20 + bob)
		"elite":
			return Vector2(0, -24 + bob)
		_:
			return Vector2(0, -21 + bob)


func _map_logic_state(logic_state: StringName, current_velocity: Vector2, is_active: bool) -> StringName:
	if not is_active or logic_state == &"inactive":
		return &"inactive"
	if logic_state == &"telegraph":
		return &"attack_telegraph"
	if logic_state == &"recover":
		return &"recover"
	if logic_state == &"stagger":
		return &"stagger"
	if enemy_kind == "assault":
		return &"run" if logic_state == &"pursue" or absf(current_velocity.x) > 30.0 else &"idle"
	if enemy_kind == "gunner":
		return &"move" if logic_state == &"reposition" and absf(current_velocity.x) > 18.0 else &"idle"
	if enemy_kind == "shield":
		return &"guard_break" if guard_open else (&"walk" if absf(current_velocity.x) > 18.0 else &"guard")
	if enemy_kind == "elite":
		return &"heavy_walk" if logic_state == &"advance" and absf(current_velocity.x) > 12.0 else &"idle"
	return &"idle"


func _draw() -> void:
	if hurt_remaining > 0.0 and hit_reaction_duration > 0.0:
		var pose_ratio := clampf(hurt_remaining / hit_reaction_duration, 0.0, 1.0)
		draw_set_transform((hit_pose_offset * pose_ratio).round(), hit_pose_rotation * pose_ratio)
	match enemy_kind:
		"assault":
			_draw_assault()
		"shield":
			_draw_shield_trooper()
		"elite":
			_draw_elite()
		_:
			_draw_gunner()
	if base_animation_state == &"attack_telegraph":
		_draw_telegraph_accent()
	if animation_state == &"hurt":
		_draw_hurt_edge()


func _draw_telegraph_accent() -> void:
	var pulse := Color("fff0a0") if telegraph_progress > 0.55 else Color("ff8b58")
	match enemy_kind:
		"gunner":
			for index in range(3):
				_r(34 + index * 9, -14, 5, 3, pulse)
		"assault":
			_r(19, -12, 7, 4, pulse)
			_r(27, -8, 7, 4, pulse)
		"shield":
			_r(26, -25, 4, 48, pulse)
		"elite":
			if pending_attack == &"hazard":
				_r(-42, 31, 25, 4, pulse)
				_r(17, 31, 25, 4, pulse)
			else:
				for index in range(3):
					_r(39 + index * 10, -17, 6, 4, pulse)


func _draw_assault() -> void:
	var bob := _move_bob()
	var lean := 3 if base_animation_state == &"run" else 0
	if base_animation_state == &"attack_telegraph":
		lean = -4
	elif animation_state == &"attack":
		lean = 6
	_draw_runner_legs(bob, lean)
	_r(-13 + lean, -7 + bob, 25, 23, ENEMY_INK)
	_r(-10 + lean, -5 + bob, 19, 17, RED)
	_r(-8 + lean, 6 + bob, 15, 7, RED_DARK)
	_r(-12 + lean, -27 + bob, 24, 21, ENEMY_INK)
	_r(-9 + lean, -25 + bob, 18, 16, Color("c98268"))
	_r(-15 + lean, -31 + bob, 27, 8, ENEMY_INK)
	_r(-12 + lean, -29 + bob, 21, 5, RED_LIGHT)
	_r(-6 + lean, -21 + bob, 16, 6, ENEMY_INK)
	_r(-4 + lean, -19 + bob, 12, 3, VISOR)
	_r(-13 + lean, -10 + bob, 23, 4, ORANGE)
	var blade_x := 15 + lean + (5 if animation_state == &"attack" else 0)
	_poly([Vector2(blade_x, -7), Vector2(blade_x + 19, -3), Vector2(blade_x + 23, 2), Vector2(blade_x + 4, 0)], METAL_LIGHT)
	_r(blade_x - 3, -6, 8, 7, ENEMY_INK)


func _draw_runner_legs(bob: int, lean: int) -> void:
	var stride := 0
	if base_animation_state == &"run":
		stride = 5 if sin(animation_phase * 1.8) > 0.0 else -5
	_r(-11 + lean + stride, 12 + bob, 9, 17, ENEMY_INK)
	_r(-9 + lean + stride, 13 + bob, 5, 11, RED_DARK)
	_r(-13 + lean + stride, 25 + bob, 13, 5, SHADOW)
	_r(2 + lean - stride, 12 + bob, 9, 17, ENEMY_INK)
	_r(4 + lean - stride, 13 + bob, 5, 11, RED_DARK)
	_r(1 + lean - stride, 25 + bob, 13, 5, SHADOW)


func _draw_gunner() -> void:
	var bob := _move_bob()
	_draw_standard_legs(bob, RED_DARK)
	_r(-15, -8 + bob, 30, 25, ENEMY_INK)
	_r(-12, -6 + bob, 24, 19, Color("c75c45"))
	_r(-12, 5 + bob, 24, 8, RED_DARK)
	_r(-14, -28 + bob, 28, 22, ENEMY_INK)
	_r(-11, -25 + bob, 22, 16, Color("bd8067"))
	_r(-15, -31 + bob, 30, 8, ENEMY_INK)
	_r(-12, -29 + bob, 24, 5, Color("d96a45"))
	_r(-8, -21 + bob, 19, 7, ENEMY_INK)
	_r(-6, -19 + bob, 15, 3, VISOR)
	var lift := -4 if base_animation_state == &"attack_telegraph" else 0
	var recoil := -4 if animation_state == &"attack" else 0
	_r(-3 + recoil, -15 + lift + bob, 31, 9, ENEMY_INK)
	_r(1 + recoil, -13 + lift + bob, 22, 5, SHADOW)
	_r(8 + recoil, -13 + lift + bob, 13, 4, ORANGE)
	_r(24 + recoil, -12 + lift + bob, 8, 3, METAL_LIGHT)
	_r(3 + recoil, -6 + lift + bob, 7, 8, ENEMY_INK)


func _draw_shield_trooper() -> void:
	var bob := _move_bob()
	_draw_standard_legs(bob, Color("7d3b42"))
	_r(-17, -9 + bob, 32, 26, ENEMY_INK)
	_r(-14, -6 + bob, 26, 20, RED_DARK)
	_r(-10, -5 + bob, 16, 17, PURPLE)
	_r(-16, -30 + bob, 29, 23, ENEMY_INK)
	_r(-13, -27 + bob, 23, 17, Color("a36b65"))
	_r(-15, -32 + bob, 29, 8, ENEMY_INK)
	_r(-12, -30 + bob, 23, 5, Color("a74d52"))
	_r(-7, -22 + bob, 17, 6, ENEMY_INK)
	_r(-5, -20 + bob, 13, 3, VISOR)
	var shield_shift := 7 if guard_open else 0
	var shield_y := 4 if guard_open else 0
	if animation_state == &"block":
		shield_shift = -2
	var sx := 13 + shield_shift
	_poly([Vector2(sx, -27 + shield_y), Vector2(sx + 14, -22 + shield_y), Vector2(sx + 16, 17 + shield_y), Vector2(sx + 5, 29 + shield_y), Vector2(sx - 3, 17 + shield_y), Vector2(sx - 3, -20 + shield_y)], ENEMY_INK)
	_poly([Vector2(sx + 2, -22 + shield_y), Vector2(sx + 10, -18 + shield_y), Vector2(sx + 12, 14 + shield_y), Vector2(sx + 5, 22 + shield_y), Vector2(sx + 1, 14 + shield_y)], Color("9b5050") if guard_open else Color("b85a4c"))
	_r(sx + 3, -12 + shield_y, 7, 20, ORANGE if guard_open else GOLD)
	if guard_open:
		_r(sx - 5, -18 + shield_y, 4, 7, ORANGE)
		_r(sx + 14, 8 + shield_y, 4, 6, RED_LIGHT)
	elif animation_state == &"block":
		_r(sx - 3, -25 + shield_y, 4, 48, BLOCK)


func _draw_elite() -> void:
	var bob := 1 if base_animation_state == &"heavy_walk" and sin(animation_phase) > 0.0 else 0
	var stomp := 4 if base_animation_state == &"attack_telegraph" else 0
	_r(-23 - stomp, 9 + bob, 18, 23, ENEMY_INK)
	_r(-19 - stomp, 10 + bob, 10, 16, PURPLE)
	_r(-25 - stomp, 27 + bob, 21, 7, SHADOW)
	_r(5 + stomp, 9 + bob, 18, 23, ENEMY_INK)
	_r(9 + stomp, 10 + bob, 10, 16, PURPLE)
	_r(4 + stomp, 27 + bob, 21, 7, SHADOW)
	_r(-25, -12 + bob, 50, 27, ENEMY_INK)
	_r(-21, -9 + bob, 42, 21, PURPLE)
	_r(-14, -5 + bob, 28, 16, RED_DARK)
	_r(-8, -2 + bob, 16, 12, PURPLE_LIGHT if base_animation_state != &"attack_telegraph" else GOLD)
	_r(-28, -17 + bob, 14, 17, ENEMY_INK)
	_r(14, -17 + bob, 14, 17, ENEMY_INK)
	_r(-24, -14 + bob, 8, 11, RED)
	_r(16, -14 + bob, 8, 11, RED)
	_r(-20, -35 + bob, 40, 25, ENEMY_INK)
	_r(-16, -32 + bob, 32, 18, Color("6d455d"))
	_r(-12, -27 + bob, 24, 8, INK)
	_r(-9, -25 + bob, 18, 4, Color("ff8b58"))
	var recoil := -5 if animation_state == &"attack" and pending_attack == &"elite_volley" else 0
	_r(-11 + recoil, -19 + bob, 43, 11, ENEMY_INK)
	_r(-5 + recoil, -17 + bob, 32, 7, SHADOW)
	_r(7 + recoil, -16 + bob, 18, 5, PURPLE_LIGHT)
	_r(27 + recoil, -15 + bob, 10, 4, METAL_LIGHT)
	if base_animation_state == &"attack_telegraph" and pending_attack == &"hazard":
		_r(-28, 15, 7, 12, ORANGE)
		_r(21, 15, 7, 12, ORANGE)


func _draw_standard_legs(bob: int, fill: Color) -> void:
	var stride := 0
	if base_animation_state in [&"move", &"walk"]:
		stride = 3 if sin(animation_phase * 1.6) > 0.0 else -3
	_r(-12 + stride, 12 + bob, 10, 18, ENEMY_INK)
	_r(-9 + stride, 13 + bob, 5, 12, fill)
	_r(-14 + stride, 26 + bob, 14, 5, SHADOW)
	_r(2 - stride, 12 + bob, 10, 18, ENEMY_INK)
	_r(5 - stride, 13 + bob, 5, 12, fill)
	_r(1 - stride, 26 + bob, 14, 5, SHADOW)


func _draw_hurt_edge() -> void:
	var width := 23 if enemy_kind == "elite" else 16
	var top := -36 if enemy_kind == "elite" else -31
	var edge_color := HURT
	if hit_material == &"armor":
		edge_color = METAL_LIGHT
	elif hit_material == &"shield":
		edge_color = BLOCK
	elif hit_was_headshot:
		edge_color = GOLD
	_r(-width, top, 4, 22, edge_color)
	_r(width - 4, top + 7, 4, 18, edge_color)


func _move_bob() -> int:
	if base_animation_state in [&"run", &"move", &"walk", &"heavy_walk"]:
		return int(round(absf(sin(animation_phase * 1.6))))
	if base_animation_state == &"recover":
		return 2
	return 0


func _show_muzzle_flash() -> void:
	muzzle_flash.call("play", &"enemy", ORANGE, 1.45 if enemy_kind == "elite" else 1.0, enemy_kind == "elite")


func _update_muzzle() -> void:
	muzzle_point.position = Vector2(24 * facing, -12)
	muzzle_flash.position = muzzle_point.position
	muzzle_flash.rotation = 0.0 if facing > 0 else PI


func _r(x: int, y: int, width: int, height: int, draw_color: Color) -> void:
	var draw_x := x if facing > 0 else -x - width
	draw_rect(Rect2(draw_x, y, width, height), draw_color, true)


func _poly(points: Array[Vector2], draw_color: Color) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(Vector2(point.x if facing > 0 else -point.x, point.y))
	draw_polygon(transformed, PackedColorArray([draw_color]))


func _normalized_kind(kind: String) -> String:
	if kind in ["assault", "runner"]:
		return "assault"
	if kind in ["elite", "heavy"]:
		return "elite"
	if kind == "shield":
		return "shield"
	return "gunner"
