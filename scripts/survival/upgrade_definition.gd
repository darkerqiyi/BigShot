extends Resource
class_name UpgradeDefinition

@export var id: StringName
@export var display_name := ""
@export var description := ""
@export var category: StringName
@export var icon: StringName
@export var max_stacks := 1
@export var selection_weight := 1.0
@export var modifiers: Dictionary = {}


static func create(
	upgrade_id: StringName,
	upgrade_name: String,
	upgrade_description: String,
	upgrade_category: StringName,
	upgrade_icon: StringName,
	stack_limit: int,
	weight: float,
	modifier_data: Dictionary,
) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.id = upgrade_id
	definition.display_name = upgrade_name
	definition.description = upgrade_description
	definition.category = upgrade_category
	definition.icon = upgrade_icon
	definition.max_stacks = maxi(stack_limit, 1)
	definition.selection_weight = maxf(weight, 0.01)
	definition.modifiers = modifier_data.duplicate(true)
	return definition


static func all() -> Array[UpgradeDefinition]:
	return [
		create(&"endurance_core", "ENDURANCE CORE", "MAX STAMINA +20\nRESTORE 20 STAMINA", &"movement", &"core", 3, 1.0, {"max_stamina_add": 20.0, "stamina_restore": 20.0}),
		create(&"efficient_drive", "EFFICIENT DRIVE", "SPRINT DRAIN -12%", &"movement", &"drive", 3, 1.0, {"stamina_drain_reduction": 0.12}),
		create(&"momentum_module", "MOMENTUM MODULE", "SPRINT SPEED +7%", &"movement", &"momentum", 2, 0.9, {"sprint_speed_bonus": 0.07}),
		create(&"evasive_circuit", "EVASIVE CIRCUIT", "ROLL COOLDOWN -0.08 SEC", &"roll", &"evasion", 3, 1.0, {"roll_cooldown_reduction": 0.08}),
		create(&"extra_ordnance", "EXTRA ORDNANCE", "GRENADE CAPACITY +1\nGAIN 1 GRENADE", &"grenade", &"ordnance", 2, 0.95, {"grenade_capacity_add": 1, "grenade_restore": 1}),
		create(&"blast_radius", "BLAST RADIUS", "GRENADE RADIUS +15%", &"grenade", &"radius", 3, 0.95, {"grenade_radius_bonus": 0.15}),
		create(&"high_explosive", "HIGH EXPLOSIVE", "GRENADE DAMAGE +15%", &"grenade", &"explosive", 3, 1.0, {"grenade_damage_bonus": 0.15}),
		create(&"quick_reload", "QUICK RELOAD", "ALL RELOAD TIMES -12%", &"weapon", &"reload", 3, 1.0, {"reload_time_reduction": 0.12}),
		create(&"auto_overclock", "AUTO OVERCLOCK", "AUTO RIFLE FIRE RATE +10%", &"weapon", &"rifle", 3, 0.9, {"rifle_rate_bonus": 0.10}),
		create(&"scatter_load", "SCATTER LOAD", "SCATTERGUN PELLETS +1", &"weapon", &"shotgun", 2, 0.9, {"shotgun_projectile_add": 1}),
		create(&"lance_penetration", "LANCE PENETRATION", "RAIL LANCE PENETRATION +1", &"weapon", &"sniper", 2, 0.85, {"sniper_penetration_add": 1}),
		create(&"reinforced_vitals", "REINFORCED VITALS", "MAX HEALTH +15\nRESTORE 15 HEALTH", &"survival", &"vitals", 3, 1.0, {"max_health_add": 15, "health_restore": 15}),
	]


func to_card(current_stacks: int) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"category": category,
		"icon": icon,
		"current_stacks": current_stacks,
		"max_stacks": max_stacks,
	}
