extends Node2D

var velocity := Vector2.ZERO
var age := 0.0
var lifetime := 0.48
var casing_color := Color("ffd35a")
var pixel_size := Vector2(5, 2)


func configure(origin: Vector2, shot_direction: Vector2, weapon_id: StringName, sequence: int = 0) -> void:
	global_position = origin - shot_direction.normalized() * 10.0 + Vector2(0, -4)
	var side := -1.0 if shot_direction.x >= 0.0 else 1.0
	velocity = Vector2(side * (70.0 + float(sequence % 3) * 13.0), -105.0 - float(sequence % 2) * 18.0)
	match weapon_id:
		&"shotgun":
			pixel_size = Vector2(7, 3)
			casing_color = Color("d89048")
		&"sniper":
			pixel_size = Vector2(8, 2)
			casing_color = Color("65c8ff")
		&"pistol":
			pixel_size = Vector2(4, 2)
			casing_color = Color("86e7c5")
		_:
			pixel_size = Vector2(5, 2)
			casing_color = Color("ffd35a")
	rotation = float(sequence % 4) * 0.35
	add_to_group("combat_casings")
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	velocity.y += 520.0 * delta
	position += velocity * delta
	rotation += delta * 8.0
	modulate.a = clampf((lifetime - age) / 0.14, 0.0, 1.0)
	if age >= lifetime:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-pixel_size * 0.5, pixel_size), casing_color, true)
