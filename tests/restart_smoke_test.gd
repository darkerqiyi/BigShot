extends SceneTree

const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	if packed == null:
		_fail("main scene failed to load")
		return
	var first_run := packed.instantiate()
	root.add_child(first_run)
	current_scene = first_run
	for _frame in range(4):
		await physics_frame
	var first_id := first_run.get_instance_id()
	first_run._debug_unlock_boss_for_tests()
	first_run.player.global_position.x = 17850.0
	first_run._process(0.0)
	if first_run.run_state != "boss" or not first_run.boss.active or not first_run.hud.boss_panel.visible:
		_fail("test setup could not enter boss battle")
		return
	var phase_two_damage: int = int(first_run.boss.health) - int(first_run.boss.MAX_HEALTH * 0.62)
	first_run.boss.take_damage(phase_two_damage, Vector2.ZERO, first_run.boss.global_position, {"weapon_id": &"rifle", "direction": Vector2.RIGHT})
	if first_run.boss.phase != 2:
		_fail("test setup could not enter boss phase two")
		return
	first_run.sfx.set_bus_level(&"Music", 52)
	first_run.sfx.toggle_bus_mute(&"SFX")
	first_run._run_elapsed = 182.0
	first_run._run_shots = 94
	first_run._run_projectiles = 126
	first_run._run_hits = 61
	first_run._run_kills = 28
	first_run._run_damage_events = 3
	first_run.player.take_damage(9999, Vector2.ZERO, first_run.player.global_position)
	if first_run.run_state != "dead":
		_fail("player death did not enter dead state")
		return
	var restart_started := Time.get_ticks_msec()
	await create_timer(1.75).timeout
	var restart_elapsed := Time.get_ticks_msec() - restart_started
	if current_scene == null or current_scene.get_instance_id() == first_id:
		_fail("death did not reload the current scene within three seconds")
		return
	var restarted_player := current_scene.get_node_or_null("World/Player")
	if restarted_player == null or restarted_player.health != restarted_player.MAX_HEALTH or not restarted_player.alive:
		_fail("restarted scene did not restore a live full-health player")
		return
	if restarted_player.current_weapon_id != &"rifle" or restarted_player.ammo != restarted_player.MAGAZINE_SIZE:
		_fail("restarted scene did not restore default rifle weapon state")
		return
	var restarted_boss := current_scene.get_node_or_null("World/Boss")
	var restarted_hud := current_scene.get_node_or_null("HUD")
	if restarted_boss == null or not restarted_boss.active or restarted_boss.phase != 1 or restarted_boss.health != restarted_boss.MAX_HEALTH or not restarted_hud.boss_panel.visible:
		_fail("boss checkpoint did not restore a fresh phase-one boss and HUD")
		return
	if current_scene.run_state != "boss" or current_scene.boss_gate.collision_layer != 1 or current_scene.enemies.get_child_count() != 0:
		_fail("boss checkpoint repeated regular encounters or failed to lock the arena")
		return
	if current_scene.projectiles.get_child_count() != 0 or current_scene.hazards.get_child_count() != 0:
		_fail("boss checkpoint retained old projectiles or hazards")
		return
	if current_scene._run_elapsed < 182.0 or current_scene._run_shots != 94 or current_scene._run_hits != 61 or current_scene._run_kills != 28 or current_scene._run_damage_events != 4:
		_fail("boss checkpoint discarded the mission statistics needed for settlement")
		return
	for weapon_id in [&"rifle", &"shotgun", &"sniper", &"pistol"]:
		var data: Dictionary = WeaponData.get_weapon(weapon_id)
		if restarted_player.weapon_inventory.get_ammo_for(weapon_id) != int(data["magazine_size"]):
			_fail("boss checkpoint did not fully resupply %s" % weapon_id)
			return
	if restart_elapsed >= 3000:
		_fail("boss checkpoint took %d ms to restore control" % restart_elapsed)
		return
	var restarted_mix: Dictionary = current_scene.sfx.get_mix_snapshot()
	if int(restarted_mix[&"Music"]["percent"]) != 52 or not bool(restarted_mix[&"SFX"]["muted"]):
		_fail("session audio settings did not survive death restart")
		return
	current_scene.sfx.set_bus_level(&"Music", 72)
	current_scene.sfx.toggle_bus_mute(&"SFX")
	print("RESTART_SMOKE_PASS phase-two death restored a clean full-resupply Boss checkpoint in %dms, phase-one Boss/HUD/arena, no dangers, retained session audio mix" % restart_elapsed)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
