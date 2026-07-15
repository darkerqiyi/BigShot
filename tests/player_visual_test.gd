extends SceneTree

const PlayerScene := preload("res://scenes/player/player.tscn")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")
const HorizontalMotion := preload("res://scripts/player/player_horizontal_motion.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	_test_structure_and_physics_contract(player)
	_test_animation_states(player)
	_test_aim_and_facing(player)
	_test_weapon_silhouettes(player)
	_test_shot_and_hurt_layers(player)
	player.queue_free()
	await process_frame
	await _test_death_and_restart_visual()
	_finish()


func _test_structure_and_physics_contract(player: CharacterBody2D) -> void:
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	_expect(shape != null and shape.size == Vector2(34, 64), "player collision changed from the 34x64 baseline")
	_expect(player.floor_snap_length == 8.0 and player.collision_layer == 2 and player.collision_mask == 5, "player collision/floor contract changed")
	_expect(HorizontalMotion.MAX_SPEED == 260.0 and Tuning.PLAYER_JUMP_SPEED == 590.0 and Tuning.PLAYER_MAX_HEALTH == 100, "movement, jump, or health tuning changed during visual work")
	for path in ["PlayerVisual/Shadow", "PlayerVisual/BodySprite", "PlayerVisual/WeaponPivot/BackArm", "PlayerVisual/WeaponPivot/WeaponSprite", "PlayerVisual/WeaponPivot/FrontArm", "PlayerVisual/WeaponPivot/MuzzlePoint", "PlayerVisual/VisualEffects"]:
		_expect(player.has_node(path), "missing separated player visual node: %s" % path)
	for path in ["GrenadeChargeIndicator", "GrenadeTrajectoryPreview"]:
		_expect(player.has_node(path), "missing world-space grenade aiming aid: %s" % path)
	_expect(player.visual.scale.x > 0.0 and player.visual.scale.y > 0.0, "player visual uses a negative scale that can corrupt children")
	_expect(player.visual.scale == Vector2(1.25, 1.25) and player.visual.position == Vector2(0, -8), "player second-pass 125% visual calibration or foot compensation is missing")
	var shadow_relative_y: float = player.visual.get_node("Shadow").global_position.y - player.global_position.y
	_expect(absf(shadow_relative_y - 30.75) < 0.2, "enlarged player shadow/feet no longer align with the original ground baseline: %.2f" % shadow_relative_y)
	_expect(ProjectSettings.get_setting("rendering/textures/default_filters/use_nearest_mipmap_filter") == false, "nearest pixel filter baseline was lost")


func _test_animation_states(player: CharacterBody2D) -> void:
	var visual = player.visual
	visual.update_pose(0.05, Vector2.ZERO, true, 0.0, Vector2.RIGHT, 0.0)
	_expect(visual.base_animation_state == &"idle", "stationary player did not enter idle")
	visual.update_pose(0.05, Vector2(220, 0), true, 1.0, Vector2.RIGHT, 0.0)
	_expect(visual.base_animation_state == &"run", "moving player did not enter run")
	visual.update_pose(0.05, Vector2(120, -280), false, 1.0, Vector2.RIGHT, 0.0)
	_expect(visual.base_animation_state == &"jump", "rising player did not enter jump")
	visual.update_pose(0.05, Vector2(120, 320), false, 1.0, Vector2.RIGHT, 0.0)
	_expect(visual.base_animation_state == &"fall", "descending player did not enter fall")
	visual.update_pose(0.02, Vector2.ZERO, true, 0.0, Vector2.RIGHT, 0.12)
	_expect(visual.base_animation_state == &"land", "landing feedback did not enter land pose")
	_expect(player.controls_enabled and player.alive, "visual pose changed player control or life state")


func _test_aim_and_facing(player: CharacterBody2D) -> void:
	var visual = player.visual
	visual.set_aim_direction(Vector2.RIGHT, 1)
	var right_muzzle: Vector2 = visual.get_muzzle_global_position()
	_expect(right_muzzle.x > player.global_position.x + 20.0, "right aim muzzle is not in front of player")
	visual.set_aim_direction(Vector2.LEFT, -1)
	var left_muzzle: Vector2 = visual.get_muzzle_global_position()
	_expect(left_muzzle.x < player.global_position.x - 20.0, "left aim muzzle did not flip without negative scale")
	_expect(visual.scale.x > 0.0 and player.get_node("CollisionShape2D").scale.x > 0.0, "left aim introduced negative visual or collision scale")
	visual.set_aim_direction(Vector2.UP, 1)
	var up_muzzle: Vector2 = visual.get_muzzle_global_position()
	_expect(up_muzzle.y < player.global_position.y - 32.0 and up_muzzle.x > player.global_position.x, "extreme upward aim is not clamped into a readable forward pose")


func _test_weapon_silhouettes(player: CharacterBody2D) -> void:
	var visual = player.visual
	var muzzle_lengths: Array[float] = []
	var recoil_distances: Array[float] = []
	for weapon_id in WeaponData.ORDER:
		var data := WeaponData.get_weapon(weapon_id)
		visual.configure_weapon(weapon_id, data)
		muzzle_lengths.append(float(player.weapon.muzzle_length))
		recoil_distances.append(float(player.weapon.recoil_distance))
		_expect(player.weapon.weapon_id == weapon_id and player.weapon.color == data["color"], "scene weapon did not follow %s visual identity" % weapon_id)
	_expect(muzzle_lengths == [40.0, 39.0, 52.0, 25.0], "four weapons do not retain distinct configured silhouettes/muzzles: %s" % str(muzzle_lengths))
	_expect(recoil_distances[2] > recoil_distances[1] and recoil_distances[1] > recoil_distances[0] and recoil_distances[0] > recoil_distances[3], "weapon visual recoil hierarchy is not sniper > shotgun > rifle > pistol")
	visual.configure_weapon(&"rifle", WeaponData.get_weapon(&"rifle"))


func _test_shot_and_hurt_layers(player: CharacterBody2D) -> void:
	player._using_mouse_aim = false
	player.aim_direction = Vector2.RIGHT
	player.facing_direction = 1
	player.visual.set_aim_direction(Vector2.RIGHT, 1)
	var expected_muzzle: Vector2 = player.visual.get_muzzle_global_position()
	var emitted_origins: Array[Vector2] = []
	player.volley_requested.connect(func(origin: Vector2, _directions: Array[Vector2], _team: StringName, _data: Dictionary, _damage: int) -> void: emitted_origins.append(origin))
	player._fire_current_weapon()
	_expect(emitted_origins.size() == 1 and emitted_origins[0].distance_to(expected_muzzle) < 0.1, "real projectile origin does not use the visual muzzle point")
	_expect(player.weapon.recoil_remaining > 0.0 and player.muzzle_flash.visible, "shoot did not trigger layered weapon recoil and muzzle flash")
	player.visual.update_pose(0.01, Vector2(140, 0), true, 1.0, Vector2.RIGHT, 0.0)
	_expect(player.visual.animation_state == &"shoot" and player.visual.base_animation_state == &"run", "shoot did not layer over the current locomotion state")
	var health_before: int = player.health
	player.take_damage(7)
	player.visual.update_pose(0.01, Vector2.ZERO, true, 0.0, Vector2.RIGHT, 0.0)
	_expect(player.health == health_before - 7 and player.visual.animation_state == &"hurt", "hurt did not trigger a short visual-priority state")


func _test_death_and_restart_visual() -> void:
	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.take_damage(9999)
	player.visual.update_pose(0.12, player.velocity, false, 0.0, Vector2.RIGHT, 0.0)
	_expect(not player.alive and player.visual.animation_state == &"death" and not player.weapon.visible, "death did not suppress ordinary weapon/action animation")
	player.queue_free()
	await process_frame
	var restarted = PlayerScene.instantiate()
	root.add_child(restarted)
	await process_frame
	_expect(restarted.alive and not restarted.visual.is_dead and restarted.weapon.visible and restarted.current_weapon_id == &"rifle", "fresh restart did not reset animation and weapon visual")
	restarted.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_VISUAL_PASS separated physics/visuals, idle/run/jump/fall/land/hurt/death, bidirectional aim, four silhouettes/recoil profiles, muzzle-origin sync, restart reset")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
