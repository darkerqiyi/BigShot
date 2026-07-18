extends Node

signal mix_changed(snapshot: Dictionary)
signal music_changed(track: StringName)

const SAMPLE_RATE := 22050
const MUSIC_SAMPLE_RATE := 11025
const MAX_SFX_VOICES := 20
const BUS_ORDER: Array[StringName] = [&"Master", &"Music", &"SFX", &"Weapons", &"Player", &"Enemies", &"Boss", &"UI"]
const BUS_SENDS := {
	&"Music": &"Master",
	&"SFX": &"Master",
	&"Weapons": &"SFX",
	&"Player": &"SFX",
	&"Enemies": &"SFX",
	&"Boss": &"SFX",
	&"UI": &"SFX",
}
const DEFAULT_LEVELS := {
	&"Master": 100,
	&"Music": 72,
	&"SFX": 86,
}
const LEGACY_ALIASES := {
	&"shot": &"rifle",
	&"accent_shot": &"rifle_accent",
	&"switch": &"weapon_switch",
	&"hit": &"impact_normal",
	&"accent_hit": &"impact_heavy",
	&"wall": &"impact_wall",
	&"kill": &"enemy_kill_light",
	&"hurt": &"player_hurt",
	&"warning": &"enemy_warning",
	&"boss_phase": &"boss_phase_2",
	&"boss_down": &"boss_death",
	&"complete": &"mission_complete",
}

