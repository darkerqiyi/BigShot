extends Area2D
class_name MissionPickup

signal collected(kind: StringName, amount: int)

var pickup_kind: StringName = &"health"
var amount := 20
var ammo_floor := 0.0
var _collected := false


func configure(kind: StringName, value: int, floor_ratio: float = 0.0) -> void:
	pickup_kind = kind
	amount = value
	ammo_floor = floor_ratio


func _ready() -> void:
	add_to_group("mission_pickups")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 42)
	shape_node.shape = shape
	add_child(shape_node)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	if body.has_method("apply_field_resupply"):
		body.apply_field_resupply(amount if pickup_kind == &"health" else 0, ammo_floor, amount if pickup_kind == &"grenade" else 0)
	collected.emit(pickup_kind, amount)
	queue_free()


func _draw() -> void:
	var accent := Color("55e39a") if pickup_kind == &"health" else (Color("ff8a45") if pickup_kind == &"grenade" else Color("ffd35a"))
	draw_rect(Rect2(-18, -22, 36, 44), Color("10243a"), true)
	draw_rect(Rect2(-14, -18, 28, 36), Color("24636a"), true)
	draw_rect(Rect2(-10, -14, 20, 8), accent, true)
	if pickup_kind == &"health":
		draw_rect(Rect2(-4, -4, 8, 18), accent, true)
		draw_rect(Rect2(-9, 1, 18, 8), accent, true)
	elif pickup_kind == &"ammo":
		for index in range(3):
			draw_rect(Rect2(-10 + index * 8, -2, 5, 14), accent, true)
	else:
		draw_rect(Rect2(-7, -5, 14, 14), accent, true)
		draw_rect(Rect2(-3, -10, 6, 6), Color("fff4d2"), true)
