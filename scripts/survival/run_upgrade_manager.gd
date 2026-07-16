extends Node
class_name RunUpgradeManager

signal candidates_generated(candidates: Array[Dictionary])
signal upgrade_applied(upgrade_id: StringName, stack_count: int, final_modifiers: Dictionary)
signal run_reset

const UpgradeData := preload("res://scripts/survival/upgrade_definition.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")

var random_seed := 0
var stacks: Dictionary = {}
var selection_history: Array[StringName] = []
var current_candidates: Array[Dictionary] = []
var selection_open := false
var last_selected_id: StringName = &""

var _definitions: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _player: Node
var _debug_allowed_ids: Array[StringName] = []


func _ready() -> void:
	for definition in UpgradeData.all():
		_definitions[definition.id] = definition


func configure(player: Node, seed_value: int = 0) -> void:
	_player = player
	set_random_seed(seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()) ^ get_instance_id())
	reset_run()


func set_random_seed(seed_value: int) -> void:
	random_seed = seed_value
	_rng.seed = random_seed


func reset_run() -> void:
	stacks.clear()
	selection_history.clear()
	current_candidates.clear()
	selection_open = false
	last_selected_id = &""
	_apply_to_player({}, {})
	run_reset.emit()


func generate_candidates(count: int = 3) -> Array[Dictionary]:
	var available: Array[UpgradeDefinition] = []
	for definition_value in _definitions.values():
		var definition := definition_value as UpgradeDefinition
		if (_debug_allowed_ids.is_empty() or _debug_allowed_ids.has(definition.id)) and get_stack_count(definition.id) < definition.max_stacks:
			available.append(definition)
	var selected: Array[UpgradeDefinition] = []
	if not available.is_empty():
		selected.append(_weighted_take(available))
	if selected.size() < count and not available.is_empty():
		var other_categories: Array[UpgradeDefinition] = []
		for definition in available:
			if definition.category != selected[0].category:
				other_categories.append(definition)
		selected.append(_weighted_take(other_categories if not other_categories.is_empty() else available))
	while selected.size() < count and not available.is_empty():
		selected.append(_weighted_take(available))
	current_candidates.clear()
	for definition in selected:
		current_candidates.append(definition.to_card(get_stack_count(definition.id)))
	selection_open = not current_candidates.is_empty()
	candidates_generated.emit(current_candidates.duplicate(true))
	return current_candidates.duplicate(true)


func apply_candidate(upgrade_id: StringName) -> bool:
	if not selection_open or not _candidate_contains(upgrade_id):
		return false
	var definition := _definitions.get(upgrade_id) as UpgradeDefinition
	if definition == null:
		return false
	var next_stack := get_stack_count(upgrade_id) + 1
	if next_stack > definition.max_stacks:
		return false
	selection_open = false
	current_candidates.clear()
	stacks[upgrade_id] = next_stack
	selection_history.append(upgrade_id)
	last_selected_id = upgrade_id
	var selection_effects := _selection_effects(definition)
	var final_modifiers := calculate_final_modifiers()
	_apply_to_player(final_modifiers, selection_effects)
	upgrade_applied.emit(upgrade_id, next_stack, final_modifiers.duplicate(true))
	return true


func apply_debug_upgrade(upgrade_id: StringName) -> bool:
	if not OS.is_debug_build() or not _definitions.has(upgrade_id):
		return false
	var definition := _definitions[upgrade_id] as UpgradeDefinition
	if get_stack_count(upgrade_id) >= definition.max_stacks:
		return false
	current_candidates = [definition.to_card(get_stack_count(upgrade_id))]
	selection_open = true
	return apply_candidate(upgrade_id)


func set_debug_candidate_pool(upgrade_ids: Array[StringName]) -> void:
	if not OS.is_debug_build():
		return
	_debug_allowed_ids = upgrade_ids.duplicate()


func clear_debug_candidate_pool() -> void:
	_debug_allowed_ids.clear()


func get_stack_count(upgrade_id: StringName) -> int:
	return int(stacks.get(upgrade_id, 0))


func get_definition(upgrade_id: StringName) -> UpgradeDefinition:
	return _definitions.get(upgrade_id) as UpgradeDefinition


