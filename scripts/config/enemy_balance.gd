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
	&"assault": 192,
	&"gunner": 216,
	&"shield": 288,
	&"elite": 1200,
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


static func health_for(kind: String, mode: StringName) -> int:
	var role := normalized_kind(kind)
	var table: Dictionary = SURVIVAL_HEALTH if mode == &"survival" else PVE_HEALTH
	return int(table.get(role, PVE_HEALTH[&"gunner"]))


static func head_size_for(kind: String) -> Vector2:
	return HEAD_SIZES.get(normalized_kind(kind), HEAD_SIZES[&"gunner"])
