extends Node2D

const Tuning := preload("res://scripts/config/game_tuning.gd")

signal impacted(position: Vector2, color: Color, strength: float)
signal impact_detailed(position: Vector2, color: Color, strength: float, details: Dictionary)

var direction := Vector2.RIGHT
var speed := 1000.0
var damage := 20
var team: StringName = &"player"
var lifetime := 1.6
var tint := Color(1.0, 0.82, 0.28, 1.0)
var weapon_id: StringName = &""
var max_range := 1800.0
var falloff_start := 1800.0
var minimum_damage_multiplier := 1.0
var penetration_remaining := 0
var penetrate_heavy := false
var knockback := Tuning.PLAYER_HIT_KNOCKBACK
var impact_strength := Tuning.NORMAL_HIT_STRENGTH
var spawn_origin := Vector2.ZERO
var distance_travelled := 0.0
var trail_style: StringName = &"rifle"
var source_tag: StringName = &"projectile"
var _excluded_rids: Array[RID] = []
var _penetration_index := 0


func configure(origin: Vector2, shot_direction: Vector2, shot_team: StringName, shot_damage: int, shot_speed: float, options: Dictionary = {}) -> void:
	global_position = origin
	spawn_origin = origin
	direction = shot_direction.normalized()
	team = shot_team
	damage = shot_damage
	speed = shot_speed
	weapon_id = options.get("weapon_id", &"")
	source_tag = options.get("source_tag", weapon_id if weapon_id != &"" else (&"enemy" if team == &"enemy" else &"player"))
	trail_style = weapon_id if weapon_id != &"" else (&"enemy" if team == &"enemy" else &"rifle")
	max_range = float(options.get("max_range", speed * lifetime))
	falloff_start = float(options.get("falloff_start", max_range))
	minimum_damage_multiplier = float(options.get("minimum_damage_multiplier", 1.0))
	penetration_remaining = int(options.get("penetration_count", 0))
	penetrate_heavy = bool(options.get("penetrate_heavy", false))
	knockback = float(options.get("knockback", Tuning.PLAYER_HIT_KNOCKBACK if team == &"player" else Tuning.ENEMY_HIT_KNOCKBACK))
	var default_impact_strength := Tuning.ACCENT_HIT_STRENGTH if team == &"player" and damage >= Tuning.WEAPON_ACCENT_DAMAGE else Tuning.NORMAL_HIT_STRENGTH
	impact_strength = float(options.get("impact_strength", default_impact_strength))
	if team == &"player":
		tint = options.get("color", Color(0.72, 1.0, 0.92, 1.0) if damage >= Tuning.WEAPON_ACCENT_DAMAGE else Color(1.0, 0.82, 0.28, 1.0))
	else:
		tint = Color(1.0, 0.24, 0.18, 1.0)
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	var step_distance := minf(speed * delta, maxf(max_range - distance_travelled, 0.0))
	if step_distance <= 0.0:
		queue_free()
		return
	var segment_end := global_position + direction * step_distance
	var cast_from := global_position
	var casts := 0
	while casts < 8:
		casts += 1
		var hit := _find_segment_hit(cast_from, segment_end)
		if hit.is_empty():
			break
		var raw_collider := hit["collider"] as Node
		var collider := _damage_target_for(raw_collider)
		var can_damage: bool = collider != null and ((team == &"player" and collider.is_in_group("enemies")) or (team == &"enemy" and collider.is_in_group("player")))
		var hit_distance := distance_travelled + global_position.distance_to(hit["position"])
		var hit_normal: Vector2 = hit.get("normal", -direction)
		if hit_normal.length_squared() < 0.01:
			hit_normal = -direction
		else:
			hit_normal = hit_normal.normalized()
		var applied_damage := 0
		var base_damage_at_distance := 0
		var hit_zone: StringName = hit.get("hit_zone", &"body")
		var critical := false
		var damage_result: Dictionary = {}
		if can_damage and collider.has_method("take_damage"):
			base_damage_at_distance = calculate_damage_at_distance(damage, hit_distance, falloff_start, max_range, minimum_damage_multiplier)
			var zone_context := {"direction": direction, "weapon_id": weapon_id}
			if collider.has_method("resolve_hit_zone"):
				hit_zone = collider.resolve_hit_zone(hit_zone, zone_context)
			critical = team == &"player" and hit_zone == &"head" and not collider.is_in_group("boss")
			var requested_damage := int(round(float(base_damage_at_distance) * (Tuning.HEADSHOT_MULTIPLIER if critical else 1.0)))
			var health_before_value = collider.get("health")
			var returned_result = collider.take_damage(requested_damage, direction * knockback, hit["position"], {
				"attacker": self,
				"base_damage": base_damage_at_distance,
				"weapon_id": weapon_id,
				"team": team,
				"direction": direction,
				"hit_normal": hit_normal,
				"impact_strength": impact_strength,
				"source": source_tag,
				"damage_kind": &"projectile",
				"hit_zone": hit_zone,
				"critical": critical,
			})
			if returned_result is Dictionary:
				damage_result = returned_result
				applied_damage = int(damage_result.get("final_damage", 0))
			elif health_before_value != null and collider.get("health") != null:
				applied_damage = maxi(int(health_before_value) - int(collider.get("health")), 0)
		var strength := impact_strength if can_damage else Tuning.TERRAIN_HIT_STRENGTH
		if critical:
			strength = maxf(strength, Tuning.ACCENT_HIT_STRENGTH)
		var impact_color := Color("ffd35a") if critical else tint
		impacted.emit(hit["position"], impact_color, strength)
		var feedback: StringName = &"normal"
		if can_damage and team == &"player":
			var reported_feedback = collider.get("last_hit_feedback")
			if reported_feedback != null:
				feedback = StringName(reported_feedback)
		var target_kind := "terrain"
		if can_damage:
			target_kind = "boss" if collider.is_in_group("boss") else (str(collider.get("kind")) if team == &"player" else "player")
		var blocked := bool(damage_result.get("blocked", false))
		var target_material := _target_material_for(collider, target_kind, blocked)
		var is_lethal := false
		if can_damage:
			if damage_result.has("health_after"):
				is_lethal = int(damage_result.get("health_after", 1)) <= 0
			elif collider.get("alive") != null:
				is_lethal = not bool(collider.get("alive"))
		impact_detailed.emit(hit["position"], impact_color, strength, {
			"target": collider,
			"target_id": collider.get_instance_id() if collider != null else 0,
			"weapon_id": weapon_id,
			"team": team,
			"can_damage": can_damage,
			"is_boss": collider != null and collider.is_in_group("boss"),
			"target_kind": target_kind,
			"distance": hit_distance,
			"max_range": max_range,
			"applied_damage": applied_damage,
			"base_damage": base_damage_at_distance,
			"final_damage": applied_damage,
			"damage_amount": applied_damage,
			"hit_position": hit["position"],
			"hit_normal": hit_normal,
			"hit_zone": hit_zone,
			"critical": critical,
			"headshot": critical,
			"is_headshot": critical,
			"blocked": blocked,
			"mitigation": int(damage_result.get("mitigation", 0)),
			"feedback": feedback,
			"penetration_index": _penetration_index,
			"direction": direction,
			"source_direction": direction,
			"weapon_type": weapon_id,
			"target_material": target_material,
			"is_lethal": is_lethal,
		})
		var blocks_penetration := true
		if can_damage and penetration_remaining > 0:
			var is_heavy := str(collider.get("kind")) in ["heavy", "elite"]
			var is_boss := collider.is_in_group("boss")
			blocks_penetration = is_boss or (is_heavy and not penetrate_heavy)
			if not blocks_penetration and collider is CollisionObject2D:
				penetration_remaining -= 1
				_penetration_index += 1
				_append_target_exclusions(collider)
				cast_from = hit["position"] + direction * 2.0
				continue
		queue_free()
		return
	distance_travelled += step_distance
	global_position = segment_end
	lifetime -= delta
	if lifetime <= 0.0 or distance_travelled >= max_range:
		queue_free()


