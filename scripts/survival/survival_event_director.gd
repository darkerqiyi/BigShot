extends Node
class_name SurvivalEventDirector

signal event_started(definition: Dictionary, wave: int)
signal event_updated(definition: Dictionary, remaining: float, progress: float)
signal event_timed_out(event_id: StringName)
signal event_finished(record: Dictionary)
signal state_changed(state: StringName)

const EventData := preload("res://scripts/survival/survival_event_data.gd")
const DEFAULT_EVENT_WAVES: Array[int] = [3, 5, 7]
const MAX_EVENTS_PER_RUN := 1

enum State {
	IDLE,
	PENDING,
	ACTIVE,
	RESOLVING,
	COOLDOWN,
}

var enabled := true
var map_id: StringName = &"industrial_district"
var random_seed := 0
var schedule: Dictionary = {}
var history: Array[Dictionary] = []
var state := State.IDLE
var pending_definition: Dictionary = {}
var pending_wave := 0
var active_definition: Dictionary = {}
var active_wave := 0
var remaining := 0.0
var suspended := false

var _rng := RandomNumberGenerator.new()
var _resolved := false


func configure(selected_map: StringName, seed_value: int = 0, is_enabled: bool = true) -> void:
	map_id = selected_map
	random_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec() & 0x7fffffff)
	enabled = is_enabled
	_rng.seed = random_seed
	reset_run()


func reset_run() -> void:
	history.clear()
	pending_definition.clear()
	pending_wave = 0
	active_definition.clear()
	active_wave = 0
	remaining = 0.0
	suspended = false
	_resolved = false
	schedule.clear()
	_set_state(State.IDLE)
	if enabled:
		_build_schedule()


func _build_schedule() -> void:
	var definitions: Array[Dictionary] = []
	for definition in EventData.all_events():
		var allowed_maps: Array = definition.get("allowed_maps", []) as Array
		if allowed_maps.has(map_id):
			definitions.append(definition)
	var definition := _take_weighted_definition(definitions)
	if definition.is_empty():
		return
	var eligible_waves: Array[int] = []
	for wave in DEFAULT_EVENT_WAVES:
		if (definition.get("allowed_waves", []) as Array).has(wave):
			eligible_waves.append(wave)
	if eligible_waves.is_empty():
		return
	var wave := eligible_waves[_rng.randi_range(0, eligible_waves.size() - 1)]
	schedule[wave] = definition.duplicate(true)


func _take_weighted_definition(definitions: Array[Dictionary]) -> Dictionary:
	var total_weight := 0.0
	for definition in definitions:
		total_weight += maxf(float(definition.get("weight", 1.0)), 0.0)
	if definitions.is_empty() or total_weight <= 0.0:
		return {}
	var roll := _rng.randf_range(0.0, total_weight)
	for index in range(definitions.size()):
		var definition: Dictionary = definitions[index]
		roll -= maxf(float(definition.get("weight", 1.0)), 0.0)
		if roll <= 0.0:
			definitions.remove_at(index)
			return definition
	return definitions.pop_back()


func get_scheduled_event(wave: int) -> Dictionary:
	if not enabled:
		return {}
	return (schedule.get(wave, {}) as Dictionary).duplicate(true)


func mark_pending(wave: int, current_state: StringName = &"") -> Dictionary:
	if not enabled or state != State.IDLE or history.size() >= MAX_EVENTS_PER_RUN:
		return {}
	var definition := get_scheduled_event(wave)
	if definition.is_empty() or not bool(definition.get("blocks_wave_start", false)):
		return {}
	if current_state != &"" and (definition.get("incompatible_states", []) as Array).has(current_state):
		return {}
	pending_definition = definition.duplicate(true)
	pending_wave = wave
	_set_state(State.PENDING)
	return pending_definition.duplicate(true)


func begin_pending() -> bool:
	if state != State.PENDING or pending_definition.is_empty():
		return false
	var definition := pending_definition.duplicate(true)
	var wave := pending_wave
	pending_definition.clear()
	pending_wave = 0
	return _begin_event(definition, wave)


func begin_event(definition: Dictionary, wave: int) -> bool:
	if state == State.PENDING and wave == pending_wave and StringName(definition.get("event_id", &"")) == StringName(pending_definition.get("event_id", &"")):
		return begin_pending()
	return _begin_event(definition, wave)


func _begin_event(definition: Dictionary, wave: int) -> bool:
	if not enabled or definition.is_empty() or not active_definition.is_empty() or history.size() >= MAX_EVENTS_PER_RUN:
		return false
	var event_id := StringName(definition.get("event_id", &""))
	if event_id == &"":
		return false
	for record in history:
		if StringName(record.get("event_id", &"")) == event_id:
			return false
	active_definition = definition.duplicate(true)
	active_wave = wave
	remaining = maxf(float(active_definition.get("duration", 0.0)), 0.0)
	_resolved = false
	_set_state(State.ACTIVE)
	event_started.emit(active_definition.duplicate(true), active_wave)
	event_updated.emit(active_definition.duplicate(true), remaining, 0.0)
	return true


