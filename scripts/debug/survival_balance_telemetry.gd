extends Node
class_name SurvivalBalanceTelemetry

# Debug-build-only, in-memory survival pacing evidence. This node never writes
# telemetry to disk or sends data outside the running Godot process.

var _player: Node
var _run_telemetry: Node
var _waves: Dictionary = {}
var _current_wave := 0
var _run_started_at := 0.0
var _last_elapsed := 0.0
var _printed := false


func configure(player: Node, run_telemetry: Node, elapsed: float = 0.0) -> void:
	_player = player
	_run_telemetry = run_telemetry
	_run_started_at = elapsed
	_last_elapsed = elapsed


func begin_wave(wave_number: int, title: String, elapsed: float) -> void:
	if _waves.has(wave_number - 1):
		var previous: Dictionary = _waves[wave_number - 1]
		if float(previous.get("ended_at", -1.0)) >= 0.0:
			previous["wait_after"] = snappedf(elapsed - float(previous["ended_at"]), 0.01)
	_current_wave = wave_number
	_last_elapsed = elapsed
	_waves[wave_number] = {
		"wave": wave_number,
		"title": title,
		"started_at": elapsed,
		"ended_at": -1.0,
		"duration": -1.0,
		"wait_after": -1.0,
		"spawned": {},
		"defeated": {},
		"weapon_kills": {},
		"damage_received": 0,
		"damage_sources": {},
		"max_active": 0,
		"max_attacking": 0,
		"max_projectiles": 0,
		"max_effects": 0,
		"start_resources": _resource_snapshot(),
		"end_resources": {},
		"weapon_start": _weapon_snapshot(),
		"weapons": {},
		"grenades_start": _grenade_snapshot(),
		"grenades": {},
		"supply": {},
		"upgrade": {},
	}


func sample(elapsed: float, active: int, attacking: int, projectiles: int, effects: int) -> void:
	_last_elapsed = elapsed
	if not _waves.has(_current_wave):
		return
	var entry: Dictionary = _waves[_current_wave]
	entry["max_active"] = maxi(int(entry["max_active"]), active)
	entry["max_attacking"] = maxi(int(entry["max_attacking"]), attacking)
	entry["max_projectiles"] = maxi(int(entry["max_projectiles"]), projectiles)
	entry["max_effects"] = maxi(int(entry["max_effects"]), effects)


func record_spawn(kind: String) -> void:
	if not _waves.has(_current_wave):
		return
	var spawned: Dictionary = _waves[_current_wave]["spawned"]
	spawned[kind] = int(spawned.get(kind, 0)) + 1


func record_defeat(kind: String, weapon_id: StringName) -> void:
	if not _waves.has(_current_wave):
		return
	var entry: Dictionary = _waves[_current_wave]
	var defeated: Dictionary = entry["defeated"]
	defeated[kind] = int(defeated.get(kind, 0)) + 1
	var kills: Dictionary = entry["weapon_kills"]
	var weapon_key := str(weapon_id if weapon_id != &"" else &"unknown")
	kills[weapon_key] = int(kills.get(weapon_key, 0)) + 1


func record_player_damage(amount: int, context: Dictionary) -> void:
	if not _waves.has(_current_wave):
		return
	var entry: Dictionary = _waves[_current_wave]
	entry["damage_received"] = int(entry["damage_received"]) + maxi(amount, 0)
	var sources: Dictionary = entry["damage_sources"]
	var source := str(context.get("source", "unknown"))
	sources[source] = int(sources.get(source, 0)) + maxi(amount, 0)


func record_supply(health: int, ammo_floor: float, grenades: int) -> void:
	if not _waves.has(_current_wave):
		return
	_waves[_current_wave]["supply"] = {
		"health": health,
		"ammo_floor": snappedf(ammo_floor, 0.01),
		"grenades": grenades,
	}


func record_upgrade(completed_wave: int, upgrade_id: StringName, stack_count: int, elapsed: float) -> void:
	if not _waves.has(completed_wave):
		return
	_waves[completed_wave]["upgrade"] = {
		"id": str(upgrade_id),
		"stack": stack_count,
		"selected_at": snappedf(elapsed, 0.01),
	}


