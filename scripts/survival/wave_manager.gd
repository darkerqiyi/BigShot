extends Node
class_name SurvivalWaveManager

signal state_changed(state: StringName)
signal wave_started(wave_number: int, total_waves: int, title: String)
signal spawn_warning_requested(ticket: int, kind: String, side: String, warning_time: float)
signal spawn_requested(ticket: int, kind: String, side: String)
signal counters_changed(wave_number: int, total_waves: int, alive: int, pending: int, countdown: float, state: StringName)
signal rest_started(completed_wave: int, duration: float)
signal wave_completed(wave_number: int)
signal boss_requested(wave_number: int)
signal run_completed

enum State {
	IDLE,
	COUNTDOWN,
	SPAWNING,
	ACTIVE,
	REST,
	BOSS,
	COMPLETE,
	STOPPED,
}

var state := State.IDLE
var current_wave := 0
var total_waves := 0
var max_active_enemies := 6
var intermission_duration := 10.0
var initial_countdown := 2.5
var spawn_warning_time := 0.55
var spawn_interval := 0.42
var countdown_remaining := 0.0
var completed_waves: Array[int] = []

var _waves: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _warnings: Array[Dictionary] = []
var _active: Dictionary = {}
var _defeated_ids: Dictionary = {}
var _next_ticket := 1
var _spawn_cooldown := 0.0
var _wave_completion_locked := false


func configure(waves: Array[Dictionary], active_limit: int = 6) -> void:
	_waves = waves.duplicate(true)
	total_waves = _waves.size()
	max_active_enemies = maxi(active_limit, 1)


func set_debug_timings(initial: float, rest: float, warning: float, interval: float) -> void:
	if not OS.is_debug_build():
		return
	initial_countdown = maxf(initial, 0.0)
	intermission_duration = maxf(rest, 0.0)
	spawn_warning_time = maxf(warning, 0.0)
	spawn_interval = maxf(interval, 0.0)


func start_run() -> void:
	reset_run()
	if _waves.is_empty():
		_finish_run()
		return
	_set_state(State.COUNTDOWN)
	countdown_remaining = initial_countdown
	_emit_counters()


func reset_run() -> void:
	state = State.IDLE
	current_wave = 0
	countdown_remaining = 0.0
	completed_waves.clear()
	_pending.clear()
	_warnings.clear()
	_active.clear()
	_defeated_ids.clear()
	_next_ticket = 1
	_spawn_cooldown = 0.0
	_wave_completion_locked = false


func stop_run() -> void:
	_pending.clear()
	_warnings.clear()
	_active.clear()
	countdown_remaining = 0.0
	_set_state(State.STOPPED)
	_emit_counters()


func register_spawned(ticket: int, enemy: Node) -> void:
	if state not in [State.SPAWNING, State.ACTIVE] or enemy == null:
		return
	_active[enemy.get_instance_id()] = {"ticket": ticket, "node": weakref(enemy)}
	_set_state(State.ACTIVE if _pending.is_empty() and _warnings.is_empty() else State.SPAWNING)
	_emit_counters()


func spawn_failed(ticket: int, kind: String, side: String) -> void:
	if state not in [State.SPAWNING, State.ACTIVE]:
		return
	_pending.push_front({"ticket": ticket, "kind": kind, "side": side})
	_emit_counters()


func enemy_defeated(instance_id: int) -> bool:
	if _defeated_ids.has(instance_id) or not _active.has(instance_id):
		return false
	_defeated_ids[instance_id] = true
	_active.erase(instance_id)
	_emit_counters()
	_check_wave_complete()
	return true


func enemy_lost(instance_id: int) -> bool:
	if not _active.has(instance_id):
		return false
	_active.erase(instance_id)
	_emit_counters()
	_check_wave_complete()
	return true


func boss_defeated() -> void:
	if state != State.BOSS:
		return
	_complete_current_wave()


func get_state_name() -> StringName:
	return [&"idle", &"countdown", &"spawning", &"active", &"rest", &"boss", &"complete", &"stopped"][state]


func get_alive_count() -> int:
	return _active.size()


func get_pending_count() -> int:
	return _pending.size() + _warnings.size()


