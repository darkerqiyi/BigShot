extends Node
class_name CombatFeedback

signal shake_scale_changed(scale: float)

const PROFILES := {
	&"rifle_shot": {"shake": 0.012, "cap": 0.14, "hold": 0.0},
	&"shotgun_shot": {"shake": 0.10, "cap": 0.30, "hold": 0.0},
	&"sniper_shot": {"shake": 0.16, "cap": 0.34, "hold": 0.0},
	&"pistol_shot": {"shake": 0.002, "cap": 0.05, "hold": 0.0},
	&"enemy_shot": {"shake": 0.0, "cap": 0.0, "hold": 0.0},
	&"normal_hit": {"shake": 0.025, "cap": 0.18, "hold": 0.0},
	&"shotgun_hit": {"shake": 0.07, "cap": 0.28, "hold": 0.022},
	&"sniper_hit": {"shake": 0.11, "cap": 0.36, "hold": 0.038},
	&"heavy_hit": {"shake": 0.075, "cap": 0.30, "hold": 0.026},
	&"wall_hit": {"shake": 0.01, "cap": 0.08, "hold": 0.0},
	&"guard_block": {"shake": 0.025, "cap": 0.16, "hold": 0.0},
	&"guard_break": {"shake": 0.08, "cap": 0.30, "hold": 0.032},
	&"kill_light": {"shake": 0.18, "cap": 0.34, "hold": 0.018},
	&"kill_heavy": {"shake": 0.28, "cap": 0.48, "hold": 0.032},
	&"boss_normal": {"shake": 0.012, "cap": 0.20, "hold": 0.0},
	&"boss_heavy": {"shake": 0.12, "cap": 0.42, "hold": 0.03},
	&"player_hurt": {"shake": 0.24, "cap": 0.48, "hold": 0.0},
	&"land": {"shake": 0.035, "cap": 0.12, "hold": 0.0},
	&"player_death": {"shake": 0.55, "cap": 0.72, "hold": 0.035},
	&"boss_intro": {"shake": 0.34, "cap": 0.45, "hold": 0.0},
	&"boss_phase": {"shake": 0.38, "cap": 0.50, "hold": 0.025},
	&"boss_death": {"shake": 0.52, "cap": 0.70, "hold": 0.045},
	&"complete": {"shake": 0.25, "cap": 0.35, "hold": 0.0},
}

var shake_scale := 1.0
var _camera: Camera2D
var _frame_groups: Dictionary = {}
var _accepted_shakes := 0
var _merged_requests := 0
var _last_profile: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("combat_feedback")


func configure(camera: Camera2D) -> void:
	_camera = camera


func request_shake(profile: StringName, merge_group: StringName = &"") -> bool:
	var data: Dictionary = PROFILES.get(profile, PROFILES[&"normal_hit"])
	var amount := float(data["shake"]) * shake_scale
	if amount <= 0.0 or _camera == null:
		return false
	var group := merge_group if merge_group != &"" else profile
	if _already_requested_this_frame(&"shake", group):
		_merged_requests += 1
		return false
	_camera.call("add_trauma_limited", amount, float(data["cap"]) * shake_scale)
	_accepted_shakes += 1
	_last_profile = profile
	return true


func request_visual_hold(profile: StringName, merge_group: StringName = &"") -> float:
	var data: Dictionary = PROFILES.get(profile, PROFILES[&"normal_hit"])
	var duration := float(data["hold"])
	if duration <= 0.0:
		return 0.0
	var group := merge_group if merge_group != &"" else profile
	if _already_requested_this_frame(&"hold", group):
		_merged_requests += 1
		return 0.0
	return duration


func cycle_shake_scale() -> float:
	if shake_scale > 0.75:
		shake_scale = 0.5
	elif shake_scale > 0.1:
		shake_scale = 0.0
	else:
		shake_scale = 1.0
	shake_scale_changed.emit(shake_scale)
	return shake_scale


func clear() -> void:
	_frame_groups.clear()
	if _camera != null and _camera.has_method("clear_feedback"):
		_camera.call("clear_feedback")


func get_debug_snapshot() -> Dictionary:
	return {
		"shake_scale": shake_scale,
		"accepted_shakes": _accepted_shakes,
		"merged_requests": _merged_requests,
		"last_profile": _last_profile,
	}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		cycle_shake_scale()
		get_viewport().set_input_as_handled()


func _already_requested_this_frame(channel: StringName, group: StringName) -> bool:
	var key := "%s:%s" % [channel, group]
	var frame := Engine.get_physics_frames()
	if int(_frame_groups.get(key, -1)) == frame:
		return true
	_frame_groups[key] = frame
	return false
