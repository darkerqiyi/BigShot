extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const ProjectileScene := preload("res://scenes/combat/projectile.tscn")
const ImpactScene := preload("res://scenes/effects/impact_effect.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await physics_frame
	_test_balance_contract()
	_test_four_weapon_pixels(game)
	_test_capped_shake(game)
	_test_merged_impacts(game)
	_test_feedback_classification(game)
	_test_local_hold()
	_test_casing_budget(game)
	for casing in get_nodes_in_group("combat_casings"):
		casing._process(0.5)
	await process_frame
	_expect(get_nodes_in_group("combat_casings").is_empty(), "pixel casings did not clean up after their bounded lifetime")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "combat feedback changed global time scale")
	game.queue_free()
	await process_frame
	_finish()


func _test_balance_contract() -> void:
	var rifle := WeaponData.get_weapon(&"rifle")
	var shotgun := WeaponData.get_weapon(&"shotgun")
	var sniper := WeaponData.get_weapon(&"sniper")
	var pistol := WeaponData.get_weapon(&"pistol")
	_expect([rifle.damage, shotgun.damage, sniper.damage, pistol.damage] == [24, 17, 92, 32], "combat presentation work changed weapon damage")
	_expect([rifle.fire_rate, shotgun.fire_rate, sniper.fire_rate, pistol.fire_rate] == [0.085, 0.62, 1.0, 0.23], "combat presentation work changed weapon fire intervals")
	_expect([rifle.projectile_speed, shotgun.projectile_speed, sniper.projectile_speed, pistol.projectile_speed] == [1050.0, 900.0, 3600.0, 1250.0], "combat presentation work changed projectile speeds")


func _test_four_weapon_pixels(game: Node) -> void:
	var expected_profiles := [&"rifle", &"shotgun", &"sniper", &"pistol"]
	var durations: Array[float] = []
	for weapon_id in WeaponData.ORDER:
		var data := WeaponData.get_weapon(weapon_id)
		var projectile = ProjectileScene.instantiate()
		root.add_child(projectile)
		projectile.configure(Vector2.ZERO, Vector2.RIGHT, &"player", int(data["damage"]), float(data["projectile_speed"]), {"weapon_id": weapon_id, "color": data["color"]})
		_expect(projectile.trail_style == weapon_id, "%s did not select its own pixel trail" % weapon_id)
		projectile.free()
		game.player.visual.configure_weapon(weapon_id, data)
		game.player.muzzle_flash.play(weapon_id, data["color"], float(data["muzzle_scale"]), false)
		_expect(game.player.muzzle_flash.profile == weapon_id and game.player.muzzle_flash.visible, "%s did not select its own pixel muzzle flash" % weapon_id)
		durations.append(float(game.player.muzzle_flash.duration))
	_expect(expected_profiles == WeaponData.ORDER, "weapon order changed unexpectedly")
	_expect(durations[1] > durations[0] and durations[2] > durations[0] and durations[3] < durations[0], "muzzle timing does not distinguish shotgun/sniper/pistol from rifle")
	game.player.visual.set_aim_direction(Vector2.LEFT, -1)
	game.player.muzzle_flash.play(&"pistol", WeaponData.get_weapon(&"pistol")["color"], 1.0, false)
	_expect(game.player.muzzle_flash.global_transform.x.normalized().x < -0.9, "left aim did not rotate the pixel muzzle effect with the weapon")
	game.player.visual.set_aim_direction(Vector2.RIGHT, 1)


func _test_capped_shake(game: Node) -> void:
	game.combat_feedback.clear()
	for index in range(30):
		game.combat_feedback.request_shake(&"rifle_shot", StringName("rifle_%d" % index))
	_expect(game.camera.trauma <= 0.1401, "continuous rifle shake exceeded its configured comfort cap: %.3f" % game.camera.trauma)
	game.combat_feedback.clear()
	_expect(is_zero_approx(game.camera.trauma) and game.camera.offset == Vector2.ZERO, "camera feedback clear left a permanent shake offset")
	game.combat_feedback.cycle_shake_scale()
	game.combat_feedback.cycle_shake_scale()
	_expect(is_zero_approx(game.combat_feedback.shake_scale), "F4 shake control did not reach OFF")
	game.combat_feedback.request_shake(&"sniper_shot", &"off_test")
	_expect(is_zero_approx(game.camera.trauma), "disabled camera shake still added trauma")
	game.combat_feedback.cycle_shake_scale()
	_expect(is_equal_approx(game.combat_feedback.shake_scale, 1.0), "shake control did not cycle back to 100%")


