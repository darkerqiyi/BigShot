extends Node2D
class_name IronTempestVisual

const INTRO_DURATION := 0.90
const DEATH_DURATION := 0.82

@onready var main_body: CanvasItem = $MainBody
@onready var core: CanvasItem = $Core
@onready var left_muzzle: Marker2D = $MuzzlePoints/LeftMuzzle
@onready var right_muzzle: Marker2D = $MuzzlePoints/RightMuzzle

var phase_visual := 1
var facing := 1
var animation_state: StringName = &"inactive"
var attack_kind: StringName = &""
var telegraph_progress := 0.0
var transition_progress := 0.0
var intro_remaining := 0.0
var attack_fx_remaining := 0.0
var hurt_remaining := 0.0
var heavy_hurt := false
var hit_local := Vector2.ZERO
var death_elapsed := -1.0
var animation_time := 0.0
var pose_offset := Vector2.ZERO
var recoil_offset := 0.0
var body_compression := 0.0

var _layers: Array[CanvasItem] = []


func _ready() -> void:
	_layers = [
		$Shadow,
		$LowerBody,
		$MainBody,
		$ArmorFront,
		$Core,
		$LeftWeapon,
		$RightWeapon,
		$DamageEffects,
		$GroundContactEffects,
	]
	reset_visual()


func reset_visual() -> void:
	phase_visual = 1
	facing = 1
	animation_state = &"inactive"
	attack_kind = &""
	telegraph_progress = 0.0
	transition_progress = 0.0
	intro_remaining = 0.0
	attack_fx_remaining = 0.0
	hurt_remaining = 0.0
	heavy_hurt = false
	hit_local = Vector2.ZERO
	death_elapsed = -1.0
	animation_time = 0.0
	pose_offset = Vector2.ZERO
	recoil_offset = 0.0
	body_compression = 0.0
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = true
	_queue_layers()


func start_intro(duration: float = INTRO_DURATION) -> void:
	intro_remaining = maxf(duration, 0.01)
	animation_state = &"intro"
	_queue_layers()


func play_attack(kind: StringName) -> void:
	attack_kind = kind
	attack_fx_remaining = 0.22 if kind == &"charge" else (0.18 if kind == &"area" else 0.15)
	_queue_layers()


func play_hurt(is_heavy: bool, world_hit_position: Vector2) -> void:
	if death_elapsed >= 0.0:
		return
	heavy_hurt = is_heavy
	hurt_remaining = maxf(hurt_remaining, 0.10 if is_heavy else 0.055)
	var local_hit := to_local(world_hit_position)
	if world_hit_position == Vector2.ZERO or local_hit.length() > 180.0:
		local_hit = Vector2(14 * facing, -10)
	hit_local = Vector2(clampf(local_hit.x, -52.0, 52.0), clampf(local_hit.y, -68.0, 48.0))
	_queue_layers()


func play_death() -> void:
	if death_elapsed >= 0.0:
		return
	death_elapsed = 0.0
	animation_state = &"death"
	attack_fx_remaining = 0.0
	hurt_remaining = 0.0
	telegraph_progress = 0.0
	_queue_layers()


func get_muzzle_global_position(direction: float) -> Vector2:
	return right_muzzle.global_position if direction >= 0.0 else left_muzzle.global_position


func get_visual_contract() -> Dictionary:
	return {
		"phase": phase_visual,
		"state": animation_state,
		"attack": attack_kind,
		"facing": facing,
		"left_muzzle": left_muzzle.position,
		"right_muzzle": right_muzzle.position,
		"layer_count": _layers.size(),
		"death_elapsed": death_elapsed,
	}


func _process(delta: float) -> void:
	animation_time += delta
	attack_fx_remaining = maxf(attack_fx_remaining - delta, 0.0)
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	if death_elapsed >= 0.0:
		death_elapsed += delta
		animation_state = &"death"
		_update_death_pose()
		_queue_layers()
		return

	var boss := get_parent()
	if boss == null:
		return
	phase_visual = int(boss.get("phase"))
	var logic_state := StringName(boss.get("state"))
	var target_node := boss.get("target") as Node2D
	if target_node != null and is_instance_valid(target_node):
		var horizontal: float = target_node.global_position.x - boss.global_position.x
		if absf(horizontal) > 2.0:
			facing = 1 if horizontal >= 0.0 else -1
	attack_kind = StringName(boss.get("_pending_attack"))

	if intro_remaining > 0.0:
		intro_remaining = maxf(intro_remaining - delta, 0.0)
		animation_state = &"intro"
	else:
		animation_state = _map_logic_state(logic_state)

	var windup := float(boss.get("windup_remaining"))
	var windup_total := maxf(float(boss.get("_telegraph_duration")), 0.001)
	telegraph_progress = 1.0 - windup / windup_total if windup > 0.0 else 0.0
	var transition := float(boss.get("transition_remaining"))
	transition_progress = 1.0 - transition / 0.85 if transition > 0.0 else 0.0
	_update_pose()
	_queue_layers()


func _map_logic_state(logic_state: StringName) -> StringName:
	match logic_state:
		&"telegraph":
			return StringName("%s_telegraph" % attack_kind)
		&"charge":
			return &"charge_active"
		&"transition":
			return &"transition"
		&"recover":
			return &"recover"
		&"idle":
			return &"idle"
		&"dead":
			return &"death"
		_:
			return logic_state


func _update_pose() -> void:
	pose_offset = Vector2.ZERO
	recoil_offset = 0.0
	body_compression = 0.0
	if animation_state == &"intro":
		var intro_progress := 1.0 - intro_remaining / INTRO_DURATION
		pose_offset.y = roundf(-26.0 * (1.0 - clampf(intro_progress, 0.0, 1.0)))
		body_compression = 3.0 * maxf(0.0, sin(intro_progress * PI))
	elif animation_state == &"idle":
		pose_offset.y = roundf(sin(animation_time * 2.2))
	elif animation_state == &"recover":
		body_compression = 2.0
	elif animation_state == &"charge_telegraph":
		pose_offset.x = roundf(-5.0 * facing * telegraph_progress)
		pose_offset.y = roundf(4.0 * telegraph_progress)
		body_compression = 4.0 * telegraph_progress
	elif animation_state == &"volley_telegraph":
		recoil_offset = -3.0 * telegraph_progress
	elif animation_state == &"area_telegraph":
		pose_offset.y = roundf(3.0 * telegraph_progress)
	elif animation_state == &"charge_active":
		pose_offset.x = roundf(5.0 * facing)
		pose_offset.y = 3.0
	elif animation_state == &"transition":
		body_compression = (7.0 if phase_visual == 3 else 4.0) * sin(clampf(transition_progress, 0.0, 1.0) * PI)
		pose_offset.y = roundf(body_compression)
	if attack_fx_remaining > 0.0 and attack_kind == &"volley":
		recoil_offset = -6.0 * attack_fx_remaining / 0.15


func _update_death_pose() -> void:
	var progress := clampf(death_elapsed / DEATH_DURATION, 0.0, 1.0)
	pose_offset.y = roundf(9.0 * progress)
	body_compression = roundf(12.0 * progress)
	rotation = sin(progress * PI) * 0.035 * facing
	if progress >= 1.0:
		visible = false


func _queue_layers() -> void:
	for layer in _layers:
		if is_instance_valid(layer):
			layer.queue_redraw()
