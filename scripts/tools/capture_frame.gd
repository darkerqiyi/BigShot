extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load main scene for capture")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	var user_args := OS.get_cmdline_user_args()
	var mode := user_args[1] if user_args.size() > 1 else "start"
	if mode == "boss" or mode.begins_with("boss_"):
		game._debug_unlock_boss_for_tests()
		game.player.global_position.x = 17850.0
		game._process(0.0)
		game.player.global_position.x = 18720.0
		game.camera.global_position = Vector2(19000.0, 360.0)
		game.player.set_physics_process(false)
		game.player._invulnerability_remaining = 100.0
		game.boss.recovery_remaining = 10.0
		game.boss.attack_cooldown = 10.0
		game.boss.visual.intro_remaining = 0.0
		if mode != "boss_intro":
			game.hud.show_boss(game.boss.boss_name, game.boss.MAX_HEALTH)
			game.hud.hide_objective(true)
			game.hud.hide_controls(true)
			game.hud._clear_banner()
		if mode == "boss_phase2":
			game.boss.phase = 2
			game.boss.health = 500
			game.hud.set_boss_health(500, game.boss.MAX_HEALTH, 2)
		elif mode == "boss_phase3":
			game.boss.phase = 3
			game.boss.health = 200
			game.hud.set_boss_health(200, game.boss.MAX_HEALTH, 3)
		elif mode == "boss_transition2":
			game.boss.phase = 2
			game.hud.set_boss_health(500, game.boss.MAX_HEALTH, 2)
			game.boss.state = &"transition"
			game.boss.transition_remaining = 0.42
			game.boss.invulnerable = true
			game.hud.show_boss_phase(2)
		elif mode == "boss_transition3":
			game.boss.phase = 3
			game.hud.set_boss_health(200, game.boss.MAX_HEALTH, 3)
			game.boss.state = &"transition"
			game.boss.transition_remaining = 0.42
			game.boss.invulnerable = true
			game.hud.show_boss_phase(3)
		elif mode.begins_with("boss_telegraph_"):
			var attack_name := StringName(mode.trim_prefix("boss_telegraph_"))
			game.boss._begin_attack(attack_name, 1.0)
			game.boss.windup_remaining = 0.24
			game.boss.set_physics_process(false)
		elif mode == "boss_death":
			game.boss._die()
		elif mode == "boss_settlement":
			game.boss._die()
	elif mode == "start_clean":
		game.hud.hide_controls(true)
		game.hud.hide_objective(true)
		game.hud._clear_banner()
	elif mode == "player_death":
		game.player.take_damage(9999, Vector2.ZERO, game.player.global_position)
	elif mode == "enemies":
		game.player.global_position.x = 5400.0
		game._process(0.0)
		for enemy in game.enemies.get_children():
			enemy.set_physics_process(false)
	elif mode == "pause":
		game.hud.toggle_pause()
	elif mode in ["enemy_showcase", "enemy_telegraphs"]:
		game.player.global_position = Vector2(9000, 552)
		for kind in ["assault", "gunner", "shield", "elite"]:
			var sample: Node = game._spawn_enemy(kind, game.player.global_position, 0.0, false, false, 0)
			sample.activate()
		game.player.set_physics_process(false)
		game.player.health = game.player.MAX_HEALTH
		game.player._invulnerability_remaining = 100.0
		game.hud.set_health(game.player.health, game.player.MAX_HEALTH)
		game.player._using_mouse_aim = false
		game.player.aim_direction = Vector2.RIGHT
		game.player.facing_direction = 1
		game.player.visual.set_aim_direction(Vector2.RIGHT, 1)
		game.player.visual.update_pose(0.0, Vector2.ZERO, true, 0.0, Vector2.RIGHT, 0.0)
		var lineup := {"assault": -360.0, "gunner": -165.0, "shield": 155.0, "elite": 380.0}
		var placed: Dictionary = {}
		for enemy in game.enemies.get_children():
			if lineup.has(enemy.kind) and not placed.has(enemy.kind):
				placed[enemy.kind] = true
				enemy.visible = true
				enemy.set_physics_process(false)
				enemy.global_position = Vector2(game.player.global_position.x + float(lineup[enemy.kind]), 552)
				enemy.active = true
				enemy.target = game.player
				enemy._facing = signf(game.player.global_position.x - enemy.global_position.x)
				enemy.state = &"guard" if enemy.kind == "shield" else (&"advance" if enemy.kind == "elite" else (&"pursue" if enemy.kind == "assault" else &"idle"))
				enemy.velocity = Vector2.ZERO
				enemy._sync_visual(0.0)
				if mode == "enemy_telegraphs":
					if enemy.kind == "assault":
						enemy._start_melee(17, 0.32, 0.82)
					elif enemy.kind == "gunner":
						enemy._start_attack(12, 700.0, 0.38, 0.92)
					elif enemy.kind == "shield":
						enemy._start_melee(20, 0.46, 1.05)
					elif enemy.kind == "elite":
						enemy._start_hazard(92.0, 22, 0.72, 1.1)
			else:
				enemy.visible = false
	elif mode in ["rifle", "shotgun", "sniper", "pistol"]:
		game.player.global_position = Vector2(1180, 552)
		game.player.set_physics_process(false)
		game.player._using_mouse_aim = false
		game.player.aim_direction = Vector2.RIGHT
		game.player.facing_direction = 1
		game.player.weapon_inventory.select_weapon(StringName(mode))
		game.player.visual.set_aim_direction(Vector2.RIGHT, 1)
		game.player.visual.update_pose(0.0, Vector2.ZERO, true, 0.0, Vector2.RIGHT, 0.0)
		for enemy in game.enemies.get_children():
			enemy.set_physics_process(false)
			enemy.visible = false
		for _warmup in range(8):
			await process_frame
		game.player._fire_current_weapon()
	elif mode == "impact_tiers":
		game.player.global_position = Vector2(1180, 552)
		game.player.set_physics_process(false)
		for enemy in game.enemies.get_children():
			enemy.set_physics_process(false)
			enemy.visible = false
		for _warmup in range(8):
			await process_frame
		game._spawn_impact(Vector2(1010, 510), Color("ffd35a"), 0.62, false, &"normal", Vector2.RIGHT)
		game._spawn_impact(Vector2(1120, 500), Color("ff8b58"), 0.9, false, &"heavy", Vector2.RIGHT, 0.026)
		game._spawn_impact(Vector2(1270, 500), Color("65c8ff"), 0.7, false, &"block", Vector2.UP)
		game._spawn_impact(Vector2(1410, 500), Color("ff8b58"), 1.0, false, &"guard_break", Vector2.UP, 0.032)
		game._spawn_impact(Vector2(1550, 500), Color("e65345"), 0.9, true, &"kill_heavy", Vector2.UP, 0.032)
	var is_boss_mode := mode == "boss" or mode.begins_with("boss_")
	var capture_frames := (90 if mode == "boss_settlement" else (30 if mode == "boss_death" else 24)) if is_boss_mode else (90 if mode in ["enemies", "enemy_showcase", "enemy_telegraphs"] else (1 if mode in ["rifle", "shotgun", "sniper", "pistol", "impact_tiers"] else 8))
	for _frame in range(capture_frames):
		if is_boss_mode or mode in ["enemies", "enemy_showcase", "enemy_telegraphs"]:
			await physics_frame
		else:
			await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "/tmp/bigshot-preview.png"
	if not user_args.is_empty():
		output_path = user_args[0]
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save capture: %s" % error_string(error))
		quit(1)
		return
	print("CAPTURE_PASS %s FPS=%d PLAYER_UI=%s VISIBLE=%s MODULATE=%s WEAPON_UI=%s BOSS_UI=%s" % [
		output_path,
		Engine.get_frames_per_second(),
		game.hud.player_panel.get_global_rect(),
		game.hud.player_panel.visible,
		game.hud.player_panel.modulate,
		game.hud.weapon_rack.get_global_rect(),
		game.hud.boss_panel.get_global_rect(),
	])
	game.queue_free()
	await process_frame
	quit(0)