# Every value affecting mix density lives here. Gameplay scripts only request semantic cues.
const CUE_PROFILES := {
	&"rifle": {"bus": &"Weapons", "volume": -7.0, "cooldown": 0.036, "max": 3, "priority": 1, "pitch": 0.016, "synth": [112.0, 0.070, 0.38, 0.48, 1.68], "shape": [2.90, 0.18, 0.20]},
	&"rifle_accent": {"bus": &"Weapons", "volume": -6.0, "cooldown": 0.055, "max": 2, "priority": 2, "pitch": 0.012, "synth": [88.0, 0.092, 0.52, 0.70, 1.46], "shape": [2.45, 0.28, 0.18]},
	&"shotgun": {"bus": &"Weapons", "volume": -4.7, "cooldown": 0.110, "max": 2, "priority": 3, "pitch": 0.005, "synth": [58.0, 0.225, 0.62, -0.48, 1.28], "shape": [1.42, 0.76, 0.14]},
	&"shotgun_air": {"bus": &"Weapons", "volume": -10.0, "cooldown": 0.110, "max": 1, "priority": 2, "pitch": 0.004, "synth": [286.0, 0.090, 0.66, 0.72, 2.05], "shape": [1.90, 0.08, 0.24]},
	&"sniper": {"bus": &"Weapons", "volume": -4.0, "cooldown": 0.160, "max": 2, "priority": 3, "pitch": 0.003, "synth": [172.0, 0.270, 0.30, 1.20, 2.92], "shape": [1.32, 0.34, 0.34]},
	&"sniper_crack": {"bus": &"Weapons", "volume": -8.5, "cooldown": 0.160, "max": 1, "priority": 3, "pitch": 0.002, "synth": [930.0, 0.058, 0.12, 1.12, 3.10], "shape": [2.45, 0.01, 0.52]},
	&"sniper_tail": {"bus": &"Weapons", "volume": -10.5, "cooldown": 0.160, "max": 1, "priority": 1, "pitch": 0.0, "synth": [108.0, 0.340, 0.54, -0.22, 1.40], "shape": [1.04, 0.30, 0.04]},
	&"pistol": {"bus": &"Weapons", "volume": -8.0, "cooldown": 0.060, "max": 2, "priority": 2, "pitch": 0.014, "synth": [158.0, 0.065, 0.28, 0.34, 1.86], "shape": [2.85, 0.22, 0.11]},
	&"rifle_mechanic": {"bus": &"Weapons", "volume": -13.2, "cooldown": 0.055, "max": 1, "priority": 0, "pitch": 0.018, "synth": [840.0, 0.032, 0.16, -0.30, 1.35]},
	&"shotgun_pump": {"bus": &"Weapons", "volume": -8.1, "cooldown": 0.280, "max": 1, "priority": 1, "pitch": 0.005, "synth": [164.0, 0.135, 0.34, 0.48, 1.60]},
	&"sniper_bolt": {"bus": &"Weapons", "volume": -7.8, "cooldown": 0.320, "max": 1, "priority": 1, "pitch": 0.003, "synth": [540.0, 0.125, 0.15, -0.44, 1.38]},
	&"pistol_slide": {"bus": &"Weapons", "volume": -12.0, "cooldown": 0.080, "max": 1, "priority": 0, "pitch": 0.016, "synth": [620.0, 0.035, 0.10, -0.18, 1.52]},
	&"weapon_switch": {"bus": &"UI", "volume": -11.0, "cooldown": 0.055, "max": 1, "priority": 1, "pitch": 0.0, "synth": [720.0, 0.040, 0.06, 0.20, 1.50]},
	&"reload": {"bus": &"Player", "volume": -9.0, "cooldown": 0.100, "max": 1, "priority": 1, "pitch": 0.015, "synth": [430.0, 0.082, 0.14, 0.18, 1.68]},
	&"rifle_reload": {"bus": &"Weapons", "volume": -9.0, "cooldown": 0.200, "max": 1, "priority": 1, "pitch": 0.01, "synth": [390.0, 0.085, 0.14, -0.12, 1.72]},
	&"shotgun_reload": {"bus": &"Weapons", "volume": -7.8, "cooldown": 0.250, "max": 1, "priority": 1, "pitch": 0.01, "synth": [210.0, 0.125, 0.30, 0.38, 1.44]},
	&"sniper_reload": {"bus": &"Weapons", "volume": -8.0, "cooldown": 0.300, "max": 1, "priority": 1, "pitch": 0.008, "synth": [510.0, 0.120, 0.16, -0.32, 1.28]},
	&"pistol_reload": {"bus": &"Weapons", "volume": -10.0, "cooldown": 0.180, "max": 1, "priority": 1, "pitch": 0.02, "synth": [630.0, 0.070, 0.12, 0.14, 1.55]},
	&"mag_insert": {"bus": &"Weapons", "volume": -10.5, "cooldown": 0.090, "max": 2, "priority": 1, "pitch": 0.025, "synth": [330.0, 0.070, 0.22, 0.30, 1.62]},
	&"reload_complete": {"bus": &"Weapons", "volume": -11.0, "cooldown": 0.090, "max": 1, "priority": 1, "pitch": 0.01, "synth": [780.0, 0.050, 0.04, 0.20, 1.42]},
	&"empty_click": {"bus": &"Weapons", "volume": -9.5, "cooldown": 0.160, "max": 1, "priority": 2, "pitch": 0.015, "synth": [1080.0, 0.045, 0.10, -0.18, 1.24]},
	&"impact_normal": {"bus": &"SFX", "volume": -10.0, "cooldown": 0.026, "max": 3, "priority": 1, "pitch": 0.045, "synth": [610.0, 0.045, 0.44, 0.20, 1.83]},
	&"impact_armor": {"bus": &"Enemies", "volume": -9.0, "cooldown": 0.040, "max": 2, "priority": 2, "pitch": 0.025, "synth": [1080.0, 0.052, 0.18, -0.22, 1.31]},
	&"impact_heavy": {"bus": &"SFX", "volume": -6.2, "cooldown": 0.060, "max": 2, "priority": 3, "pitch": 0.018, "synth": [226.0, 0.118, 0.62, -0.42, 1.47]},
	&"headshot": {"bus": &"SFX", "volume": -7.2, "cooldown": 0.055, "max": 2, "priority": 3, "pitch": 0.012, "synth": [920.0, 0.085, 0.08, 0.62, 1.76]},
	&"impact_wall": {"bus": &"SFX", "volume": -14.0, "cooldown": 0.035, "max": 2, "priority": 0, "pitch": 0.05, "synth": [980.0, 0.030, 0.20, 0.08, 1.33]},
	&"shield_block": {"bus": &"Enemies", "volume": -7.4, "cooldown": 0.060, "max": 2, "priority": 2, "pitch": 0.018, "synth": [1180.0, 0.070, 0.12, -0.34, 1.27]},
	&"guard_break": {"bus": &"Enemies", "volume": -5.4, "cooldown": 0.100, "max": 2, "priority": 3, "pitch": 0.01, "synth": [180.0, 0.160, 0.56, -0.60, 1.52]},
	&"enemy_warning": {"bus": &"Enemies", "volume": -12.0, "cooldown": 0.075, "max": 2, "priority": 2, "pitch": 0.025, "synth": [840.0, 0.105, 0.02, 0.34, 1.50]},
	&"elite_warning": {"bus": &"Enemies", "volume": -8.8, "cooldown": 0.180, "max": 1, "priority": 3, "pitch": 0.0, "synth": [238.0, 0.185, 0.30, 0.74, 1.33]},
	&"enemy_shot": {"bus": &"Enemies", "volume": -10.5, "cooldown": 0.042, "max": 3, "priority": 1, "pitch": 0.035, "synth": [210.0, 0.078, 0.27, -0.18, 1.71]},
	&"hazard": {"bus": &"Enemies", "volume": -9.5, "cooldown": 0.120, "max": 2, "priority": 2, "pitch": 0.01, "synth": [74.0, 0.190, 0.58, -0.50, 1.38]},
	&"enemy_kill_light": {"bus": &"Enemies", "volume": -7.0, "cooldown": 0.045, "max": 2, "priority": 2, "pitch": 0.04, "synth": [112.0, 0.175, 0.50, -0.58, 1.62]},
	&"enemy_kill_heavy": {"bus": &"Enemies", "volume": -4.8, "cooldown": 0.110, "max": 2, "priority": 3, "pitch": 0.012, "synth": [66.0, 0.290, 0.66, -0.72, 1.29]},
	&"enemy_hurt": {"bus": &"Enemies", "volume": -13.0, "cooldown": 0.055, "max": 2, "priority": 0, "pitch": 0.05, "synth": [310.0, 0.058, 0.26, -0.30, 1.46]},
	&"enemy_hurt_heavy": {"bus": &"Enemies", "volume": -8.5, "cooldown": 0.100, "max": 2, "priority": 2, "pitch": 0.02, "synth": [128.0, 0.130, 0.48, -0.55, 1.31]},
	&"assault_swing": {"bus": &"Enemies", "volume": -8.5, "cooldown": 0.160, "max": 2, "priority": 2, "pitch": 0.035, "synth": [240.0, 0.120, 0.44, 0.72, 1.32]},
	&"shield_bash": {"bus": &"Enemies", "volume": -6.8, "cooldown": 0.220, "max": 1, "priority": 3, "pitch": 0.015, "synth": [96.0, 0.180, 0.58, -0.45, 1.37]},
	&"elite_attack": {"bus": &"Enemies", "volume": -6.0, "cooldown": 0.220, "max": 1, "priority": 3, "pitch": 0.01, "synth": [116.0, 0.210, 0.46, 0.48, 1.49]},
	&"elite_step": {"bus": &"Enemies", "volume": -14.0, "cooldown": 0.180, "max": 1, "priority": 0, "pitch": 0.025, "synth": [62.0, 0.090, 0.66, -0.42, 1.22]},
	&"player_hurt": {"bus": &"Player", "volume": -5.5, "cooldown": 0.095, "max": 1, "priority": 3, "pitch": 0.018, "synth": [164.0, 0.145, 0.40, -0.36, 1.44]},
	&"player_death": {"bus": &"Player", "volume": -3.8, "cooldown": 0.400, "max": 1, "priority": 4, "pitch": 0.0, "synth": [86.0, 0.420, 0.58, -0.82, 1.26]},
	&"land": {"bus": &"Player", "volume": -12.5, "cooldown": 0.070, "max": 1, "priority": 0, "pitch": 0.035, "synth": [88.0, 0.068, 0.68, -0.42, 1.31]},
	&"heavy_land": {"bus": &"Player", "volume": -8.8, "cooldown": 0.120, "max": 1, "priority": 1, "pitch": 0.02, "synth": [62.0, 0.110, 0.72, -0.52, 1.26]},
	&"jump": {"bus": &"Player", "volume": -13.0, "cooldown": 0.080, "max": 1, "priority": 0, "pitch": 0.035, "synth": [210.0, 0.065, 0.22, 0.55, 1.52]},
	&"footstep": {"bus": &"Player", "volume": -17.0, "cooldown": 0.075, "max": 1, "priority": 0, "pitch": 0.05, "synth": [92.0, 0.045, 0.72, -0.28, 1.21]},
	&"roll": {"bus": &"Player", "volume": -12.0, "cooldown": 0.180, "max": 1, "priority": 1, "pitch": 0.03, "synth": [150.0, 0.090, 0.34, 0.48, 1.46]},
	&"projectile_evade": {"bus": &"Player", "volume": -10.5, "cooldown": 0.090, "max": 1, "priority": 2, "pitch": 0.025, "synth": [760.0, 0.065, 0.04, 0.34, 1.56]},
	&"grenade_throw": {"bus": &"Player", "volume": -9.5, "cooldown": 0.100, "max": 1, "priority": 2, "pitch": 0.02, "synth": [260.0, 0.090, 0.30, 0.58, 1.42]},
	&"grenade_bounce": {"bus": &"SFX", "volume": -12.0, "cooldown": 0.070, "max": 2, "priority": 1, "pitch": 0.05, "synth": [520.0, 0.045, 0.18, -0.32, 1.36]},
	&"grenade_fuse": {"bus": &"SFX", "volume": -11.5, "cooldown": 0.075, "max": 1, "priority": 2, "pitch": 0.0, "synth": [920.0, 0.045, 0.02, 0.18, 1.42]},
	&"grenade_explosion": {"bus": &"Weapons", "volume": -3.8, "cooldown": 0.160, "max": 2, "priority": 4, "pitch": 0.025, "synth": [58.0, 0.340, 0.82, -0.64, 1.20]},
	&"grenade_empty": {"bus": &"UI", "volume": -10.0, "cooldown": 0.180, "max": 1, "priority": 2, "pitch": 0.01, "synth": [900.0, 0.055, 0.08, -0.34, 1.28]},
	&"low_health": {"bus": &"Player", "volume": -8.5, "cooldown": 1.000, "max": 1, "priority": 3, "pitch": 0.0, "synth": [720.0, 0.160, 0.02, -0.22, 1.50]},
	&"boss_intro": {"bus": &"Boss", "volume": -4.0, "cooldown": 0.600, "max": 1, "priority": 4, "pitch": 0.0, "synth": [92.0, 0.440, 0.38, 0.74, 1.50]},
	&"boss_land": {"bus": &"Boss", "volume": -5.0, "cooldown": 0.500, "max": 1, "priority": 4, "pitch": 0.0, "synth": [48.0, 0.260, 0.78, -0.58, 1.18]},
	&"boss_phase_2": {"bus": &"Boss", "volume": -3.8, "cooldown": 0.500, "max": 1, "priority": 4, "pitch": 0.0, "synth": [278.0, 0.340, 0.16, 1.05, 1.26]},
	&"boss_phase_3": {"bus": &"Boss", "volume": -3.2, "cooldown": 0.500, "max": 1, "priority": 4, "pitch": 0.0, "synth": [352.0, 0.380, 0.22, 1.18, 1.41]},
	&"boss_warning_volley": {"bus": &"Boss", "volume": -8.0, "cooldown": 0.120, "max": 1, "priority": 3, "pitch": 0.0, "synth": [690.0, 0.140, 0.04, 0.56, 1.50]},
	&"boss_warning_charge": {"bus": &"Boss", "volume": -6.4, "cooldown": 0.180, "max": 1, "priority": 3, "pitch": 0.0, "synth": [118.0, 0.220, 0.42, 0.66, 1.27]},
	&"boss_warning_area": {"bus": &"Boss", "volume": -6.8, "cooldown": 0.180, "max": 1, "priority": 3, "pitch": 0.0, "synth": [196.0, 0.210, 0.16, 0.92, 2.00]},
	&"boss_cannon": {"bus": &"Boss", "volume": -6.2, "cooldown": 0.045, "max": 3, "priority": 2, "pitch": 0.012, "synth": [126.0, 0.120, 0.43, 0.44, 1.61]},
	&"boss_hit_normal": {"bus": &"Boss", "volume": -11.5, "cooldown": 0.040, "max": 2, "priority": 1, "pitch": 0.025, "synth": [520.0, 0.052, 0.34, -0.16, 1.48]},
	&"boss_hit_heavy": {"bus": &"Boss", "volume": -5.4, "cooldown": 0.090, "max": 2, "priority": 3, "pitch": 0.01, "synth": [146.0, 0.170, 0.58, -0.52, 1.32]},
	&"boss_death": {"bus": &"Boss", "volume": -2.8, "cooldown": 0.800, "max": 1, "priority": 5, "pitch": 0.0, "synth": [58.0, 0.620, 0.70, -0.76, 1.22]},
	&"boss_charge_release": {"bus": &"Boss", "volume": -4.8, "cooldown": 0.260, "max": 1, "priority": 4, "pitch": 0.0, "synth": [82.0, 0.250, 0.54, 0.62, 1.25]},
	&"boss_area_release": {"bus": &"Boss", "volume": -5.2, "cooldown": 0.260, "max": 1, "priority": 4, "pitch": 0.0, "synth": [170.0, 0.240, 0.24, -0.68, 1.81]},
	&"boss_failure": {"bus": &"Boss", "volume": -5.0, "cooldown": 0.700, "max": 1, "priority": 5, "pitch": 0.0, "synth": [390.0, 0.240, 0.22, -0.90, 1.24]},
	&"boss_explosion": {"bus": &"Boss", "volume": -4.0, "cooldown": 0.180, "max": 2, "priority": 4, "pitch": 0.04, "synth": [54.0, 0.280, 0.82, -0.55, 1.18]},
	&"boss_core_off": {"bus": &"Boss", "volume": -4.5, "cooldown": 0.600, "max": 1, "priority": 5, "pitch": 0.0, "synth": [440.0, 0.340, 0.12, -0.88, 1.33]},
	&"ui_pause": {"bus": &"UI", "volume": -9.5, "cooldown": 0.080, "max": 1, "priority": 2, "pitch": 0.0, "synth": [540.0, 0.075, 0.03, -0.20, 1.50]},
	&"ui_resume": {"bus": &"UI", "volume": -9.5, "cooldown": 0.080, "max": 1, "priority": 2, "pitch": 0.0, "synth": [620.0, 0.070, 0.03, 0.22, 1.50]},
	&"ui_adjust": {"bus": &"UI", "volume": -11.0, "cooldown": 0.035, "max": 1, "priority": 1, "pitch": 0.0, "synth": [760.0, 0.042, 0.02, 0.10, 1.33]},
	&"ui_confirm": {"bus": &"UI", "volume": -8.5, "cooldown": 0.080, "max": 1, "priority": 2, "pitch": 0.0, "synth": [680.0, 0.090, 0.03, 0.34, 1.50]},
	&"ui_hover": {"bus": &"UI", "volume": -14.0, "cooldown": 0.055, "max": 1, "priority": 0, "pitch": 0.0, "synth": [820.0, 0.035, 0.02, 0.10, 1.42]},
	&"mission_complete": {"bus": &"UI", "volume": -4.8, "cooldown": 0.600, "max": 1, "priority": 4, "pitch": 0.0, "synth": [560.0, 0.310, 0.03, 0.48, 1.50]},
}

