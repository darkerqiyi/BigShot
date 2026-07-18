extends Node
class_name RunUpgradeManager

signal candidates_generated(candidates: Array[Dictionary])
signal upgrade_applied(upgrade_id: StringName, stack_count: int, final_modifiers: Dictionary)
signal run_reset

const UpgradeData := preload("res://scripts/survival/upgrade_definition.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")
const CANDIDATE_FAMILIES: Array[StringName] = [&"output", &"survival", &"mobility"]

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
	var family_order := CANDIDATE_FAMILIES.duplicate()
	for index in range(family_order.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var held: StringName = family_order[index]
		family_order[index] = family_order[swap_index]
		family_order[swap_index] = held
	for family in family_order:
		if selected.size() >= count:
			break
		var family_pool: Array[UpgradeDefinition] = []
		for definition in available:
			if _candidate_family(definition) == family:
				family_pool.append(definition)
		if not family_pool.is_empty():
			var chosen := _weighted_take(family_pool)
			selected.append(chosen)
			_remove_available(available, chosen.id)
	while selected.size() < count and not available.is_empty():
		selected.append(_weighted_take(available))
	current_candidates.clear()
	for definition in selected:
		current_candidates.append(_card_for(definition))
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
	current_candidates = [_card_for(definition)]
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
	return _calculate_modifiers(stacks)


func _calculate_modifiers(stack_source: Dictionary) -> Dictionary:
	var endurance := int(stack_source.get(&"endurance_core", 0))
	var efficient := int(stack_source.get(&"efficient_drive", 0))
	var momentum := int(stack_source.get(&"momentum_module", 0))
	var evasive := int(stack_source.get(&"evasive_circuit", 0))
	var ordnance := int(stack_source.get(&"extra_ordnance", 0))
	var radius := int(stack_source.get(&"blast_radius", 0))
	var explosive := int(stack_source.get(&"high_explosive", 0))
	var reload := int(stack_source.get(&"quick_reload", 0))
	var overclock := int(stack_source.get(&"auto_overclock", 0))
	var scatter := int(stack_source.get(&"scatter_load", 0))
	var lance := int(stack_source.get(&"lance_penetration", 0))
	var vitals := int(stack_source.get(&"reinforced_vitals", 0))
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


func _remove_available(pool: Array[UpgradeDefinition], upgrade_id: StringName) -> void:
	for index in range(pool.size() - 1, -1, -1):
		if pool[index].id == upgrade_id:
			pool.remove_at(index)


func _candidate_family(definition: UpgradeDefinition) -> StringName:
	if definition.category == &"survival" or definition.id in [&"endurance_core", &"extra_ordnance"]:
		return &"survival"
	if definition.category in [&"movement", &"roll"]:
		return &"mobility"
	return &"output"


func _card_for(definition: UpgradeDefinition) -> Dictionary:
	var card := definition.to_card(get_stack_count(definition.id))
	var before := calculate_final_modifiers()
	var projected_stacks := stacks.duplicate(true)
	projected_stacks[definition.id] = get_stack_count(definition.id) + 1
	var after := _calculate_modifiers(projected_stacks)
	card["value_preview"] = _value_preview(definition.id, before, after)
	card["family"] = _candidate_family(definition)
	return card


func _value_preview(upgrade_id: StringName, before: Dictionary, after: Dictionary) -> String:
	var before_weapons: Dictionary = before["weapon_modifiers"]
	var after_weapons: Dictionary = after["weapon_modifiers"]
	match upgrade_id:
		&"endurance_core":
			return "STAMINA %.0f -> %.0f" % [before["max_stamina"], after["max_stamina"]]
		&"efficient_drive":
			return "SPRINT DRAIN %.1f/s -> %.1f/s" % [before["stamina_drain"], after["stamina_drain"]]
		&"momentum_module":
			return "SPRINT %.0f -> %.0f" % [before["sprint_speed"], after["sprint_speed"]]
		&"evasive_circuit":
			return "ROLL %.2fs -> %.2fs" % [before["roll_cooldown"], after["roll_cooldown"]]
		&"extra_ordnance":
			return "GRENADES %d -> %d" % [before["grenade_capacity"], after["grenade_capacity"]]
		&"blast_radius":
			return "RADIUS %.0fpx -> %.0fpx" % [before["grenade_radius"], after["grenade_radius"]]
		&"high_explosive":
			return "GRENADE DAMAGE %d -> %d" % [before["grenade_damage"], after["grenade_damage"]]
		&"quick_reload":
			return "RELOAD %.0f%% -> %.0f%%" % [float(before_weapons["reload_time_multiplier"]) * 100.0, float(after_weapons["reload_time_multiplier"]) * 100.0]
		&"auto_overclock":
			var base_interval := float(WeaponData.get_weapon(&"rifle")["fire_rate"])
			return "AUTO INTERVAL %.3fs -> %.3fs" % [base_interval * float(before_weapons["rifle_fire_rate_multiplier"]), base_interval * float(after_weapons["rifle_fire_rate_multiplier"])]
		&"scatter_load":
			var pellets := int(WeaponData.get_weapon(&"shotgun")["projectile_count"])
			return "PELLETS %d -> %d" % [pellets + int(before_weapons["shotgun_projectile_bonus"]), pellets + int(after_weapons["shotgun_projectile_bonus"])]
		&"lance_penetration":
			var penetration := int(WeaponData.get_weapon(&"sniper")["penetration_count"])
			return "PENETRATION %d -> %d" % [penetration + int(before_weapons["sniper_penetration_bonus"]), penetration + int(after_weapons["sniper_penetration_bonus"])]
		&"reinforced_vitals":
			return "HEALTH %d -> %d" % [before["max_health"], after["max_health"]]
	return ""


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
