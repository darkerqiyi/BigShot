extends CharacterBody2D
class_name PlayerGrenade

signal bounced(position: Vector2, strength: float)
signal exploded(position: Vector2, radius: float, damage: int, knockback: float)
signal fuse_tick(position: Vector2, urgency: float)

var gravity := 1200.0
var fuse_remaining := 1.70
var bounce_damping := 0.56
var max_bounces := 5
var blast_radius := 110.0
var blast_damage := 80
var blast_knockback := 360.0
var _bounce_count := 0
var _settled := false
var _resolved := false
var _initial_fuse := 1.70
var _next_fuse_tick := 0.72


func configure(origin: Vector2, initial_velocity: Vector2, options: Dictionary = {}) -> void:
	global_position = origin
	velocity = initial_velocity
	gravity = float(options.get("gravity", gravity))
	fuse_remaining = float(options.get("fuse", fuse_remaining))
	_initial_fuse = fuse_remaining
	_next_fuse_tick = minf(0.72, fuse_remaining * 0.48)
	bounce_damping = float(options.get("bounce_damping", bounce_damping))
	max_bounces = int(options.get("max_bounces", max_bounces))
	blast_radius = float(options.get("radius", blast_radius))
	blast_damage = int(options.get("damage", blast_damage))
	blast_knockback = float(options.get("knockback", blast_knockback))


func _ready() -> void:
	add_to_group("player_grenades")
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	collision.shape = shape
	add_child(collision)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	fuse_remaining = maxf(fuse_remaining - delta, 0.0)
	if fuse_remaining <= _next_fuse_tick and fuse_remaining > 0.0:
		var urgency := 1.0 - clampf(fuse_remaining / maxf(_initial_fuse, 0.01), 0.0, 1.0)
		fuse_tick.emit(global_position, urgency)
		_next_fuse_tick = maxf(fuse_remaining - lerpf(0.24, 0.09, urgency), 0.0)
	if fuse_remaining <= 0.0:
		explode_now()
		return
	if not _settled:
		velocity.y += gravity * delta
		var collision := move_and_collide(velocity * delta)
		if collision != null:
			_bounce_count += 1
			var incoming_speed := velocity.length()
			velocity = velocity.bounce(collision.get_normal()) * bounce_damping
			if collision.get_normal().y < -0.55:
				velocity.x *= 0.82
			if _bounce_count >= max_bounces or velocity.length() < 92.0:
				velocity = Vector2.ZERO
				_settled = true
			bounced.emit(global_position, clampf(incoming_speed / 700.0, 0.2, 1.0))
		rotation += velocity.x * delta * 0.018
	if global_position.y > 900.0 or global_position.x < -600.0 or global_position.x > 20600.0:
		queue_free()
	queue_redraw()


func explode_now() -> void:
	if _resolved:
		return
	_resolved = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	exploded.emit(global_position, blast_radius, blast_damage, blast_knockback)
	queue_free()


func _draw() -> void:
	var blink := fuse_remaining < 0.55 and int(fuse_remaining * 14.0) % 2 == 0
	draw_rect(Rect2(-8, -8, 16, 16), Color("10243a"), true)
	draw_rect(Rect2(-5, -5, 10, 10), Color("f49a36") if blink else Color("24636a"), true)
	draw_rect(Rect2(-2, -8, 4, 5), Color("ffd35a"), true)
	draw_rect(Rect2(2, -4, 3, 3), Color("fff4d2"), true)