func complete_wave(wave_number: int, elapsed: float) -> void:
	if not _waves.has(wave_number):
		return
	_last_elapsed = elapsed
	var entry: Dictionary = _waves[wave_number]
	if float(entry["ended_at"]) >= 0.0:
		return
	entry["ended_at"] = elapsed
	entry["duration"] = snappedf(elapsed - float(entry["started_at"]), 0.01)
	entry["end_resources"] = _resource_snapshot()
	entry["weapons"] = _subtract_weapon_snapshots(entry["weapon_start"], _weapon_snapshot())
	entry["grenades"] = _subtract_numeric(entry["grenades_start"], _grenade_snapshot())


func finish(reason: StringName, elapsed: float) -> void:
	if _printed:
		return
	_last_elapsed = elapsed
	if _waves.has(_current_wave) and float(_waves[_current_wave]["ended_at"]) < 0.0:
		var entry: Dictionary = _waves[_current_wave]
		entry["end_resources"] = _resource_snapshot()
		entry["weapons"] = _subtract_weapon_snapshots(entry["weapon_start"], _weapon_snapshot())
		entry["grenades"] = _subtract_numeric(entry["grenades_start"], _grenade_snapshot())
	_printed = true
	print("SURVIVAL_BALANCE_SUMMARY %s %s" % [reason, JSON.stringify(get_summary())])


func get_summary() -> Dictionary:
	var ordered: Array[Dictionary] = []
	var total_damage := 0
	var peak_active := 0
	var peak_attacking := 0
	var keys := _waves.keys()
	keys.sort()
	for wave_number in keys:
		var entry: Dictionary = _waves[wave_number].duplicate(true)
		entry.erase("weapon_start")
		entry.erase("grenades_start")
		ordered.append(entry)
		total_damage += int(entry["damage_received"])
		peak_active = maxi(peak_active, int(entry["max_active"]))
		peak_attacking = maxi(peak_attacking, int(entry["max_attacking"]))
	return {
		"elapsed": snappedf(_last_elapsed - _run_started_at, 0.01),
		"waves": ordered,
		"total_damage_received": total_damage,
		"peak_active": peak_active,
		"peak_attacking": peak_attacking,
	}


func _resource_snapshot() -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		return {}
	var ammo := {}
	for weapon_id in [&"rifle", &"shotgun", &"sniper", &"pistol"]:
		ammo[str(weapon_id)] = int(_player.weapon_inventory.get_ammo_for(weapon_id))
	return {
		"health": int(_player.health),
		"stamina": snappedf(float(_player.current_stamina), 0.1),
		"grenades": int(_player.grenade_count),
		"ammo": ammo,
	}


func _weapon_snapshot() -> Dictionary:
	if _run_telemetry == null or not is_instance_valid(_run_telemetry):
		return {}
	return (_run_telemetry.get_snapshot().get("weapons", {}) as Dictionary).duplicate(true)


func _grenade_snapshot() -> Dictionary:
	if _run_telemetry == null or not is_instance_valid(_run_telemetry):
		return {}
	var source: Dictionary = _run_telemetry.get_snapshot().get("grenades", {}) as Dictionary
	return {
		"throws": int(source.get("throws", 0)),
		"hits": int(source.get("hits", 0)),
		"kills": int(source.get("kills", 0)),
		"damage": int(source.get("damage", 0)),
	}


func _subtract_weapon_snapshots(start: Dictionary, finish: Dictionary) -> Dictionary:
	var result := {}
	for weapon_id in finish:
		var before: Dictionary = start.get(weapon_id, {})
		var after: Dictionary = finish[weapon_id]
		result[str(weapon_id)] = _subtract_numeric(before, after)
	return result


func _subtract_numeric(start: Dictionary, finish: Dictionary) -> Dictionary:
	var result := {}
	for key in finish:
		var value = finish[key]
		if value is int:
			result[key] = int(value) - int(start.get(key, 0))
		elif value is float:
			result[key] = snappedf(float(value) - float(start.get(key, 0.0)), 0.01)
	return result