func is_boss_wave(wave_number: int = current_wave) -> bool:
	if wave_number <= 0 or wave_number > _waves.size():
		return false
	return bool(_waves[wave_number - 1].get("boss", false))


func _process(delta: float) -> void:
	if state in [State.IDLE, State.COMPLETE, State.STOPPED]:
		return
	if state in [State.COUNTDOWN, State.REST]:
		countdown_remaining = maxf(countdown_remaining - delta, 0.0)
		_emit_counters()
		if is_zero_approx(countdown_remaining):
			_begin_next_wave()
		return
	if state in [State.SPAWNING, State.ACTIVE]:
		_prune_invalid_enemies()
		_spawn_cooldown = maxf(_spawn_cooldown - delta, 0.0)
		_update_warnings(delta)
		_queue_warning_if_possible()
		_check_wave_complete()


func _begin_next_wave() -> void:
	if current_wave >= total_waves:
		_finish_run()
		return
	current_wave += 1
	_wave_completion_locked = false
	_defeated_ids.clear()
	var definition: Dictionary = _waves[current_wave - 1]
	wave_started.emit(current_wave, total_waves, str(definition.get("title", "WAVE")))
	if bool(definition.get("boss", false)):
		_set_state(State.BOSS)
		boss_requested.emit(current_wave)
		_emit_counters()
		return
	_pending = _expand_entries(definition.get("entries", []) as Array)
	_set_state(State.SPAWNING)
	_spawn_cooldown = 0.0
	_emit_counters()


func _expand_entries(entries: Array) -> Array[Dictionary]:
	var expanded: Array[Dictionary] = []
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		for _index in range(maxi(int(entry.get("count", 1)), 0)):
			expanded.append({
				"ticket": _next_ticket,
				"kind": str(entry.get("kind", "assault")),
				"side": str(entry.get("side", "split")),
			})
			_next_ticket += 1
	return expanded


func _queue_warning_if_possible() -> void:
	if _pending.is_empty() or _spawn_cooldown > 0.0:
		return
	if _active.size() + _warnings.size() >= max_active_enemies:
		return
	var entry: Dictionary = _pending.pop_front()
	entry["remaining"] = spawn_warning_time
	_warnings.append(entry)
	_spawn_cooldown = spawn_interval
	spawn_warning_requested.emit(int(entry["ticket"]), str(entry["kind"]), str(entry["side"]), spawn_warning_time)
	_emit_counters()


func _update_warnings(delta: float) -> void:
	for index in range(_warnings.size() - 1, -1, -1):
		var entry: Dictionary = _warnings[index]
		entry["remaining"] = maxf(float(entry["remaining"]) - delta, 0.0)
		_warnings[index] = entry
		if is_zero_approx(float(entry["remaining"])):
			_warnings.remove_at(index)
			spawn_requested.emit(int(entry["ticket"]), str(entry["kind"]), str(entry["side"]))


func _check_wave_complete() -> void:
	if _wave_completion_locked or state not in [State.SPAWNING, State.ACTIVE]:
		return
	if not _pending.is_empty() or not _warnings.is_empty() or not _active.is_empty():
		return
	_complete_current_wave()


func _prune_invalid_enemies() -> void:
	var lost_ids: Array[int] = []
	for instance_id_value in _active:
		var record: Dictionary = _active[instance_id_value]
		var reference: WeakRef = record.get("node") as WeakRef
		if reference == null or reference.get_ref() == null:
			lost_ids.append(int(instance_id_value))
	for instance_id in lost_ids:
		_active.erase(instance_id)


func _complete_current_wave() -> void:
	if _wave_completion_locked:
		return
	_wave_completion_locked = true
	completed_waves.append(current_wave)
	wave_completed.emit(current_wave)
	if current_wave >= total_waves:
		_finish_run()
		return
	_set_state(State.REST)
	countdown_remaining = intermission_duration
	rest_started.emit(current_wave, intermission_duration)
	_emit_counters()


func _finish_run() -> void:
	_set_state(State.COMPLETE)
	countdown_remaining = 0.0
	_emit_counters()
	run_completed.emit()


func _set_state(next_state: int) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(get_state_name())


func _emit_counters() -> void:
	counters_changed.emit(current_wave, total_waves, _active.size(), get_pending_count(), countdown_remaining, get_state_name())
