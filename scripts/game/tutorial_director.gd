extends Node
class_name TutorialDirector

signal step_changed(step_id: StringName, index: int)
signal tutorial_completed

const STEPS: Array[Dictionary] = [
	{"id": &"move", "text": "MOVE // A / D"},
	{"id": &"jump", "text": "JUMP // SPACE"},
	{"id": &"fire", "text": "AIM // MOUSE  •  FIRE // LEFT MOUSE / J"},
	{"id": &"switch", "text": "SWITCH WEAPON // 1—4"},
	{"id": &"reload", "text": "RELOAD // R"},
	{"id": &"sprint", "text": "SPRINT // HOLD SHIFT + A / D"},
	{"id": &"roll", "text": "ROLL // DOUBLE-TAP A / D"},
	{"id": &"grenade", "text": "GRENADE // HOLD & RELEASE RIGHT MOUSE"},
	{"id": &"headshot", "text": "WEAK POINT // HEADSHOTS DEAL DOUBLE DAMAGE"},
]

var active := false
var current_step := 0
var hud: CanvasLayer
var _advance_pending := false


func configure(target_hud: CanvasLayer) -> void:
	hud = target_hud
	var settings := get_node_or_null("/root/SettingsManager")
	var complete := bool(settings.call("get_value", &"experience", &"tutorial_complete", false)) if settings != null else false
	var hints_enabled := bool(settings.call("get_value", &"experience", &"show_control_hints", true)) if settings != null else true
	active = not complete and hints_enabled
	current_step = 0
	if active:
		call_deferred("_show_current_step")


func _process(_delta: float) -> void:
	if not active or _advance_pending or get_tree().paused:
		return
	var step_id: StringName = STEPS[current_step]["id"]
	match step_id:
		&"move":
			if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
				complete_current(&"move")
		&"jump":
			if Input.is_action_just_pressed("jump"):
				complete_current(&"jump")
		&"fire":
			if Input.is_action_just_pressed("fire"):
				complete_current(&"fire")
		&"switch":
			for action in [&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4"]:
				if Input.is_action_just_pressed(action):
					complete_current(&"switch")
					break
		&"reload":
			if Input.is_action_just_pressed("reload"):
				complete_current(&"reload")
		&"sprint":
			if Input.is_action_pressed("sprint") and (Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")):
				complete_current(&"sprint")


func notify_action(action: StringName) -> void:
	if not active or _advance_pending:
		return
	if StringName(STEPS[current_step]["id"]) == action:
		complete_current(action)


func complete_current(action: StringName) -> void:
	if not active or _advance_pending or StringName(STEPS[current_step]["id"]) != action:
		return
	_advance_pending = true
	if hud != null:
		hud.hide_controls()
	await get_tree().create_timer(0.18, false).timeout
	current_step += 1
	_advance_pending = false
	if current_step >= STEPS.size():
		_finish_tutorial()
	else:
		_show_current_step()


func skip_and_complete() -> void:
	if not active:
		return
	_finish_tutorial()


func get_debug_snapshot() -> Dictionary:
	return {
		"active": active,
		"index": current_step,
		"step": StringName(STEPS[current_step]["id"]) if active and current_step < STEPS.size() else &"complete",
	}


func _show_current_step() -> void:
	if not active or hud == null or current_step >= STEPS.size():
		return
	var step: Dictionary = STEPS[current_step]
	hud.show_controls_hint(str(step["text"]), 0.0)
	step_changed.emit(StringName(step["id"]), current_step)


func _finish_tutorial() -> void:
	active = false
	if hud != null:
		hud.hide_controls()
		hud.show_banner("TRAINING PROTOCOL COMPLETE", Color(0.38, 1.0, 0.68, 1.0), false, 0.8)
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.call("set_value", &"experience", &"tutorial_complete", true)
	tutorial_completed.emit()
