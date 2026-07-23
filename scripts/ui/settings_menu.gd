extends Control
class_name ProductSettingsMenu

signal close_requested

const Style := preload("res://scripts/ui/pixel_ui_style.gd")
const ACTION_LABELS := {
	&"move_left": "MOVE LEFT",
	&"move_right": "MOVE RIGHT",
	&"jump": "JUMP",
	&"sprint": "SPRINT",
	&"reload": "RELOAD",
	&"weapon_1": "WEAPON 1",
	&"weapon_2": "WEAPON 2",
	&"weapon_3": "WEAPON 3",
	&"weapon_4": "WEAPON 4",
	&"pause": "PAUSE",
}

var _settings: Node
var _value_buttons: Dictionary = {}
var _key_buttons: Dictionary = {}
var _status: Label
var _waiting_action: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_settings = get_node_or_null("/root/SettingsManager")
	_build_ui()
	if _settings != null:
		_settings.setting_changed.connect(_on_setting_changed)
		_settings.keybind_changed.connect(_on_keybind_changed)
		_settings.settings_reset.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.045, 0.08, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 650)
	panel.theme = Style.create_theme()
	panel.add_theme_stylebox_override("panel", Style.make_panel(Style.PRIMARY, Color(Style.PANEL, 0.99)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)
	var title := Label.new()
	title.text = "SYSTEM SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Style.GOLD)
	root_box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	_add_section(content, "DISPLAY")
	_add_value_row(content, &"window_mode", "WINDOW MODE", _cycle_display.bind(&"window_mode"))
	_add_value_row(content, &"resolution", "RESOLUTION", _cycle_resolution)
	_add_value_row(content, &"vsync", "VSYNC", _toggle_setting.bind(&"display", &"vsync"))
	_add_value_row(content, &"integer_scaling", "PIXEL SCALING", _toggle_setting.bind(&"display", &"integer_scaling"))

	_add_section(content, "AUDIO")
	for item in [[&"master", "MASTER"], [&"music", "MUSIC"], [&"sfx", "SFX"], [&"ui", "UI"]]:
		_add_audio_row(content, item[0], item[1])

	_add_section(content, "EXPERIENCE")
	_add_value_row(content, &"camera_shake", "CAMERA SHAKE", _cycle_percent.bind(&"camera_shake"))
	_add_value_row(content, &"damage_numbers", "DAMAGE NUMBERS", _toggle_setting.bind(&"experience", &"damage_numbers"))
	_add_value_row(content, &"screen_flash", "FLASH INTENSITY", _cycle_percent.bind(&"screen_flash"))
	_add_value_row(content, &"show_control_hints", "CONTROL HINTS", _toggle_setting.bind(&"experience", &"show_control_hints"))
	_add_value_row(content, &"tutorial_complete", "FIRST-RUN TUTORIAL", _reset_tutorial)

	_add_section(content, "KEY BINDINGS")
	for action in ACTION_LABELS:
		_add_key_row(content, action, ACTION_LABELS[action])

	_status = Label.new()
	_status.text = "CHANGES APPLY IMMEDIATELY"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Style.MUTED)
	root_box.add_child(_status)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	root_box.add_child(footer)
	var defaults := Button.new()
	defaults.text = "RESTORE DEFAULTS"
	defaults.custom_minimum_size = Vector2(220, 42)
	defaults.pressed.connect(_on_restore_defaults)
	_focus_on_hover(defaults)
	footer.add_child(defaults)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 42)
	back.pressed.connect(func() -> void: close_requested.emit())
	_focus_on_hover(back)
	footer.add_child(back)
	back.grab_focus()


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Style.GOLD)
	parent.add_child(label)