static var _session_levels: Dictionary = {}
static var _session_mutes: Dictionary = {}

var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _voices: Array[Dictionary] = []
var _last_play_time: Dictionary = {}
var _accepted_plays: Dictionary = {}
var _bus_levels: Dictionary = {}
var _sequence := 0
var _rejected_plays := 0
var _peak_voice_count := 0
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _current_track: StringName = &""
var _music_tween: Tween
var _music_ducked := false
var _semantic_duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _session_levels.is_empty():
		_session_levels = DEFAULT_LEVELS.duplicate(true)
	if _session_mutes.is_empty():
		for bus_name in DEFAULT_LEVELS:
			_session_mutes[bus_name] = false
	_bus_levels = _session_levels.duplicate(true)
	_ensure_audio_buses()
	_build_streams()
	_build_voice_pool()
	_build_music_players()
	_apply_session_mix()
	play_music(&"level", 0.0)


func _process(_delta: float) -> void:
	_peak_voice_count = maxi(_peak_voice_count, get_active_voice_count())


func play_cue(cue: StringName, volume_offset_db: float = 0.0) -> bool:
	var resolved := _resolve_cue(cue)
	if not _streams.has(resolved):
		return false
	var profile: Dictionary = CUE_PROFILES[resolved]
	var now := float(Time.get_ticks_usec()) / 1000000.0
	var cooldown := float(profile["cooldown"])
	if now - float(_last_play_time.get(resolved, -999.0)) < cooldown:
		_rejected_plays += 1
		return false
	if _count_active_cue(resolved) >= int(profile["max"]):
		_rejected_plays += 1
		return false
	var voice_index := _find_voice(int(profile["priority"]))
	if voice_index < 0:
		_rejected_plays += 1
		return false
	var voice := _voices[voice_index]
	var player: AudioStreamPlayer = voice["player"]
	player.stop()
	player.stream = _streams[resolved]
	player.bus = String(profile["bus"])
	player.volume_db = float(profile["volume"]) + clampf(volume_offset_db, -12.0, 3.0)
	_sequence += 1
	var pitch_variation := float(profile["pitch"])
	player.pitch_scale = 1.0 + sin(float(_sequence) * 2.39996) * pitch_variation
	voice["cue"] = resolved
	voice["priority"] = int(profile["priority"])
	voice["started"] = now
	_voices[voice_index] = voice
	_last_play_time[resolved] = now
	_accepted_plays[resolved] = int(_accepted_plays.get(resolved, 0)) + 1
	player.play()
	_peak_voice_count = maxi(_peak_voice_count, get_active_voice_count())
	return true


