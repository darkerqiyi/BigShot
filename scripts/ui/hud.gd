extends CanvasLayer

signal restart_requested
signal quit_requested
signal menu_requested
signal map_select_requested
signal audio_adjust_requested(bus_name: StringName, delta_steps: int)
signal audio_mute_requested(bus_name: StringName)
signal ui_cue_requested(cue: StringName)
signal pause_changed(paused: bool)

enum BossUIState {
	HIDDEN,
	INTRO,
	ACTIVE,
	PHASE_TRANSITION,
	DEFEATED,
}

const Style := preload("res://scripts/ui/pixel_ui_style.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const SLOT_IDS: Array[StringName] = [&"rifle", &"shotgun", &"sniper", &"pistol"]
const SLOT_NAMES := ["AUTO RIFLE", "SCATTERGUN", "RAIL LANCE", "SIDEARM"]
const SLOT_SHORT_NAMES := ["AUTO", "SCATTER", "LANCE", "SIDE"]
const SLOT_ICON_KINDS := ["rifle", "shotgun", "sniper", "pistol"]
const SLOT_COLORS := [Style.GOLD, Color("ff6c3a"), Style.SHIELD, Style.HEALTH]
const UI_SCALE_CHOICES := [80, 90, 100]
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI"]
const CONTROLS_TEXT := "A/D MOVE  •  AA/DD ROLL  •  SPACE JUMP  •  MOUSE AIM  •  LMB/J FIRE  •  RMB GRENADE  •  1—4 WEAPONS  •  R RELOAD  •  ESC PAUSE"

@onready var player_panel: PanelContainer = $PlayerPanel
@onready var health_bar: ProgressBar = $PlayerPanel/Content/Info/HealthBar
@onready var health_label: Label = $PlayerPanel/Content/Info/HealthRow/HealthLabel
@onready var health_value: Label = $PlayerPanel/Content/Info/HealthRow/HealthValue
@onready var ammo_label: Label = $PlayerPanel/Content/Info/AmmoLabel
@onready var score_panel: PanelContainer = $ScorePanel
@onready var score_label: Label = $ScorePanel/ScoreLabel
@onready var objective_label: Label = $Objective
@onready var banner: Label = $Banner
@onready var controls_label: Label = $Controls
@onready var crosshair: Node2D = $Crosshair
@onready var survival_panel: PanelContainer = $SurvivalPanel
@onready var survival_title: Label = $SurvivalPanel/Rows/Title
@onready var survival_state: Label = $SurvivalPanel/Rows/State
@onready var survival_stats: Label = $SurvivalPanel/Rows/Stats

@onready var weapon_rack: PanelContainer = $WeaponRack
@onready var weapon_name_label: Label = $WeaponRack/Content/Header/CurrentWeaponLabel
@onready var weapon_slots: Array[PanelContainer] = [
	$WeaponRack/Content/Grid/Slot1,
	$WeaponRack/Content/Grid/Slot2,
	$WeaponRack/Content/Grid/Slot3,
	$WeaponRack/Content/Grid/Slot4,
]
@onready var weapon_icons: Array[Control] = [
	$WeaponRack/Content/Grid/Slot1/Row/Icon,
	$WeaponRack/Content/Grid/Slot2/Row/Icon,
	$WeaponRack/Content/Grid/Slot3/Row/Icon,
	$WeaponRack/Content/Grid/Slot4/Row/Icon,
]
@onready var weapon_key_labels: Array[Label] = [
	$WeaponRack/Content/Grid/Slot1/Row/Key,
	$WeaponRack/Content/Grid/Slot2/Row/Key,
	$WeaponRack/Content/Grid/Slot3/Row/Key,
	$WeaponRack/Content/Grid/Slot4/Row/Key,
]
@onready var weapon_slot_names: Array[Label] = [
	$WeaponRack/Content/Grid/Slot1/Row/Info/Name,
	$WeaponRack/Content/Grid/Slot2/Row/Info/Name,
	$WeaponRack/Content/Grid/Slot3/Row/Info/Name,
	$WeaponRack/Content/Grid/Slot4/Row/Info/Name,
]
@onready var weapon_ammo_labels: Array[Label] = [
	$WeaponRack/Content/Grid/Slot1/Row/Info/Ammo,
	$WeaponRack/Content/Grid/Slot2/Row/Info/Ammo,
	$WeaponRack/Content/Grid/Slot3/Row/Info/Ammo,
	$WeaponRack/Content/Grid/Slot4/Row/Info/Ammo,
]

@onready var boss_panel: PanelContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/Rows/BossName
@onready var boss_actual_bar: ProgressBar = $BossPanel/Rows/BarStack/Actual
@onready var boss_delayed_bar: ProgressBar = $BossPanel/Rows/BarStack/Delayed
@onready var boss_value_label: Label = $BossPanel/Rows/BarStack/Value
@onready var boss_phase_label: Label = $BossPanel/Rows/PhaseLabel
@onready var boss_thresholds: Control = $BossPanel/Rows/BarStack/Thresholds
@onready var boss_phase_toast: Label = $BossPhaseToast

@onready var state_overlay: Control = $StateOverlay
@onready var state_panel: PanelContainer = $StateOverlay/Center/MenuPanel
@onready var state_title: Label = $StateOverlay/Center/MenuPanel/Content/Title
@onready var state_subtitle: Label = $StateOverlay/Center/MenuPanel/Content/Subtitle
@onready var primary_button: Button = $StateOverlay/Center/MenuPanel/Content/Primary
@onready var secondary_button: Button = $StateOverlay/Center/MenuPanel/Content/Secondary
@onready var map_select_button: Button = $StateOverlay/Center/MenuPanel/Content/MapSelect
@onready var settings_button: Button = $StateOverlay/Center/MenuPanel/Content/Settings
@onready var controls_button: Button = $StateOverlay/Center/MenuPanel/Content/Controls
@onready var main_menu_button: Button = $StateOverlay/Center/MenuPanel/Content/MainMenu
@onready var audio_settings: VBoxContainer = $StateOverlay/Center/MenuPanel/Content/AudioSettings
@onready var audio_value_labels := {
	&"Master": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MasterRow/Value,
	&"Music": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MusicRow/Value,
	&"SFX": $StateOverlay/Center/MenuPanel/Content/AudioSettings/SFXRow/Value,
	&"UI": $StateOverlay/Center/MenuPanel/Content/AudioSettings/UIRow/Value,
}
@onready var audio_mute_buttons := {
	&"Master": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MasterRow/Mute,
	&"Music": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MusicRow/Mute,
	&"SFX": $StateOverlay/Center/MenuPanel/Content/AudioSettings/SFXRow/Mute,
	&"UI": $StateOverlay/Center/MenuPanel/Content/AudioSettings/UIRow/Mute,
}
@onready var audio_minus_buttons := {
	&"Master": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MasterRow/Minus,
	&"Music": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MusicRow/Minus,
	&"SFX": $StateOverlay/Center/MenuPanel/Content/AudioSettings/SFXRow/Minus,
	&"UI": $StateOverlay/Center/MenuPanel/Content/AudioSettings/UIRow/Minus,
}
@onready var audio_plus_buttons := {
	&"Master": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MasterRow/Plus,
	&"Music": $StateOverlay/Center/MenuPanel/Content/AudioSettings/MusicRow/Plus,
	&"SFX": $StateOverlay/Center/MenuPanel/Content/AudioSettings/SFXRow/Plus,
	&"UI": $StateOverlay/Center/MenuPanel/Content/AudioSettings/UIRow/Plus,
}

var boss_ui_state := BossUIState.HIDDEN
var ui_scale_percent := 100
var controls_auto_hide_enabled := true
var survival_mode_enabled := false
var _survival_build_text := "NO UPGRADES"
var _survival_final_modifiers: Dictionary = {}

var _banner_tween: Tween
var _boss_flow_tween: Tween
var _phase_tween: Tween
var _boss_damage_tween: Tween
var _health_tween: Tween
var _objective_tween: Tween
var _controls_tween: Tween
var _score_tween: Tween
var _weapon_slot_tweens: Dictionary = {}
var _current_weapon_index := 0
var _last_health := -1
var _last_score := -1
var _last_boss_phase := 0
var _overlay_mode: StringName = &"none"
var _overlay_parent_mode: StringName = &"none"
var _controls_time_remaining := 4.0
var _controls_persistent := false
var _controls_hide_requested := false
var _weapon_initialized := false
var _weapon_hint_shown := false
var _last_hover_cue_msec := -1000
var _current_ammo := 0
var _current_magazine := 0
var _ammo_reloading := false
var _grenade_count := 3
var _settings_menu: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme()
	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)
	map_select_button.pressed.connect(_on_map_select_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	for button in [primary_button, secondary_button, map_select_button, settings_button, controls_button, main_menu_button]:
		_connect_hover_cue(button)
	for bus_name in AUDIO_BUSES:
		(audio_minus_buttons[bus_name] as Button).pressed.connect(_on_audio_step_pressed.bind(bus_name, -1))
		(audio_plus_buttons[bus_name] as Button).pressed.connect(_on_audio_step_pressed.bind(bus_name, 1))
		(audio_mute_buttons[bus_name] as Button).pressed.connect(_on_audio_mute_pressed.bind(bus_name))
		_connect_hover_cue(audio_minus_buttons[bus_name] as Button)
		_connect_hover_cue(audio_plus_buttons[bus_name] as Button)
		_connect_hover_cue(audio_mute_buttons[bus_name] as Button)
	state_overlay.visible = false
	audio_settings.visible = false
	boss_panel.visible = false
	boss_phase_toast.visible = false
	_configure_controls_text()
	for index in range(weapon_slots.size()):
		_apply_slot_state(index, index == 0)
	call_deferred("_apply_ui_scale")


func _connect_hover_cue(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		button.grab_focus()
		_on_ui_hover()
	)
	button.focus_entered.connect(_on_ui_hover)


func _on_ui_hover() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_cue_msec < 45:
		return
	_last_hover_cue_msec = now
	ui_cue_requested.emit(&"ui_hover")


func _apply_theme() -> void:
	var pixel_theme := Style.create_theme()
	for control in [player_panel, score_panel, weapon_rack, objective_label, survival_panel, boss_panel, boss_phase_toast, banner, controls_label, state_overlay]:
		(control as Control).theme = pixel_theme
	player_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Style.PRIMARY, Style.PANEL, 8.0, 5.0))
	score_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Color(Style.GOLD, 0.66), Color(Style.PANEL, 0.82), 7.0, 3.0, 2))
	weapon_rack.add_theme_stylebox_override("panel", Style.make_compact_panel(Style.SHIELD, Color(Style.PANEL, 0.92), 7.0, 5.0))
	survival_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Color("ff8a45"), Color(Style.PANEL, 0.92), 7.0, 4.0))
	boss_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Style.BOSS, Color(Style.PANEL, 0.96), 9.0, 4.0))
	state_panel.add_theme_stylebox_override("panel", Style.make_panel(Style.GOLD, Color(Style.PANEL, 0.99)))
	health_bar.add_theme_stylebox_override("background", Style.make_bar_background())
	health_bar.add_theme_stylebox_override("fill", Style.make_bar_fill(Style.HEALTH))
	boss_delayed_bar.add_theme_stylebox_override("background", Style.make_bar_background())
	boss_delayed_bar.add_theme_stylebox_override("fill", Style.make_bar_fill(Color("8d375b")))
	boss_actual_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	boss_actual_bar.add_theme_stylebox_override("fill", Style.make_bar_fill(Style.DANGER))