func _add_value_row(parent: VBoxContainer, key: StringName, label_text: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(260, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 34)
	button.pressed.connect(callback)
	_focus_on_hover(button)
	row.add_child(button)
	_value_buttons[key] = button
	parent.add_child(row)


func _add_audio_row(parent: VBoxContainer, key: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(260, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(48, 34)
	minus.pressed.connect(_adjust_audio.bind(key, -5))
	_focus_on_hover(minus)
	row.add_child(minus)
	var value := Button.new()
	value.custom_minimum_size = Vector2(188, 34)
	value.pressed.connect(_toggle_audio_mute.bind(key))
	_focus_on_hover(value)
	row.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(48, 34)
	plus.pressed.connect(_adjust_audio.bind(key, 5))
	_focus_on_hover(plus)
	row.add_child(plus)
	_value_buttons[key] = value
	parent.add_child(row)


func _add_key_row(parent: VBoxContainer, action: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(260, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 34)
	button.pressed.connect(_begin_rebind.bind(action))
	_focus_on_hover(button)
	row.add_child(button)
	_key_buttons[action] = button
	parent.add_child(row)


func _refresh() -> void:
	if _settings == null or _status == null:
		return
	_value_buttons[&"window_mode"].text = str(_settings.call("get_value", &"display", &"window_mode", "windowed")).to_upper()
	_value_buttons[&"resolution"].text = str(_settings.call("get_value", &"display", &"resolution", "1280x720"))
	_value_buttons[&"vsync"].text = _on_off(bool(_settings.call("get_value", &"display", &"vsync", true)))
	_value_buttons[&"integer_scaling"].text = "INTEGER" if bool(_settings.call("get_value", &"display", &"integer_scaling", false)) else "FRACTIONAL"
	for key in [&"master", &"music", &"sfx", &"ui"]:
		var percent := int(_settings.call("get_value", &"audio", key, 100))
		var muted := bool(_settings.call("get_value", &"audio", StringName("%s_muted" % key), false))
		_value_buttons[key].text = "%03d%%  //  %s" % [percent, "MUTED" if muted else "ACTIVE"]
	_value_buttons[&"camera_shake"].text = "%03d%%" % int(_settings.call("get_value", &"experience", &"camera_shake", 100))
	_value_buttons[&"damage_numbers"].text = _on_off(bool(_settings.call("get_value", &"experience", &"damage_numbers", true)))
	_value_buttons[&"screen_flash"].text = "%03d%%" % int(_settings.call("get_value", &"experience", &"screen_flash", 100))
	_value_buttons[&"show_control_hints"].text = _on_off(bool(_settings.call("get_value", &"experience", &"show_control_hints", true)))
	_value_buttons[&"tutorial_complete"].text = "RESET" if bool(_settings.call("get_value", &"experience", &"tutorial_complete", false)) else "READY"
	for action in _key_buttons:
		_key_buttons[action].text = str(_settings.call("get_key_label", action))


func _cycle_display(key: StringName) -> void:
	var current := str(_settings.call("get_value", &"display", key, "windowed"))
	_settings.call("set_value", &"display", key, "fullscreen" if current == "windowed" else "windowed")


func _cycle_resolution() -> void:
	var current := str(_settings.call("get_value", &"display", &"resolution", "1280x720"))
	var values := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
	var index := values.find(current)
	_settings.call("set_value", &"display", &"resolution", values[(index + 1) % values.size()])


func _toggle_setting(section: StringName, key: StringName) -> void:
	var current := bool(_settings.call("get_value", section, key, false))
	_settings.call("set_value", section, key, not current)


func _cycle_percent(key: StringName) -> void:
	var current := int(_settings.call("get_value", &"experience", key, 100))
	_settings.call("set_value", &"experience", key, 0 if current >= 100 else current + 25)


func _reset_tutorial() -> void:
	_settings.call("set_value", &"experience", &"tutorial_complete", false)
	_status.text = "FIRST-RUN TUTORIAL RESET"


func _adjust_audio(key: StringName, delta: int) -> void:
	var current := int(_settings.call("get_value", &"audio", key, 100))
	_settings.call("set_value", &"audio", key, current + delta)


func _toggle_audio_mute(key: StringName) -> void:
	_toggle_setting(&"audio", StringName("%s_muted" % key))


func _begin_rebind(action: StringName) -> void:
	_waiting_action = action
	_key_buttons[action].text = "PRESS A KEY..."
	_status.text = "ESC CANCELS // DUPLICATE CRITICAL BINDS ARE REJECTED"


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action == &"":
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close_requested.emit()
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	if key_event.physical_keycode == KEY_ESCAPE:
		_waiting_action = &""
		_status.text = "REBIND CANCELLED"
		_refresh()
		return
	var action := _waiting_action
	_waiting_action = &""
	if bool(_settings.call("rebind_action", action, key_event.physical_keycode)):
		_status.text = "%s BOUND TO %s" % [ACTION_LABELS[action], OS.get_keycode_string(key_event.physical_keycode)]
	else:
		_status.text = "KEY ALREADY USED BY ANOTHER CRITICAL ACTION"
	_refresh()


func _on_setting_changed(_section: StringName, _key: StringName, _value: Variant) -> void:
	_refresh()


func _on_keybind_changed(_action: StringName, _keycode: int) -> void:
	_refresh()


func _on_restore_defaults() -> void:
	_settings.call("reset_defaults")
	_status.text = "DEFAULT SETTINGS RESTORED"


func _on_off(enabled: bool) -> String:
	return "ON" if enabled else "OFF"


func _focus_on_hover(button: Button) -> void:
	button.mouse_entered.connect(button.grab_focus)