func get_remaining_pool_size() -> int:
	var count := 0
	for definition_value in _definitions.values():
		var definition := definition_value as UpgradeDefinition
		if get_stack_count(definition.id) < definition.max_stacks:
			count += 1
	return count


func calculate_final_modifiers() -> Dictionary:
	var endurance := get_stack_count(&"endurance_core")
	var efficient := get_stack_count(&"efficient_drive")
	var momentum := get_stack_count(&"momentum_module")
	var evasive := get_stack_count(&"evasive_circuit")
	var ordnance := get_stack_count(&"extra_ordnance")
	var radius := get_stack_count(&"blast_radius")
	var explosive := get_stack_count(&"high_explosive")
	var reload := get_stack_count(&"quick_reload")
	var overclock := get_stack_count(&"auto_overclock")
	var scatter := get_stack_count(&"scatter_load")
	var lance := get_stack_count(&"lance_penetration")
	var vitals := get_stack_count(&"reinforced_vitals")
	return {
		"max_stamina": Tuning.PLAYER_MAX_STAMINA + 20.0 * endurance,
		"stamina_drain": Tuning.PLAYER_STAMINA_DRAIN_PER_SECOND * maxf(0.60, 1.0 - 0.12 * efficient),
		"sprint_speed": Tuning.PLAYER_SPRINT_SPEED * (1.0 + 0.07 * momentum),
		"roll_cooldown": maxf(0.25, Tuning.PLAYER_ROLL_COOLDOWN - 0.08 * evasive),
		"grenade_capacity": Tuning.PLAYER_GRENADE_COUNT + ordnance,
		"grenade_radius": Tuning.GRENADE_RADIUS * (1.0 + 0.15 * radius),
		"grenade_damage": int(round(Tuning.GRENADE_DAMAGE * (1.0 + 0.15 * explosive))),
		"max_health": Tuning.PLAYER_MAX_HEALTH + 15 * vitals,
		"weapon_modifiers": {
			"reload_time_multiplier": maxf(0.64, 1.0 - 0.12 * reload),
			"rifle_fire_rate_multiplier": maxf(0.70, 1.0 / (1.0 + 0.10 * overclock)),
			"shotgun_projectile_bonus": mini(scatter, 2),
			"sniper_penetration_bonus": mini(lance, 2),
		},
	}


func get_build_summary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade_id_value in stacks:
		var upgrade_id := StringName(upgrade_id_value)
		var definition := _definitions[upgrade_id] as UpgradeDefinition
		result.append({
			"id": upgrade_id,
			"display_name": definition.display_name,
			"stacks": get_stack_count(upgrade_id),
			"max_stacks": definition.max_stacks,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["display_name"]) < str(b["display_name"]))
	return result


func get_debug_snapshot() -> Dictionary:
	var candidate_ids: Array[String] = []
	for card in current_candidates:
		candidate_ids.append(str(card["id"]))
	return {
		"random_seed": random_seed,
		"candidate_ids": candidate_ids,
		"stacks": stacks.duplicate(true),
		"selection_history": selection_history.duplicate(),
		"remaining_pool": get_remaining_pool_size(),
		"selection_open": selection_open,
		"final_modifiers": calculate_final_modifiers(),
	}


func _weighted_take(pool: Array[UpgradeDefinition]) -> UpgradeDefinition:
	var total_weight := 0.0
	for definition in pool:
		total_weight += definition.selection_weight
	var roll := _rng.randf() * maxf(total_weight, 0.01)
	for index in range(pool.size()):
		var definition := pool[index]
		roll -= definition.selection_weight
		if roll <= 0.0:
			pool.remove_at(index)
			return definition
	return pool.pop_back()


func _candidate_contains(upgrade_id: StringName) -> bool:
	for card in current_candidates:
		if StringName(card["id"]) == upgrade_id:
			return true
	return false


func _selection_effects(definition: UpgradeDefinition) -> Dictionary:
	var effects := {}
	for key in ["stamina_restore", "grenade_restore", "health_restore"]:
		if definition.modifiers.has(key):
			effects[key] = definition.modifiers[key]
	return effects


func _apply_to_player(modifiers: Dictionary, selection_effects: Dictionary) -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("apply_run_upgrade_modifiers"):
		_player.apply_run_upgrade_modifiers(modifiers, selection_effects)
