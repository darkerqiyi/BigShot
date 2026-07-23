extends CanvasLayer
class_name SurvivalEventOverlay

signal supply_chosen(option_id: StringName)

const Style := preload("res://scripts/ui/pixel_ui_style.gd")

var event_panel: PanelContainer
var event_title: Label
var event_objective: Label
var event_timer: Label
var supply_root: Control
var supply_title: Label
var supply_hint: Label
var supply_cards: Array[Button] = []
var supply_options: Array[Dictionary] = []
var supply_locked := false
var selected_index := 0
var _finish_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	_build_event_panel()
	_build_supply_overlay()


func show_event(definition: Dictionary, objective: String = "") -> void:
	if _finish_tween != null and _finish_tween.is_valid():
		_finish_tween.kill()
	event_title.text = str(definition.get("display_name", "FIELD EVENT"))
	event_title.modulate = Color("ffd35a")
	event_objective.text = objective if not objective.is_empty() else str(definition.get("description", ""))
	event_timer.text = _format_time(float(definition.get("duration", 0.0)))
	event_panel.modulate = Color.WHITE
	event_panel.visible = true


func update_event(remaining: float, objective: String = "") -> void:
	if not event_panel.visible:
		return
	if not objective.is_empty():
		event_objective.text = objective
	event_timer.text = _format_time(remaining)


func finish_event(success: bool, message: String) -> void:
	event_panel.visible = true
	event_title.text = "EVENT COMPLETE" if success else "EVENT FAILED"
	event_title.modulate = Color("55e39a") if success else Color("b85f68")
	event_objective.text = message
	event_timer.text = ""
	if _finish_tween != null and _finish_tween.is_valid():
		_finish_tween.kill()
	_finish_tween = create_tween()
	_finish_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_finish_tween.tween_interval(1.1)
	_finish_tween.tween_property(event_panel, "modulate:a", 0.0, 0.22)
	_finish_tween.tween_callback(hide_event)


func hide_event() -> void:
	if event_panel != null:
		event_panel.visible = false
		event_panel.modulate = Color.WHITE


func open_supply(options: Array[Dictionary]) -> void:
	supply_options = options.duplicate(true)
	supply_locked = false
	selected_index = 0
	for index in range(supply_cards.size()):
		var card := supply_cards[index]
		card.visible = index < supply_options.size()
		card.disabled = index >= supply_options.size()
		if index < supply_options.size():
			var option: Dictionary = supply_options[index]
			card.text = "%d  %s\n%s\n\n%s\n\n%s" % [
				index + 1,
				str(option.get("icon", "■")),
				str(option.get("display_name", "SUPPLY")),
				str(option.get("description", "")),
				str(option.get("preview", "")),
			]
			card.self_modulate = Color.WHITE
			_apply_card_style(card, option.get("color", Color("55e39a")))
	supply_title.text = "SUPPLY DROP // SELECT ONE"
	supply_hint.text = "1 / 2 / 3  •  ARROWS + ENTER"
	supply_root.visible = true
	_update_supply_focus()


func confirm_supply(option_id: StringName) -> void:
	supply_locked = true
	for index in range(supply_cards.size()):
		supply_cards[index].disabled = true
		if index < supply_options.size() and StringName(supply_options[index].get("id", &"")) == option_id:
			supply_cards[index].self_modulate = Color("fff4b8")
	supply_title.text = "SUPPLY ACQUIRED"
	supply_hint.text = "NEXT WAVE IN 2 SECONDS"


func close_supply() -> void:
	for card in supply_cards:
		card.release_focus()
		card.disabled = true
		card.scale = Vector2.ONE
	supply_root.visible = false
	supply_locked = false
	supply_options.clear()


func is_supply_open() -> bool:
	return supply_root != null and supply_root.visible


func clear_all() -> void:
	hide_event()
	close_supply()


