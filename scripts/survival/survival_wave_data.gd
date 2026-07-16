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
			_entry("assault", 4, "split"),
		], false, 3, 0.78, 2, 4.0),
		_wave(2, "CROSS FIRE", [
			_entry("assault", 4, "split"),
			_entry("gunner", 3, "edges"),
		], false, 4, 0.72, 3, 5.0),
		_wave(3, "SHIELD CONTACT", [
			_entry("assault", 3, "split"),
			_entry("gunner", 2, "edges"),
			_entry("shield", 2, "far"),
		], false, 4, 0.68, 3, 5.0),
		_wave(4, "PINCER FIRE", [
			_entry("assault", 4, "left"),
			_entry("gunner", 3, "right"),
			_entry("shield", 2, "split"),
		], false, 5, 0.62, 4, 6.0),
		_wave(5, "ARMORED BREAKER", [
			_entry("elite", 1, "far"),
			_entry("assault", 3, "split"),
			_entry("gunner", 2, "edges"),
		], false, 4, 0.74, 3, 7.0),
		_wave(6, "ALL DIRECTIONS", [
			_entry("assault", 5, "split"),
			_entry("gunner", 4, "edges"),
			_entry("shield", 2, "far"),
		], false, 5, 0.58, 4, 7.0),
		_wave(7, "LOCKED SIGHTLINES", [
			_entry("shield", 3, "split"),
			_entry("gunner", 5, "edges"),
			_entry("assault", 2, "split"),
		], false, 5, 0.58, 4, 7.0),
		_wave(8, "REDLINE ASSAULT", [
			_entry("assault", 6, "split"),
			_entry("gunner", 4, "edges"),
			_entry("shield", 3, "far"),
		], false, 6, 0.52, 5, 8.0),
		_wave(9, "FINAL BULWARK", [
			_entry("elite", 1, "far"),
			_entry("shield", 3, "split"),
			_entry("gunner", 3, "edges"),
			_entry("assault", 3, "split"),
		], false, 5, 0.60, 4, 8.0),
		_wave(10, "THE IRON TEMPEST", [], true),
	]


static func _wave(number: int, title: String, entries: Array[Dictionary], boss: bool = false, active_limit: int = 6, deploy_interval: float = 0.42, batch_size: int = 99, reinforcement_delay: float = 0.0) -> Dictionary:
	return {
		"number": number,
		"title": title,
		"entries": entries,
		"boss": boss,
		"active_limit": active_limit,
		"spawn_interval": deploy_interval,
		"batch_size": batch_size,
		"reinforcement_delay": reinforcement_delay,
	}


static func _entry(kind: String, count: int, side: String) -> Dictionary:
	return {"kind": kind, "count": count, "side": side}
