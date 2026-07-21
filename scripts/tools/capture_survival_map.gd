extends SceneTree

const MapConfig := preload("res://scripts/survival/survival_map_config.gd")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output_path := args[0] if not args.is_empty() else "/tmp/bigshot-survival-map.png"
	var map_id := StringName(args[1]) if args.size() > 1 else MapConfig.SUBLEVEL_ID
	var config := MapConfig.get_map(map_id)
	var scene := load(str(config["scene_path"])) as PackedScene
	if scene == null:
		push_error("Could not load survival map %s" % map_id)
		quit(1)
		return
	var game := scene.instantiate()
	game.set_meta("survival_test_mode", true)
	root.add_child(game)
	current_scene = game
	game.wave_manager.stop_run()
	game.player._invulnerability_remaining = 100.0
	game.player.set_physics_process(false)
	game.player.global_position = config["player_spawn"]
	game.hud.show_banner(str(config["display_name"]), Color("ffcf5a"), false, 4.0)
	var samples := [
		{"kind": "assault", "position": Vector2(290, 552)},
		{"kind": "gunner", "position": Vector2(500, 460)},
		{"kind": "shield", "position": Vector2(1090, 460)},
		{"kind": "elite", "position": Vector2(1350, 540)},
	]
	for sample in samples:
		var enemy: Node = game._spawn_enemy(str(sample["kind"]), sample["position"], 0.0, false, false, 7)
		enemy.activate()
		enemy.set_physics_process(false)
		enemy._sync_visual(0.0)
	if not game.map_hazards.is_empty():
		var vent = game.map_hazards[0]
		vent.set_suspended(false)
		vent.state = vent.State.WARNING
		vent.remaining = vent.warning_time * 0.46
		vent.queue_redraw()
	for _frame in range(10):
		await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("Survival map capture requires a rendering display")
		game.queue_free()
		await process_frame
		quit(2)
		return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save survival map capture: %s" % error_string(error))
		quit(1)
		return
	print("SURVIVAL_MAP_CAPTURE_PASS %s map=%s" % [output_path, map_id])
	game.queue_free()
	await process_frame
	quit(0)
