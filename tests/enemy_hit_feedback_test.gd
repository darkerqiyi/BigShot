extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const ProjectileScene := preload("res://scenes/combat/projectile.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")
const EnemyBalance := preload("res://scripts/config/enemy_balance.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await physics_frame
	_test_balance_contract()
	_test_weapon_visual_reactions(game)
	_test_material_and_death_contract(game)
	await _test_canonical_projectile_event(game)
	_test_weapon_impact_signatures(game)
	_test_impact_pool_and_priority(game)
	game.queue_free()
	await process_frame
	_finish()


func _test_balance_contract() -> void:
	_expect([WeaponData.get_weapon(&"rifle").damage, WeaponData.get_weapon(&"shotgun").damage, WeaponData.get_weapon(&"sniper").damage, WeaponData.get_weapon(&"pistol").damage] == [24, 17, 92, 32], "hit feedback changed weapon damage")
	_expect([WeaponData.get_weapon(&"rifle").fire_rate, WeaponData.get_weapon(&"shotgun").fire_rate, WeaponData.get_weapon(&"sniper").fire_rate, WeaponData.get_weapon(&"pistol").fire_rate] == [0.085, 0.62, 1.0, 0.23], "hit feedback changed weapon fire rates")
	_expect(EnemyBalance.SURVIVAL_HEALTH == {"assault": 192, "gunner": 216, "shield": 288, "elite": 1200}, "hit feedback changed survival health")


func _test_weapon_visual_reactions(game: Node) -> void:
	var enemy: Node = game._spawn_enemy("assault", game.player.global_position + Vector2(260, 0), 99999.0, false, false)
	enemy.set_physics_process(false)
	var durations: Dictionary = {}
	var offsets: Dictionary = {}
	for weapon_id in [&"rifle", &"pistol", &"shotgun", &"sniper"]:
		enemy.take_damage(1, Vector2.ZERO, enemy.global_position, {"weapon_id": weapon_id, "direction": Vector2.RIGHT, "hit_zone": &"body"})
		durations[weapon_id] = enemy.visual.hit_reaction_duration
		offsets[weapon_id] = absf(enemy.visual.hit_pose_offset.x)
		enemy.visual.hurt_remaining = 0.0
	_expect(is_equal_approx(float(durations[&"rifle"]), 0.055), "rifle reaction is not the requested 40-60ms short flash")
	_expect(float(durations[&"pistol"]) > float(durations[&"rifle"]), "pistol reaction is not stronger than a rifle round")
	_expect(float(durations[&"shotgun"]) > float(durations[&"pistol"]) and float(offsets[&"shotgun"]) > float(offsets[&"pistol"]), "shotgun lacks heavier visual-only recoil")
	_expect(float(durations[&"sniper"]) > float(durations[&"shotgun"]) and float(offsets[&"sniper"]) > float(offsets[&"shotgun"]), "sniper is not the strongest local hit reaction")
	_expect(enemy.visual.hit_material == &"trooper", "ordinary enemy did not select trooper material feedback")


func _test_material_and_death_contract(game: Node) -> void:
	var shield: Node = game._spawn_enemy("shield", game.player.global_position + Vector2(390, 0), 99999.0, false, false)
	shield.set_physics_process(false)
	shield._facing = -1.0
	shield.visual.set_facing(-1)
	var blocked_result: Dictionary = shield.take_damage(24, Vector2.RIGHT * 10.0, shield.global_position, {"weapon_id": &"rifle", "direction": Vector2.RIGHT, "hit_zone": &"body"})
	_expect(blocked_result.get("target_material") == &"shield" and bool(blocked_result.get("blocked", false)), "shield block did not use shield material or preserve block result")
	_expect(shield.visual.animation_state == &"block", "shield block incorrectly played a body hurt reaction")
	var elite: Node = game._spawn_enemy("elite", game.player.global_position + Vector2(520, 0), 99999.0, false, false)
	elite.set_physics_process(false)
	var elite_result: Dictionary = elite.take_damage(1, Vector2.ZERO, elite.global_position, {"weapon_id": &"sniper", "direction": Vector2.RIGHT, "hit_zone": &"body"})
	_expect(elite_result.get("target_material") == &"armor" and elite.visual.hit_material == &"armor", "elite did not select restrained armor feedback")
	var victim: Node = game._spawn_enemy("assault", game.player.global_position + Vector2(650, 0), 99999.0, false, false)
	victim.set_physics_process(false)
	var death_count := [0]
	victim.died.connect(func(_enemy: Node, _points: int) -> void: death_count[0] += 1)
	var lethal_result: Dictionary = victim.take_damage(9999, Vector2.ZERO, victim.global_position + Vector2(0, -21), {"weapon_id": &"shotgun", "direction": Vector2.RIGHT, "hit_zone": &"head", "critical": true})
	var duplicate_result: Dictionary = victim.take_damage(9999)
	_expect(bool(lethal_result.get("is_lethal", false)) and bool(lethal_result.get("is_headshot", false)), "lethal headshot result lost canonical flags")
	_expect(death_count[0] == 1 and duplicate_result.is_empty(), "same-frame lethal hits could repeat death or score")
	_expect(not victim.is_physics_processing() and victim.collision_layer == 0 and victim.head_hurtbox.collision_layer == 0, "dead enemy retained AI or hurtboxes")
	_expect(victim.visual.dead and victim.visual.animation_state == &"death", "hurt feedback interrupted the death state")


func _test_canonical_projectile_event(game: Node) -> void:
	var enemy: Node = game._spawn_enemy("gunner", game.player.global_position + Vector2(780, 0), 99999.0, false, false)
	enemy.set_physics_process(false)
	var captured: Array[Dictionary] = []
	var projectile := ProjectileScene.instantiate()
	game.projectiles.add_child(projectile)
	projectile.impact_detailed.connect(func(_position: Vector2, _color: Color, _strength: float, details: Dictionary) -> void: captured.append(details.duplicate(true)))
	projectile.configure(enemy.global_position - Vector2(140, 0), Vector2.RIGHT, &"player", 1, 1800.0, {"weapon_id": &"rifle", "max_range": 320.0})
	for _frame in range(8):
		await physics_frame
		if not captured.is_empty():
			break
	_expect(captured.size() == 1, "one projectile did not emit exactly one unified hit event")
	if captured.is_empty():
		return
	var event := captured[0]
	for field in ["hit_position", "hit_normal", "damage_amount", "is_headshot", "weapon_type", "target_material", "is_lethal"]:
		_expect(event.has(field), "unified hit event is missing %s" % field)
	_expect(event.get("weapon_type") == &"rifle" and event.get("target_material") == &"trooper", "unified hit event misclassified weapon or material")
	_expect(Vector2(event.get("hit_position", Vector2.ZERO)).distance_to(enemy.global_position) < 32.0, "hit feedback did not use the actual collision point")


func _test_impact_pool_and_priority(game: Node) -> void:
	game.impact_effects.clear_all()
	var target_id := 777
	var accepted_shotgun := 0
	for index in range(7):
		if game.impact_effects.spawn_effect(Vector2(300 + index * 2, 300), Color.ORANGE, 0.8, false, &"shotgun_hit", Vector2.RIGHT, 0.0, {"target_id": target_id, "target_material": &"trooper"}):
			accepted_shotgun += 1
	_expect(accepted_shotgun == 4, "shotgun pellet visuals exceeded the per-target frame cap")
	for index in range(80):
		game.impact_effects.spawn_effect(Vector2(400 + index, 320), Color.WHITE, 0.5, false, &"rifle_hit", Vector2.RIGHT, 0.0, {"target_id": 1000 + index, "target_material": &"trooper"})
	var before_headshot: Dictionary = game.impact_effects.get_debug_snapshot()
	var preserved_headshot: bool = game.impact_effects.spawn_effect(Vector2(500, 280), Color("ffd35a"), 1.0, false, &"headshot", Vector2.RIGHT, 0.0, {"target_id": 9999, "target_material": &"armor", "is_headshot": true})
	var after_headshot: Dictionary = game.impact_effects.get_debug_snapshot()
	_expect(int(before_headshot["active"]) <= 40 and int(after_headshot["active"]) <= 40, "impact pool exceeded the active effect budget")
	_expect(preserved_headshot, "high-priority headshot visual was dropped under rifle pressure")
	_expect(int(after_headshot["pool_total"]) == 56 and int(after_headshot["available"]) + int(after_headshot["active"]) == 56, "impact pool leaked or duplicated nodes")


func _test_weapon_impact_signatures(game: Node) -> void:
	game.impact_effects.clear_all()
	for weapon_id in [&"rifle", &"pistol", &"shotgun", &"sniper"]:
		game._on_projectile_impact_detailed(Vector2(200 + game.impact_effects._active.size() * 12, 250), Color("ffd35a"), 0.72, {
			"weapon_id": weapon_id,
			"weapon_type": weapon_id,
			"team": &"player",
			"can_damage": true,
			"feedback": &"heavy" if weapon_id == &"sniper" else &"normal",
			"direction": Vector2.RIGHT,
			"distance": 80.0,
			"max_range": 720.0,
			"target_material": &"trooper",
		})
	var kinds: Array[StringName] = []
	for effect in game.impact_effects._active:
		kinds.append(StringName(effect.effect_kind))
	_expect(kinds == [&"rifle_hit", &"pistol_hit", &"shotgun_hit", &"sniper_hit"], "four weapons did not select distinct impact signatures: %s" % [kinds])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ENEMY_HIT_FEEDBACK_PASS unified collision event, four weapon weights, material response, lethal idempotence, pooled/capped pixel impacts, unchanged balance")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
