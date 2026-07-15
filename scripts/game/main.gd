extends Node2D

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")
const ProjectileScene := preload("res://scenes/combat/projectile.tscn")
const ImpactEffectScene := preload("res://scenes/effects/impact_effect.tscn")
const GroundHazardScene := preload("res://scenes/combat/ground_hazard.tscn")
const PixelCasingScene := preload("res://scenes/effects/pixel_casing.tscn")
const CombatFeedbackScript := preload("res://scripts/combat/combat_feedback.gd")
const RunTelemetryScript := preload("res://scripts/debug/run_telemetry.gd")
const CombatPacingDirectorScript := preload("res://scripts/game/combat_pacing_director.gd")
const MissionGateScript := preload("res://scripts/world/mission_gate.gd")
const MissionPickupScript := preload("res://scripts/world/mission_pickup.gd")
const MissionSpikesScript := preload("res://scripts/world/mission_spikes.gd")
const MissionMovingPlatformScript := preload("res://scripts/world/moving_platform.gd")
const PlayerGrenadeScript := preload("res://scripts/combat/player_grenade.gd")
const GrenadeExplosionScript := preload("res://scripts/effects/grenade_explosion.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")

const MISSION_ENCOUNTERS := [
	{
		"id": 1, "title": "FIRST CONTACT", "trigger_x": 2830.0, "gate_x": 5200.0, "target_seconds": Vector2i(45, 60),
		"waves": [
			[{"kind": "gunner", "x": 4300.0, "y": 552.0}],
			[{"kind": "assault", "x": 3780.0, "y": 552.0}, {"kind": "assault", "x": 3900.0, "y": 552.0}, {"kind": "assault", "x": 4020.0, "y": 552.0}],
			[{"kind": "shield", "x": 3660.0, "y": 552.0}, {"kind": "assault", "x": 4560.0, "y": 552.0}, {"kind": "gunner", "x": 4820.0, "y": 552.0}],
		],
	},
	{
		"id": 2, "title": "SKYLINE CROSSING", "trigger_x": 7800.0, "gate_x": 10500.0, "target_seconds": Vector2i(30, 45),
		"waves": [
			[{"kind": "gunner", "x": 8480.0, "y": 438.0}, {"kind": "assault", "x": 9000.0, "y": 552.0}, {"kind": "gunner", "x": 9740.0, "y": 393.0}],
			[{"kind": "assault", "x": 8200.0, "y": 552.0}, {"kind": "gunner", "x": 9240.0, "y": 552.0}, {"kind": "assault", "x": 9980.0, "y": 552.0}],
		],
	},
	{
		"id": 3, "title": "BREAK THE LINE", "trigger_x": 10800.0, "gate_x": 13300.0, "target_seconds": Vector2i(60, 75),
		"waves": [
			[{"kind": "shield", "x": 11400.0, "y": 552.0}, {"kind": "gunner", "x": 12360.0, "y": 552.0}],
			[{"kind": "assault", "x": 11160.0, "y": 552.0}, {"kind": "shield", "x": 11900.0, "y": 552.0}, {"kind": "gunner", "x": 12720.0, "y": 552.0}],
			[{"kind": "shield", "x": 11300.0, "y": 552.0}, {"kind": "assault", "x": 12180.0, "y": 552.0}, {"kind": "assault", "x": 12820.0, "y": 552.0}],
		],
	},
	{
		"id": 4, "title": "ARMORED COUNTERSTRIKE", "trigger_x": 13600.0, "gate_x": 16200.0, "target_seconds": Vector2i(60, 75),
		"waves": [
			[{"kind": "assault", "x": 14180.0, "y": 552.0}, {"kind": "gunner", "x": 15120.0, "y": 552.0}],
			[{"kind": "elite", "x": 14600.0, "y": 540.0}, {"kind": "assault", "x": 15420.0, "y": 552.0}],
			[{"kind": "elite", "x": 14160.0, "y": 540.0}, {"kind": "shield", "x": 14900.0, "y": 552.0}, {"kind": "gunner", "x": 15720.0, "y": 552.0}],
		],
	},
]

const WAVE_SPAWN_DELAY := 0.68
const ENCOUNTER_STALL_REPOSITION_TIME := 30.0
const BOSS_ENTRY_X := 17840.0
const FIRST_RUN_TARGET_SECONDS := Vector2i(350, 460)
const SKILLED_TARGET_SECONDS := Vector2i(240, 360)

@onready var player: CharacterBody2D = $World/Player
@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera
@onready var enemies: Node2D = $World/Enemies
@onready var projectiles: Node2D = $World/Projectiles
@onready var effects: Node2D = $World/Effects
@onready var hazards: Node2D = $World/Hazards
@onready var grenades: Node2D = $World/Grenades
@onready var boss: CharacterBody2D = $World/Boss
@onready var boss_gate: StaticBody2D = $World/BossGate
@onready var boss_gate_visual: Polygon2D = $World/BossGateVisual
@onready var hud: CanvasLayer = $HUD
@onready var sfx: Node = $SFX

var enemies_remaining := 0
var score := 0
var run_state := "combat"
var _restart_pending := false
var combat_feedback
var _shot_visual_sequence := 0
var boss_summons_alive := 0
var _boss_defeat_pending := false
var telemetry: Node
var combat_pacing: Node
var mission_gate: StaticBody2D
var _mission_encounter_cursor := 0
var _active_mission_encounter := -1
var _active_wave_index := -1
var _active_wave_alive := 0
var _next_wave_delay := 0.0
var _encounter_stall_elapsed := 0.0
var _boss_resupply_granted := false
var _run_elapsed := 0.0
var _run_shots := 0
var _run_projectiles := 0
var _run_hits := 0
var _run_kills := 0
var _run_damage_events := 0
var _roll_tutorial_shown := false
var _grenade_tutorial_shown := false
var _active_ability_tutorial: StringName = &""
static var _resume_boss_checkpoint_next := false
static var _resume_run_stats_next: Dictionary = {}


