extends Area2D
class_name MissionSpikes

const DAMAGE := 14
const DAMAGE_COOLDOWN := 0.85

var strip_width := 180.0
var _target: Node
var _cooldown := 0.0


func configure(width: float) -> void:
	strip_width = width


func _ready() -> void:
	add_to_group("mission_hazards")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(strip_width, 20)
	shape_node.shape = shape
	add_child(shape_node)
	body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			_target = body
			_apply_damage()
	)
	body_exited.connect(func(body: Node) -> void:
		if body == _target:
			_target = null
	)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _target != null and is_instance_valid(_target) and _cooldown <= 0.0:
		_apply_damage()


func _apply_damage() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.has_method("take_damage"):
		return
	_cooldown = DAMAGE_COOLDOWN
	_target.take_damage(DAMAGE, Vector2(0, -180), global_position, {"source": &"spikes", "damage_kind": &"environment"})


func _draw() -> void:
	draw_rect(Rect2(-strip_width * 0.5, 6, strip_width, 8), Color("5c2c48"), true)
	var count := maxi(int(strip_width / 24.0), 1)
	for index in range(count):
		var x := -strip_width * 0.5 + index * 24.0
		draw_polygon(PackedVector2Array([
			Vector2(x, 6), Vector2(x + 12, -14), Vector2(x + 24, 6),
		]), PackedColorArray([Color("ff6c3a")]))
		draw_rect(Rect2(x + 9, -4, 6, 6), Color("ffd35a"), true)
