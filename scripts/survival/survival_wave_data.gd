extends RefCounted
class_name SurvivalWaveData


static func phase_a_waves() -> Array[Dictionary]:
	return [
		_wave(1, "FIRST PRESSURE", [
			_entry("assault", 3, "split"),
		]),
		_wave(2, "CROSS FIRE", [
			_entry("assault", 3, "split"),
			_entry("gunner", 2, "edges"),
		]),
		_wave(3, "HOLD THE LINE", [
			_entry("assault", 2, "split"),
			_entry("gunner", 2, "edges"),
			_entry("shield", 1, "far"),
		]),
	]


static func full_waves() -> Array[Dictionary]:
	return [
		_wave(1, "FIRST PRESSURE", [
			_entry("assault", 5, "split"),
		], false, 4, 0.62, 3, 3.2),
		_wave(2, "CROSS FIRE", [
			_entry("assault", 5, "split"),
			_entry("gunner", 4, "edges"),
		], false, 5, 0.58, 4, 4.0),
		_wave(3, "SHIELD CONTACT", [
			_entry("assault", 4, "split"),
			_entry("gunner", 3, "edges"),
			_entry("shield", 2, "far"),
		], false, 5, 0.54, 4, 4.0),
		_wave(4, "PINCER FIRE", [
			_entry("assault", 5, "left"),
			_entry("gunner", 4, "right"),
			_entry("shield", 3, "split"),
		], false, 6, 0.50, 5, 4.8),
		_wave(5, "ARMORED BREAKER", [
			_entry("elite", 1, "far"),
			_entry("assault", 4, "split"),
			_entry("gunner", 3, "edges"),
		], false, 5, 0.59, 4, 5.6, 6.0),
		_wave(6, "ALL DIRECTIONS", [
			_entry("assault", 7, "split"),
			_entry("gunner", 5, "edges"),
			_entry("shield", 3, "far"),
		], false, 6, 0.46, 5, 5.6),
		_wave(7, "LOCKED SIGHTLINES", [
			_entry("shield", 4, "split"),
			_entry("gunner", 7, "edges"),
			_entry("assault", 3, "split"),
		], false, 6, 0.46, 5, 5.6),
		_wave(8, "REDLINE ASSAULT", [
			_entry("assault", 8, "split"),
			_entry("gunner", 6, "edges"),
			_entry("shield", 4, "far"),
		], false, 7, 0.42, 6, 6.4),
		_wave(9, "FINAL BULWARK", [
			_entry("elite", 1, "far"),
			_entry("shield", 4, "split"),
			_entry("gunner", 5, "edges"),
			_entry("assault", 4, "split"),
		], false, 6, 0.48, 5, 6.4, 6.0),
		_wave(10, "THE IRON TEMPEST", [], true),
	]


static func _wave(number: int, title: String, entries: Array[Dictionary], boss: bool = false, active_limit: int = 6, deploy_interval: float = 0.42, batch_size: int = 99, reinforcement_delay: float = 0.0, rest_duration_after: float = 3.5) -> Dictionary:
	return {
		"number": number,
		"title": title,
		"entries": entries,
		"boss": boss,
		"active_limit": active_limit,
		"spawn_interval": deploy_interval,
		"batch_size": batch_size,
		"reinforcement_delay": reinforcement_delay,
		"rest_duration_after": rest_duration_after,
	}


static func _entry(kind: String, count: int, side: String) -> Dictionary:
	return {"kind": kind, "count": count, "side": side}