func _ready() -> void:
	var resume_boss_checkpoint := _resume_boss_checkpoint_next
	_resume_boss_checkpoint_next = false
	if resume_boss_checkpoint and not _resume_run_stats_next.is_empty():
		_run_elapsed = float(_resume_run_stats_next.get("elapsed", 0.0))
		_run_shots = int(_resume_run_stats_next.get("shots", 0))
		_run_projectiles = int(_resume_run_stats_next.get("projectiles", 0))
		_run_hits = int(_resume_run_stats_next.get("hits", 0))
		_run_kills = int(_resume_run_stats_next.get("kills", 0))
		_run_damage_events = int(_resume_run_stats_next.get("damage_events", 0))
	_resume_run_stats_next = {}
	if OS.is_debug_build():
		telemetry = RunTelemetryScript.new()
		telemetry.name = "RunTelemetry"
		add_child(telemetry)
	combat_pacing = CombatPacingDirectorScript.new()
	combat_pacing.name = "CombatPacingDirector"
	add_child(combat_pacing)
	combat_feedback = CombatFeedbackScript.new()
	combat_feedback.name = "CombatFeedback"
	add_child(combat_feedback)
	combat_feedback.configure(camera)
	combat_feedback.shake_scale_changed.connect(_on_shake_scale_changed)
	player.add_to_group("player")
	player.volley_requested.connect(_spawn_player_volley)
	player.health_changed.connect(hud.set_health)
	player.ammo_changed.connect(hud.set_ammo)
	player.weapon_changed.connect(_on_weapon_changed)
	player.reload_stage.connect(_on_player_reload_stage)
	player.magazine_empty.connect(func(_weapon_id: StringName) -> void: sfx.play_cue(&"empty_click"))
	player.hurt.connect(_on_player_hurt)
	player.damage_received.connect(_on_player_damage_received)
	player.landed.connect(_on_player_landed)
	player.jumped.connect(_on_player_jumped)
	player.footstep.connect(_on_player_footstep)
	player.low_health.connect(func() -> void: sfx.play_cue(&"low_health"))
	player.roll_started.connect(_on_player_roll_started)
	player.roll_attempted.connect(func(success: bool) -> void:
		if telemetry != null:
			telemetry.record_roll_attempt(success)
	)
	player.projectile_evaded.connect(_on_player_projectile_evaded)
	player.grenade_requested.connect(_spawn_player_grenade)
	player.grenade_count_changed.connect(hud.set_grenade_count)
	player.grenade_empty.connect(func() -> void: sfx.play_cue(&"grenade_empty"))
	player.died.connect(_on_player_died)
	hud.restart_requested.connect(_restart_scene)
	hud.quit_requested.connect(func() -> void: get_tree().quit())
	hud.audio_adjust_requested.connect(_on_audio_adjust_requested)
	hud.audio_mute_requested.connect(_on_audio_mute_requested)
	hud.ui_cue_requested.connect(_on_ui_cue_requested)
	hud.pause_changed.connect(_on_pause_changed)
	sfx.mix_changed.connect(hud.set_audio_mix)
	hud.set_audio_mix(sfx.get_mix_snapshot())
	boss.shot_requested.connect(_spawn_projectile.bind(&"boss"))
	boss.hazard_requested.connect(_spawn_hazard.bind(&"boss"))
	boss.summon_requested.connect(_on_boss_summon_requested)
	boss.attack_telegraph_started.connect(_on_boss_telegraph)
	boss.attack_executed.connect(_on_boss_attack_executed)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.died.connect(_on_boss_died)
	_setup_mission()
	hud.set_health(player.health, player.MAX_HEALTH)
	var initial_weapon: Dictionary = player.weapon_inventory.get_current_data()
	if telemetry != null:
		telemetry.record_weapon_selected(player.current_weapon_id)
	hud.set_ammo(player.ammo, int(initial_weapon["magazine_size"]), false)
	hud.set_grenade_count(player.grenade_count)
	hud.set_weapon(player.current_weapon_id, initial_weapon)
	hud.set_score(score)
	hud.show_banner("DROP ZONE HOT", Color(1.0, 0.64, 0.24, 1))
	_update_objective()
	if resume_boss_checkpoint:
		run_state = "checkpoint_loading"
		call_deferred("_restore_boss_checkpoint")


func _process(_delta: float) -> void:
	if run_state not in ["dead", "complete"] and not get_tree().paused:
		_run_elapsed += _delta
	var active_count := 0
	var attacking_count := 0
	if run_state == "combat":
		_update_mission_flow(_delta)
		_update_ability_tutorials()
	for enemy in enemies.get_children():
		if bool(enemy.get("alive")) and bool(enemy.get("active")):
			active_count += 1
			if StringName(enemy.get("state")) in [&"telegraph", &"attack"]:
				attacking_count += 1
	if telemetry != null:
		telemetry.sample_pressure(active_count, maxi(attacking_count, combat_pacing.active_attack_count()))
	if Input.is_action_just_pressed("restart") and run_state != "combat":
		_restart_scene()
	if run_state == "boss_ready" and player.global_position.x >= BOSS_ENTRY_X:
		_start_boss_battle()


func _setup_mission() -> void:
	mission_gate = MissionGateScript.new()
	mission_gate.name = "MissionGate"
	mission_gate.z_index = 48
	world.add_child(mission_gate)
	_spawn_mission_interactions()


func _update_mission_flow(delta: float) -> void:
	if _active_mission_encounter < 0:
		if _mission_encounter_cursor < MISSION_ENCOUNTERS.size():
			var next_encounter: Dictionary = MISSION_ENCOUNTERS[_mission_encounter_cursor]
			if player.global_position.x >= float(next_encounter["trigger_x"]):
				_start_mission_encounter(_mission_encounter_cursor)
		return
	_encounter_stall_elapsed += delta
	if _next_wave_delay > 0.0:
		_next_wave_delay = maxf(_next_wave_delay - delta, 0.0)
		if is_zero_approx(_next_wave_delay):
			_spawn_next_wave()
	if _encounter_stall_elapsed >= ENCOUNTER_STALL_REPOSITION_TIME:
		_encounter_stall_elapsed = 0.0
		_recover_offscreen_enemies()


