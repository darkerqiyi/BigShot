extends RefCounted
class_name EnemyBalance

# Enemy durability lives here so survival can have its own measured TTK without
# duplicating behavior scripts or silently changing the authored PVE mission.
const PVE_HEALTH := {
	&"assault": 44,
	&"gunner": 58,
	&"shield": 92,
	&"elite": 230,
}

const SURVIVAL_HEALTH := {
	&"assault": 132,
	&"gunner": 120,
	&"shield": 216,
	&"elite": 900,
}

# Linear growth keeps later waves relevant without exponential health inflation.
const SURVIVAL_HEALTH_PER_WAVE := {
	&"assault": 8,
	&"gunner": 6,
	&"shield": 9,
	&"elite": 28,
}

const HEAD_SIZES := {
	&"assault": Vector2(22.0, 17.0),
	&"gunner": Vector2(24.0, 18.0),
	&"shield": Vector2(22.0, 18.0),
	&"elite": Vector2(32.0, 20.0),
}


static func normalized_kind(kind: String) -> StringName:
	match kind:
		"runner":
			return &"assault"
		"rifle":
			return &"gunner"
		"heavy":
			return &"elite"
		_:
			return StringName(kind)


static func health_for(kind: String, mode: StringName, wave_number: int = 0) -> int:
	var role := normalized_kind(kind)
	if mode != &"survival":
		return int(PVE_HEALTH.get(role, PVE_HEALTH[&"gunner"]))
	var base_health := int(SURVIVAL_HEALTH.get(role, SURVIVAL_HEALTH[&"gunner"]))
	var growth := int(SURVIVAL_HEALTH_PER_WAVE.get(role, 0))
	return base_health + growth * maxi(wave_number - 1, 0)


static func head_size_for(kind: String) -> Vector2:
	return HEAD_SIZES.get(normalized_kind(kind), HEAD_SIZES[&"gunner"])