func set_ui_scale_percent(requested_percent: int) -> void:
	var selected := UI_SCALE_CHOICES[0]
	var closest_distance := absi(requested_percent - selected)
	for choice in UI_SCALE_CHOICES:
		var distance := absi(requested_percent - choice)
		if distance < closest_distance:
			selected = choice
			closest_distance = distance
	ui_scale_percent = selected
	call_deferred("_apply_ui_scale")


func _apply_ui_scale() -> void:
	if not is_node_ready():
		return
	var factor := float(ui_scale_percent) / 100.0
	player_panel.pivot_offset = Vector2.ZERO
	score_panel.pivot_offset = Vector2(score_panel.size.x, 0.0)
	weapon_rack.pivot_offset = Vector2(weapon_rack.size.x, 0.0)
	boss_panel.pivot_offset = Vector2(boss_panel.size.x * 0.5, 0.0)
	objective_label.pivot_offset = objective_label.size * 0.5
	boss_phase_toast.pivot_offset = boss_phase_toast.size * 0.5
	controls_label.pivot_offset = Vector2(controls_label.size.x * 0.5, controls_label.size.y)
	for control in [player_panel, score_panel, weapon_rack, survival_panel, boss_panel, objective_label, boss_phase_toast, controls_label]:
		(control as Control).scale = Vector2.ONE * factor