func _start_mission_encounter(encounter_index: int) -> void:
	_active_mission_encounter = encounter_index
	_active_wave_index = -1
	_active_wave_alive = 0
	_next_wave_delay = 0.0
	_encounter_stall_elapsed = 0.0
	var encounter: Dictionary = MISSION_ENCOUNTERS[encounter_index]
	mission_gate.global_position = Vector2(float(encounter["gate_x"]), 360.0)
	mission_gate.set_closed(true)
	hud.show_banner("SECTOR LOCK // %s" % str(encounter["title"]), Color(1.0, 0.64, 0.24, 1.0))
	_spawn_next_wave()


func _spawn_next_wave() -> void:
	if _active_mission_encounter < 0:
		return
	var encounter: Dictionary = MISSION_ENCOUNTERS[_active_mission_encounter]
	var waves: Array = encounter["waves"]
	_active_wave_index += 1
	if _active_wave_index >= waves.size():
		_complete_mission_encounter()
		return
	var wave: Array = waves[_active_wave_index]
	_active_wave_alive = wave.size()
	enemies_remaining = _active_wave_alive
	for entry_value in wave:
		var entry: Dictionary = entry_value
		var spawn_position := _safe_mission_spawn(Vector2(float(entry["x"]), float(entry["y"])), encounter)
		var enemy := _spawn_enemy(str(entry["kind"]), spawn_position, float(encounter["trigger_x"]), true, false, int(encounter["id"]))
		enemy.activate()
		if telemetry != null:
			telemetry.encounter_activated(int(encounter["id"]))
			telemetry.enemy_activated(enemy.get_instance_id())
	hud.show_banner("%s // WAVE %d OF %d" % [str(encounter["title"]), _active_wave_index + 1, waves.size()], Color(0.42, 0.92, 1.0, 1.0))
	_update_objective()


func _safe_mission_spawn(authored: Vector2, encounter: Dictionary) -> Vector2:
	var result := authored
	if absf(result.x - player.global_position.x) < 360.0:
		var direction := -1.0 if player.global_position.x > (float(encounter["trigger_x"]) + float(encounter["gate_x"])) * 0.5 else 1.0
		result.x = player.global_position.x + direction * 420.0
	result.x = clampf(result.x, float(encounter["trigger_x"]) + 180.0, float(encounter["gate_x"]) - 160.0)
	return result


func _complete_mission_encounter() -> void:
	var encounter: Dictionary = MISSION_ENCOUNTERS[_active_mission_encounter]
	mission_gate.set_closed(false)
	hud.show_banner("SECTOR CLEAR // %s" % str(encounter["title"]), Color(0.42, 1.0, 0.72, 1.0))
	_mission_encounter_cursor += 1
	_active_mission_encounter = -1
	_active_wave_index = -1
	_active_wave_alive = 0
	enemies_remaining = 0
	if _mission_encounter_cursor >= MISSION_ENCOUNTERS.size():
		run_state = "boss_ready"
		_grant_boss_resupply()
	_update_objective()


func _recover_offscreen_enemies() -> void:
	if _active_mission_encounter < 0:
		return
	var encounter: Dictionary = MISSION_ENCOUNTERS[_active_mission_encounter]
	var left := float(encounter["trigger_x"]) + 120.0
	var right := float(encounter["gate_x"]) - 120.0
	var recovered := 0
	var midpoint := (left + right) * 0.5
	var direction := -1.0 if player.global_position.x > midpoint else 1.0
	for enemy in enemies.get_children():
		if not bool(enemy.get("alive")) or not bool(enemy.get("active")) or bool(enemy.get_meta("boss_summon", false)):
			continue
		enemy.global_position = Vector2(clampf(player.global_position.x + direction * (440.0 + recovered * 90.0), left, right), 552.0)
		enemy.velocity = Vector2.ZERO
		recovered += 1
	if recovered > 0:
		hud.show_banner("TRACKING RECALIBRATED // %d HOSTILES" % recovered, Color(1.0, 0.78, 0.28, 1.0))


func _spawn_mission_interactions() -> void:
	_spawn_pickup(Vector2(5480, 548), &"grenade", 1, 0.0)
	_spawn_pickup(Vector2(7620, 548), &"health", 20, 0.0)
	_spawn_pickup(Vector2(10660, 548), &"ammo", 0, 0.35)
	_spawn_pickup(Vector2(13420, 548), &"health", 25, 0.0)
	_spawn_pickup(Vector2(16620, 548), &"ammo", 0, 0.45)
	for spike_data in [[8600.0, 72.0], [10000.0, 72.0], [12120.0, 72.0]]:
		var spikes := MissionSpikesScript.new()
		spikes.configure(float(spike_data[1]))
		spikes.global_position = Vector2(float(spike_data[0]), 574.0)
		world.add_child(spikes)
	for platform_data in [[8250.0, 520.0, -104.0, 3.5], [9400.0, 520.0, -132.0, 4.1]]:
		var moving_platform := MissionMovingPlatformScript.new()
		moving_platform.configure(Vector2(0, float(platform_data[2])), float(platform_data[3]))
		moving_platform.global_position = Vector2(float(platform_data[0]), float(platform_data[1]))
		world.add_child(moving_platform)


func _spawn_pickup(pickup_position: Vector2, kind: StringName, amount: int, ammo_floor: float) -> void:
	var pickup := MissionPickupScript.new()
	pickup.configure(kind, amount, ammo_floor)
	pickup.global_position = pickup_position
	pickup.collected.connect(_on_pickup_collected)
	world.add_child(pickup)


func _on_pickup_collected(kind: StringName, amount: int) -> void:
	var message := "FIELD MEDKIT // +%d HP" % amount
	if kind == &"ammo":
		message = "FIELD AMMO // MAGAZINES STABILIZED"
	elif kind == &"grenade":
		message = "FIELD ORDNANCE // +%d GRENADE" % amount
	hud.show_banner(message, Color(0.42, 1.0, 0.72, 1.0))
	sfx.play_cue(&"mission_start")