func play_world_cue(cue: StringName, source_position: Vector2, listener_position: Vector2, important: bool = false, volume_offset_db: float = 0.0) -> bool:
	return play_cue(cue, volume_offset_db + calculate_world_attenuation(source_position, listener_position, important))


func play_cue_delayed(cue: StringName, delay: float, volume_offset_db: float = 0.0) -> void:
	await get_tree().create_timer(maxf(delay, 0.0), true, false, true).timeout
	if is_inside_tree():
		play_cue(cue, volume_offset_db)


func play_world_cue_delayed(cue: StringName, delay: float, source_position: Vector2, listener_position: Vector2, important: bool = false, volume_offset_db: float = 0.0) -> void:
	await get_tree().create_timer(maxf(delay, 0.0), true, false, true).timeout
	if is_inside_tree():
		play_world_cue(cue, source_position, listener_position, important, volume_offset_db)


func calculate_world_attenuation(source_position: Vector2, listener_position: Vector2, important: bool = false) -> float:
	var distance := source_position.distance_to(listener_position)
	var ratio := clampf((distance - 220.0) / 1050.0, 0.0, 1.0)
	return lerpf(0.0, -6.0 if important else -14.0, ratio)


func stop_bus_cues(bus_name: StringName) -> void:
	for voice in _voices:
		var player: AudioStreamPlayer = voice["player"]
		if player.bus == String(bus_name):
			player.stop()
			voice["cue"] = &""