func _find_segment_hit(cast_from: Vector2, segment_end: Vector2) -> Dictionary:
	var solid_query := PhysicsRayQueryParameters2D.create(cast_from, segment_end)
	solid_query.collision_mask = 5 if team == &"player" else 3
	solid_query.collide_with_areas = false
	solid_query.collide_with_bodies = true
	solid_query.exclude = _excluded_rids
	var solid_hit := get_world_2d().direct_space_state.intersect_ray(solid_query)
	if team != &"player":
		if not solid_hit.is_empty():
			solid_hit["hit_zone"] = &"body"
		return solid_hit
	var head_query := PhysicsRayQueryParameters2D.create(cast_from, segment_end)
	head_query.collision_mask = 16
	head_query.collide_with_areas = true
	head_query.collide_with_bodies = false
	head_query.exclude = _excluded_rids
	var head_hit := get_world_2d().direct_space_state.intersect_ray(head_query)
	if head_hit.is_empty():
		if not solid_hit.is_empty():
			solid_hit["hit_zone"] = &"body"
		return solid_hit
	head_hit["hit_zone"] = &"head"
	if solid_hit.is_empty():
		return head_hit
	var head_target := _damage_target_for(head_hit["collider"] as Node)
	var solid_target := _damage_target_for(solid_hit["collider"] as Node)
	if head_target != null and head_target == solid_target:
		return head_hit
	if cast_from.distance_to(head_hit["position"]) < cast_from.distance_to(solid_hit["position"]):
		return head_hit
	solid_hit["hit_zone"] = &"body"
	return solid_hit


