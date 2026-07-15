extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	var boss = game.boss
	_test_physics_and_layers(boss)
	_test_phase_and_pose_contract(game, boss)
	_test_visual_source_contract()
	game.queue_free()
	await process_frame
	_finish()


func _test_physics_and_layers(boss: CharacterBody2D) -> void:
	var collision := boss.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	_expect(shape.size == Vector2(112, 122) and collision.position == Vector2(0, -1), "Boss collision changed during visual replacement")
	for path in [
		"Visual/Shadow",
		"Visual/LowerBody",
		"Visual/MainBody",
		"Visual/ArmorFront",
		"Visual/Core",
		"Visual/LeftWeapon",
		"Visual/RightWeapon",
		"Visual/DamageEffects",
		"Visual/MuzzlePoints/LeftMuzzle",
		"Visual/MuzzlePoints/RightMuzzle",
		"Visual/GroundContactEffects",
	]:
		_expect(boss.has_node(path), "Boss visual layer is missing: %s" % path)
	var contract: Dictionary = boss.visual.get_visual_contract()
	_expect(contract["layer_count"] == 9, "Boss visual layer registry is incomplete")
	_expect(contract["left_muzzle"] == Vector2(-62, -26) and contract["right_muzzle"] == Vector2(62, -26), "Boss projectile origins changed during art pass")


func _test_phase_and_pose_contract(game: Node, boss: CharacterBody2D) -> void:
	var phase_events: Array[int] = []
	var death_count := [0]
	boss.phase_changed.connect(func(next_phase: int) -> void: phase_events.append(next_phase))
	boss.died.connect(func(_node: Node) -> void: death_count[0] += 1)
	boss.activate(game.player)
	game.player.global_position = Vector2(boss.global_position.x - 260.0, 552.0)
	boss.visual.intro_remaining = 0.0
	boss.visual._process(0.0)
	_expect(boss.visual.phase_visual == 1 and boss.visual.animation_state == &"recover", "Phase I visual did not initialize as armored/recovering")
	_expect(boss.visual.get_muzzle_global_position(-1.0) == boss.global_position + Vector2(-62, -26), "left-facing Boss muzzle no longer matches the established attack origin")
	boss._begin_attack(&"volley", 0.52)
	boss.windup_remaining = 0.20
	boss.visual._process(0.0)
	_expect(boss.visual.animation_state == &"volley_telegraph" and boss.warning.visible, "volley visual is not bound to the authoritative telegraph state")
	boss.visual.play_attack(&"volley")
	_expect(boss.visual.attack_fx_remaining > 0.0, "volley active frame did not reach the visual layer")

	var phase_two_damage: int = boss.health - int(boss.MAX_HEALTH * 0.62)
	boss.take_damage(phase_two_damage, Vector2.ZERO, boss.global_position + Vector2(16, -12), {"weapon_id": &"rifle"})
	boss.visual._process(0.0)
	_expect(boss.phase == 2 and boss.visual.phase_visual == 2 and boss.state == &"transition", "65 percent transition did not produce Phase II damaged armor")
	_expect(boss.body_shape.modulate == Color.WHITE, "normal hit flashed the entire Boss instead of local/core feedback")
	boss._update_transition(1.0)
	var phase_three_damage: int = boss.health - int(boss.MAX_HEALTH * 0.28)
	boss.take_damage(phase_three_damage, Vector2.ZERO, boss.global_position + Vector2(4, -12), {"weapon_id": &"sniper", "impact_strength": 1.0})
	boss.visual._process(0.0)
	_expect(boss.phase == 3 and boss.visual.phase_visual == 3 and boss.visual.heavy_hurt, "30 percent transition did not produce Phase III overload/heavy feedback")
	boss._update_transition(1.0)
	boss.take_damage(9999, Vector2.ZERO, boss.global_position, {"weapon_id": &"shotgun", "impact_strength": 1.0})
	_expect(not boss.alive and boss.collision_layer == 0 and boss.visual.death_elapsed >= 0.0, "Boss death did not stop collision and start the visual sequence")
	boss._die()
	_expect(phase_events == [2, 3], "Boss phase visual transitions did not remain one-shot")
	_expect(death_count[0] == 1, "Boss visual death path caused duplicate settlement/death")


func _test_visual_source_contract() -> void:
	for path in [
		"res://scripts/bosses/iron_tempest_visual.gd",
		"res://scripts/bosses/iron_tempest_pixel_layer.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("draw_circle("), "%s uses smooth circles instead of pixel primitives" % path)
		_expect(not source.contains("draw_arc("), "%s uses smooth arcs instead of pixel primitives" % path)
		_expect(not source.contains("draw_line("), "%s uses antialiased lines instead of pixel primitives" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("BOSS_VISUAL_PASS layered industrial silhouette, exact collision/muzzles, three visual phases, logic-driven telegraphs, local hurt, one-shot death")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
