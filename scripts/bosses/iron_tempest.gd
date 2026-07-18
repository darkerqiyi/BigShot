extends CharacterBody2D

signal shot_requested(origin: Vector2, direction: Vector2, team: StringName, damage: int, speed: float)
signal hazard_requested(position: Vector2, radius: float, damage: int, windup: float)
signal summon_requested(position: Vector2, kind: String)
signal attack_telegraph_started(attack_name: StringName, duration: float)
signal attack_executed(attack_name: StringName)
signal health_changed(current: int, maximum: int, phase: int)
signal phase_changed(phase: int)
signal died(boss: Node)

const MAX_HEALTH := 1200
const GRAVITY := 1800.0
const MAX_FALL_SPEED := 900.0
@export var boss_name := "THE IRON TEMPEST"
@export var arena_left := 17855.0
@export var arena_right := 19900.0
@export var phase_two_summon_positions := PackedVector2Array([
	Vector2(3570.0, 552.0),
	Vector2(4140.0, 552.0),
])
var target: CharacterBody2D
var health := MAX_HEALTH
var phase := 1
var active := false
var alive := true
var state: StringName = &"inactive"
var invulnerable := false
var attack_cooldown := 0.0
var windup_remaining := 0.0
var recovery_remaining := 0.0
var transition_remaining := 0.0
var charge_remaining := 0.0
var last_hit_feedback: StringName = &"boss_normal"
var last_damage_result: Dictionary = {}

var _pending_attack: StringName = &""
var _last_attack: StringName = &""
var _attack_index := 0
var _telegraph_duration := 0.0
var _charge_direction := 1.0
var _charge_hit := false
@onready var visual: IronTempestVisual = $Visual
@onready var body_shape: CanvasItem = $Visual/MainBody
@onready var core: CanvasItem = $Visual/Core
@onready var warning: Node2D = $Warning


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	visual.reset_visual()
	visible = false
	collision_layer = 0
	health_changed.emit(health, MAX_HEALTH, phase)


func activate(player_target: CharacterBody2D) -> void:
	target = player_target
	health = MAX_HEALTH
	phase = 1
	active = true
	alive = true
	invulnerable = false
	state = &"recover"
	recovery_remaining = 0.9
	attack_cooldown = 0.35
	visible = true
	modulate = Color.WHITE
	visual.reset_visual()
	visual.start_intro(0.9)
	collision_layer = 4
	collision_mask = 3
	health_changed.emit(health, MAX_HEALTH, phase)


func _physics_process(delta: float) -> void:
	if not active or not alive:
		return
	_apply_gravity(delta)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if transition_remaining > 0.0:
		_update_transition(delta)
		move_and_slide()
		return
	if windup_remaining > 0.0:
		_update_telegraph(delta)
		move_and_slide()
		return
	if charge_remaining > 0.0:
		_update_charge(delta)
		move_and_slide()
		global_position.x = clampf(global_position.x, arena_left, arena_right)
		return
	if recovery_remaining > 0.0:
		recovery_remaining = maxf(recovery_remaining - delta, 0.0)
		state = &"recover"
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
		move_and_slide()
		return
	if target == null or not is_instance_valid(target) or not bool(target.get("alive")):
		state = &"idle"
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		return
	if attack_cooldown <= 0.0:
		_select_attack()
	else:
		state = &"idle"
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0


func _select_attack() -> void:
	var distance := absf(target.global_position.x - global_position.x)
	var options: Array = []
	if phase == 1:
		options = [&"volley", &"charge"] if distance > 260.0 else [&"charge", &"volley"]
	elif phase == 2:
		options = [&"area", &"volley", &"charge"]
	else:
		options = [&"volley", &"area", &"charge"]
	var selected: StringName = options[_attack_index % options.size()]
	_attack_index += 1
	if selected == _last_attack and options.size() > 1:
		selected = options[_attack_index % options.size()]
		_attack_index += 1
	_last_attack = selected
	match selected:
		&"charge":
			_begin_attack(selected, 0.72 if phase == 1 else 0.62)
		&"area":
			_begin_attack(selected, 0.78 if phase == 2 else 0.66)
		_:
			_begin_attack(selected, 0.52 if phase < 3 else 0.42)


func _begin_attack(attack_name: StringName, duration: float) -> void:
	_pending_attack = attack_name
	windup_remaining = duration
	_telegraph_duration = duration
	state = &"telegraph"
	velocity.x = 0.0
	warning.visible = true
	warning.modulate = Color(1.0, 0.25, 0.08, 0.9)
	warning.scale = Vector2(0.8, 0.8)
	attack_telegraph_started.emit(attack_name, duration)


func _update_telegraph(delta: float) -> void:
	windup_remaining = maxf(windup_remaining - delta, 0.0)
	var progress := 1.0 - windup_remaining / maxf(_telegraph_duration, 0.001)
	warning.scale = Vector2.ONE * (0.8 + progress * 0.85 + sin(progress * TAU * 4.0) * 0.08)
	if windup_remaining <= 0.0:
		warning.visible = false
		_execute_attack()


