extends Control

const Style := preload("res://scripts/ui/pixel_ui_style.gd")
const SurvivalMapConfigScript := preload("res://scripts/survival/survival_map_config.gd")

@onready var panel: PanelContainer = $Center/Panel
@onready var pve_button: Button = $Center/Panel/Content/PVE
@onready var survival_button: Button = $Center/Panel/Content/Survival
@onready var quit_button: Button = $Center/Panel/Content/Quit
@onready var map_center: CenterContainer = $MapCenter
@onready var map_panel: PanelContainer = $MapCenter/Panel
@onready var industrial_panel: PanelContainer = $MapCenter/Panel/Content/Cards/Industrial
@onready var sublevel_panel: PanelContainer = $MapCenter/Panel/Content/Cards/Sublevel
@onready var industrial_button: Button = $MapCenter/Panel/Content/Cards/Industrial/Content/Start
@onready var sublevel_button: Button = $MapCenter/Panel/Content/Cards/Sublevel/Content/Start
@onready var map_back_button: Button = $MapCenter/Panel/Content/Back


func _ready() -> void:
	var pixel_theme := Style.create_theme()
	theme = pixel_theme
	panel.add_theme_stylebox_override("panel", Style.make_panel(Style.PRIMARY, Color(Style.PANEL, 0.98)))
	map_panel.add_theme_stylebox_override("panel", Style.make_panel(Style.GOLD, Color(Style.PANEL, 0.98)))
	industrial_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Color("55d8c4"), Color(Style.PANEL, 0.94), 6.0, 3.0))
	sublevel_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Color("ffad3d"), Color(Style.PANEL, 0.94), 6.0, 3.0))
	pve_button.pressed.connect(_open_pve)
	survival_button.pressed.connect(_show_map_select)
	industrial_button.pressed.connect(_open_survival_map.bind(SurvivalMapConfigScript.INDUSTRIAL_ID))
	sublevel_button.pressed.connect(_open_survival_map.bind(SurvivalMapConfigScript.SUBLEVEL_ID))
	map_back_button.pressed.connect(_hide_map_select)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	pve_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if map_center.visible:
		if event.is_action_pressed("weapon_1"):
			_open_survival_map(SurvivalMapConfigScript.INDUSTRIAL_ID)
		elif event.is_action_pressed("weapon_2"):
			_open_survival_map(SurvivalMapConfigScript.SUBLEVEL_ID)
		elif event.is_action_pressed("ui_cancel"):
			_hide_map_select()
		return
	if event.is_action_pressed("weapon_1"):
		_open_pve()
	elif event.is_action_pressed("weapon_2"):
		_show_map_select()


func _open_pve() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _show_map_select() -> void:
	$Center.visible = false
	map_center.visible = true
	industrial_button.grab_focus()


func _hide_map_select() -> void:
	map_center.visible = false
	$Center.visible = true
	survival_button.grab_focus()


func _open_survival_map(selected_map_id: StringName) -> void:
	var config := SurvivalMapConfigScript.get_map(selected_map_id)
	get_tree().change_scene_to_file(str(config.get("scene_path", "res://scenes/survival/survival.tscn")))