func complete_active(reward: StringName = &"none", detail: String = "", result: Dictionary = {}) -> bool:
	return _resolve_active(&"success", reward, detail, result)


func fail_active(detail: String = "") -> bool:
	return _resolve_active(&"failed", &"none", detail, {})


func cancel_active(detail: String = "RUN INTERRUPTED") -> bool:
	if state == State.PENDING:
		pending_definition.clear()
		pending_wave = 0
		_set_state(State.IDLE)
		return true
	return _resolve_active(&"cancelled", &"none", detail, {})


func _resolve_active(status: StringName, reward: StringName, detail: String, result: Dictionary) -> bool:
	if active_definition.is_empty() or _resolved:
		return false
	_resolved = true
	var record := {
		"event_id": StringName(active_definition.get("event_id", &"unknown")),
		"display_name": str(active_definition.get("display_name", "EVENT")),
		"wave": active_wave,
		"status": status,
		"reward": reward,
		"detail": detail,
	}
	for key in result:
		record[key] = result[key]
	history.append(record)
	_set_state(State.RESOLVING)
	active_definition.clear()
	active_wave = 0
	remaining = 0.0
	event_finished.emit(record.duplicate(true))
	_set_state(State.COOLDOWN)
	return true


func set_suspended(value: bool) -> void:
	suspended = value


func is_active(event_id: StringName = &"") -> bool:
	if active_definition.is_empty():
		return false
	return event_id == &"" or StringName(active_definition.get("event_id", &"")) == event_id


func get_history() -> Array[Dictionary]:
	return history.duplicate(true)


func get_summary() -> Dictionary:
	var supplies: Array[StringName] = []
	var supply_wave := 0
	var health_restored := 0
	var magazines_refilled := 0
	var grenades_added := 0
	for record in history:
		if StringName(record.get("event_id", &"")) != &"supply_drop":
			continue
		supply_wave = int(record.get("wave", 0))
		var reward := StringName(record.get("reward", &"none"))
		if reward != &"none":
			supplies.append(reward)
		health_restored += int(record.get("health_restored", 0))
		magazines_refilled += int(record.get("magazines_refilled", 0))
		grenades_added += int(record.get("grenades_added", 0))
	return {
		"event_count": history.size(),
		"event_history": get_history(),
		"supply_triggered": not history.is_empty(),
		"supply_wave": supply_wave,
		"supply_choice": supplies[0] if not supplies.is_empty() else &"none",
		"supply_health_restored": health_restored,
		"supply_magazines_refilled": magazines_refilled,
		"supply_grenades_added": grenades_added,
		"supplies": supplies,
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"seed": random_seed,
		"schedule": schedule.duplicate(true),
		"history": get_history(),
		"state": get_state_name(),
		"pending_event": StringName(pending_definition.get("event_id", &"none")),
		"pending_wave": pending_wave,
		"active_event": StringName(active_definition.get("event_id", &"none")),
		"active_wave": active_wave,
		"remaining": remaining,
		"suspended": suspended,
	}


func debug_clear_schedule() -> void:
	if OS.is_debug_build():
		schedule.clear()


func debug_force_event(event_id: StringName, wave: int) -> bool:
	if not OS.is_debug_build() or wave not in DEFAULT_EVENT_WAVES:
		return false
	var definition := EventData.get_event(event_id)
	if definition.is_empty() or not bool(definition.get("debug_force_enabled", false)) or not (definition.get("allowed_maps", []) as Array).has(map_id):
		return false
	for scheduled_wave in schedule.keys():
		var scheduled: Dictionary = schedule[scheduled_wave]
		if StringName(scheduled.get("event_id", &"")) == event_id:
			schedule.erase(scheduled_wave)
	schedule[wave] = definition
	return true


func debug_expire_active() -> bool:
	if not OS.is_debug_build() or active_definition.is_empty():
		return false
	remaining = 0.0
	var event_id := StringName(active_definition.get("event_id", &""))
	event_timed_out.emit(event_id)
	return true


func get_state_name() -> StringName:
	match state:
		State.IDLE:
			return &"idle"
		State.PENDING:
			return &"pending"
		State.ACTIVE:
			return &"active"
		State.RESOLVING:
			return &"resolving"
		_:
			return &"cooldown"


func _set_state(next_state: int) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(get_state_name())


func _process(delta: float) -> void:
	if suspended or active_definition.is_empty() or remaining <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)
	var duration := maxf(float(active_definition.get("duration", 0.0)), 0.001)
	event_updated.emit(active_definition.duplicate(true), remaining, 1.0 - remaining / duration)
	if is_zero_approx(remaining):
		event_timed_out.emit(StringName(active_definition.get("event_id", &"")))