func duck_music(duration: float = 0.34, reduction_db: float = 4.5) -> void:
	if _semantic_duck_tween != null and _semantic_duck_tween.is_valid():
		_semantic_duck_tween.kill()
	var active := _music_players[_active_music_index]
	if not active.playing:
		return
	var base_volume := -7.0 if _music_ducked else -3.0
	_semantic_duck_tween = create_tween()
	_semantic_duck_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_semantic_duck_tween.tween_property(active, "volume_db", base_volume - clampf(reduction_db, 0.0, 8.0), 0.045)
	_semantic_duck_tween.tween_interval(maxf(duration, 0.0))
	_semantic_duck_tween.tween_property(active, "volume_db", base_volume, 0.16)


func has_cue(cue: StringName) -> bool:
	var resolved := _resolve_cue(cue)
	return _streams.has(resolved) and (_streams[resolved] as AudioStreamWAV).data.size() > 0


func get_cue_profile(cue: StringName) -> Dictionary:
	var resolved := _resolve_cue(cue)
	return (CUE_PROFILES.get(resolved, {}) as Dictionary).duplicate(true)


func get_active_voice_count() -> int:
	var count := 0
	for voice in _voices:
		if (voice["player"] as AudioStreamPlayer).playing:
			count += 1
	return count


func get_rejected_play_count() -> int:
	return _rejected_plays


