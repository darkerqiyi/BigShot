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
			_entry("assault", 3, "split"),
		]),
		_wave(2, "CROSS FIRE", [
			_entry("assault", 3, "split"),
			_entry("gunner", 2, "edges"),
		]),
		_wave(3, "SHIELD CONTACT", [
			_entry("assault", 2, "split"),
			_entry("gunner", 2, "edges"),
			_entry("shield", 1, "far"),
		]),
		_wave(4, "PINCER FIRE", [
			_entry("assault", 3, "left"),
			_entry("gunner", 2, "right"),
			_entry("shield", 2, "split"),
		]),
		_wave(5, "ARMORED BREAKER", [
			_entry("elite", 1, "far"),
			_entry("assault", 2, "split"),
		]),
		_wave(6, "ALL DIRECTIONS", [
			_entry("assault", 4, "split"),
			_entry("gunner", 3, "edges"),
			_entry("shield", 1, "far"),
		]),
		_wave(7, "LOCKED SIGHTLINES", [
			_entry("shield", 3, "split"),
			_entry("gunner", 4, "edges"),
		]),
		_wave(8, "REDLINE ASSAULT", [
			_entry("assault", 5, "split"),
			_entry("gunner", 3, "edges"),
			_entry("shield", 2, "far"),
		]),
		_wave(9, "FINAL BULWARK", [
			_entry("elite", 1, "far"),
			_entry("shield", 2, "split"),
			_entry("gunner", 2, "edges"),
			_entry("assault", 2, "split"),
		]),
		_wave(10, "THE IRON TEMPEST", [], true),
	]


static func _wave(number: int, title: String, entries: Array[Dictionary], boss: bool = false) -> Dictionary:
	return {
		"number": number,
		"title": title,
		"entries": entries,
		"boss": boss,
	}


static func _entry(kind: String, count: int, side: String) -> Dictionary:
	return {"kind": kind, "count": count, "side": side}