func _ui_scale() -> float:
	return float(ui_scale_percent) / 100.0


func set_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP"
	health_value.text = "%03d / %03d" % [current, maximum]
	if _last_health >= 0 and current != _last_health:
		if _health_tween != null and _health_tween.is_valid():
			_health_tween.kill()
		player_panel.modulate = Style.DANGER if current < _last_health else Style.HEALTH
		player_panel.scale = Vector2.ONE * _ui_scale() * 1.025
		_health_tween = _new_gameplay_tween()
		_health_tween.set_parallel(true)
		_health_tween.tween_property(player_panel, "modulate", Color.WHITE, 0.16)
		_health_tween.tween_property(player_panel, "scale", Vector2.ONE * _ui_scale(), 0.16)
	_last_health = current


func set_ammo(current: int, maximum: int, reloading: bool) -> void:
	_current_ammo = current
	_current_magazine = maximum
	_ammo_reloading = reloading
	_update_ammo_text()
	ammo_label.modulate = Style.DANGER if reloading or current <= 2 else Style.GOLD
	for index in range(weapon_ammo_labels.size()):
		weapon_ammo_labels[index].text = (("LOAD" if reloading else "%02d/%02d" % [current, maximum]) if index == _current_weapon_index else "")
		weapon_ammo_labels[index].modulate = SLOT_COLORS[index] if index == _current_weapon_index else Style.MUTED


func set_grenade_count(current: int, _maximum: int = 3) -> void:
	_grenade_count = maxi(current, 0)
	_update_ammo_text()


func _update_ammo_text() -> void:
	var magazine_text := "RELOADING" if _ammo_reloading else "MAG %02d / %02d" % [_current_ammo, _current_magazine]
	ammo_label.text = "%s  •  GRENADES %d" % [magazine_text, _grenade_count]


