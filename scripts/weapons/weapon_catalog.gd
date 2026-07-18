extends RefCounted
class_name WeaponCatalog

const ORDER: Array[StringName] = [&"rifle", &"shotgun", &"sniper", &"pistol"]


static func all() -> Dictionary:
	return {
		&"rifle": _weapon(
			&"rifle", "AUTO RIFLE", 24, 0.085, 1050.0, 1, 1.2, 9.0, 0.018,
			185.0, 1500.0, 900.0, 0.75, 0, true, 32, 0.85,
			0.8, 1.35, Color(1.0, 0.78, 0.24, 1.0), 1.25
		),
		&"shotgun": _weapon(
			&"shotgun", "SCATTERGUN", 17, 0.62, 900.0, 7, 16.0, 35.0, 0.12,
			330.0, 720.0, 220.0, 0.25, 0, false, 8, 1.05,
			1.05, 1.15, Color(1.0, 0.42, 0.12, 1.0), 2.1
		),
		&"sniper": _weapon(
			&"sniper", "RAIL LANCE", 92, 1.0, 3600.0, 1, 0.0, 45.0, 0.16,
			420.0, 2400.0, 2400.0, 1.0, 2, false, 5, 1.2,
			0.0, 0.0, Color(0.42, 0.94, 1.0, 1.0), 1.85
		),
		&"pistol": _weapon(
			&"pistol", "SIDEARM", 32, 0.23, 1250.0, 1, 0.35, 5.0, 0.01,
			135.0, 1400.0, 1000.0, 0.85, 0, false, 15, 0.72,
			0.55, 0.9, Color(0.44, 1.0, 0.72, 1.0), 1.0
		),
	}


static func get_weapon(weapon_id: StringName) -> Dictionary:
	var catalog := all()
	return (catalog.get(weapon_id, catalog[&"rifle"]) as Dictionary).duplicate(true)


static func _weapon(
	weapon_id: StringName,
	display_name: String,
	damage: int,
	fire_rate: float,
	projectile_speed: float,
	projectile_count: int,
	spread_angle: float,
	recoil: float,
	camera_shake: float,
	knockback: float,
	max_range: float,
	falloff_start: float,
	minimum_damage_multiplier: float,
	penetration_count: int,
	automatic_fire: bool,
	magazine_size: int,
	reload_time: float,
	movement_accuracy: float,
	airborne_accuracy: float,
	color: Color,
	muzzle_scale: float,
) -> Dictionary:
	return {
		"id": weapon_id,
		"display_name": display_name,
		"damage": damage,
		"fire_rate": fire_rate,
		"projectile_speed": projectile_speed,
		"projectile_count": projectile_count,
		"spread_angle": spread_angle,
		"recoil": recoil,
		"camera_shake": camera_shake,
		"camera_recoil": clampf(recoil * 0.11, 0.8, 4.8),
		"knockback": knockback,
		"max_range": max_range,
		"damage_falloff": {
			"start": falloff_start,
			"minimum_multiplier": minimum_damage_multiplier,
		},
		"penetration_count": penetration_count,
		"penetrate_heavy": false,
		"automatic_fire": automatic_fire,
		"movement_accuracy": movement_accuracy,
		"airborne_accuracy": airborne_accuracy,
		"magazine_size": magazine_size,
		"reload_time": reload_time,
		"switch_lock": 0.055,
		"color": color,
		"muzzle_scale": muzzle_scale,
		"impact_strength": _impact_strength(weapon_id),
		"camera_aim_bonus": 45.0 if weapon_id == &"sniper" else 0.0,
	}


static func _impact_strength(weapon_id: StringName) -> float:
	match weapon_id:
		&"shotgun":
			return 0.78
		&"sniper":
			return 1.05
		&"pistol":
			return 0.58
		_:
			return 0.62
