extends Node2D
class_name GrenadeExplosion

var radius := 110.0
var age := 0.0
var duration := 0.36


func configure(world_position: Vector2, blast_radius: float) -> void:
	global_position = world_position
	radius = blast_radius


func _ready() -> void:
	add_to_group("grenade_effects")
	z_index = 32
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var expansion := sin(progress * PI)
	var blast_extent := radius * clampf(progress * 2.8, 0.0, 1.0)
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var distance := blast_extent * (0.68 + float(index % 3) * 0.14)
		var point := Vector2(cos(angle), sin(angle)) * distance
		var size := 12.0 - progress * 5.0 + float(index % 2) * 4.0
		var color := Color("fff4d2") if index % 4 == 0 else (Color("ffd35a") if index % 2 == 0 else Color("ff6c3a"))
		color.a = expansion
		draw_rect(Rect2(point.round() - Vector2.ONE * size * 0.5, Vector2.ONE * size), color, true)
	var core_size := 58.0 * expansion
	draw_rect(Rect2(Vector2.ONE * -core_size * 0.5, Vector2.ONE * core_size), Color(1.0, 0.42, 0.16, expansion * 0.86), true)
	if progress > 0.45:
		for index in range(7):
			var smoke := Vector2(-42 + index * 14, -26 - (index % 3) * 10)
			draw_rect(Rect2(smoke, Vector2(12, 12)), Color(0.07, 0.14, 0.20, (1.0 - progress) * 0.72), true)