func _unhandled_input(event: InputEvent) -> void:
	if not is_supply_open() or supply_locked or get_tree().paused:
		return
	if event.is_action_pressed("weapon_1"):
		_choose_supply(0)
	elif event.is_action_pressed("weapon_2"):
		_choose_supply(1)
	elif event.is_action_pressed("weapon_3"):
		_choose_supply(2)
	elif event.is_action_pressed("ui_left"):
		selected_index = posmod(selected_index - 1, maxi(supply_options.size(), 1))
		_update_supply_focus()
	elif event.is_action_pressed("ui_right"):
		selected_index = posmod(selected_index + 1, maxi(supply_options.size(), 1))
		_update_supply_focus()
	elif event.is_action_pressed("ui_accept"):
		_choose_supply(selected_index)
	else:
		return
	get_viewport().set_input_as_handled()


func _choose_supply(index: int) -> void:
	if supply_locked or index < 0 or index >= supply_options.size():
		return
	supply_locked = true
	for card in supply_cards:
		card.disabled = true
	supply_chosen.emit(StringName(supply_options[index].get("id", &"")))


func _update_supply_focus() -> void:
	if supply_options.is_empty():
		return
	selected_index = clampi(selected_index, 0, supply_options.size() - 1)
	for index in range(supply_cards.size()):
		supply_cards[index].scale = Vector2.ONE * (1.04 if index == selected_index else 1.0)
		supply_cards[index].self_modulate = Color.WHITE if index == selected_index else Color(0.76, 0.80, 0.86, 0.92)
	supply_cards[selected_index].grab_focus()


func _build_event_panel() -> void:
	event_panel = PanelContainer.new()
	event_panel.name = "EventPanel"
	event_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	event_panel.position = Vector2(-265, 106)
	event_panel.size = Vector2(530, 70)
	event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_panel.theme = Style.create_theme()
	event_panel.add_theme_stylebox_override("panel", Style.make_compact_panel(Color("ffd35a"), Color(Style.PANEL, 0.94), 7.0, 4.0))
	add_child(event_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	event_panel.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	event_title = Label.new()
	event_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_title.add_theme_font_size_override("font_size", 16)
	header.add_child(event_title)
	event_timer = Label.new()
	event_timer.add_theme_font_size_override("font_size", 16)
	event_timer.modulate = Color("fff4b8")
	header.add_child(event_timer)
	event_objective = Label.new()
	event_objective.add_theme_font_size_override("font_size", 12)
	event_objective.modulate = Color("9cc3d6")
	rows.add_child(event_objective)
	event_panel.visible = false


func _build_supply_overlay() -> void:
	supply_root = Control.new()
	supply_root.name = "SupplySelection"
	supply_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	supply_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(supply_root)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.035, 0.065, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	supply_root.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	supply_root.add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(940, 360)
	panel.add_theme_constant_override("separation", 16)
	panel.theme = Style.create_theme()
	center.add_child(panel)
	supply_title = Label.new()
	supply_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	supply_title.add_theme_font_size_override("font_size", 26)
	supply_title.modulate = Color("fff4d2")
	panel.add_child(supply_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(290, 250)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_choose_supply.bind(index))
		button.mouse_entered.connect(button.grab_focus)
		supply_cards.append(button)
		row.add_child(button)
	supply_hint = Label.new()
	supply_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	supply_hint.add_theme_font_size_override("font_size", 15)
	supply_hint.modulate = Color("9cc3d6")
	panel.add_child(supply_hint)
	supply_root.visible = false


func _apply_card_style(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", Style.make_button(Style.PANEL, Color(accent, 0.78)))
	button.add_theme_stylebox_override("hover", Style.make_button(Style.PANEL_HIGHLIGHT, accent))
	button.add_theme_stylebox_override("focus", Style.make_button(Style.PANEL_HIGHLIGHT, accent))
	button.add_theme_stylebox_override("pressed", Style.make_button(Style.INK, accent.lightened(0.18)))
	button.add_theme_stylebox_override("disabled", Style.make_button(Color(Style.PANEL, 0.80), Color(accent, 0.75)))


func _format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return ""
	return "%02d" % int(ceil(seconds))
