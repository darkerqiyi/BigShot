extends Camera2D

const Tuning := preload("res://scripts/config/game_tuning.gd")

@export var target_path: NodePath
@export var level_width := 20000.0
@export var fixed_y := 360.0

@onready var target: CharacterBody2D = get_node_or_null(target_path) as CharacterBody2D

var trauma := 0.0
var _shake_seed := 0.0
var _recoil_offset := Vector2.ZERO
var _look_ahead := 0.0


func _ready() -> void:
	position = Vector2(640.0, fixed_y)
	position_smoothing_enabled = false


func _physics_process(delta: float) -> void:
	if target != null:
		var target_aim: Vector2 = target.get("aim_direction")
		var aim_bonus: float = float(target.get("weapon_camera_aim_bonus"))
		var target_sprinting := bool(target.get("is_sprinting"))
		var desired_look_ahead := calculate_desired_look_ahead(target.velocity.x, target_aim.x, aim_bonus, target_sprinting)
		_look_ahead = smooth_look_ahead(_look_ahead, desired_look_ahead, delta)
		var desired_x := clampf(target.global_position.x + _look_ahead, 640.0, level_width - 640.0)
		global_position.x = roundf(lerpf(global_position.x, desired_x, 1.0 - exp(-delta * Tuning.CAMERA_FOLLOW_RESPONSE)))
		global_position.y = fixed_y
	trauma = maxf(trauma - delta * Tuning.CAMERA_SHAKE_DECAY, 0.0)
	_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, 1.0 - exp(-delta * Tuning.CAMERA_RECOIL_DECAY))
	_shake_seed += delta * 48.0
	var strength := trauma * trauma
	var shake_offset := Vector2(sin(_shake_seed * 1.7), cos(_shake_seed * 2.3)) * Tuning.CAMERA_SHAKE_PIXELS * strength
	var composed_offset := shake_offset + _recoil_offset
	offset = Vector2(roundf(composed_offset.x), roundf(composed_offset.y))


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func add_trauma_limited(amount: float, maximum: float) -> void:
	var cap := clampf(maximum, 0.0, 1.0)
	trauma = minf(trauma + maxf(amount, 0.0), cap)


func add_recoil(direction: Vector2, magnitude: float) -> void:
	_recoil_offset -= direction.normalized() * magnitude
	if _recoil_offset.length() > 5.0:
		_recoil_offset = _recoil_offset.normalized() * 5.0


func clear_feedback() -> void:
	trauma = 0.0
	_recoil_offset = Vector2.ZERO
	offset = Vector2.ZERO


static func calculate_desired_look_ahead(velocity_x: float, aim_x: float, aim_bonus: float = 0.0, sprinting: bool = false) -> float:
	var movement_look := clampf(
		velocity_x * Tuning.CAMERA_VELOCITY_LOOK_FACTOR,
		-Tuning.CAMERA_MOVEMENT_LOOK_LIMIT,
		Tuning.CAMERA_MOVEMENT_LOOK_LIMIT,
	)
	var aim_look := clampf(aim_x, -1.0, 1.0) * (Tuning.CAMERA_AIM_LOOK_PIXELS + aim_bonus)
	var sprint_look := signf(velocity_x) * Tuning.CAMERA_SPRINT_LOOK_AHEAD if sprinting and absf(velocity_x) > Tuning.PLAYER_MAX_SPEED else 0.0
	var limit := Tuning.CAMERA_MAX_LOOK_AHEAD + aim_bonus + (Tuning.CAMERA_SPRINT_LOOK_AHEAD if sprinting else 0.0)
	return clampf(movement_look + aim_look + sprint_look, -limit, limit)


static func smooth_look_ahead(current: float, target_value: float, delta: float) -> float:
	return lerpf(current, target_value, 1.0 - exp(-delta * Tuning.CAMERA_LOOK_RESPONSE))
