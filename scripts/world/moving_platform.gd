extends AnimatableBody2D
class_name MissionMovingPlatform

var travel := Vector2(0, -96)
var cycle_seconds := 3.6
var platform_size := Vector2(180, 18)
var _origin := Vector2.ZERO
var _elapsed := 0.0


func configure(motion: Vector2, cycle: float, size: Vector2 = Vector2(180, 18)) -> void:
	travel = motion
	cycle_seconds = cycle
	platform_size = size


func _ready() -> void:
	add_to_group("mission_platforms")
	_origin = global_position
	collision_layer = 1
	collision_mask = 6
	sync_to_physics = true
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = platform_size
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var phase := (sin(_elapsed / maxf(cycle_seconds, 0.1) * TAU - PI * 0.5) + 1.0) * 0.5
	global_position = (_origin + travel * phase).round()


func _draw() -> void:
	draw_rect(Rect2(-platform_size * 0.5, platform_size), Color("10243a"), true)
	draw_rect(Rect2(-platform_size * 0.5 + Vector2(4, 4), platform_size - Vector2(8, 8)), Color("24636a"), true)
	draw_rect(Rect2(-platform_size.x * 0.5, -platform_size.y * 0.5, platform_size.x, 5), Color("86e7c5"), true)
	for x in range(int(-platform_size.x * 0.5 + 16), int(platform_size.x * 0.5 - 8), 32):
		draw_rect(Rect2(x, -2, 16, 4), Color("ffd35a"), true)