func _test_merged_impacts(game: Node) -> void:
	game.combat_feedback.clear()
	var accepted_before := int(game.combat_feedback.get_debug_snapshot()["accepted_shakes"])
	game.impact_effects.clear_all()
	var effects_before := int(game.impact_effects.get_debug_snapshot()["active"])
	var details := {
		"weapon_id": &"shotgun", "team": &"player", "can_damage": true, "is_boss": false,
		"feedback": &"normal", "direction": Vector2.RIGHT, "distance": 80.0, "max_range": 720.0,
		"penetration_index": 0,
	}
	game._on_projectile_impact_detailed(Vector2(400, 400), Color.ORANGE, 0.78, details)
	game._on_projectile_impact_detailed(Vector2(407, 404), Color.ORANGE, 0.78, details)
	var accepted_after := int(game.combat_feedback.get_debug_snapshot()["accepted_shakes"])
	_expect(int(game.impact_effects.get_debug_snapshot()["active"]) == effects_before + 2, "shotgun did not preserve multiple visible impact points")
	_expect(accepted_after - accepted_before == 1, "same-frame shotgun pellets were not merged into one camera response")
	var held_effects := 0
	for effect in game.impact_effects._active:
		if effect.get("effect_kind") == &"shotgun_hit" and float(effect.get("hold_remaining")) > 0.0:
			held_effects += 1
	_expect(held_effects == 1, "same-frame shotgun pellets did not merge local visual hold")


func _test_feedback_classification(game: Node) -> void:
	game._spawn_enemy("shield", game.player.global_position + Vector2(240, 0), 99999.0, false, false)
	game._spawn_enemy("assault", game.player.global_position + Vector2(360, 0), 99999.0, false, false)
	var shield: Node
	for enemy in game.enemies.get_children():
		if enemy.kind == "shield":
			shield = enemy
			break
	_expect(shield != null, "shield enemy missing from combat test")
	if shield != null:
		shield.active = true
		shield._facing = -1.0
		shield.take_damage(20, Vector2.RIGHT * 20.0, shield.global_position, {"weapon_id": &"rifle", "direction": Vector2.RIGHT})
		_expect(shield.last_hit_feedback == &"block", "rifle front hit was not classified as shield block")
		shield.guard_open_remaining = 0.0
		shield.take_damage(20, Vector2.RIGHT * 20.0, shield.global_position, {"weapon_id": &"sniper", "direction": Vector2.RIGHT})
		_expect(shield.last_hit_feedback == &"guard_break", "sniper front hit was not classified as guard break")
	var assault: Node
	for enemy in game.enemies.get_children():
		if enemy.kind == "assault":
			assault = enemy
			break
	if assault != null:
		for _hit in range(30):
			assault.visual.play_hurt(1.0)
		_expect(assault.visual.hurt_remaining <= 0.1801, "rapid hits extended enemy hurt visuals without a cap")
	game.boss.activate(game.player)
	game.boss.take_damage(1, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"rifle", "impact_strength": 0.62})
	_expect(game.boss.last_hit_feedback == &"boss_normal", "ordinary boss hit did not use subdued classification")
	_expect(game.boss.body_shape.modulate == Color.WHITE, "ordinary rifle hit still flashed the entire Boss body")
	game.boss.take_damage(1, Vector2.ZERO, game.boss.global_position, {"weapon_id": &"sniper", "impact_strength": 1.05})
	_expect(game.boss.last_hit_feedback == &"boss_heavy", "sniper boss hit did not use heavy classification")


func _test_local_hold() -> void:
	var effect = ImpactScene.instantiate()
	root.add_child(effect)
	effect.configure(Color.CYAN, 1.0, false, &"sniper", Vector2.RIGHT, 0.038)
	var age_before: float = effect.age
	effect._process(0.02)
	_expect(effect.age == age_before and effect.hold_remaining > 0.0, "heavy hit local hold did not preserve the peak visual frame")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "local hit emphasis altered Engine.time_scale")
	effect.free()


func _test_casing_budget(game: Node) -> void:
	for index in range(24):
		game._spawn_casing(Vector2(200 + index, 300), Vector2.RIGHT, &"pistol")
	_expect(get_nodes_in_group("combat_casings").size() <= 12, "casing budget exceeded 12 live nodes")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("COMBAT_FEEDBACK_PASS four pixel fire signatures, capped/optional shake, merged shotgun response, hit tiers, local hold, casing cleanup, unchanged balance")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