func get_play_count(cue: StringName) -> int:
	return int(_accepted_plays.get(_resolve_cue(cue), 0))


func get_peak_voice_count() -> int:
	return _peak_voice_count


func play_music(track: StringName, fade_duration: float = 0.45) -> void:
	if not _music_streams.has(track) or track == _current_track:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var old_player := _music_players[_active_music_index]
	_active_music_index = 1 - _active_music_index
	var next_player := _music_players[_active_music_index]
	next_player.stream = _music_streams[track]
	next_player.volume_db = -36.0
	next_player.play()
	_current_track = track
	var target_volume := -7.0 if _music_ducked else -3.0
	if fade_duration <= 0.0:
		old_player.stop()
		next_player.volume_db = target_volume
		music_changed.emit(track)
		return
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.set_parallel(true)
	_music_tween.tween_property(old_player, "volume_db", -36.0, fade_duration)
	_music_tween.tween_property(next_player, "volume_db", target_volume, fade_duration)
	_music_tween.chain().tween_callback(old_player.stop)
	music_changed.emit(track)


func stop_music(fade_duration: float = 0.4) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_current_track = &""
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.set_parallel(true)
	for player in _music_players:
		_music_tween.tween_property(player, "volume_db", -36.0, fade_duration)
	_music_tween.chain().tween_callback(func() -> void:
		for player in _music_players:
			player.stop()
	)
	music_changed.emit(&"")


func set_game_paused(paused: bool) -> void:
	_music_ducked = paused
	if _semantic_duck_tween != null and _semantic_duck_tween.is_valid():
		_semantic_duck_tween.kill()
	var active := _music_players[_active_music_index]
	if active.playing:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(active, "volume_db", -7.0 if paused else -3.0, 0.12)


