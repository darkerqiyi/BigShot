extends Node
class_name RunTelemetry

# Local, debug-build-only session metrics. Nothing is written to disk or sent anywhere.

var elapsed := 0.0
var weapon_stats: Dictionary = {}
var damage_sources: Dictionary = {}
var encounters: Dictionary = {}
var boss_phase_started: Dictionary = {}
var boss_phase_durations: Dictionary = {}
var deaths: Array[Dictionary] = []
var damage_event_count := 0
var max_active_enemies := 0
var max_attacking_enemies := 0
var active_encounter_id := 0
var boss_started_at := -1.0
var finished_at := -1.0
var _last_damage_source := "unknown"
var _printed := false
var _current_weapon: StringName = &""
var _enemy_activated_at: Dictionary = {}
var _enemy_kinds: Dictionary = {}
var enemy_lifetimes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for weapon_id in [&"rifle", &"shotgun", &"sniper", &"pistol"]:
		weapon_stats[weapon_id] = {"shots": 0, "projectiles": 0, "hits": 0, "damage": 0, "kills": 0, "active_seconds": 0.0}


func _process(delta: float) -> void:
	if not get_tree().paused and finished_at < 0.0:
		elapsed += delta
		if _current_weapon != &"":
			var stats := _weapon_entry(_current_weapon)
			stats["active_seconds"] = float(stats["active_seconds"]) + delta


func register_enemy(encounter_id: int, kind: String, instance_id: int) -> void:
	_enemy_kinds[instance_id] = kind
	if not enemy_lifetimes.has(kind):
		enemy_lifetimes[kind] = []
	if encounter_id <= 0:
		return
	var entry: Dictionary = encounters.get(encounter_id, {
		"spawned": 0,
		"defeated": 0,
		"kinds": [],
		"started_at": -1.0,
		"completed_at": -1.0,
	})
	entry["spawned"] = int(entry["spawned"]) + 1
	entry["completed_at"] = -1.0
	(entry["kinds"] as Array).append(kind)
	encounters[encounter_id] = entry


func encounter_activated(encounter_id: int) -> void:
	if encounter_id <= 0 or not encounters.has(encounter_id):
		return
	var entry: Dictionary = encounters[encounter_id]
	if float(entry["started_at"]) < 0.0:
		entry["started_at"] = elapsed
	active_encounter_id = encounter_id


func enemy_activated(instance_id: int) -> void:
	if not _enemy_activated_at.has(instance_id):
		_enemy_activated_at[instance_id] = elapsed


func enemy_defeated(encounter_id: int, instance_id: int) -> void:
	if _enemy_activated_at.has(instance_id):
		var kind := str(_enemy_kinds.get(instance_id, "unknown"))
		var samples: Array = enemy_lifetimes.get(kind, [])
		samples.append(snappedf(elapsed - float(_enemy_activated_at[instance_id]), 0.01))
		enemy_lifetimes[kind] = samples
	_enemy_activated_at.erase(instance_id)
	_enemy_kinds.erase(instance_id)
	if encounter_id <= 0 or not encounters.has(encounter_id):
		return
	var entry: Dictionary = encounters[encounter_id]
	entry["defeated"] = int(entry["defeated"]) + 1
	if int(entry["defeated"]) >= int(entry["spawned"]):
		entry["completed_at"] = elapsed


func record_weapon_selected(weapon_id: StringName) -> void:
	_current_weapon = weapon_id
	_weapon_entry(weapon_id)


func record_shot(weapon_id: StringName, projectile_count: int = 1) -> void:
	var stats := _weapon_entry(weapon_id)
	stats["shots"] = int(stats["shots"]) + 1
	stats["projectiles"] = int(stats["projectiles"]) + maxi(projectile_count, 1)


func record_hit(weapon_id: StringName, applied_damage: int, feedback: StringName) -> void:
	if weapon_id == &"" or applied_damage <= 0:
		return
	var stats := _weapon_entry(weapon_id)
	stats["hits"] = int(stats["hits"]) + 1
	stats["damage"] = int(stats["damage"]) + applied_damage
	if feedback == &"kill":
		stats["kills"] = int(stats["kills"]) + 1


func record_player_damage(amount: int, context: Dictionary) -> void:
	damage_event_count += 1
	var source := str(context.get("source", "unknown"))
	_last_damage_source = source
	damage_sources[source] = int(damage_sources.get(source, 0)) + amount


func record_death(position: Vector2) -> void:
	deaths.append({
		"time": snappedf(elapsed, 0.01),
		"position": [snappedf(position.x, 1.0), snappedf(position.y, 1.0)],
		"source": _last_damage_source,
	})
	finish(&"death")


func sample_pressure(active_count: int, attacking_count: int) -> void:
	max_active_enemies = maxi(max_active_enemies, active_count)
	max_attacking_enemies = maxi(max_attacking_enemies, attacking_count)


func boss_started() -> void:
	boss_started_at = elapsed
	boss_phase_started[1] = elapsed


func boss_phase_changed(phase: int) -> void:
	var previous := phase - 1
	if boss_phase_started.has(previous):
		boss_phase_durations[previous] = elapsed - float(boss_phase_started[previous])
	boss_phase_started[phase] = elapsed


func finish(reason: StringName = &"complete") -> void:
	if finished_at >= 0.0:
		return
	finished_at = elapsed
	if boss_phase_started.has(3) and not boss_phase_durations.has(3):
		boss_phase_durations[3] = elapsed - float(boss_phase_started[3])
	print_summary(reason)


func get_snapshot() -> Dictionary:
	var encounter_snapshot := {}
	for encounter_id in encounters:
		var entry: Dictionary = encounters[encounter_id].duplicate(true)
		var start := float(entry["started_at"])
		var end := float(entry["completed_at"])
		entry["duration"] = snappedf(end - start, 0.01) if start >= 0.0 and end >= start else -1.0
		encounter_snapshot[encounter_id] = entry
	var phase_snapshot := {}
	for phase in boss_phase_durations:
		phase_snapshot[phase] = snappedf(float(boss_phase_durations[phase]), 0.01)
	return {
		"elapsed": snappedf(elapsed, 0.01),
		"weapons": weapon_stats.duplicate(true),
		"damage_sources": damage_sources.duplicate(true),
		"damage_events": damage_event_count,
		"deaths": deaths.duplicate(true),
		"encounters": encounter_snapshot,
		"active_encounter": active_encounter_id,
		"enemy_lifetimes": enemy_lifetimes.duplicate(true),
		"max_active_enemies": max_active_enemies,
		"max_attacking_enemies": max_attacking_enemies,
		"boss_started_at": snappedf(boss_started_at, 0.01),
		"boss_phase_durations": phase_snapshot,
	}


func print_summary(reason: StringName) -> void:
	if _printed:
		return
	_printed = true
	print("BALANCE_SESSION_SUMMARY %s %s" % [reason, JSON.stringify(get_snapshot())])


func _weapon_entry(weapon_id: StringName) -> Dictionary:
	if not weapon_stats.has(weapon_id):
		weapon_stats[weapon_id] = {"shots": 0, "projectiles": 0, "hits": 0, "damage": 0, "kills": 0, "active_seconds": 0.0}
	return weapon_stats[weapon_id]
