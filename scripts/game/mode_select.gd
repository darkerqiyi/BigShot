extends Control

const Style := preload("res://scripts/ui/pixel_ui_style.gd")
const SurvivalMapConfigScript := preload("res://scripts/survival/survival_map_config.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")

@onready var panel: PanelContainer = $Center/Panel
@onready var title_center: CenterContainer = $TitleCenter
@onready var title_panel: PanelContainer = $TitleCenter/Panel
@onready var pve_button: Button = $Center/Panel/Content/PVE
@onready var survival_button: Button = $Center/Panel/Content/Survival
@onready var settings_button: Button = $Center/Panel/Content/Settings
@onready var controls_button: Button = $Center/Panel/Content/Controls
@onready var quit_button: Button = $Center/Panel/Content/Quit
@onready var info_center: CenterContainer = $InfoCenter
@onready var info_panel: PanelContainer = $InfoCenter/Panel
@onready var info_title: Label = $InfoCenter/Panel/Content/Title
@onready var info_body: Label = $InfoCenter/Panel/Content/Body
@onready var info_back_button: Button = $InfoCenter/Panel/Content/Back
@onready var map_center: CenterContainer = $MapCenter
@onready var map_panel: PanelContainer = $MapCenter/Panel
@onready var industrial_panel: PanelContainer = $MapCenter/Panel/Content/Cards/Industrial
@onready var sublevel_panel: PanelContainer = $MapCenter/Panel/Content/Cards/Sublevel
@onready var industrial_button: Button = $MapCenter/Panel/Content/Cards/Industrial/Content/Start
@onready var sublevel_button: Button = $MapCenter/Panel/Content/Cards/Sublevel/Content/Start
@onready var map_back_button: Button = $MapCenter/Panel/Content/Back
var _settings_menu: Control


func _ready() -> void:
	var pixel_theme := Style.create_theme()
	theme = pixel_theme
	panel.add_theme_stylebox_override("panel", Style.make_panel(Style.PRIMARY, Color(Style.PANEL, 0.98)))
	title_panel.add_theme_stylebox_override("panel", Style.make_panel(Style.GOLD, Color(Style.PANEL, 0.98)))
	info_panel.add_theme_stylebox_override("panel", Style.make_panel(Style.PRIMARY, Color(Style.PANEL, 0.98)))
	map_panel.add_theme_stylebox_override("panel", Style.make_panel(Style.GOLD, Color(Style.PANEL, 0.98)))
	industrial_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Color("55d8c4"), Color(Style.PANEL, 0.94), 6.0, 3.0))
	sublevel_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Color("ffad3d"), Color(Style.PANEL, 0.94), 6.0, 3.0))
	pve_button.pressed.connect(_open_pve)
	survival_button.pressed.connect(_show_map_select)
	settings_button.pressed.connect(_show_settings)
	controls_button.pressed.connect(_show_controls)
	industrial_button.pressed.connect(_open_survival_map.bind(SurvivalMapConfigScript.INDUSTRIAL_ID))
	sublevel_button.pressed.connect(_open_survival_map.bind(SurvivalMapConfigScript.SUBLEVEL_ID))
	map_back_button.pressed.connect(_hide_map_select)
	info_back_button.pressed.connect(_hide_info)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	for button in [pve_button, survival_button, settings_button, controls_button, quit_button, industrial_button, sublevel_button, map_back_button, info_back_button]:
		button.mouse_entered.connect(button.grab_focus)
	title_center.visible = true
	$Center.visible = false
	map_center.visible = false
	info_center.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_settings_menu):
		return
	if _scene_transitioning():
		return
	if title_center.visible:
		if event.is_pressed():
			_dismiss_title()
			get_viewport().set_input_as_handled()
		return
	if info_center.visible:
		if event.is_action_pressed("ui_cancel"):
			_hide_info()
			get_viewport().set_input_as_handled()
		return
	if map_center.visible:
		if event.is_action_pressed("weapon_1"):
			_open_survival_map(SurvivalMapConfigScript.INDUSTRIAL_ID)
		elif event.is_action_pressed("weapon_2"):
			_open_survival_map(SurvivalMapConfigScript.SUBLEVEL_ID)
		elif event.is_action_pressed("ui_cancel"):
			_hide_map_select()
		return
	if event.is_action_pressed("ui_cancel"):
		title_center.visible = true
		$Center.visible = false
		return
	if event.is_action_pressed("weapon_1"):
		_open_pve()
	elif event.is_action_pressed("weapon_2"):
		_show_map_select()


func _open_pve() -> void:
	_change_scene("res://scenes/main/main.tscn", {
		"product_intro": true,
		"map_name": "IRON DISTRICT // ARCADE MISSION",
		"objective": "ADVANCE THROUGH THE DISTRICT AND BREAK THE IRON TEMPEST",
	})


func _show_map_select() -> void:
	if _scene_transitioning():
		return
	$Center.visible = false
	map_center.visible = true
	industrial_button.grab_focus()


func _hide_map_select() -> void:
	map_center.visible = false
	$Center.visible = true
	survival_button.grab_focus()


func show_map_select_from_flow() -> void:
	_dismiss_title()
	$Center.visible = false
	map_center.visible = true
	industrial_button.grab_focus()


func _dismiss_title() -> void:
	title_center.visible = false
	$Center.visible = true
	pve_button.grab_focus()


func _show_controls() -> void:
	_show_info(
		"CONTROLS",
		"A / D  // MOVE & DOUBLE-TAP ROLL\nSPACE  // JUMP\nSHIFT  // SPRINT\nMOUSE  // AIM\nLEFT MOUSE / J  // FIRE\nRIGHT MOUSE  // CHARGE GRENADE\n1—4  // SELECT WEAPON\nR  // RELOAD\nESC  // PAUSE / BACK"
	)


func _show_settings() -> void:
	if is_instance_valid(_settings_menu):
		return
	$Center.visible = false
	_settings_menu = SettingsMenuScript.new()
	_settings_menu.name = "SettingsMenu"
	add_child(_settings_menu)
	_settings_menu.close_requested.connect(_close_settings)


func _close_settings() -> void:
	if is_instance_valid(_settings_menu):
		_settings_menu.queue_free()
	_settings_menu = null
	$Center.visible = true
	settings_button.grab_focus()


func _show_info(title: String, body: String) -> void:
	$Center.visible = false
	map_center.visible = false
	info_center.visible = true
	info_title.text = title
	info_body.text = body
	info_back_button.grab_focus()


func _hide_info() -> void:
	info_center.visible = false
	$Center.visible = true
	controls_button.grab_focus()


func _open_survival_map(selected_map_id: StringName) -> void:
	var config := SurvivalMapConfigScript.get_map(selected_map_id)
	_change_scene(str(config.get("scene_path", "res://scenes/survival/survival.tscn")), {
		"product_intro": true,
		"map_name": str(config.get("display_name", "SURVIVAL")),
		"objective": "SURVIVE 10 WAVES // ADAPT // DEFEAT THE IRON TEMPEST",
	})


func _scene_transitioning() -> bool:
	var flow := get_node_or_null("/root/SceneFlow")
	return flow != null and bool(flow.get("transitioning"))


func _change_scene(scene_path: String, context: Dictionary = {}) -> void:
	var flow := get_node_or_null("/root/SceneFlow")
	if flow != null and flow.has_method("change_scene"):
		flow.call("change_scene", scene_path, context)
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(scene_path)
