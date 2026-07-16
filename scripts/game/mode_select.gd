extends Control

const Style := preload("res://scripts/ui/pixel_ui_style.gd")

@onready var panel: PanelContainer = $Center/Panel
@onready var pve_button: Button = $Center/Panel/Content/PVE
@onready var survival_button: Button = $Center/Panel/Content/Survival
@onready var quit_button: Button = $Center/Panel/Content/Quit


func _ready() -> void:
	var pixel_theme := Style.create_theme()
	theme = pixel_theme
	panel.add_theme_stylebox_override("panel", Style.make_panel(Style.PRIMARY, Color(Style.PANEL, 0.98)))
	pve_button.pressed.connect(_open_pve)
	survival_button.pressed.connect(_open_survival)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	pve_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_1"):
		_open_pve()
	elif event.is_action_pressed("weapon_2"):
		_open_survival()


func _open_pve() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _open_survival() -> void:
	get_tree().change_scene_to_file("res://scenes/survival/survival.tscn")
