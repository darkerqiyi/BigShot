extends Node2D
class_name ImpactEffectManager

const ImpactEffectScene := preload("res://scenes/effects/impact_effect.tscn")
const POOL_SIZE := 56
const MAX_ACTIVE := 40
const MAX_SHOTGUN_IMPACTS_PER_TARGET_FRAME := 4

var _available: Array[Node2D] = []
var _active: Array[Node2D] = []
var _frame_target_counts: Dictionary = {}
var _tracked_frame := -1
var _sequence := 0
var dropped_effects := 0
var recycled_effects := 0
var flash_scale := 1.0


func _ready() -> void:
	for _index in range(POOL_SIZE):
		var effect := ImpactEffectScene.instantiate() as Node2D
		effect.set_pool_managed(true)
		effect.completed.connect(_release_effect)
		add_child(effect)
		effect.deactivate()
		_available.append(effect)


func spawn_effect(
	effect_position: Vector2,
	color: Color,
	strength: float,
	large: bool,
	kind: StringName = &"normal",
	direction: Vector2 = Vector2.ZERO,
	visual_hold: float = 0.0,
	details: Dictionary = {},
) -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _tracked_frame:
		_tracked_frame = frame
		_frame_target_counts.clear()
	var target_id := int(details.get("target_id", 0))
	if kind == &"shotgun_hit" and target_id != 0:
		var emitted := int(_frame_target_counts.get(target_id, 0))
		if emitted >= MAX_SHOTGUN_IMPACTS_PER_TARGET_FRAME:
			dropped_effects += 1
			return false
		_frame_target_counts[target_id] = emitted + 1
	var priority := _priority_for(kind, bool(details.get("is_lethal", false)), bool(details.get("is_headshot", false)))
	var effect := _acquire_effect(priority)
	if effect == null:
		dropped_effects += 1
		return false
	_sequence += 1
	effect.global_position = effect_position.round()
	effect.set_meta("impact_priority", priority)
	effect.set_meta("impact_sequence", _sequence)
	effect.configure(
		color,
		strength * clampf(flash_scale, 0.0, 1.0),
		large,
		kind,
		direction,
		visual_hold,
		StringName(details.get("target_material", &"terrain")),
	)
	_active.append(effect)
	return true


func clear_all() -> void:
	for effect in _active.duplicate():
		_release_effect(effect)
	_frame_target_counts.clear()


func get_debug_snapshot() -> Dictionary:
	return {
		"pool_total": POOL_SIZE,
		"active": _active.size(),
		"available": _available.size(),
		"dropped_effects": dropped_effects,
		"recycled_effects": recycled_effects,
	}


func _acquire_effect(priority: int) -> Node2D:
	if not _available.is_empty() and _active.size() < MAX_ACTIVE:
		return _available.pop_back()
	var candidate: Node2D
	var candidate_priority := priority
	var candidate_sequence := 1 << 30
	for active_effect in _active:
		var active_priority := int(active_effect.get_meta("impact_priority", 0))
		var active_sequence := int(active_effect.get_meta("impact_sequence", 0))
		if active_priority < candidate_priority or (active_priority == candidate_priority and active_sequence < candidate_sequence):
			candidate = active_effect
			candidate_priority = active_priority
			candidate_sequence = active_sequence
	if candidate == null:
		return null
	_active.erase(candidate)
	candidate.deactivate()
	recycled_effects += 1
	return candidate


func _release_effect(effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	_active.erase(effect)
	effect.deactivate()
	if not _available.has(effect):
		_available.append(effect)


func _priority_for(kind: StringName, lethal: bool, headshot: bool) -> int:
	if lethal or kind in [&"kill_light", &"kill_heavy", &"headshot_kill", &"player_death"]:
		return 4
	if headshot or kind == &"headshot":
		return 3
	if kind in [&"sniper_hit", &"shotgun_hit", &"guard_break", &"boss_heavy"]:
		return 2
	if kind in [&"rifle_hit", &"pistol_hit", &"block", &"armor_hit", &"boss_armor_hit"]:
		return 1
	return 0