func _damage_target_for(collider: Node) -> Node:
	if collider == null:
		return null
	if collider is Area2D and collider.has_meta("damage_target"):
		var target = collider.get_meta("damage_target")
		if target is Node and is_instance_valid(target):
			return target
	return collider


func _append_target_exclusions(target: Node) -> void:
	if target is CollisionObject2D:
		_excluded_rids.append((target as CollisionObject2D).get_rid())
	var head := target.get_node_or_null("HeadHurtbox")
	if head is CollisionObject2D:
		_excluded_rids.append((head as CollisionObject2D).get_rid())


func _target_material_for(target: Node, target_kind: String, blocked: bool) -> StringName:
	if target == null:
		return &"terrain"
	if blocked:
		return &"shield"
	if target.is_in_group("boss"):
		return &"boss_armor"
	if target_kind in ["elite", "heavy", "shield"]:
		return &"armor"
	if target.is_in_group("player"):
		return &"player"
	return &"trooper"


static func calculate_damage_at_distance(base_damage: int, distance: float, start: float, end: float, minimum_multiplier: float) -> int:
	if distance <= start or end <= start:
		return base_damage
	var ratio := clampf((distance - start) / (end - start), 0.0, 1.0)
	return maxi(int(round(float(base_damage) * lerpf(1.0, minimum_multiplier, ratio))), 1)


func _draw() -> void:
	var glow := Color(tint, 0.24)
	var core := Color(1.0, 1.0, 0.86, 1.0)
	match trail_style:
		&"shotgun":
			draw_rect(Rect2(-10, -3, 16, 6), glow, true)
			draw_rect(Rect2(-5, -2, 12, 4), tint, true)
			draw_rect(Rect2(5, -2, 5, 4), core, true)
		&"sniper":
			draw_rect(Rect2(-86, -3, 96, 6), glow, true)
			draw_rect(Rect2(-62, -1, 74, 2), tint, true)
			draw_rect(Rect2(5, -2, 11, 4), core, true)
		&"pistol":
			draw_rect(Rect2(-15, -1, 20, 2), Color(tint, 0.42), true)
			draw_rect(Rect2(-7, -1, 15, 2), tint, true)
			draw_rect(Rect2(6, -2, 4, 4), core, true)
		&"enemy":
			draw_rect(Rect2(-18, -3, 23, 6), glow, true)
			draw_rect(Rect2(-9, -2, 15, 4), tint, true)
			draw_rect(Rect2(4, -3, 6, 6), core, true)
		_:
			draw_rect(Rect2(-27, -3, 34, 6), glow, true)
			draw_rect(Rect2(-14, -1, 23, 2), tint, true)
			draw_rect(Rect2(6, -2, 6, 4), core, true)