func set_weapon(current_id: StringName, weapon_data: Dictionary) -> void:
	var next_index := SLOT_IDS.find(current_id)
	if next_index < 0:
		return
	var changed := _weapon_initialized and next_index != _current_weapon_index
	_current_weapon_index = next_index
	weapon_name_label.text = str(weapon_data.get("display_name", SLOT_NAMES[next_index]))
	weapon_name_label.modulate = SLOT_COLORS[next_index]
	for index in range(weapon_slots.size()):
		_apply_slot_state(index, index == next_index)
	var old_tween: Tween = _weapon_slot_tweens.get(next_index) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var active_slot := weapon_slots[next_index]
	active_slot.pivot_offset = active_slot.size * 0.5
	active_slot.scale = Vector2(1.07, 1.07)
	var tween := _new_gameplay_tween()
	_weapon_slot_tweens[next_index] = tween
	tween.tween_property(active_slot, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if changed and not _weapon_hint_shown and boss_ui_state == BossUIState.HIDDEN:
		_weapon_hint_shown = true
		show_controls_hint("1—4 SWITCH WEAPON  •  R RELOAD", 1.6)
	_weapon_initialized = true


func _apply_slot_state(index: int, is_selected: bool) -> void:
	weapon_slots[index].add_theme_stylebox_override("panel", Style.make_slot_style(SLOT_COLORS[index], is_selected))
	weapon_key_labels[index].modulate = SLOT_COLORS[index] if is_selected else Color(Style.MUTED, 0.68)
	weapon_slot_names[index].text = SLOT_SHORT_NAMES[index]
	weapon_slot_names[index].modulate = Style.TEXT if is_selected else Color(Style.MUTED, 0.62)
	weapon_icons[index].configure(SLOT_ICON_KINDS[index], SLOT_COLORS[index], is_selected)
	weapon_icons[index].modulate = Color.WHITE if is_selected else Color(0.48, 0.52, 0.57, 0.58)
	if not is_selected:
		weapon_ammo_labels[index].text = ""
		weapon_ammo_labels[index].modulate = Color(Style.MUTED, 0.5)


func set_score(value: int) -> void:
	score_label.text = "SCORE %06d" % value
	if _last_score >= 0 and value > _last_score:
		if _score_tween != null and _score_tween.is_valid():
			_score_tween.kill()
		score_panel.modulate = Color(1.0, 0.92, 0.58, 1.0)
		score_panel.scale = Vector2.ONE * _ui_scale() * 1.055
		_score_tween = _new_gameplay_tween()
		_score_tween.set_parallel(true)
		_score_tween.tween_property(score_panel, "modulate", Color.WHITE, 0.16)
		_score_tween.tween_property(score_panel, "scale", Vector2.ONE * _ui_scale(), 0.16)
	_last_score = value


func set_survival_mode(enabled: bool) -> void:
	survival_mode_enabled = enabled
	survival_panel.visible = enabled
	if enabled:
		hide_objective(true)


func set_survival_status(wave: int, total_waves: int, alive: int, pending: int, countdown: float, state: StringName, elapsed: float, kills: int) -> void:
	if not survival_panel.visible:
		return
	var shown_wave := clampi(wave if wave > 0 else 1, 1, maxi(total_waves, 1))
	survival_title.text = "SURVIVAL // WAVE %02d / %02d" % [shown_wave, total_waves]
	var state_label := str({
		&"countdown": "DEPLOYMENT",
		&"spawning": "INCOMING",
		&"active": "ENGAGED",
		&"rest": "INTERMISSION",
		&"upgrade_selection": "UPGRADE SELECT",
		&"event_resolution": "FIELD EVENT",
		&"boss": "IRON TEMPEST",
		&"complete": "COMPLETE",
		&"stopped": "RUN ENDED",
	}.get(state, str(state).to_upper()))
	survival_state.text = "%s  •  %02d:%02d" % [state_label, int(ceil(countdown)) / 60, int(ceil(countdown)) % 60]
	var elapsed_seconds := int(elapsed)
	survival_stats.text = "HOSTILES %02d  •  QUEUED %02d  •  KILLS %03d  •  TIME %02d:%02d" % [alive, pending, kills, elapsed_seconds / 60, elapsed_seconds % 60]


func set_survival_build_summary(build: Array[Dictionary], final_modifiers: Dictionary) -> void:
	var parts: Array[String] = []
	for item in build:
		parts.append("%s x%d" % [str(item.get("display_name", item.get("id", "UPGRADE"))), int(item.get("stacks", 0))])
	_survival_build_text = "NO UPGRADES" if parts.is_empty() else "  •  ".join(parts)
	_survival_final_modifiers = final_modifiers.duplicate(true)


func _survival_parameter_text(modifiers: Dictionary = _survival_final_modifiers) -> String:
	if modifiers.is_empty():
		return "BASE PARAMETERS"
	return "HP %d  STAM %.0f  SPRINT %.0f  ROLL %.2fs  GRENADE %d / %.0fpx / %d" % [
		int(modifiers.get("max_health", 100)),
		float(modifiers.get("max_stamina", 100.0)),
		float(modifiers.get("sprint_speed", 468.0)),
		float(modifiers.get("roll_cooldown", 0.50)),
		int(modifiers.get("grenade_capacity", 3)),
		float(modifiers.get("grenade_radius", 110.0)),
		int(modifiers.get("grenade_damage", 80)),
	]


func show_survival_death(wave: int, elapsed: float, kills: int, damage_source: String) -> void:
	show_survival_failure({"reached_wave": wave, "elapsed": elapsed, "kills": kills}, damage_source)


func show_survival_failure(summary: Dictionary, damage_source: String) -> void:
	get_tree().paused = false
	_clear_transient_labels()
	_overlay_mode = &"death"
	state_title.text = "SURVIVAL RUN LOST"
	state_title.modulate = Style.DANGER
	var elapsed_seconds := int(round(float(summary.get("elapsed", 0.0))))
	var headshot_rate := float(summary.get("headshot_rate", 0.0)) * 100.0
	var event_text := _survival_event_summary(summary)
	state_subtitle.text = "REACHED WAVE %02d  •  TIME %02d:%02d  •  KILLS %03d\nDAMAGE %05d  •  TAKEN %04d  •  HEADSHOTS %02d / %.0f%%\nMOST USED // %s  •  LAST HIT // %s\nBUILD // %s\n%s" % [
		int(summary.get("reached_wave", 0)), elapsed_seconds / 60, elapsed_seconds % 60, int(summary.get("kills", 0)),
		int(summary.get("total_damage", 0)), int(summary.get("damage_received", 0)), int(summary.get("headshots", 0)), headshot_rate,
		_weapon_display_name(StringName(summary.get("most_used_weapon", &"rifle"))), damage_source.to_upper(), _survival_build_text, event_text,
	]
	primary_button.text = "RESTART SURVIVAL"
	secondary_button.visible = false
	map_select_button.visible = true
	settings_button.visible = false
	controls_button.visible = false
	main_menu_button.visible = true
	audio_settings.visible = false
	_show_state_overlay()


func show_survival_settlement(summary: Dictionary) -> void:
	_clear_transient_labels()
	_overlay_mode = &"settlement"
	state_title.text = "SURVIVAL COMPLETE"
	state_title.modulate = Style.HEALTH
	var elapsed_seconds := int(round(float(summary.get("elapsed", 0.0))))
	var best_seconds := int(round(float(summary.get("best_time", 0.0))))
	var weapon_kills: Dictionary = summary.get("weapon_kills", {})
	var build_items: Array = summary.get("upgrade_build", []) as Array
	var build_parts: Array[String] = []
	for item_value in build_items:
		var item: Dictionary = item_value
		build_parts.append("%s x%d" % [str(item.get("display_name", item.get("id", "UPGRADE"))), int(item.get("stacks", 0))])
	var build_text := "NONE" if build_parts.is_empty() else "  •  ".join(build_parts)
	var final_text := _survival_parameter_text(summary.get("upgrade_final_modifiers", {}) as Dictionary)
	var boss_seconds := int(round(float(summary.get("boss_time", 0.0))))
	var event_text := _survival_event_summary(summary)
	state_subtitle.text = "%s\n10 WAVES CLEARED  •  SCORE %06d  •  TIME %02d:%02d\nKILLS %03d  •  DAMAGE %05d  •  TAKEN %04d  •  HEADSHOTS %02d / %.0f%%\nMOST USED // %s  •  BOSS %02d:%02d  •  BEST COMBO %02d  •  ROLL EVADES %02d\nAUTO %02d  SCATTER %02d  LANCE %02d  SIDE %02d  GRENADE %02d\nBUILD // %s\nFINAL // %s\n%s\nRECORD %06d  •  BEST TIME %02d:%02d" % [
		str(summary.get("map_name", "SURVIVAL BATTLEGROUND")),
		int(summary.get("score", 0)), elapsed_seconds / 60, elapsed_seconds % 60,
		int(summary.get("kills", 0)), int(summary.get("total_damage", 0)), int(summary.get("damage_received", 0)), int(summary.get("headshots", 0)), float(summary.get("headshot_rate", 0.0)) * 100.0,
		_weapon_display_name(StringName(summary.get("most_used_weapon", &"rifle"))), boss_seconds / 60, boss_seconds % 60, int(summary.get("highest_combo", 0)), int(summary.get("roll_evades", 0)),
		int(weapon_kills.get(&"rifle", 0)), int(weapon_kills.get(&"shotgun", 0)), int(weapon_kills.get(&"sniper", 0)), int(weapon_kills.get(&"pistol", 0)), int(summary.get("grenade_kills", 0)),
		build_text,
		final_text,
		event_text,
		int(summary.get("best_score", 0)), best_seconds / 60, best_seconds % 60,
	]
	primary_button.text = "REPLAY SURVIVAL"
	secondary_button.visible = false
	map_select_button.visible = true
	settings_button.visible = false
	controls_button.visible = false
	main_menu_button.visible = true
	audio_settings.visible = false
	_show_state_overlay()


func _survival_event_summary(summary: Dictionary) -> String:
	var history: Array = summary.get("event_history", []) as Array
	if history.is_empty():
		return "EVENTS // NONE"
	var parts: Array[String] = []
	for record_value in history:
		var record: Dictionary = record_value
		var status := str(record.get("status", "unknown")).to_upper()
		parts.append("%s [%s]" % [str(record.get("display_name", record.get("event_id", "EVENT"))), status])
	var supply_names: Array[String] = []
	for supply_value in summary.get("supplies", []) as Array:
		supply_names.append(str(supply_value).to_upper())
	var supply_text := "NONE" if supply_names.is_empty() else ", ".join(supply_names)
	var field_supply_text := "NO FIELD DROP"
	if bool(summary.get("supply_triggered", false)):
		field_supply_text = "DROP WAVE %d  •  CHOICE %s  •  HP +%d  •  MAGS %d  •  GRENADES +%d" % [
			int(summary.get("supply_wave", 0)),
			str(summary.get("supply_choice", &"none")).to_upper(),
			int(summary.get("supply_health_restored", 0)),
			int(summary.get("supply_magazines_refilled", 0)),
			int(summary.get("supply_grenades_added", 0)),
		]
	return "EVENTS %d // %s\nBOUNTIES %d  •  SURGES %d  •  REWARDS %s\n%s" % [
		history.size(), "  •  ".join(parts),
		int(summary.get("bounty_successes", 0)),
		int(summary.get("reinforcement_successes", 0)),
		supply_text,
		field_supply_text,
	]


func _weapon_display_name(weapon_id: StringName) -> String:
	return {
		&"rifle": "AUTO RIFLE",
		&"shotgun": "SCATTERGUN",
		&"sniper": "RAIL LANCE",
		&"pistol": "SIDEARM",
	}.get(weapon_id, str(weapon_id).to_upper())


func show_boss(boss_name: String, maximum: int) -> void:
	_cancel_boss_flow()
	_prepare_boss_panel(boss_name, maximum)
	boss_ui_state = BossUIState.ACTIVE
	boss_panel.visible = true
	boss_panel.modulate = Color.WHITE
	boss_panel.scale = Vector2.ONE * _ui_scale()


func begin_boss_intro(boss_name: String, maximum: int) -> void:
	_cancel_boss_flow()
	_clear_banner()
	hide_objective(true)
	hide_controls(true)
	_prepare_boss_panel(boss_name, maximum)
	boss_ui_state = BossUIState.INTRO
	boss_panel.visible = true
	boss_panel.modulate = Color(1, 1, 1, 0)
	boss_panel.scale = Vector2.ONE * _ui_scale() * 0.97
	banner.text = "BOSS // %s" % boss_name
	banner.modulate = Color(1.0, 0.3, 0.16, 1.0)
	banner.visible = true
	banner.scale = Vector2(1.08, 1.08)
	_boss_flow_tween = _new_gameplay_tween()
	_boss_flow_tween.tween_property(banner, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_boss_flow_tween.tween_interval(0.42)
	_boss_flow_tween.tween_property(banner, "modulate:a", 0.0, 0.18)
	_boss_flow_tween.tween_callback(_hide_banner_node)
	_boss_flow_tween.tween_property(boss_panel, "modulate:a", 1.0, 0.12)
	_boss_flow_tween.parallel().tween_property(boss_panel, "scale", Vector2.ONE * _ui_scale(), 0.12)
	_boss_flow_tween.tween_callback(_finish_boss_intro)


func _prepare_boss_panel(boss_name: String, maximum: int) -> void:
	boss_name_label.text = boss_name
	boss_actual_bar.max_value = maximum
	boss_delayed_bar.max_value = maximum
	boss_actual_bar.value = maximum
	boss_delayed_bar.value = maximum
	boss_value_label.text = "%d / %d" % [maximum, maximum]
	boss_phase_label.text = "PHASE I // ARMORED"
	_last_boss_phase = 1
	boss_thresholds.queue_redraw()


func _finish_boss_intro() -> void:
	if boss_ui_state == BossUIState.INTRO:
		boss_ui_state = BossUIState.ACTIVE


func set_boss_health(current: int, maximum: int, phase: int) -> void:
	if not boss_panel.visible or boss_ui_state == BossUIState.HIDDEN:
		return
	var phase_index := clampi(phase - 1, 0, 2)
	var phase_colors := [Style.DANGER, Color("ff8a3d"), Style.BOSS]
	var phase_color: Color = phase_colors[phase_index]
	boss_actual_bar.max_value = maximum
	boss_delayed_bar.max_value = maximum
	boss_actual_bar.value = current
	boss_value_label.text = "%d / %d" % [current, maximum]
	boss_phase_label.text = "PHASE %s // %s" % [
		["I", "II", "III"][phase_index],
		["ARMORED", "CORE EXPOSED", "OVERLOAD"][phase_index],
	]
	boss_actual_bar.add_theme_stylebox_override("fill", Style.make_bar_fill(phase_color))
	boss_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(phase_color, Color(Style.PANEL, 0.97), 9.0, 4.0))
	if _boss_damage_tween != null and _boss_damage_tween.is_valid():
		_boss_damage_tween.kill()
	_boss_damage_tween = _new_gameplay_tween()
	_boss_damage_tween.tween_property(boss_delayed_bar, "value", float(current), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var phase_changed := phase != _last_boss_phase
	_last_boss_phase = phase
	boss_panel.scale = Vector2.ONE * _ui_scale() * (1.04 if phase_changed else 1.015)
	_boss_damage_tween.parallel().tween_property(boss_panel, "scale", Vector2.ONE * _ui_scale(), 0.14)


func show_boss_phase(phase: int) -> void:
	if boss_ui_state in [BossUIState.HIDDEN, BossUIState.DEFEATED] or phase <= 1:
		return
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	boss_ui_state = BossUIState.PHASE_TRANSITION
	var phase_index := clampi(phase - 1, 0, 2)
	boss_phase_toast.text = "PHASE %s // %s" % [
		["I", "II", "III"][phase_index],
		["ARMORED", "ARMOR BREAK", "OVERLOAD"][phase_index],
	]
	boss_phase_toast.modulate = Color("ff9b36") if phase == 2 else Style.BOSS
	boss_phase_toast.visible = true
	boss_phase_toast.scale = Vector2.ONE * _ui_scale() * 1.08
	_phase_tween = _new_gameplay_tween()
	_phase_tween.tween_property(boss_phase_toast, "scale", Vector2.ONE * _ui_scale(), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_phase_tween.tween_interval(0.72)
	_phase_tween.tween_property(boss_phase_toast, "modulate:a", 0.0, 0.18)
	_phase_tween.tween_callback(_finish_phase_toast)


func _finish_phase_toast() -> void:
	boss_phase_toast.visible = false
	boss_phase_toast.modulate.a = 1.0
	if boss_ui_state == BossUIState.PHASE_TRANSITION:
		boss_ui_state = BossUIState.ACTIVE


func show_boss_defeated() -> void:
	_cancel_boss_flow()
	hide_objective(true)
	hide_controls(true)
	boss_ui_state = BossUIState.DEFEATED
	boss_phase_toast.visible = false
	show_banner("IRON TEMPEST DOWN", Style.HEALTH, false, 0.46)


func hide_boss() -> void:
	if not boss_panel.visible:
		boss_ui_state = BossUIState.HIDDEN
		return
	_cancel_boss_flow()
	boss_ui_state = BossUIState.HIDDEN
	_last_boss_phase = 0
	boss_phase_toast.visible = false
	if _boss_damage_tween != null and _boss_damage_tween.is_valid():
		_boss_damage_tween.kill()
	var tween := _new_gameplay_tween()
	tween.tween_property(boss_panel, "modulate:a", 0.0, 0.24)
	tween.tween_callback(func() -> void:
		boss_panel.visible = false
		boss_panel.modulate.a = 1.0
	)


func set_objective(text: String) -> void:
	show_objective_update(text, 1.55)


func show_objective_update(text: String, hold_duration: float = 1.55) -> void:
	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	objective_label.text = text
	objective_label.visible = true
	objective_label.modulate = Color(0.396, 0.784, 1.0, 0.0)
	objective_label.scale = Vector2.ONE * _ui_scale() * 0.98
	_objective_tween = _new_gameplay_tween()
	_objective_tween.tween_property(objective_label, "modulate:a", 1.0, 0.10)
	_objective_tween.parallel().tween_property(objective_label, "scale", Vector2.ONE * _ui_scale(), 0.10)
	_objective_tween.tween_interval(maxf(hold_duration, 0.0))
	_objective_tween.tween_property(objective_label, "modulate:a", 0.0, 0.22)
	_objective_tween.tween_callback(func() -> void: objective_label.visible = false)


func hide_objective(immediate: bool = false) -> void:
	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	if immediate or not objective_label.visible:
		objective_label.visible = false
		objective_label.modulate.a = 1.0
		return
	_objective_tween = _new_gameplay_tween()
	_objective_tween.tween_property(objective_label, "modulate:a", 0.0, 0.16)
	_objective_tween.tween_callback(func() -> void:
		objective_label.visible = false
		objective_label.modulate.a = 1.0
	)


func show_banner(text: String, color: Color = Color.WHITE, persistent: bool = false, hold_duration: float = 0.9) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner.text = text
	banner.modulate = color
	banner.visible = true
	banner.scale = Vector2(1.16, 1.16)
	_banner_tween = _new_gameplay_tween()
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not persistent:
		_banner_tween.tween_interval(maxf(hold_duration, 0.0))
		_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.22)
		_banner_tween.tween_callback(_hide_banner_node)


func _clear_banner() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_hide_banner_node()


func _hide_banner_node() -> void:
	banner.visible = false
	banner.modulate.a = 1.0
	banner.scale = Vector2.ONE


func set_controls_persistent(is_persistent: bool) -> void:
	_controls_persistent = is_persistent
	controls_auto_hide_enabled = not is_persistent
	if is_persistent:
		show_controls_hint(CONTROLS_TEXT, 0.0)


func show_controls_hint(text: String = CONTROLS_TEXT, duration: float = 4.0) -> void:
	if boss_ui_state != BossUIState.HIDDEN:
		return
	if _controls_tween != null and _controls_tween.is_valid():
		_controls_tween.kill()
	controls_label.text = text + ("  •  F3 DEBUG" if OS.is_debug_build() and text == CONTROLS_TEXT else "")
	controls_label.visible = true
	controls_label.modulate.a = 0.9
	controls_label.scale = Vector2.ONE * _ui_scale()
	_controls_time_remaining = duration
	_controls_hide_requested = false


func hide_controls(immediate: bool = false) -> void:
	if _controls_hide_requested and not immediate:
		return
	if _controls_tween != null and _controls_tween.is_valid():
		_controls_tween.kill()
	if immediate or not controls_label.visible:
		controls_label.visible = false
		controls_label.modulate.a = 0.9
		_controls_hide_requested = false
		return
	_controls_hide_requested = true
	_controls_tween = _new_gameplay_tween()
	_controls_tween.tween_property(controls_label, "modulate:a", 0.0, 0.20)
	_controls_tween.tween_callback(func() -> void:
		controls_label.visible = false
		controls_label.modulate.a = 0.9
		_controls_hide_requested = false
	)


func _configure_controls_text() -> void:
	controls_label.text = CONTROLS_TEXT + ("  •  F3 DEBUG" if OS.is_debug_build() else "")
	controls_label.visible = true
	_controls_time_remaining = 4.0
	_controls_hide_requested = false


func show_death(boss_checkpoint: bool = false, damage_source: String = "UNKNOWN") -> void:
	get_tree().paused = false
	_clear_transient_labels()
	_overlay_mode = &"death"
	state_title.text = "OPERATIVE DOWN"
	state_title.modulate = Style.DANGER
	var retry_label := "BOSS CHECKPOINT // FULL RESUPPLY" if boss_checkpoint else "MISSION RESTART"
	state_subtitle.text = "%s\nLAST HIT // %s  •  REDEPLOY 1.35s" % [retry_label, damage_source.to_upper()]
	primary_button.text = "RESTART NOW"
	secondary_button.visible = false
	map_select_button.visible = false
	settings_button.visible = false
	controls_button.visible = false
	main_menu_button.visible = true
	audio_settings.visible = false
	_show_state_overlay()


func show_settlement(final_score: int, remaining_health: int, summary: Dictionary = {}) -> void:
	_clear_transient_labels()
	_overlay_mode = &"settlement"
	state_title.text = "MISSION COMPLETE"
	state_title.modulate = Style.HEALTH
	var elapsed_seconds := int(round(float(summary.get("elapsed", 0.0))))
	var time_text := "%02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60]
	state_subtitle.text = "%s\nIRON TEMPEST DEFEATED  •  RANK %s\nTIME %s  •  SCORE %06d\nKILLS %02d  •  ACCURACY %03d%%  •  HITS TAKEN %02d\nHP %03d" % [
		str(summary.get("map_name", "IRON DISTRICT // ARCADE MISSION")),
		str(summary.get("rank", "C")), time_text, final_score,
		int(summary.get("kills", 0)), int(summary.get("accuracy", 0)), int(summary.get("damage_events", 0)), remaining_health,
	]
	primary_button.text = "REPLAY MISSION"
	secondary_button.visible = false
	map_select_button.visible = false
	settings_button.visible = false
	controls_button.visible = false
	main_menu_button.visible = true
	audio_settings.visible = false
	_show_state_overlay()


func toggle_pause() -> void:
	if _overlay_mode in [&"death", &"settlement"]:
		return
	if _overlay_mode == &"pause":
		_resume_game()
	else:
		_overlay_mode = &"pause"
		state_title.text = "PAUSED"
		state_title.modulate = Style.GOLD
		state_subtitle.text = "MOVE A/D  •  JUMP SPACE  •  AIM MOUSE\nFIRE LMB/J  •  WEAPONS 1—4  •  RELOAD R" + ("\nBUILD // %s\n%s" % [_survival_build_text, _survival_parameter_text()] if survival_mode_enabled else "")
		primary_button.text = "CONTINUE"
		secondary_button.text = "RESTART SURVIVAL" if survival_mode_enabled else "RESTART MISSION"
		secondary_button.visible = true
		map_select_button.visible = false
		settings_button.visible = true
		controls_button.visible = true
		main_menu_button.visible = true
		audio_settings.visible = true
		_show_state_overlay()
		get_tree().paused = true
		pause_changed.emit(true)
		ui_cue_requested.emit(&"ui_pause")


func _show_state_overlay() -> void:
	state_overlay.visible = true
	crosshair.visible = false
	state_panel.modulate = Color(1, 1, 1, 0)
	state_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(state_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(state_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	primary_button.grab_focus()


func _resume_game() -> void:
	get_tree().paused = false
	_overlay_mode = &"none"
	state_overlay.visible = false
	audio_settings.visible = false
	crosshair.visible = true
	pause_changed.emit(false)
	ui_cue_requested.emit(&"ui_resume")


func _clear_transient_labels() -> void:
	_cancel_boss_flow()
	_clear_banner()
	hide_objective(true)
	hide_controls(true)
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	boss_phase_toast.visible = false


func _cancel_boss_flow() -> void:
	if _boss_flow_tween != null and _boss_flow_tween.is_valid():
		_boss_flow_tween.kill()
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	boss_phase_toast.visible = false
	boss_phase_toast.modulate.a = 1.0


func _new_gameplay_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	return tween


func _on_primary_pressed() -> void:
	ui_cue_requested.emit(&"ui_confirm")
	if _overlay_mode == &"pause":
		_resume_game()
	elif _overlay_mode in [&"settings", &"controls"]:
		_restore_overlay_parent()
	elif _overlay_mode == &"confirm_restart":
		get_tree().paused = false
		restart_requested.emit()
	elif _overlay_mode == &"confirm_menu":
		get_tree().paused = false
		menu_requested.emit()
	elif _overlay_mode in [&"death", &"settlement"]:
		get_tree().paused = false
		restart_requested.emit()


func _on_secondary_pressed() -> void:
	ui_cue_requested.emit(&"ui_confirm")
	if _overlay_mode == &"pause":
		_show_confirmation(&"confirm_restart", "RESTART CURRENT RUN?", "PROGRESS IN THIS RUN WILL BE LOST.")
	elif _overlay_mode in [&"confirm_restart", &"confirm_menu"]:
		_restore_overlay_parent()
	elif _overlay_mode in [&"death", &"settlement"]:
		get_tree().paused = false
		menu_requested.emit()


func _on_map_select_pressed() -> void:
	ui_cue_requested.emit(&"ui_confirm")
	get_tree().paused = false
	map_select_requested.emit()


func _on_settings_pressed() -> void:
	ui_cue_requested.emit(&"ui_confirm")
	if is_instance_valid(_settings_menu):
		return
	_overlay_parent_mode = _overlay_mode
	_overlay_mode = &"settings"
	state_overlay.visible = false
	_settings_menu = SettingsMenuScript.new()
	_settings_menu.name = "SettingsMenu"
	add_child(_settings_menu)
	_settings_menu.close_requested.connect(_close_settings_menu)


func _close_settings_menu() -> void:
	if is_instance_valid(_settings_menu):
		_settings_menu.queue_free()
	_settings_menu = null
	_overlay_mode = _overlay_parent_mode
	_overlay_parent_mode = &"none"
	state_overlay.visible = true
	if _overlay_mode == &"pause":
		audio_settings.visible = true
		settings_button.grab_focus()


func _on_controls_pressed() -> void:
	ui_cue_requested.emit(&"ui_confirm")
	_overlay_parent_mode = _overlay_mode
	_overlay_mode = &"controls"
	state_title.text = "CONTROLS"
	state_subtitle.text = CONTROLS_TEXT
	audio_settings.visible = false
	_configure_subpage_buttons()


func _on_main_menu_pressed() -> void:
	ui_cue_requested.emit(&"ui_confirm")
	if _overlay_mode == &"pause":
		_show_confirmation(&"confirm_menu", "RETURN TO MAIN MENU?", "THE CURRENT RUN WILL END.")
	else:
		get_tree().paused = false
		menu_requested.emit()


func _configure_subpage_buttons() -> void:
	primary_button.text = "BACK"
	primary_button.visible = true
	secondary_button.visible = false
	map_select_button.visible = false
	settings_button.visible = false
	controls_button.visible = false
	main_menu_button.visible = false
	primary_button.grab_focus()


func _show_confirmation(mode: StringName, title: String, subtitle: String) -> void:
	_overlay_parent_mode = _overlay_mode
	_overlay_mode = mode
	state_title.text = title
	state_title.modulate = Style.DANGER
	state_subtitle.text = subtitle
	audio_settings.visible = false
	primary_button.text = "CONFIRM"
	secondary_button.text = "CANCEL"
	primary_button.visible = true
	secondary_button.visible = true
	map_select_button.visible = false
	settings_button.visible = false
	controls_button.visible = false
	main_menu_button.visible = false
	secondary_button.grab_focus()


func _restore_overlay_parent() -> void:
	var parent_mode := _overlay_parent_mode
	_overlay_parent_mode = &"none"
	if parent_mode == &"pause":
		_overlay_mode = &"none"
		toggle_pause()
	elif parent_mode == &"death":
		_overlay_mode = &"death"
	elif parent_mode == &"settlement":
		_overlay_mode = &"settlement"


func set_audio_mix(snapshot: Dictionary) -> void:
	for bus_name in AUDIO_BUSES:
		if not snapshot.has(bus_name):
			continue
		var data: Dictionary = snapshot[bus_name]
		var muted := bool(data.get("muted", false))
		(audio_value_labels[bus_name] as Label).text = "%03d%%" % int(data.get("percent", 100))
		(audio_value_labels[bus_name] as Label).modulate = Style.MUTED if muted else Style.TEXT
		(audio_mute_buttons[bus_name] as Button).text = "UNMUTE" if muted else "MUTE"


func _on_audio_step_pressed(bus_name: StringName, delta_steps: int) -> void:
	audio_adjust_requested.emit(bus_name, delta_steps)
	ui_cue_requested.emit(&"ui_adjust")


func _on_audio_mute_pressed(bus_name: StringName) -> void:
	audio_mute_requested.emit(bus_name)
	ui_cue_requested.emit(&"ui_adjust")


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_settings_menu):
		return
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	crosshair.position = Vector2(roundf(get_viewport().get_mouse_position().x), roundf(get_viewport().get_mouse_position().y))
	crosshair.queue_redraw()
	if controls_label.visible and not _controls_hide_requested and controls_auto_hide_enabled and not _controls_persistent and not get_tree().paused:
		_controls_time_remaining = maxf(_controls_time_remaining - delta, 0.0)
		if _has_gameplay_input():
			_controls_time_remaining = 0.0
		if _controls_time_remaining <= 0.0:
			hide_controls()


func _has_gameplay_input() -> bool:
	for action in [&"move_left", &"move_right", &"jump", &"fire", &"reload", &"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4"]:
		if Input.is_action_pressed(action):
			return true
	return false
