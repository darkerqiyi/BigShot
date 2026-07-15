extends Node
class_name WeaponInventory

signal weapon_changed(weapon_id: StringName, weapon_data: Dictionary)
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal reload_started
signal reload_stage(stage: StringName, weapon_id: StringName)
signal reload_completed(weapon_id: StringName)

const WeaponData := preload("res://scripts/weapons/weapon_catalog.gd")

var current_weapon_id: StringName = &"rifle"
var fire_cooldown := 0.0
var switch_cooldown := 0.0
var reload_remaining := 0.0
var shot_sequence := 0
var _ammo: Dictionary = {}
var _reload_insert_emitted := false


func _ready() -> void:
	for weapon_id in WeaponData.ORDER:
		var data := WeaponData.get_weapon(weapon_id)
		_ammo[weapon_id] = int(data["magazine_size"])
	_emit_current_state()


func tick(delta: float) -> void:
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	switch_cooldown = maxf(switch_cooldown - delta, 0.0)
	if reload_remaining <= 0.0:
		return
	reload_remaining = maxf(reload_remaining - delta, 0.0)
	var data := get_current_data()
	if not _reload_insert_emitted and reload_remaining <= float(data["reload_time"]) * 0.45:
		_reload_insert_emitted = true
		reload_stage.emit(&"insert", current_weapon_id)
	if is_zero_approx(reload_remaining):
		_ammo[current_weapon_id] = int(data["magazine_size"])
		ammo_changed.emit(get_ammo(), int(data["magazine_size"]), false)
		reload_stage.emit(&"complete", current_weapon_id)
		reload_completed.emit(current_weapon_id)


func select_weapon(weapon_id: StringName) -> bool:
	if weapon_id == current_weapon_id or not WeaponData.ORDER.has(weapon_id):
		return false
	if switch_cooldown > 0.0:
		return false
	current_weapon_id = weapon_id
	reload_remaining = 0.0
	_reload_insert_emitted = false
	var data := get_current_data()
	var switch_lock := float(data["switch_lock"])
	fire_cooldown = switch_lock
	switch_cooldown = switch_lock
	weapon_changed.emit(current_weapon_id, data)
	ammo_changed.emit(get_ammo(), int(data["magazine_size"]), false)
	return true


func can_fire(trigger_pressed: bool, trigger_just_pressed: bool) -> bool:
	if reload_remaining > 0.0 or fire_cooldown > 0.0 or get_ammo() <= 0:
		return false
	var data := get_current_data()
	return trigger_pressed if bool(data["automatic_fire"]) else trigger_just_pressed


func commit_shot() -> void:
	var data := get_current_data()
	_ammo[current_weapon_id] = maxi(get_ammo() - 1, 0)
	fire_cooldown = float(data["fire_rate"])
	shot_sequence += 1
	ammo_changed.emit(get_ammo(), int(data["magazine_size"]), false)


func start_reload() -> bool:
	var data := get_current_data()
	if reload_remaining > 0.0 or get_ammo() >= int(data["magazine_size"]):
		return false
	reload_remaining = float(data["reload_time"])
	_reload_insert_emitted = false
	reload_started.emit()
	reload_stage.emit(&"start", current_weapon_id)
	ammo_changed.emit(get_ammo(), int(data["magazine_size"]), true)
	return true


func cancel_reload() -> bool:
	if reload_remaining <= 0.0:
		return false
	reload_remaining = 0.0
	_reload_insert_emitted = false
	var data := get_current_data()
	ammo_changed.emit(get_ammo(), int(data["magazine_size"]), false)
	return true


func get_current_data() -> Dictionary:
	return WeaponData.get_weapon(current_weapon_id)


func get_ammo() -> int:
	return int(_ammo.get(current_weapon_id, 0))


func get_ammo_for(weapon_id: StringName) -> int:
	return int(_ammo.get(weapon_id, 0))


func is_reloading() -> bool:
	return reload_remaining > 0.0


func refill_to_floor(ratio: float) -> void:
	for weapon_id in WeaponData.ORDER:
		var data := WeaponData.get_weapon(weapon_id)
		var floor_ammo := int(ceil(float(data["magazine_size"]) * clampf(ratio, 0.0, 1.0)))
		_ammo[weapon_id] = maxi(get_ammo_for(weapon_id), floor_ammo)
	_emit_current_state()


func _emit_current_state() -> void:
	var data := get_current_data()
	weapon_changed.emit(current_weapon_id, data)
	ammo_changed.emit(get_ammo(), int(data["magazine_size"]), false)
