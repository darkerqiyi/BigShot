extends Node
class_name SurvivalEventDirector

signal event_started(definition: Dictionary, wave: int)
signal event_updated(definition: Dictionary, remaining: float, progress: float)
signal event_timed_out(event_id: StringName)
signal event_finished(record: Dictionary)

const EventData := preload("res://scripts/survival/survival_event_data.gd")
const DEFAULT_EVENT_WAVES: Array[int] = [3, 5, 7]
const MAX_EVENTS_PER_RUN := 2

var enabled := true
var map_id: StringName = &"industrial_district"
var random_seed := 0
var schedule: Dictionary = {}
var history: Array[Dictionary] = []
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
	active_definition.clear()
	active_wave = 0
	remaining = 0.0
	suspended = false
	_resolved = false
	schedule.clear()
	if enabled:
		_build_schedule()


func _build_schedule() -> void:
	var waves := DEFAULT_EVENT_WAVES.duplicate()
	_shuffle_array(waves)
	var definitions: Array[Dictionary] = []
	for definition in EventData.all_events():
		var allowed_maps: Array = definition.get("allowed_maps", []) as Array
		if allowed_maps.has(map_id):
			definitions.append(definition)
	var count := mini(MAX_EVENTS_PER_RUN, mini(waves.size(), definitions.size()))
	for index in range(count):
		var wave := int(waves[index])
		var definition := _take_weighted_definition(definitions)
		if definition.is_empty():
			break
		if (definition.get("allowed_waves", []) as Array).has(wave):
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


func _shuffle_array(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value


func get_scheduled_event(wave: int) -> Dictionary:
	if not enabled:
		return {}
	return (schedule.get(wave, {}) as Dictionary).duplicate(true)


func begin_event(definition: Dictionary, wave: int) -> bool:
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
	event_started.emit(active_definition.duplicate(true), active_wave)
	event_updated.emit(active_definition.duplicate(true), remaining, 0.0)
	return true


func complete_active(reward: StringName = &"none", detail: String = "") -> bool:
	return _resolve_active(&"success", reward, detail)


func fail_active(detail: String = "") -> bool:
	return _resolve_active(&"failed", &"none", detail)


func cancel_active(detail: String = "RUN INTERRUPTED") -> bool:
	return _resolve_active(&"cancelled", &"none", detail)


func _resolve_active(status: StringName, reward: StringName, detail: String) -> bool:
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
	history.append(record)
	active_definition.clear()
	active_wave = 0
	remaining = 0.0
	event_finished.emit(record.duplicate(true))
	return true


func set_suspended(value: bool) -> void:
	suspended = value


func is_active(event_id: StringName = &"") -> bool:
	if active_definition.is_empty():
		return false
	return event_id == &"" or StringName(active_definition.get("event_id", &"")) == event_id


func choose_small_supply() -> StringName:
	var supplies: Array[StringName] = [&"medical", &"weapon", &"tactical"]
	return supplies[_rng.randi_range(0, supplies.size() - 1)]


func get_history() -> Array[Dictionary]:
	return history.duplicate(true)


func get_summary() -> Dictionary:
	var bounty_successes := 0
	var reinforcement_successes := 0
	var supplies: Array[StringName] = []
	for record in history:
		var event_id := StringName(record.get("event_id", &""))
		var success := StringName(record.get("status", &"")) == &"success"
		if event_id == &"elite_bounty" and success:
			bounty_successes += 1
		elif event_id == &"emergency_reinforcements" and success:
			reinforcement_successes += 1
		var reward := StringName(record.get("reward", &"none"))
		if reward in [&"medical", &"weapon", &"tactical"]:
			supplies.append(reward)
	return {
		"event_count": history.size(),
		"event_history": get_history(),
		"bounty_successes": bounty_successes,
		"reinforcement_successes": reinforcement_successes,
		"supplies": supplies,
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"seed": random_seed,
		"schedule": schedule.duplicate(true),
		"history": get_history(),
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
	if definition.is_empty() or not (definition.get("allowed_maps", []) as Array).has(map_id):
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


func _process(delta: float) -> void:
	if suspended or active_definition.is_empty() or remaining <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)
	var duration := maxf(float(active_definition.get("duration", 0.0)), 0.001)
	event_updated.emit(active_definition.duplicate(true), remaining, 1.0 - remaining / duration)
	if is_zero_approx(remaining):
		event_timed_out.emit(StringName(active_definition.get("event_id", &"")))
