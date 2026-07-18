extends CharacterBody2D

signal shot_requested(origin: Vector2, direction: Vector2, team: StringName, damage: int, speed: float)
signal hazard_requested(position: Vector2, radius: float, damage: int, windup: float)
signal attack_telegraph_started(enemy: Node, duration: float)
signal attack_executed(enemy: Node, attack_kind: StringName)
signal hurt_feedback(enemy: Node, feedback: StringName)
signal movement_step(enemy: Node, intensity: float)
signal blocked(position: Vector2, strength: float)
signal died(enemy: Node, points: int)
signal damage_resolved(enemy: Node, result: Dictionary)

const GRAVITY := 1800.0
const MAX_FALL_SPEED := 900.0
const Tuning := preload("res://scripts/config/game_tuning.gd")
const EnemyBalanceData := preload("res://scripts/config/enemy_balance.gd")

@export_enum("assault", "gunner", "shield", "elite", "rifle", "runner", "heavy") var kind := "gunner"
var balance_mode: StringName = &"pve"
var balance_wave := 0
var target: CharacterBody2D
var active := true
var activation_x := 0.0
var health := 55
var max_health := 55
var move_speed := 90.0
var attack_cooldown := 0.8
var contact_cooldown := 0.0
var attack_windup_remaining := 0.0
var recovery_remaining := 0.0
var stagger_remaining := 0.0
var guard_open_remaining := 0.0
var alive := true
var state: StringName = &"idle"
var last_hit_feedback: StringName = &"normal"
var last_damage_weapon_id: StringName = &"unknown"
var last_damage_result: Dictionary = {}
var attack_coordinator: Node

var _flash_tween: Tween
var _pending_damage := 0
var _pending_projectile_speed := 0.0
var _telegraph_duration := 0.0
var _pending_attack: StringName = &"projectile"
var _pending_recovery := 0.8
var _attack_cycle := 0
var _facing := 1.0
var _step_distance := 0.0
var _last_step_x := 0.0
var _attack_slot_held := false

@onready var visual = $EnemyVisual
@onready var health_fill: Polygon2D = $HealthBar/Fill
@onready var warning: Node2D = $Warning
@onready var head_hurtbox: Area2D = $HeadHurtbox
@onready var head_shape: CollisionShape2D = $HeadHurtbox/CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	_apply_kind()
	_last_step_x = global_position.x
	_sync_visual(0.0)


func activate() -> void:
	if alive:
		active = true
		state = &"idle"
		visual.reset_visual()
		_sync_visual(0.0)


func _apply_kind() -> void:
	scale = Vector2.ONE
	match kind:
		"assault", "runner":
			move_speed = 175.0
		"shield":
			move_speed = 68.0
		"elite", "heavy":
			move_speed = 52.0
			scale = Vector2(1.28, 1.28)
		_:
			move_speed = 82.0
	max_health = EnemyBalanceData.health_for(kind, balance_mode, balance_wave)
	var head_rectangle := head_shape.shape.duplicate() as RectangleShape2D
	if head_rectangle != null:
		head_rectangle.size = EnemyBalanceData.head_size_for(kind)
		head_shape.shape = head_rectangle
	head_hurtbox.set_meta("hit_zone", &"head")
	head_hurtbox.set_meta("damage_target", self)
	visual.configure(kind)
	health = max_health
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if not alive:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		move_and_slide()
		_sync_visual(delta)
		return
	_tick_timers(delta)
	_apply_gravity(delta)
	if not active or target == null or not is_instance_valid(target) or not bool(target.get("alive")):
		state = &"inactive" if not active else &"idle"
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		_sync_visual(delta)
		return
	if stagger_remaining > 0.0:
		state = &"stagger"
		velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
		move_and_slide()
		_sync_visual(delta)
		return
	if attack_windup_remaining > 0.0:
		_update_telegraph(delta)
		move_and_slide()
		_sync_visual(delta)
		return
	if recovery_remaining > 0.0:
		state = &"recover"
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		_sync_visual(delta)
		return

	var to_target := target.global_position - global_position
	var distance := absf(to_target.x)
	_facing = signf(to_target.x) if not is_zero_approx(to_target.x) else _facing
	visual.set_facing(int(_facing))
	if distance > Tuning.ENEMY_DETECTION_RANGE:
		state = &"idle"
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif kind in ["assault", "runner"]:
		_update_assault(distance)
	elif kind == "shield":
		_update_shield(distance)
	elif kind in ["elite", "heavy"]:
		_update_elite(distance)
	else:
		_update_gunner(distance)
	move_and_slide()
	_sync_visual(delta)