func adjust_bus_step(bus_name: StringName, delta_steps: int) -> void:
	if not DEFAULT_LEVELS.has(bus_name):
		return
	set_bus_level(bus_name, int(_bus_levels.get(bus_name, 100)) + delta_steps * 10)


func set_bus_level(bus_name: StringName, percent: int) -> void:
	if not DEFAULT_LEVELS.has(bus_name):
		return
	var clamped := clampi(percent, 0, 100)
	_bus_levels[bus_name] = clamped
	_session_levels[bus_name] = clamped
	var index := AudioServer.get_bus_index(String(bus_name))
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(clamped) / 100.0, 0.0001)))
	mix_changed.emit(get_mix_snapshot())


func toggle_bus_mute(bus_name: StringName) -> void:
	var index := AudioServer.get_bus_index(String(bus_name))
	if index < 0 or not DEFAULT_LEVELS.has(bus_name):
		return
	AudioServer.set_bus_mute(index, not AudioServer.is_bus_mute(index))
	_session_mutes[bus_name] = AudioServer.is_bus_mute(index)
	mix_changed.emit(get_mix_snapshot())


func get_mix_snapshot() -> Dictionary:
	var snapshot := {}
	for bus_name in DEFAULT_LEVELS:
		var index := AudioServer.get_bus_index(String(bus_name))
		snapshot[bus_name] = {
			"percent": int(_bus_levels.get(bus_name, DEFAULT_LEVELS[bus_name])),
			"muted": AudioServer.is_bus_mute(index) if index >= 0 else false,
		}
	return snapshot


func get_audio_contract() -> Dictionary:
	return {
		"buses": BUS_ORDER.duplicate(),
		"max_voices": MAX_SFX_VOICES,
		"cue_count": CUE_PROFILES.size(),
		"music_tracks": _music_streams.keys(),
		"current_track": _current_track,
		"music_players": _music_players.size(),
		"spatial_ordinary_floor_db": -14.0,
		"spatial_important_floor_db": -6.0,
	}


func _resolve_cue(cue: StringName) -> StringName:
	return LEGACY_ALIASES.get(cue, cue) as StringName


func _count_active_cue(cue: StringName) -> int:
	var count := 0
	for voice in _voices:
		if voice["cue"] == cue and (voice["player"] as AudioStreamPlayer).playing:
			count += 1
	return count


func _find_voice(request_priority: int) -> int:
	for index in range(_voices.size()):
		if not (_voices[index]["player"] as AudioStreamPlayer).playing:
			return index
	var candidate := -1
	var candidate_priority := request_priority
	var oldest := INF
	for index in range(_voices.size()):
		var priority := int(_voices[index]["priority"])
		var started := float(_voices[index]["started"])
		if priority < candidate_priority or (priority == candidate_priority and started < oldest):
			candidate = index
			candidate_priority = priority
			oldest = started
	return candidate


func _build_voice_pool() -> void:
	for index in range(MAX_SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % index
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_voices.append({"player": player, "cue": &"", "priority": -1, "started": -999.0})


func _build_music_players() -> void:
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicDeck%d" % (index + 1)
		player.bus = "Music"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_music_players.append(player)


func _build_streams() -> void:
	for cue in CUE_PROFILES:
		var profile: Dictionary = CUE_PROFILES[cue]
		var synth: Array = profile["synth"]
		var shape: Array = profile.get("shape", [2.15, 0.0, 0.0])
		_streams[cue] = _make_stream(float(synth[0]), float(synth[1]), float(synth[2]), float(synth[3]), float(synth[4]), shape)
	_music_streams[&"level"] = _make_music_stream(false)
	_music_streams[&"boss"] = _make_music_stream(true)


func _apply_session_mix() -> void:
	for bus_name in DEFAULT_LEVELS:
		set_bus_level(bus_name, int(_session_levels.get(bus_name, DEFAULT_LEVELS[bus_name])))
		var index := AudioServer.get_bus_index(String(bus_name))
		if index >= 0:
			AudioServer.set_bus_mute(index, bool(_session_mutes.get(bus_name, false)))


func _ensure_audio_buses() -> void:
	for bus_name in BUS_ORDER:
		if AudioServer.get_bus_index(String(bus_name)) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, String(bus_name))
	for bus_name in BUS_SENDS:
		var index := AudioServer.get_bus_index(String(bus_name))
		AudioServer.set_bus_send(index, String(BUS_SENDS[bus_name]))
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0 and AudioServer.get_bus_effect_count(master_index) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -3.0
		AudioServer.add_bus_effect(master_index, limiter)


