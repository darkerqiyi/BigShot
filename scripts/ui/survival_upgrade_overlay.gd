extends Control
class_name SurvivalUpgradeOverlay

signal upgrade_chosen(upgrade_id: StringName)

const Style := preload("res://scripts/ui/pixel_ui_style.gd")
const CATEGORY_COLORS := {
	&"movement": Color("55e39a"),
	&"roll": Color("62d8ff"),
	&"grenade": Color("ff9f43"),
	&"weapon": Color("ffd35a"),
	&"survival": Color("ff6b78"),
}

var cards: Array[Button] = []
var candidates: Array[Dictionary] = []
var selected_index := 0
var locked := false
var title_label: Label
var hint_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	_build_ui()
	visible = false


func open(candidate_data: Array[Dictionary]) -> void:
	candidates = candidate_data.duplicate(true)
	locked = false
	selected_index = 0
	for index in range(cards.size()):
		var button := cards[index]
		button.visible = index < candidates.size()
		button.disabled = index >= candidates.size()
		if index < candidates.size():
			var card: Dictionary = candidates[index]
			button.text = "%d   [%s]\n%s\n\n%s\n\n%s\nSTACK %d / %d" % [
				index + 1,
				str(card["icon"]).to_upper(),
				str(card["display_name"]),
				str(card["description"]),
				str(card.get("value_preview", "")),
				int(card["current_stacks"]),
				int(card["max_stacks"]),
			]
			button.modulate = Color.WHITE
			_apply_card_style(button, CATEGORY_COLORS.get(StringName(card["category"]), Style.PRIMARY))
	title_label.text = "SELECT RUN UPGRADE"
	hint_label.text = "1 / 2 / 3  •  ARROWS + ENTER  •  ONE CHOICE"
	visible = true
	_update_focus()


func close() -> void:
	visible = false
	locked = false
	candidates.clear()


func confirm_selection(upgrade_id: StringName) -> void:
	locked = true
	for index in range(cards.size()):
		cards[index].disabled = true
		if index < candidates.size() and StringName(candidates[index]["id"]) == upgrade_id:
			cards[index].self_modulate = Color("fff4b8")
	title_label.text = "UPGRADE INSTALLED"
	hint_label.text = "COMBAT SYSTEMS RECALIBRATING"


func _unhandled_input(event: InputEvent) -> void:
	if not visible or locked or get_tree().paused:
		return
	if event.is_action_pressed("pause"):
		return
	if event.is_action_pressed("weapon_1"):
		_choose(0)
	elif event.is_action_pressed("weapon_2"):
		_choose(1)
	elif event.is_action_pressed("weapon_3"):
		_choose(2)
	elif event.is_action_pressed("ui_left"):
		selected_index = posmod(selected_index - 1, maxi(candidates.size(), 1))
		_update_focus()
	elif event.is_action_pressed("ui_right"):
		selected_index = posmod(selected_index + 1, maxi(candidates.size(), 1))
		_update_focus()
	elif event.is_action_pressed("ui_accept"):
		_choose(selected_index)
	else:
		return
	get_viewport().set_input_as_handled()


func _choose(index: int) -> void:
	if locked or index < 0 or index >= candidates.size():
		return
	locked = true
	for card in cards:
		card.disabled = true
	upgrade_chosen.emit(StringName(candidates[index]["id"]))


func _update_focus() -> void:
	if candidates.is_empty():
		return
	selected_index = clampi(selected_index, 0, candidates.size() - 1)
	for index in range(cards.size()):
		cards[index].scale = Vector2.ONE * (1.04 if index == selected_index else 1.0)
		cards[index].self_modulate = Color.WHITE if index == selected_index else Color(0.78, 0.82, 0.88, 0.92)
	cards[selected_index].grab_focus()


func _build_ui() -> void:
	theme = Style.create_theme()
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.035, 0.065, 0.84)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(1030, 420)
	panel.add_theme_constant_override("separation", 18)
	center.add_child(panel)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color("fff4d2"))
	panel.add_child(title_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 300)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_constant_override("outline_size", 2)
		button.pressed.connect(_choose.bind(index))
		button.mouse_entered.connect(button.grab_focus)
		cards.append(button)
		row.add_child(button)
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color("9cc3d6"))
	panel.add_child(hint_label)


func _apply_card_style(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", Style.make_button(Style.PANEL, Color(accent, 0.78)))
	button.add_theme_stylebox_override("hover", Style.make_button(Style.PANEL_HIGHLIGHT, accent))
	button.add_theme_stylebox_override("focus", Style.make_button(Style.PANEL_HIGHLIGHT, accent))
	button.add_theme_stylebox_override("pressed", Style.make_button(Style.INK, accent.lightened(0.18)))
	button.add_theme_stylebox_override("disabled", Style.make_button(Color(Style.PANEL, 0.80), Color(accent, 0.75)))