func _sync_visual(delta: float) -> void:
	_update_audio_steps()
	visual.set_facing(int(_facing))
	visual.update_from_logic(
		delta,
		state,
		velocity,
		attack_windup_remaining,
		_telegraph_duration,
		guard_open_remaining,
		stagger_remaining,
		_pending_attack,
		active,
		alive,
	)
	if alive:
		head_hurtbox.position = visual.get_head_local_position()


func _update_audio_steps() -> void:
	var moved := absf(global_position.x - _last_step_x)
	_last_step_x = global_position.x
	if not alive or not active or kind not in ["elite", "heavy"] or state != &"advance" or not is_on_floor():
		_step_distance = 0.0
		return
	_step_distance += moved
	if _step_distance < 76.0:
		return
	_step_distance = fmod(_step_distance, 76.0)
	movement_step.emit(self, clampf(absf(velocity.x) / 80.0, 0.45, 1.0))


func _tick_timers(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	contact_cooldown = maxf(contact_cooldown - delta, 0.0)
	recovery_remaining = maxf(recovery_remaining - delta, 0.0)
	stagger_remaining = maxf(stagger_remaining - delta, 0.0)
	guard_open_remaining = maxf(guard_open_remaining - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0


func _update_assault(distance: float) -> void:
	state = &"pursue"
	velocity.x = _facing * move_speed
	if distance < 94.0 and attack_cooldown <= 0.0:
		_start_melee(17, 0.32, 0.82)


func _update_gunner(distance: float) -> void:
	state = &"reposition"
	if distance < 230.0:
		velocity.x = -_facing * move_speed * 0.72
	elif distance > 410.0:
		velocity.x = _facing * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 / 60.0)
	if distance < Tuning.ENEMY_ATTACK_READABLE_RANGE and attack_cooldown <= 0.0:
		_start_attack(12, 700.0, 0.38, 0.92)


func _update_shield(distance: float) -> void:
	state = &"guard" if guard_open_remaining <= 0.0 else &"opening"
	velocity.x = _facing * move_speed if distance > 105.0 else 0.0
	if distance < 118.0 and attack_cooldown <= 0.0:
		guard_open_remaining = 0.75
		_start_melee(20, 0.46, 1.05)


func _update_elite(distance: float) -> void:
	state = &"advance"
	var enraged := health <= int(float(max_health) * 0.5)
	velocity.x = _facing * move_speed * (1.18 if enraged else 1.0) if distance > 335.0 else 0.0
	if distance < Tuning.ENEMY_ATTACK_READABLE_RANGE and attack_cooldown <= 0.0:
		_attack_cycle += 1
		if _attack_cycle % 2 == 0 and distance < 480.0:
			_start_hazard(92.0, 22, 0.72, 1.2 if not enraged else 0.92)
		else:
			_start_elite_volley(19, 610.0, 0.56, 1.25 if not enraged else 0.96)


func _start_attack(damage: int, projectile_speed: float, windup: float, recovery: float) -> void:
	_begin_attack(&"projectile", damage, projectile_speed, windup, recovery)


func _start_melee(damage: int, windup: float, recovery: float) -> void:
	_begin_attack(&"melee", damage, 0.0, windup, recovery)


func _start_elite_volley(damage: int, projectile_speed: float, windup: float, recovery: float) -> void:
	_begin_attack(&"elite_volley", damage, projectile_speed, windup, recovery)


func _start_hazard(radius: float, damage: int, windup: float, recovery: float) -> void:
	_pending_attack = &"hazard"
	_pending_damage = damage
	_pending_projectile_speed = radius
	_begin_attack(&"hazard", damage, radius, windup, recovery)


func _begin_attack(attack_kind: StringName, damage: int, projectile_speed: float, windup: float, recovery: float) -> void:
	if attack_windup_remaining > 0.0 or not alive or not active:
		return
	var high_risk := damage >= 19 or attack_kind in [&"elite_volley", &"hazard"]
	if attack_coordinator != null and not attack_coordinator.request_attack(self, high_risk):
		attack_cooldown = maxf(attack_cooldown, 0.18)
		return
	_attack_slot_held = true
	_pending_attack = attack_kind
	_pending_damage = damage
	_pending_projectile_speed = projectile_speed
	_pending_recovery = recovery
	_telegraph_duration = windup
	attack_windup_remaining = windup
	attack_cooldown = windup + recovery
	state = &"telegraph"
	warning.visible = true
	warning.scale = Vector2(0.82, 0.82)
	warning.modulate = Color(1.0, 0.72, 0.22, 0.82)
	_sync_visual(0.0)
	attack_telegraph_started.emit(self, windup)


func _update_telegraph(delta: float) -> void:
	state = &"telegraph"
	attack_windup_remaining = maxf(attack_windup_remaining - delta, 0.0)
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	var progress := 1.0 - attack_windup_remaining / maxf(_telegraph_duration, 0.001)
	warning.scale = Vector2.ONE * (0.85 + progress * 0.45 + sin(progress * TAU * 3.0) * 0.08)
	warning.modulate.a = 0.65 + progress * 0.35
	if attack_windup_remaining <= 0.0:
		_finish_attack()


func _finish_attack() -> void:
	warning.visible = false
	if not alive or target == null or not is_instance_valid(target):
		_release_attack_slot()
		return
	visual.play_attack(_pending_attack)
	attack_executed.emit(self, _pending_attack)
	match _pending_attack:
		&"melee":
			if global_position.distance_to(target.global_position) <= 125.0:
				target.take_damage(_pending_damage, Vector2(_facing * 245.0, -110.0), target.global_position, {"source": kind, "damage_kind": &"melee"})
			velocity.x = _facing * 245.0
		&"elite_volley":
			_fire_volley(_pending_damage, _pending_projectile_speed, [-0.11, 0.0, 0.11])
		&"hazard":
			hazard_requested.emit(target.global_position + Vector2(0, 30), _pending_projectile_speed, _pending_damage, 0.62)
		_:
			_fire_at_target(_pending_damage, _pending_projectile_speed)
	_release_attack_slot()
	recovery_remaining = _pending_recovery
	state = &"recover"
	_sync_visual(0.0)


func _fire_at_target(damage: int, projectile_speed: float) -> void:
	_fire_volley(damage, projectile_speed, [0.0])


func _fire_volley(damage: int, projectile_speed: float, offsets: Array) -> void:
	var origin: Vector2 = visual.get_muzzle_global_position()
	var base_direction := (target.global_position + Vector2(0, -8) - origin).normalized()
	for offset in offsets:
		shot_requested.emit(origin, base_direction.rotated(float(offset)), &"enemy", damage, projectile_speed)


func resolve_hit_zone(requested_zone: StringName, context: Dictionary = {}) -> StringName:
	if requested_zone != &"head":
		return &"body"
	# A closed shield visually covers the frontal head line. Breaking or moving
	# around the guard exposes the ordinary head multiplier again.
	if kind == "shield" and guard_open_remaining <= 0.0 and _is_front_hit(context):
		return &"body"
	return &"head"


func take_damage(amount: int, impulse: Vector2 = Vector2.ZERO, hit_position: Vector2 = Vector2.ZERO, context: Dictionary = {}) -> Dictionary:
	if not alive:
		return {}
	last_damage_weapon_id = context.get("weapon_id", &"unknown")
	last_hit_feedback = &"normal"
	var requested_zone: StringName = context.get("hit_zone", &"body")
	var hit_zone := resolve_hit_zone(requested_zone, context)
	var headshot := bool(context.get("critical", false)) and hit_zone == &"head"
	var health_before := health
	var applied_damage := amount
	var was_blocked := false
	if kind == "shield" and guard_open_remaining <= 0.0 and _is_front_hit(context):
		was_blocked = true
		var weapon_id: StringName = context.get("weapon_id", &"rifle")
		var multiplier := 0.24
		if weapon_id == &"pistol":
			multiplier = 0.42
		elif weapon_id == &"shotgun":
			multiplier = 0.72
			guard_open_remaining = 0.72
			stagger_remaining = 0.18
			last_hit_feedback = &"guard_break"
		elif weapon_id == &"sniper":
			multiplier = 0.82
			guard_open_remaining = 1.1
			stagger_remaining = 0.34
			last_hit_feedback = &"guard_break"
		elif weapon_id == &"grenade":
			multiplier = 0.78
			guard_open_remaining = 1.0
			stagger_remaining = 0.30
			last_hit_feedback = &"guard_break"
		else:
			last_hit_feedback = &"block"
		applied_damage = maxi(int(round(float(amount) * multiplier)), 1)
		impulse *= multiplier
		visual.play_block(1.0 if weapon_id in [&"shotgun", &"sniper"] else 0.55)
		blocked.emit(hit_position, 1.0 if weapon_id in [&"shotgun", &"sniper"] else 0.55)
	if kind in ["elite", "heavy"] and context.get("weapon_id", &"") in [&"shotgun", &"sniper", &"grenade"]:
		stagger_remaining = maxf(stagger_remaining, 0.14)
		last_hit_feedback = &"heavy"
	elif not was_blocked and context.get("weapon_id", &"") == &"sniper":
		last_hit_feedback = &"heavy"
	elif headshot:
		last_hit_feedback = &"headshot"
	health = maxi(health - applied_damage, 0)
	var final_damage := health_before - health
	var source_direction: Vector2 = context.get("direction", Vector2.ZERO)
	var target_material := get_target_material(was_blocked)
	var is_lethal := health <= 0
	velocity += impulse
	_update_health_bar()
	if not was_blocked:
		visual.play_hit_reaction(last_damage_weapon_id, target_material, headshot, is_lethal, source_direction)
		hurt_feedback.emit(self, last_hit_feedback)
	_sync_visual(0.0)
	last_damage_result = {
		"attacker": context.get("attacker"),
		"target": self,
		"base_damage": int(context.get("base_damage", amount)),
		"requested_damage": amount,
		"final_damage": final_damage,
		"damage_amount": final_damage,
		"hit_position": hit_position,
		"hit_normal": context.get("hit_normal", -source_direction.normalized() if source_direction.length_squared() > 0.01 else Vector2.UP),
		"hit_zone": hit_zone,
		"damage_type": context.get("damage_kind", &"unknown"),
		"weapon_id": last_damage_weapon_id,
		"weapon_type": last_damage_weapon_id,
		"blocked": was_blocked,
		"critical": headshot,
		"headshot": headshot,
		"is_headshot": headshot,
		"source_direction": source_direction,
		"target_material": target_material,
		"is_lethal": is_lethal,
		"mitigation": maxi(amount - applied_damage, 0),
		"health_before": health_before,
		"health_after": health,
	}
	damage_resolved.emit(self, last_damage_result.duplicate(true))
	if health <= 0:
		last_hit_feedback = &"kill"
		_die()
	return last_damage_result.duplicate(true)


func get_debug_combat_snapshot() -> Dictionary:
	return {
		"kind": kind,
		"health": health,
		"max_health": max_health,
		"head_position": head_hurtbox.global_position,
		"head_size": (head_shape.shape as RectangleShape2D).size,
		"last_damage": last_damage_result.duplicate(true),
	}


func _is_front_hit(context: Dictionary) -> bool:
	var incoming: Vector2 = context.get("direction", Vector2.ZERO)
	if absf(incoming.x) < 0.01:
		return true
	return signf(incoming.x) == -signf(_facing)


func _update_health_bar() -> void:
	var ratio := float(health) / float(maxi(max_health, 1))
	health_fill.scale.x = ratio
	$HealthBar.visible = health < max_health and alive


func _flash_white() -> void:
	visual.play_hit_reaction(last_damage_weapon_id, get_target_material(false), false, false, Vector2(_facing, 0.0))


func get_target_material(blocked_hit: bool = false) -> StringName:
	if blocked_hit:
		return &"shield"
	if kind in ["elite", "heavy", "shield"]:
		return &"armor"
	return &"trooper"


func _die() -> void:
	if not alive:
		return
	alive = false
	_release_attack_slot()
	active = false
	state = &"dead"
	attack_windup_remaining = 0.0
	recovery_remaining = 0.0
	warning.visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	head_hurtbox.collision_layer = 0
	$HealthBar.visible = false
	visual.set_facing(int(signf(velocity.x)) if not is_zero_approx(velocity.x) else int(_facing))
	visual.play_death(
		StringName(last_damage_result.get("weapon_id", &"unknown")),
		bool(last_damage_result.get("headshot", false)),
		Vector2(last_damage_result.get("source_direction", Vector2.ZERO)),
		StringName(last_damage_result.get("target_material", get_target_material(false))),
	)
	var points := 500 if kind in ["elite", "heavy"] else (180 if kind == "shield" else (150 if kind in ["assault", "runner"] else 100))
	died.emit(self, points)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)


func _release_attack_slot() -> void:
	if not _attack_slot_held:
		return
	_attack_slot_held = false
	if attack_coordinator != null:
		attack_coordinator.release_attack(self)