func _update_ability_tutorials() -> void:
	if not _roll_tutorial_shown and player.global_position.x >= 650.0:
		_roll_tutorial_shown = true
		_active_ability_tutorial = &"roll"
		hud.show_objective_update("DOUBLE-TAP A / D // ROLL THROUGH PROJECTILES", 4.5)
	elif not _grenade_tutorial_shown and player.global_position.x >= 1800.0:
		_grenade_tutorial_shown = true
		_active_ability_tutorial = &"grenade"
		hud.show_objective_update("HOLD RMB // CHARGE  •  RELEASE // THROW GRENADE", 4.5)


func _on_player_roll_started(_position: Vector2, _direction: int) -> void:
	sfx.play_cue(&"roll")
	if _active_ability_tutorial == &"roll":
		_active_ability_tutorial = &""
		hud.hide_objective()


func _spawn_enemy(kind: String, spawn_position: Vector2, activation: float, counts_for_progress: bool, boss_summon: bool, encounter_id: int = 0) -> Node:
	var enemy := EnemyScene.instantiate()
	enemy.kind = kind
	enemy.target = player
	enemy.position = spawn_position
	enemy.activation_x = activation
	enemy.attack_coordinator = combat_pacing
	enemy.active = boss_summon
	enemy.set_meta("counts_for_progress", counts_for_progress)
	enemy.set_meta("boss_summon", boss_summon)
	enemy.set_meta("encounter_id", encounter_id)
	enemy.shot_requested.connect(_spawn_projectile.bind(StringName(kind)))
	enemy.hazard_requested.connect(_spawn_hazard.bind(&"elite"))
	enemy.attack_telegraph_started.connect(_on_enemy_telegraph)
	enemy.attack_executed.connect(_on_enemy_attack_executed)
	enemy.hurt_feedback.connect(_on_enemy_hurt_feedback)
	enemy.movement_step.connect(_on_enemy_movement_step)
	enemy.blocked.connect(_on_shield_blocked)
	enemy.died.connect(_on_enemy_died)
	enemies.add_child(enemy)
	if boss_summon:
		enemy.attack_cooldown = 1.10
	if telemetry != null:
		telemetry.register_enemy(encounter_id, kind, enemy.get_instance_id())
		if boss_summon:
			telemetry.enemy_activated(enemy.get_instance_id())
	if boss_summon:
		boss_summons_alive += 1
	return enemy


func _spawn_projectile(origin: Vector2, direction: Vector2, team: StringName, damage: int, speed: float, source: StringName = &"enemy") -> void:
	if run_state == "complete":
		return
	var projectile := ProjectileScene.instantiate()
	projectile.configure(origin, direction, team, damage, speed, {"source_tag": source})
	projectile.impact_detailed.connect(_on_projectile_impact_detailed)
	projectiles.add_child(projectile)
	if team == &"player":
		combat_feedback.request_shake(&"rifle_shot", &"generic_player_shot")
		camera.add_recoil(direction, Tuning.PLAYER_SHOT_RECOIL_PIXELS)
		sfx.play_cue(&"rifle_accent" if damage >= Tuning.WEAPON_ACCENT_DAMAGE else &"rifle")
	else:
		combat_feedback.request_shake(&"enemy_shot")
		sfx.play_world_cue(&"boss_cannon" if source == &"boss" else &"enemy_shot", origin, player.global_position, source == &"boss")


func _spawn_player_grenade(origin: Vector2, initial_velocity: Vector2, charge: float = 0.0) -> void:
	if run_state in ["dead", "complete", "boss_defeated"]:
		return
	var grenade := PlayerGrenadeScript.new()
	grenades.add_child(grenade)
	grenade.configure(origin, initial_velocity, {
		"gravity": Tuning.GRENADE_GRAVITY,
		"fuse": Tuning.GRENADE_FUSE,
		"bounce_damping": Tuning.GRENADE_BOUNCE_DAMPING,
		"max_bounces": Tuning.GRENADE_MAX_BOUNCES,
		"radius": Tuning.GRENADE_RADIUS,
		"damage": Tuning.GRENADE_DAMAGE,
		"knockback": Tuning.GRENADE_KNOCKBACK,
	})
	grenade.bounced.connect(func(position: Vector2, strength: float) -> void:
		sfx.play_world_cue(&"grenade_bounce", position, player.global_position, false, -2.0 + strength * 2.0)
	)
	grenade.fuse_tick.connect(func(position: Vector2, urgency: float) -> void:
		sfx.play_world_cue(&"grenade_fuse", position, player.global_position, false, lerpf(-2.0, 1.2, urgency))
	)
	grenade.exploded.connect(_on_player_grenade_exploded)
	if telemetry != null:
		telemetry.record_grenade_throw(charge)
	sfx.play_cue(&"grenade_throw")


