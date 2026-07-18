extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const ProjectileScene := preload("res://scenes/combat/projectile.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")
const WaveData := preload("res://scripts/survival/survival_wave_data.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const EnemyBalance := preload("res://scripts/config/enemy_balance.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MainScene.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in range(4):
		await physics_frame
	game.enemy_balance_mode = &"survival"

	var body_enemy: Node = game._spawn_enemy("assault", Vector2(820, 552), 0.0, false, false)
	body_enemy.active = false
	await physics_frame
	var body_details := await _fire_test_projectile(game, body_enemy, body_enemy.global_position + Vector2(0, 10), &"rifle", 24)
	_expect(int(body_details.get("final_damage", 0)) == 24, "rifle body hit did not apply/display 24")
	_expect(StringName(body_details.get("hit_zone", &"")) == &"body" and not bool(body_details.get("headshot", true)), "body hit was mislabeled as a headshot")
	_expect(body_enemy.health == 108, "survival assault body health result was incorrect")
	body_enemy.free()

	var head_enemy: Node = game._spawn_enemy("assault", Vector2(930, 552), 0.0, false, false)
	head_enemy.active = false
	await physics_frame
	var head_details := await _fire_test_projectile(game, head_enemy, head_enemy.head_hurtbox.global_position, &"rifle", 24)
	_expect(int(head_details.get("final_damage", 0)) == 48, "rifle headshot did not apply/display 48")
	_expect(StringName(head_details.get("hit_zone", &"")) == &"head" and bool(head_details.get("headshot", false)), "head hit was not marked critical")
	_expect(head_enemy.health == 84, "head and body hurtboxes resolved duplicate damage")
	head_enemy.global_position = Vector2(420, 552)

	var shield: Node = game._spawn_enemy("shield", Vector2(1040, 552), 0.0, false, false)
	shield.active = false
	shield._facing = -1.0
	shield.visual.set_facing(-1)
	await physics_frame
	var shield_details := await _fire_test_projectile(game, shield, shield.head_hurtbox.global_position, &"rifle", 24)
	_expect(StringName(shield_details.get("hit_zone", &"")) == &"body" and not bool(shield_details.get("headshot", true)), "closed frontal shield allowed a headshot")
	_expect(int(shield_details.get("final_damage", 0)) == 6, "shield mitigation did not report actual applied damage")

	var grenade_target: Node = game._spawn_enemy("gunner", Vector2(700, 552), 0.0, false, false)
	grenade_target.active = false
	game._on_player_grenade_exploded(grenade_target.global_position, 110.0, 80, 0.0)
	_expect(not bool(grenade_target.last_damage_result.get("headshot", true)) and StringName(grenade_target.last_damage_result.get("hit_zone", &"")) == &"body", "grenade incorrectly produced a headshot")
	_expect(int(grenade_target.last_damage_result.get("final_damage", 0)) == 80, "grenade damage result did not report actual damage")

	var pve_enemy: Node = game._spawn_enemy("assault", Vector2(560, 552), 0.0, false, false)
	pve_enemy.active = false
	pve_enemy.balance_mode = &"pve"
	pve_enemy._apply_kind()
	_expect(pve_enemy.max_health == 44, "PVE enemy health inherited survival tuning")
	_expect(not game.boss.has_node("HeadHurtbox"), "Iron Tempest incorrectly gained a head hurtbox")

	game.damage_numbers.clear_all()
	game.damage_numbers.show_result(head_enemy, head_enemy.global_position + Vector2(0, -30), {"final_damage": 18, "headshot": false, "blocked": false})
	_expect(game.damage_numbers._active.size() == 1 and game.damage_numbers._active[0]._label.text == "18", "an applied 18-damage result did not display 18")
	game.damage_numbers.clear_all()
	game.damage_numbers.show_result(head_enemy, head_enemy.global_position + Vector2(0, -30), {"final_damage": 36, "headshot": true, "blocked": false})
	var headshot_number: DamageNumber = game.damage_numbers._active[0] if game.damage_numbers._active.size() == 1 else null
	_expect(headshot_number != null and headshot_number._label.text == "36", "an applied 36-damage headshot did not display only its final damage")
	if headshot_number != null:
		_expect(not headshot_number._label.text.contains("HEAD") and not headshot_number._label.text.contains("CRIT"), "headshot damage retained a redundant text marker")
		_expect(headshot_number._label.get_theme_font_size("font_size") == 22, "headshot number lost its compact size emphasis")
		_expect(headshot_number._label.get_theme_color("font_color").is_equal_approx(Color("ffd34e")), "headshot number lost its gold identity")
		_expect(headshot_number._label.get_theme_color("font_outline_color").is_equal_approx(Color("963b2b")), "headshot number lost its dark orange outline")
		_expect(is_equal_approx(headshot_number.scale.x, DamageNumber.HEADSHOT_TARGET_SCALE * DamageNumber.HEADSHOT_POP_IN_SCALE), "headshot pop did not begin at 0.8 of its target scale")
		headshot_number._process(DamageNumber.HEADSHOT_POP_TIME)
		_expect(headshot_number.scale.x >= DamageNumber.HEADSHOT_TARGET_SCALE * 1.14, "headshot pop did not reach its short 1.15 overshoot")
		headshot_number._process(DamageNumber.HEADSHOT_SETTLE_TIME)
		_expect(absf(headshot_number.scale.x - DamageNumber.HEADSHOT_TARGET_SCALE) < 0.01, "headshot pop did not settle to its target scale")
	game.damage_numbers.clear_all()
	for index in range(20):
		game.damage_numbers.show_result(head_enemy, head_enemy.global_position + Vector2(0, -30), {"final_damage": 24, "headshot": false, "blocked": false})
	_expect(game.damage_numbers.get_debug_snapshot()["visible"] <= Tuning.DAMAGE_NUMBERS_PER_TARGET, "per-target number cap was exceeded")
	game.damage_numbers.show_result(head_enemy, head_enemy.global_position + Vector2(0, -30), {"final_damage": 48, "headshot": true, "blocked": false})
	var preserved_headshot := false
	for number in game.damage_numbers._active:
		if number.target_id == head_enemy.get_instance_id() and number.priority == 3:
			preserved_headshot = true
	_expect(preserved_headshot, "headshot number was not prioritized at the display cap")
	for _frame in range(55):
		await physics_frame
	_expect(int(game.damage_numbers.get_debug_snapshot()["visible"]) == 0, "damage numbers did not return to the pool")

	var rifle: Dictionary = WeaponData.get_weapon(&"rifle")
	var health_values := {"assault": 132, "gunner": 120, "shield": 216, "elite": 900}
	var shot_counts := {}
	for kind in health_values:
		shot_counts[kind] = {
			"body": _shots_to_kill(int(health_values[kind]), int(rifle["damage"]), false),
			"head": _shots_to_kill(int(health_values[kind]), int(rifle["damage"]), true),
		}
	_expect(shot_counts["assault"] == {"body": 6, "head": 3}, "assault rifle TTK target changed")
	_expect(shot_counts["gunner"] == {"body": 5, "head": 3}, "gunner rifle TTK target changed")
	_expect(shot_counts["shield"] == {"body": 9, "head": 5}, "shield open-state rifle TTK target changed")
	_expect(int(shot_counts["elite"]["body"]) == 35, "elite sustained rifle target changed")
	_expect(EnemyBalance.health_for("assault", &"survival", 9) == 196, "late assault health did not use linear growth")
	_expect(EnemyBalance.health_for("gunner", &"survival", 9) == 168, "late gunner health did not use linear growth")

	var waves := WaveData.full_waves()
	var counts: Array[int] = []
	for wave in waves:
		var count := 0
		for entry in wave["entries"]:
			count += int(entry["count"])
		counts.append(count)
	_expect(counts == [6, 8, 9, 10, 15, 13, 15, 18, 24, 0], "survival wave counts did not match the tuned curve")
	_expect(float(waves[4]["rest_duration_after"]) == 4.5 and float(waves[8]["rest_duration_after"]) == 5.0, "major supply rests were not preserved")
	_expect(float(waves[0]["rest_duration_after"]) == 3.5 and int(waves[7]["active_limit"]) == 7, "normal rest or pressure cap was incorrect")

	print("SURVIVAL_HEADSHOT_PACING_METRICS health=%s rifle_shots=%s wave_counts=%s pool=%s" % [JSON.stringify(health_values), JSON.stringify(shot_counts), JSON.stringify(counts), JSON.stringify(game.damage_numbers.get_debug_snapshot())])
	_finish()


func _fire_test_projectile(game: Node, enemy: Node, target_position: Vector2, weapon_id: StringName, damage: int) -> Dictionary:
	var details: Array[Dictionary] = []
	var projectile := ProjectileScene.instantiate()
	var origin := Vector2(enemy.global_position.x - 180.0, target_position.y)
	projectile.configure(origin, (target_position - origin).normalized(), &"player", damage, 1800.0, {
		"weapon_id": weapon_id,
		"max_range": 400.0,
		"falloff_start": 400.0,
		"minimum_damage_multiplier": 1.0,
	})
	projectile.impact_detailed.connect(func(_position: Vector2, _color: Color, _strength: float, result: Dictionary) -> void: details.append(result))
	game.projectiles.add_child(projectile)
	for _frame in range(12):
		await physics_frame
		if not details.is_empty():
			break
	return details[0] if not details.is_empty() else {}


func _shots_to_kill(health: int, base_damage: int, headshot: bool) -> int:
	var remaining := health
	var shots := 0
	while remaining > 0 and shots < 200:
		shots += 1
		var shot_damage := 34 if shots % 4 == 0 else base_damage
		remaining -= int(round(float(shot_damage) * (Tuning.HEADSHOT_MULTIPLIER if headshot else 1.0)))
	return shots


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SURVIVAL_HEADSHOT_PACING_PASS actual damage numbers, head/body exclusivity, shield/Boss rules, bounded pool, TTK and wave curve")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