func _execute_attack() -> void:
	visual.play_attack(_pending_attack)
	attack_executed.emit(_pending_attack)
	match _pending_attack:
		&"charge":
			_charge_direction = signf(target.global_position.x - global_position.x)
			charge_remaining = 0.52
			_charge_hit = false
			state = &"charge"
		&"area":
			var base := target.global_position + Vector2(0, 30)
			var positions := [base, base + Vector2(-145, 0), base + Vector2(145, 0)]
			var count := 2 if phase == 2 else 3
			for index in range(count):
				hazard_requested.emit(positions[index], 76.0, 24 if phase == 2 else 28, 0.72)
			_finish_attack(0.95 if phase == 2 else 0.72)
		_:
			_fire_volley()
			_finish_attack(0.82 if phase < 3 else 0.62)


func _fire_volley() -> void:
	var fire_direction := signf(target.global_position.x - global_position.x)
	var origin := visual.get_muzzle_global_position(fire_direction)
	var base_direction := (target.global_position + Vector2(0, -10) - origin).normalized()
	var offsets := [-0.12, 0.0, 0.12] if phase < 3 else [-0.18, -0.09, 0.0, 0.09, 0.18]
	for offset in offsets:
		shot_requested.emit(origin, base_direction.rotated(float(offset)), &"enemy", 15 if phase == 1 else 18, 650.0 if phase < 3 else 720.0)


func _update_charge(delta: float) -> void:
	charge_remaining = maxf(charge_remaining - delta, 0.0)
	velocity.x = _charge_direction * (390.0 if phase == 1 else 445.0)
	if not _charge_hit and target != null and global_position.distance_to(target.global_position) < 92.0:
		_charge_hit = true
		target.take_damage(26 if phase < 3 else 30, Vector2(_charge_direction * 320.0, -160.0), target.global_position, {"source": &"boss", "damage_kind": &"charge"})
	if charge_remaining <= 0.0 or global_position.x <= arena_left + 8.0 or global_position.x >= arena_right - 8.0:
		charge_remaining = 0.0
		_finish_attack(0.92 if phase < 3 else 0.7)


func _finish_attack(recovery: float) -> void:
	state = &"recover"
	recovery_remaining = recovery
	attack_cooldown = 0.38 if phase < 3 else 0.26
	velocity.x = 0.0


func take_damage(amount: int, impulse: Vector2 = Vector2.ZERO, hit_position: Vector2 = Vector2.ZERO, context: Dictionary = {}) -> Dictionary:
	if not alive or not active or invulnerable:
		return {}
	var health_before := health
	health = maxi(health - amount, 0)
	velocity += impulse * 0.12
	var weapon_id: StringName = context.get("weapon_id", &"")
	var heavy_hit := weapon_id in [&"shotgun", &"sniper", &"grenade"] or float(context.get("impact_strength", 0.0)) >= 0.8
	last_hit_feedback = &"boss_heavy" if heavy_hit else &"boss_normal"
	_flash_white(heavy_hit, hit_position)
	var next_phase := 3 if health <= int(MAX_HEALTH * 0.30) else (2 if health <= int(MAX_HEALTH * 0.65) else 1)
	var source_direction: Vector2 = context.get("direction", Vector2.ZERO)
	last_damage_result = {
		"attacker": context.get("attacker"),
		"target": self,
		"base_damage": int(context.get("base_damage", amount)),
		"requested_damage": amount,
		"final_damage": health_before - health,
		"damage_amount": health_before - health,
		"hit_position": hit_position,
		"hit_normal": context.get("hit_normal", -source_direction.normalized() if source_direction.length_squared() > 0.01 else Vector2.UP),
		"hit_zone": &"core" if bool(context.get("core_hit", false)) else &"armor",
		"damage_type": context.get("damage_kind", &"unknown"),
		"weapon_id": weapon_id,
		"weapon_type": weapon_id,
		"blocked": false,
		"critical": false,
		"headshot": false,
		"is_headshot": false,
		"source_direction": source_direction,
		"target_material": &"boss_armor",
		"is_lethal": health <= 0,
		"mitigation": 0,
		"health_before": health_before,
		"health_after": health,
	}
	health_changed.emit(health, MAX_HEALTH, next_phase)
	if health <= 0:
		last_hit_feedback = &"kill"
		_die()
	elif next_phase > phase:
		_begin_phase_transition(next_phase)
	return last_damage_result.duplicate(true)


func _begin_phase_transition(next_phase: int) -> void:
	phase = next_phase
	invulnerable = true
	transition_remaining = 0.85
	windup_remaining = 0.0
	charge_remaining = 0.0
	recovery_remaining = 0.0
	state = &"transition"
	warning.visible = false
	phase_changed.emit(phase)
	if phase == 2:
		for index in range(mini(phase_two_summon_positions.size(), 2)):
			summon_requested.emit(phase_two_summon_positions[index], "assault" if index == 0 else "gunner")


func _update_transition(delta: float) -> void:
	transition_remaining = maxf(transition_remaining - delta, 0.0)
	velocity.x = 0.0
	if transition_remaining <= 0.0:
		invulnerable = false
		_finish_attack(0.7)


func _flash_white(heavy: bool = false, hit_position: Vector2 = Vector2.ZERO) -> void:
	# Keep feedback local to the layered visual so automatic fire never flashes
	# or shakes the entire Boss body.
	visual.play_hurt(heavy, hit_position)


func _die() -> void:
	if not alive:
		return
	alive = false
	active = false
	state = &"dead"
	invulnerable = true
	windup_remaining = 0.0
	charge_remaining = 0.0
	transition_remaining = 0.0
	recovery_remaining = 0.0
	warning.visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	visual.play_death()
	died.emit(self)