func _on_player_grenade_exploded(center: Vector2, radius: float, damage: int, knockback: float) -> void:
	if _active_ability_tutorial == &"grenade":
		_active_ability_tutorial = &""
		hud.hide_objective()
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 4
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var resolved_targets: Dictionary = {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var target := hit.get("collider") as Node
		if target == null or resolved_targets.has(target.get_instance_id()) or not target.has_method("take_damage"):
			continue
		if not target.is_in_group("enemies") and not target.is_in_group("boss"):
			continue
		resolved_targets[target.get_instance_id()] = true
		var distance_ratio := clampf(center.distance_to(target.global_position) / maxf(radius, 1.0), 0.0, 1.0)
		var applied_request := maxi(1, int(round(float(damage) * lerpf(1.0, Tuning.GRENADE_EDGE_DAMAGE_MULTIPLIER, distance_ratio))))
		var health_before := int(target.get("health"))
		var alive_before := bool(target.get("alive")) if target.get("alive") != null else health_before > 0
		var direction: Vector2 = (target.global_position - center).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.UP
		target.take_damage(applied_request, direction * knockback, center, {
			"weapon_id": &"grenade",
			"team": &"player",
			"direction": direction,
			"impact_strength": 1.0,
			"source": &"grenade",
			"damage_kind": &"explosion",
		})
		if telemetry != null:
			var health_after := int(target.get("health"))
			var alive_after := bool(target.get("alive")) if target.get("alive") != null else health_after > 0
			var target_type := "boss" if target.is_in_group("boss") else str(target.get("kind"))
			telemetry.record_grenade_hit(target_type, maxi(health_before - health_after, 0), alive_before and not alive_after)
	var effect := GrenadeExplosionScript.new()
	effects.add_child(effect)
	effect.configure(center, radius)
	sfx.play_world_cue(&"grenade_explosion", center, player.global_position, true)
	combat_feedback.request_shake(&"grenade_explosion", &"grenade_explosion")


func _on_player_projectile_evaded(hit_position: Vector2, direction: Vector2) -> void:
	_spawn_impact(hit_position, Color("6ee7ff"), 0.42, false, &"block", -direction)
	sfx.play_world_cue(&"projectile_evade", hit_position, player.global_position, false)
	if telemetry != null:
		telemetry.record_projectile_dodge()


func _spawn_player_volley(origin: Vector2, directions: Array[Vector2], team: StringName, weapon_data: Dictionary, damage: int) -> void:
	if run_state == "complete":
		return
	var weapon_id: StringName = weapon_data["id"]
	if telemetry != null:
		telemetry.record_shot(weapon_id, directions.size())
	_run_shots += 1
	_run_projectiles += directions.size()
	var falloff: Dictionary = weapon_data["damage_falloff"]
	var options := {
		"weapon_id": weapon_id,
		"max_range": weapon_data["max_range"],
		"falloff_start": falloff["start"],
		"minimum_damage_multiplier": falloff["minimum_multiplier"],
		"penetration_count": weapon_data["penetration_count"],
		"penetrate_heavy": weapon_data["penetrate_heavy"],
		"knockback": weapon_data["knockback"],
		"impact_strength": weapon_data["impact_strength"],
		"color": weapon_data["color"],
	}
	for shot_direction in directions:
		var projectile := ProjectileScene.instantiate()
		projectile.configure(origin, shot_direction, team, damage, float(weapon_data["projectile_speed"]), options)
		projectile.impact_detailed.connect(_on_projectile_impact_detailed)
		projectiles.add_child(projectile)
	combat_feedback.request_shake(StringName("%s_shot" % weapon_id), StringName("%s_volley" % weapon_id))
	camera.add_recoil(directions[0] if not directions.is_empty() else Vector2.RIGHT, float(weapon_data["camera_recoil"]))
	_spawn_casing(origin, directions[0] if not directions.is_empty() else Vector2.RIGHT, weapon_id)
	var cue: StringName = weapon_id
	if weapon_id == &"rifle":
		cue = &"accent_shot" if damage >= Tuning.WEAPON_ACCENT_DAMAGE else &"shot"
	sfx.play_cue(cue)
	match weapon_id:
		&"rifle":
			if player.weapon_inventory.shot_sequence % 2 == 0:
				sfx.play_cue(&"rifle_mechanic")
		&"shotgun":
			sfx.play_cue_delayed(&"shotgun_pump", 0.15)
		&"sniper":
			sfx.play_cue_delayed(&"sniper_bolt", 0.17)
		&"pistol":
			sfx.play_cue_delayed(&"pistol_slide", 0.045)


func _on_projectile_impact(hit_position: Vector2, color: Color, strength: float, weapon_id: StringName = &"") -> void:
	_on_projectile_impact_detailed(hit_position, color, strength, {
		"weapon_id": weapon_id,
		"team": &"player",
		"can_damage": strength >= Tuning.NORMAL_HIT_STRENGTH,
		"is_boss": false,
		"feedback": &"normal",
		"direction": Vector2.RIGHT,
		"distance": 0.0,
		"max_range": 1.0,
		"penetration_index": 0,
	})


func _on_projectile_impact_detailed(hit_position: Vector2, color: Color, strength: float, details: Dictionary) -> void:
	var team: StringName = details.get("team", &"player")
	var weapon_id: StringName = details.get("weapon_id", &"")
	var feedback: StringName = details.get("feedback", &"normal")
	var can_damage := bool(details.get("can_damage", false))
	if telemetry != null and team == &"player" and can_damage:
		telemetry.record_hit(weapon_id, int(details.get("applied_damage", 0)), feedback)
	if team == &"player" and can_damage:
		_run_hits += 1
	var direction: Vector2 = details.get("direction", Vector2.RIGHT)
	if feedback in [&"block", &"guard_break", &"kill"]:
		return
	var profile: StringName = &"wall_hit"
	var effect_kind: StringName = &"wall"
	var effect_strength := strength
	if can_damage:
		if bool(details.get("is_boss", false)):
			profile = &"boss_heavy" if feedback == &"boss_heavy" else &"boss_normal"
			effect_kind = profile
		elif feedback == &"heavy" or weapon_id == &"sniper":
			profile = &"sniper_hit" if weapon_id == &"sniper" else &"heavy_hit"
			effect_kind = &"sniper" if weapon_id == &"sniper" else &"heavy"
		elif weapon_id == &"shotgun":
			profile = &"shotgun_hit"
			effect_kind = &"shotgun"
			var range_ratio := float(details.get("distance", 0.0)) / maxf(float(details.get("max_range", 1.0)), 1.0)
			effect_strength *= lerpf(1.0, 0.58, clampf(range_ratio, 0.0, 1.0))
		else:
			profile = &"heavy_hit" if strength >= Tuning.ACCENT_HIT_STRENGTH else &"normal_hit"
			effect_kind = &"heavy" if profile == &"heavy_hit" else &"normal"
	var merge_group: StringName = profile
	if weapon_id == &"shotgun":
		merge_group = &"shotgun_impact_volley"
	elif weapon_id == &"sniper":
		merge_group = &"sniper_penetration_trace"
	var hold: float = float(combat_feedback.request_visual_hold(profile, merge_group))
	_spawn_impact(hit_position, color, effect_strength, false, effect_kind, direction, hold)
	if team != &"player":
		return
	if not combat_feedback.request_shake(profile, merge_group):
		return
	if profile == &"boss_heavy":
		sfx.play_world_cue(&"boss_hit_heavy", hit_position, player.global_position, true)
	elif profile == &"boss_normal":
		sfx.play_world_cue(&"boss_hit_normal", hit_position, player.global_position)
	elif profile in [&"sniper_hit", &"heavy_hit"]:
		sfx.play_world_cue(&"impact_heavy", hit_position, player.global_position, true)
	elif profile == &"wall_hit":
		sfx.play_world_cue(&"impact_wall", hit_position, player.global_position)
	else:
		sfx.play_world_cue(&"impact_normal", hit_position, player.global_position)


func _on_weapon_changed(weapon_id: StringName, weapon_data: Dictionary) -> void:
	hud.set_weapon(weapon_id, weapon_data)
	if telemetry != null:
		telemetry.record_weapon_selected(weapon_id)
	sfx.play_cue(&"weapon_switch")


func _spawn_impact(
	effect_position: Vector2,
	color: Color,
	strength: float,
	large: bool,
	kind: StringName = &"normal",
	direction: Vector2 = Vector2.ZERO,
	visual_hold: float = 0.0,
) -> void:
	var effect := ImpactEffectScene.instantiate()
	effect.global_position = effect_position
	effect.configure(color, strength, large, kind, direction, visual_hold)
	effects.add_child(effect)


func _spawn_casing(origin: Vector2, direction: Vector2, weapon_id: StringName) -> void:
	_shot_visual_sequence += 1
	if weapon_id == &"rifle" and _shot_visual_sequence % 2 != 0:
		return
	var existing := get_tree().get_nodes_in_group("combat_casings")
	if existing.size() >= 12:
		existing[0].free()
	var casing := PixelCasingScene.instantiate()
	casing.configure(origin, direction, weapon_id, _shot_visual_sequence)
	effects.add_child(casing)


func _on_enemy_died(enemy: Node, points: int) -> void:
	if telemetry != null:
		telemetry.enemy_defeated(int(enemy.get_meta("encounter_id", 0)), enemy.get_instance_id())
	if bool(enemy.get_meta("counts_for_progress", false)):
		_encounter_stall_elapsed = 0.0
		enemies_remaining = maxi(enemies_remaining - 1, 0)
		_active_wave_alive = maxi(_active_wave_alive - 1, 0)
		if _active_wave_alive == 0 and _active_mission_encounter >= 0:
			var encounter: Dictionary = MISSION_ENCOUNTERS[_active_mission_encounter]
			var waves: Array = encounter["waves"]
			if _active_wave_index + 1 >= waves.size():
				_complete_mission_encounter()
			else:
				_next_wave_delay = WAVE_SPAWN_DELAY
	if bool(enemy.get_meta("boss_summon", false)):
		boss_summons_alive = maxi(boss_summons_alive - 1, 0)
	_run_kills += 1
	score += points
	hud.set_score(score)
	var heavy_death := str(enemy.get("kind")) in ["elite", "heavy", "shield"]
	var death_profile: StringName = &"kill_heavy" if heavy_death else &"kill_light"
	_spawn_impact(enemy.global_position, Color(1.0, 0.32, 0.16, 1), 0.8 if heavy_death else 0.62, true, death_profile)
	sfx.play_world_cue(&"enemy_kill_heavy" if heavy_death else &"enemy_kill_light", enemy.global_position, player.global_position, heavy_death)
	combat_feedback.request_shake(death_profile, StringName("death_%s" % enemy.get_instance_id()))
	if run_state in ["combat", "boss_ready"]:
		_update_objective()


func _on_player_hurt(amount: int) -> void:
	combat_feedback.request_shake(&"player_hurt", &"player_hurt")
	_spawn_impact(player.global_position, Color(1.0, 0.24, 0.18, 1), 0.35, false, &"player_hurt")
	sfx.play_cue(&"player_hurt")


func _on_player_damage_received(amount: int, context: Dictionary) -> void:
	_run_damage_events += 1
	if telemetry != null:
		telemetry.record_player_damage(amount, context)


func _on_player_landed(landing_position: Vector2, intensity: float) -> void:
	_spawn_impact(landing_position, Color(0.28, 0.78, 0.66, 0.8), 0.34 * intensity, false, &"land")
	combat_feedback.request_shake(&"land", &"player_land")
	sfx.play_cue(&"heavy_land" if intensity >= 0.78 else &"land", clampf((intensity - 1.0) * 2.0, -2.0, 2.0))


func _on_player_jumped(_jump_position: Vector2) -> void:
	sfx.play_cue(&"jump")


func _on_player_footstep(_step_position: Vector2, intensity: float, side: int) -> void:
	sfx.play_cue(&"footstep", -1.0 + intensity + (0.25 if side == 1 else 0.0))


func _on_player_reload_stage(stage: StringName, weapon_id: StringName) -> void:
	match stage:
		&"start":
			sfx.play_cue(StringName("%s_reload" % weapon_id))
		&"insert":
			sfx.play_cue(&"mag_insert", 0.8 if weapon_id == &"shotgun" else 0.0)
		&"complete":
			sfx.play_cue(&"reload_complete")


func _on_enemy_telegraph(enemy: Node, _duration: float) -> void:
	var kind := str(enemy.get("kind"))
	sfx.play_world_cue(&"elite_warning" if kind in ["elite", "heavy"] else &"enemy_warning", enemy.global_position, player.global_position, true)


func _on_enemy_attack_executed(enemy: Node, attack_kind: StringName) -> void:
	var kind := str(enemy.get("kind"))
	var cue: StringName = &""
	if attack_kind == &"melee":
		cue = &"shield_bash" if kind == "shield" else &"assault_swing"
	elif kind in ["elite", "heavy"]:
		cue = &"elite_attack"
	if cue != &"":
		sfx.play_world_cue(cue, enemy.global_position, player.global_position, true)


func _on_enemy_hurt_feedback(enemy: Node, feedback: StringName) -> void:
	var cue := &"enemy_hurt_heavy" if feedback == &"heavy" else &"enemy_hurt"
	sfx.play_world_cue(cue, enemy.global_position, player.global_position, feedback == &"heavy")


func _on_enemy_movement_step(enemy: Node, intensity: float) -> void:
	sfx.play_world_cue(&"elite_step", enemy.global_position, player.global_position, false, -1.0 + intensity)


func _on_shield_blocked(hit_position: Vector2, strength: float) -> void:
	var broken := strength >= 0.8
	var profile: StringName = &"guard_break" if broken else &"guard_block"
	var effect_kind: StringName = &"guard_break" if broken else &"block"
	var hold: float = float(combat_feedback.request_visual_hold(profile, &"shield_response"))
	_spawn_impact(hit_position, Color(1.0, 0.58, 0.20, 1.0) if broken else Color(0.28, 0.92, 1.0, 1), strength, false, effect_kind, Vector2.UP, hold)
	sfx.play_world_cue(&"guard_break" if broken else &"shield_block", hit_position, player.global_position, broken)
	combat_feedback.request_shake(profile, &"shield_response")


func _spawn_hazard(hazard_position: Vector2, radius: float, damage: int, windup: float, source: StringName) -> void:
	if run_state in ["dead", "complete", "boss_defeated"]:
		return
	var hazard := GroundHazardScene.instantiate()
	hazard.configure(hazard_position, radius, damage, windup, player, source)
	hazards.add_child(hazard)
	sfx.play_world_cue(&"hazard", hazard_position, player.global_position, true)


func _on_player_died() -> void:
	if _restart_pending:
		return
	var boss_checkpoint := run_state == "boss"
	_resume_boss_checkpoint_next = boss_checkpoint
	_resume_run_stats_next = {
		"elapsed": _run_elapsed,
		"shots": _run_shots,
		"projectiles": _run_projectiles,
		"hits": _run_hits,
		"kills": _run_kills,
		"damage_events": _run_damage_events,
	} if boss_checkpoint else {}
	for grenade in grenades.get_children():
		grenade.queue_free()
	run_state = "dead"
	if telemetry != null:
		telemetry.record_death(player.global_position)
	_restart_pending = true
	combat_feedback.request_shake(&"player_death", &"player_death")
	var hold: float = float(combat_feedback.request_visual_hold(&"player_death", &"player_death"))
	_spawn_impact(player.global_position, Color(1.0, 0.2, 0.12, 1), 1.1, true, &"player_death", Vector2.UP, hold)
	sfx.play_cue(&"player_death")
	sfx.duck_music(0.55, 5.0)
	hud.show_death(boss_checkpoint, player.last_damage_source)
	await get_tree().create_timer(Tuning.DEATH_RESTART_DELAY).timeout
	_restart_scene()


func _complete_run() -> void:
	if run_state == "complete":
		return
	run_state = "complete"
	_resume_boss_checkpoint_next = false
	_resume_run_stats_next = {}
	if telemetry != null:
		telemetry.finish(&"complete")
	player.controls_enabled = false
	score += 1000
	hud.set_score(score)
	var accuracy := int(round(clampf(float(_run_hits) / float(maxi(_run_projectiles, 1)), 0.0, 1.0) * 100.0))
	var rank := _calculate_mission_rank(_run_elapsed, accuracy, _run_damage_events)
	hud.show_settlement(score, player.health, {
		"elapsed": _run_elapsed,
		"kills": _run_kills,
		"accuracy": accuracy,
		"damage_events": _run_damage_events,
		"rank": rank,
	})
	combat_feedback.request_shake(&"complete", &"complete")
	sfx.stop_music(0.45)
	sfx.play_cue(&"mission_complete")


func _update_objective() -> void:
	if run_state == "combat":
		if _active_mission_encounter >= 0:
			var encounter: Dictionary = MISSION_ENCOUNTERS[_active_mission_encounter]
			var waves: Array = encounter["waves"]
			hud.set_objective("%s  •  WAVE %d/%d  •  HOSTILES %02d" % [str(encounter["title"]), _active_wave_index + 1, waves.size(), enemies_remaining])
		else:
			var section := mini(_mission_encounter_cursor + 1, MISSION_ENCOUNTERS.size())
			hud.set_objective("ADVANCE TO SECTOR %d/%d" % [section, MISSION_ENCOUNTERS.size()])
	elif run_state == "boss_ready":
		hud.set_objective("COMMAND CORE OPEN  •  ADVANCE TO THE ARENA")


func _start_boss_battle() -> void:
	if run_state != "boss_ready":
		return
	run_state = "boss"
	combat_pacing.set_boss_mode(true)
	boss_gate.collision_layer = 1
	boss_gate_visual.visible = true
	boss.activate(player)
	if telemetry != null:
		telemetry.boss_started()
	hud.begin_boss_intro(boss.boss_name, boss.MAX_HEALTH)
	combat_feedback.request_shake(&"boss_intro", &"boss_intro")
	sfx.play_music(&"boss", 0.48)
	sfx.play_cue(&"boss_intro")
	sfx.play_world_cue_delayed(&"boss_land", 0.20, boss.global_position, player.global_position, true)
	sfx.duck_music(0.42, 5.0)


func _on_boss_health_changed(current: int, maximum: int, phase: int) -> void:
	if run_state == "boss":
		hud.set_boss_health(current, maximum, phase)


func _on_boss_phase_changed(phase: int) -> void:
	if telemetry != null:
		telemetry.boss_phase_changed(phase)
	_clear_hostile_dangers()
	hud.show_boss_phase(phase)
	sfx.play_world_cue(&"boss_phase_2" if phase == 2 else &"boss_phase_3", boss.global_position, player.global_position, true)
	sfx.duck_music(0.38, 5.0)
	combat_feedback.request_shake(&"boss_phase", &"boss_phase")


func _on_boss_telegraph(attack_name: StringName, duration: float) -> void:
	combat_pacing.suspend_boss_support(duration + 0.60)
	var cue := {
		&"volley": &"boss_warning_volley",
		&"charge": &"boss_warning_charge",
		&"area": &"boss_warning_area",
	}.get(attack_name, &"boss_warning_volley") as StringName
	sfx.play_world_cue(cue, boss.global_position, player.global_position, true)


func _on_boss_attack_executed(attack_name: StringName) -> void:
	if attack_name == &"charge":
		sfx.play_world_cue(&"boss_charge_release", boss.global_position, player.global_position, true)
	elif attack_name == &"area":
		sfx.play_world_cue(&"boss_area_release", boss.global_position, player.global_position, true)


func _on_boss_summon_requested(spawn_position: Vector2, kind: String) -> void:
	if run_state != "boss" or boss_summons_alive >= 2:
		return
	_spawn_enemy(kind, spawn_position, 0.0, false, true)


func _on_boss_died(_boss: Node) -> void:
	if _boss_defeat_pending:
		return
	_boss_defeat_pending = true
	_run_kills += 1
	combat_pacing.set_boss_mode(false)
	run_state = "boss_defeated"
	_clear_hostile_dangers()
	for grenade in grenades.get_children():
		grenade.queue_free()
	for enemy in enemies.get_children():
		if bool(enemy.get_meta("boss_summon", false)):
			enemy.queue_free()
	boss_summons_alive = 0
	boss_gate.collision_layer = 0
	boss_gate_visual.visible = false
	hud.set_boss_health(0, boss.MAX_HEALTH, 3)
	hud.show_boss_defeated()
	sfx.stop_bus_cues(&"Boss")
	sfx.play_world_cue(&"boss_failure", boss.global_position, player.global_position, true)
	sfx.duck_music(0.72, 6.0)
	combat_feedback.request_shake(&"boss_death", &"boss_death")
	await get_tree().create_timer(0.18).timeout
	sfx.play_world_cue(&"boss_explosion", boss.global_position + Vector2(-38, -28), player.global_position, true)
	await get_tree().create_timer(0.20).timeout
	sfx.play_world_cue(&"boss_explosion", boss.global_position + Vector2(42, 2), player.global_position, true)
	await get_tree().create_timer(0.22).timeout
	sfx.play_world_cue(&"boss_death", boss.global_position, player.global_position, true)
	await get_tree().create_timer(0.25).timeout
	sfx.play_world_cue(&"boss_core_off", boss.global_position, player.global_position, true)
	hud.hide_boss()
	_complete_run()


func _clear_hostile_dangers() -> void:
	for projectile in projectiles.get_children():
		if projectile.team == &"enemy":
			projectile.queue_free()
	for hazard in hazards.get_children():
		hazard.queue_free()


func _restart_scene() -> void:
	get_tree().paused = false
	if not _resume_boss_checkpoint_next:
		_resume_run_stats_next = {}
	if combat_feedback != null:
		combat_feedback.clear()
	get_tree().reload_current_scene()


func _debug_unlock_boss_for_tests() -> void:
	if not OS.is_debug_build():
		return
	for enemy in enemies.get_children():
		enemy.free()
	_mission_encounter_cursor = MISSION_ENCOUNTERS.size()
	_active_mission_encounter = -1
	_active_wave_index = -1
	_active_wave_alive = 0
	_next_wave_delay = 0.0
	enemies_remaining = 0
	mission_gate.set_closed(false)
	run_state = "boss_ready"
	_grant_boss_resupply()
	_update_objective()


func _grant_boss_resupply(full_restore: bool = false) -> void:
	if _boss_resupply_granted:
		return
	_boss_resupply_granted = true
	player.apply_field_resupply(
		player.MAX_HEALTH if full_restore else Tuning.BOSS_RESUPPLY_HEALTH,
		1.0 if full_restore else Tuning.BOSS_RESUPPLY_AMMO_FLOOR,
		Tuning.PLAYER_GRENADE_COUNT if full_restore else Tuning.BOSS_RESUPPLY_GRENADES,
	)
	var ammo_percent := 100 if full_restore else int(Tuning.BOSS_RESUPPLY_AMMO_FLOOR * 100.0)
	hud.show_banner("COMMAND CACHE // HP RESTORED  •  AMMO %d%%  •  GRENADES" % ammo_percent, Color(0.42, 1.0, 0.72, 1.0))


func _restore_boss_checkpoint() -> void:
	for enemy in enemies.get_children():
		enemy.free()
	enemies_remaining = 0
	_mission_encounter_cursor = MISSION_ENCOUNTERS.size()
	_active_mission_encounter = -1
	_active_wave_alive = 0
	_next_wave_delay = 0.0
	mission_gate.set_closed(false)
	player.global_position = Vector2(17850.0, 552.0)
	run_state = "boss_ready"
	_grant_boss_resupply(true)
	_update_objective()
	_start_boss_battle()


func _on_shake_scale_changed(scale: float) -> void:
	var label := "SHAKE OFF" if is_zero_approx(scale) else "SHAKE %d%%" % int(round(scale * 100.0))
	hud.show_banner(label, Color(0.42, 0.92, 1.0, 1.0))


func _on_audio_adjust_requested(bus_name: StringName, delta_steps: int) -> void:
	sfx.adjust_bus_step(bus_name, delta_steps)


func _calculate_mission_rank(elapsed: float, accuracy: int, damage_events: int) -> String:
	if elapsed <= 360.0 and accuracy >= 55 and damage_events <= 5:
		return "S"
	if elapsed <= 480.0 and accuracy >= 40 and damage_events <= 10:
		return "A"
	if elapsed <= 600.0 and damage_events <= 16:
		return "B"
	return "C"


func _on_audio_mute_requested(bus_name: StringName) -> void:
	sfx.toggle_bus_mute(bus_name)


func _on_ui_cue_requested(cue: StringName) -> void:
	sfx.play_cue(cue)


func _on_pause_changed(paused: bool) -> void:
	if paused:
		player.cancel_transient_actions()
	sfx.set_game_paused(paused)
