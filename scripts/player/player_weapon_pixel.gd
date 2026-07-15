extends Node2D
class_name PlayerWeaponPixel

const INK := Color("10243a")
const DEEP := Color("183852")
const METAL := Color("718395")
const METAL_LIGHT := Color("b5c7cf")
const SKIN := Color("b9f5e7")
const SLEEVE := Color("17666d")
const GOLD := Color("ffd35a")

@onready var muzzle_point: Marker2D = $MuzzlePoint
@onready var muzzle_flash: Node2D = $MuzzleFlash

var weapon_id: StringName = &"rifle"
var color := GOLD
var aim_direction := Vector2.RIGHT
var facing := 1
var recoil_remaining := 0.0
var recoil_duration := 0.10
var recoil_distance := 3.0
var muzzle_length := 38.0
var rear_grip_x := 3.0
var front_grip_x := 20.0


func configure(next_weapon_id: StringName, data: Dictionary) -> void:
	weapon_id = next_weapon_id
	color = data["color"]
	match weapon_id:
		&"shotgun":
			muzzle_length = 39.0
			rear_grip_x = 3.0
			front_grip_x = 22.0
			recoil_distance = 6.0
			recoil_duration = 0.14
		&"sniper":
			muzzle_length = 52.0
			rear_grip_x = 4.0
			front_grip_x = 25.0
			recoil_distance = 8.0
			recoil_duration = 0.13
		&"pistol":
			muzzle_length = 25.0
			rear_grip_x = 4.0
			front_grip_x = 12.0
			recoil_distance = 2.0
			recoil_duration = 0.08
		_:
			muzzle_length = 40.0
			rear_grip_x = 4.0
			front_grip_x = 21.0
			recoil_distance = 3.5
			recoil_duration = 0.10
	_update_muzzle_position()
	queue_redraw()


func set_aim(next_aim: Vector2, next_facing: int) -> void:
	aim_direction = next_aim.normalized() if next_aim.length_squared() > 0.01 else Vector2.RIGHT
	facing = 1 if next_facing >= 0 else -1
	var local_y := aim_direction.y
	var local_angle := clampf(atan2(local_y, maxf(absf(aim_direction.x), 0.03)), -1.40, 1.40)
	rotation = local_angle if facing > 0 else PI - local_angle
	_update_muzzle_position()


func update_animation(delta: float) -> void:
	recoil_remaining = maxf(recoil_remaining - delta, 0.0)
	_update_muzzle_position()
	queue_redraw()


func play_shot() -> void:
	recoil_remaining = recoil_duration
	_update_muzzle_position()
	queue_redraw()


func get_muzzle_global_position() -> Vector2:
	return muzzle_point.global_position


func _recoil_offset() -> float:
	if recoil_remaining <= 0.0:
		return 0.0
	var progress := recoil_remaining / maxf(recoil_duration, 0.01)
	return recoil_distance * sin(progress * PI)


func _update_muzzle_position() -> void:
	var recoil := _recoil_offset()
	muzzle_point.position = Vector2(muzzle_length - recoil, 0.0).round()
	muzzle_flash.position = muzzle_point.position


func _draw() -> void:
	var recoil := _recoil_offset()
	_draw_back_arm(recoil)
	draw_set_transform(Vector2(-recoil, 0.0))
	match weapon_id:
		&"shotgun":
			_draw_shotgun()
		&"sniper":
			_draw_sniper()
		&"pistol":
			_draw_pistol()
		_:
			_draw_rifle()
	draw_set_transform(Vector2.ZERO)
	_draw_front_arm(recoil)


func _draw_back_arm(recoil: float) -> void:
	var grip := Vector2(rear_grip_x - recoil, 2)
	draw_polygon(PackedVector2Array([Vector2(-3, -2), Vector2(3, -4), grip + Vector2(3, -1), grip + Vector2(1, 5)]), PackedColorArray([SLEEVE]))
	draw_rect(Rect2(grip.x - 1, grip.y, 5, 5), SKIN, true)


func _draw_front_arm(recoil: float) -> void:
	var grip := Vector2(front_grip_x - recoil, 3)
	draw_polygon(PackedVector2Array([Vector2(1, 2), Vector2(7, 3), grip + Vector2(3, 0), grip + Vector2(1, 6)]), PackedColorArray([SLEEVE]))
	draw_rect(Rect2(grip.x, grip.y, 6, 5), SKIN, true)


func _draw_rifle() -> void:
	draw_rect(Rect2(-8, -5, 46, 10), INK, true)
	draw_rect(Rect2(-5, -3, 29, 6), DEEP, true)
	draw_rect(Rect2(7, -3, 15, 5), color, true)
	draw_rect(Rect2(24, -2, 17, 4), METAL_LIGHT, true)
	draw_rect(Rect2(-8, -2, 8, 5), METAL, true)
	draw_rect(Rect2(8, 4, 8, 8), INK, true)
	draw_rect(Rect2(10, 4, 5, 6), METAL, true)
	draw_rect(Rect2(27, 2, 7, 6), INK, true)


func _draw_shotgun() -> void:
	draw_rect(Rect2(-7, -6, 45, 12), INK, true)
	draw_rect(Rect2(-4, -3, 25, 7), color.darkened(0.28), true)
	draw_rect(Rect2(4, -3, 14, 6), color, true)
	draw_rect(Rect2(20, -4, 20, 4), Color("d89048"), true)
	draw_rect(Rect2(20, 1, 20, 4), Color("9c5638"), true)
	draw_rect(Rect2(-10, -3, 9, 8), DEEP, true)
	draw_rect(Rect2(8, 5, 8, 8), INK, true)


func _draw_sniper() -> void:
	draw_rect(Rect2(-10, -4, 57, 8), INK, true)
	draw_rect(Rect2(-7, -2, 33, 5), DEEP, true)
	draw_rect(Rect2(6, -2, 18, 4), color.darkened(0.32), true)
	draw_rect(Rect2(25, -1, 28, 3), color, true)
	draw_rect(Rect2(2, -10, 24, 5), INK, true)
	draw_rect(Rect2(5, -9, 17, 3), Color("65c8ff"), true)
	draw_rect(Rect2(-11, -1, 9, 6), METAL, true)
	draw_rect(Rect2(9, 3, 7, 10), INK, true)
	draw_rect(Rect2(34, 2, 6, 8), INK, true)


func _draw_pistol() -> void:
	draw_rect(Rect2(-4, -5, 29, 10), INK, true)
	draw_rect(Rect2(-1, -3, 23, 5), color.darkened(0.25), true)
	draw_rect(Rect2(6, -3, 15, 4), color, true)
	draw_rect(Rect2(20, -2, 7, 3), METAL_LIGHT, true)
	draw_polygon(PackedVector2Array([Vector2(4, 4), Vector2(15, 4), Vector2(12, 15), Vector2(5, 13)]), PackedColorArray([INK]))
	draw_rect(Rect2(7, 5, 5, 7), DEEP, true)