func _make_stream(base_frequency: float, duration: float, noise_mix: float, chirp: float, overtone: float, shape: Array = [2.15, 0.0, 0.0]) -> AudioStreamWAV:
	var frame_count := maxi(int(float(SAMPLE_RATE) * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var tail_power := float(shape[0])
	var thump_mix := float(shape[1])
	var crack_mix := float(shape[2])
	for frame in range(frame_count):
		var time := float(frame) / float(SAMPLE_RATE)
		var progress := float(frame) / float(frame_count)
		var attack := minf(progress / 0.035, 1.0)
		var envelope := attack * pow(1.0 - progress, tail_power)
		var frequency := base_frequency * (1.0 + chirp * (1.0 - progress))
		var fundamental := sin(TAU * frequency * time)
		var harmonic := sin(TAU * frequency * overtone * time + 0.35) * 0.34
		var noise := sin(float(frame) * 78.233) * 0.50 + sin(float(frame) * 19.731) * 0.31 + sin(float(frame) * 5.117) * 0.19
		var tonal := fundamental * 0.72 + harmonic
		var core := (tonal * (1.0 - noise_mix) + noise * noise_mix) * envelope
		var transient_envelope := attack * pow(1.0 - progress, 8.0)
		var thump_frequency := maxf(55.0, base_frequency * 0.72)
		var thump := sin(TAU * thump_frequency * time + 0.12) * thump_mix
		var crack_frequency := base_frequency * (4.2 + overtone)
		var crack := (1.0 if sin(TAU * crack_frequency * time) >= 0.0 else -1.0) * crack_mix
		var transient := (thump + crack) * transient_envelope * 0.45
		var sample := (core + transient) * 0.68
		bytes.encode_s16(frame * 2, int(clampf(sample, -0.78, 0.78) * 32767.0))
	return _make_wav(bytes, SAMPLE_RATE, false)


func _make_music_stream(is_boss: bool) -> AudioStreamWAV:
	var bpm := 138.0 if is_boss else 120.0
	var beats := 16
	var beat_duration := 60.0 / bpm
	var duration := beat_duration * float(beats)
	var frame_count := int(duration * MUSIC_SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var roots := [55.0, 65.41, 73.42, 49.0] if is_boss else [65.41, 82.41, 73.42, 98.0]
	var melody := [0, 7, 12, 7, 3, 10, 7, 15] if is_boss else [0, 4, 7, 12, 7, 4, 9, 7]
	for frame in range(frame_count):
		var time := float(frame) / float(MUSIC_SAMPLE_RATE)
		var beat_position := time / beat_duration
		var beat_index := int(floor(beat_position))
		var beat_phase := fmod(beat_position, 1.0)
		var root := float(roots[(beat_index / 4) % roots.size()])
		var note_index: int = int(melody[(beat_index * 2 + int(beat_phase * 2.0)) % melody.size()])
		var note_frequency := root * 2.0 * pow(2.0, float(note_index) / 12.0)
		var gate := 1.0 if fmod(beat_phase, 0.5) < 0.34 else 0.0
		var melody_wave := (1.0 if sin(TAU * note_frequency * time) >= 0.0 else -1.0) * gate * (0.105 if is_boss else 0.085)
		var bass := sin(TAU * root * time) * (0.16 if is_boss else 0.13)
		var pad := sin(TAU * root * 2.0 * time) * 0.045 + sin(TAU * root * 3.0 * time) * 0.026
		var kick_phase := fmod(beat_phase, 1.0)
		var kick := sin(TAU * (52.0 + 48.0 * (1.0 - kick_phase)) * time) * exp(-kick_phase * 10.0) * (0.22 if is_boss else 0.16)
		var hat_phase := fmod(beat_position * 2.0, 1.0)
		var noise := sin(float(frame) * 41.73) * sin(float(frame) * 7.19)
		var hat := noise * exp(-hat_phase * 18.0) * (0.045 if is_boss else 0.032)
		var pulse := 0.025 * sin(TAU * (root * 0.5) * time) if is_boss else 0.0
		var sample := clampf(melody_wave + bass + pad + kick + hat + pulse, -0.68, 0.68)
		bytes.encode_s16(frame * 2, int(sample * 32767.0))
	return _make_wav(bytes, MUSIC_SAMPLE_RATE, true)


func _make_wav(bytes: PackedByteArray, mix_rate: int, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	stream.loop_end = bytes.size() / 2
	stream.data = bytes
	return stream
