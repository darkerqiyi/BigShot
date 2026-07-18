extends Node2D
class_name DamageNumberManager

const DamageNumberScript := preload("res://scripts/effects/damage_number.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")

var _pool: Array[DamageNumber] = []
var _active: Array[DamageNumber] = []
var _serial := 0
var dropped_visuals := 0


func _ready() -> void:
	for _index in range(Tuning.DAMAGE_NUMBER_POOL_SIZE):
		var number := DamageNumberScript.new() as DamageNumber
		number.finished.connect(_on_number_finished)
		add_child(number)
		_pool.append(number)


func show_result(target: Node, world_position: Vector2, result: Dictionary) -> bool:
	if target == null or not is_instance_valid(target) or not _is_on_screen(world_position):
		return false
	var final_damage := int(result.get("final_damage", 0))
	var blocked := bool(result.get("blocked", false))
	var headshot := bool(result.get("headshot", false))
	var style: StringName = &"normal"
	var text := str(final_damage)
	if blocked and final_damage <= 0:
		style = &"block"
		text = "BLOCK"
	elif final_damage <= 0:
		style = &"immune"
		text = "IMMUNE"
	elif headshot:
		style = &"headshot"
		text = str(final_damage)
	var target_id := target.get_instance_id()
	var requested_priority := 3 if style == &"headshot" else (2 if style == &"block" else (1 if style == &"immune" else 0))
	var target_numbers := _numbers_for_target(target_id)
	if target_numbers.size() >= Tuning.DAMAGE_NUMBERS_PER_TARGET:
		var replaceable := _oldest_below_priority(target_numbers, requested_priority)
		if replaceable == null:
			dropped_visuals += 1
			return false
		replaceable.recycle()
	var number := _acquire(requested_priority)
	if number == null:
		dropped_visuals += 1
		return false
	_serial += 1
	number.start(world_position, text, style, target_id, _serial)
	_active.append(number)
	return true


func clear_all() -> void:
	for number in _active.duplicate():
		number.recycle()


func get_debug_snapshot() -> Dictionary:
	return {
		"visible": _active.size(),
		"pool_free": _pool.size(),
		"pool_total": Tuning.DAMAGE_NUMBER_POOL_SIZE,
		"dropped_visuals": dropped_visuals,
	}


func _acquire(requested_priority: int) -> DamageNumber:
	if not _pool.is_empty():
		return _pool.pop_back()
	var replaceable := _oldest_below_priority(_active, requested_priority)
	if replaceable != null:
		replaceable.recycle()
		return _pool.pop_back() if not _pool.is_empty() else null
	return null


func _oldest_below_priority(numbers: Array[DamageNumber], requested_priority: int) -> DamageNumber:
	var oldest: DamageNumber
	for number in numbers:
		if number.priority >= requested_priority:
			continue
		if oldest == null or number.serial < oldest.serial:
			oldest = number
	return oldest


func _numbers_for_target(target_id: int) -> Array[DamageNumber]:
	var result: Array[DamageNumber] = []
	for number in _active:
		if number.target_id == target_id:
			result.append(number)
	return result


func _on_number_finished(number: DamageNumber) -> void:
	_active.erase(number)
	if not _pool.has(number):
		_pool.append(number)


func _is_on_screen(world_position: Vector2) -> bool:
	var screen_position := get_viewport().get_canvas_transform() * world_position
	return get_viewport_rect().grow(80.0).has_point(screen_position)
