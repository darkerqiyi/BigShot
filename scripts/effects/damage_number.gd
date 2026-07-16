extends Node2D
class_name DamageNumber

signal finished(number: DamageNumber)

var target_id := 0
var priority := 0
var serial := 0
var active := false
var elapsed := 0.0
var duration := 0.58
var rise_distance := 42.0
var _origin := Vector2.ZERO
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.custom_minimum_size = Vector2(112.0, 42.0)
	_label.position = Vector2(-56.0, -21.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	visible = false
	set_process(false)


func start(world_position: Vector2, text: String, style: StringName, next_target_id: int, next_serial: int) -> void:
	target_id = next_target_id
	serial = next_serial
	active = true
	elapsed = 0.0
	_origin = world_position + Vector2(float((serial * 17) % 19 - 9), -13.0)
	global_position = _origin
	_label.text = text
	_label.modulate = Color.WHITE
	rotation = 0.0
	match style:
		&"headshot":
			priority = 3
			duration = 0.72
			rise_distance = 60.0
			scale = Vector2.ONE * 1.42
			_label.add_theme_font_size_override("font_size", 22)
			_label.add_theme_color_override("font_color", Color("ffd35a"))
			_label.add_theme_color_override("font_outline_color", Color("7a2d35"))
		&"block":
			priority = 2
			duration = 0.62
			rise_distance = 46.0
			scale = Vector2.ONE
			_label.add_theme_font_size_override("font_size", 17)
			_label.add_theme_color_override("font_color", Color("65c8ff"))
			_label.add_theme_color_override("font_outline_color", Color("10243a"))
		&"immune":
			priority = 1
			duration = 0.52
			rise_distance = 36.0
			scale = Vector2.ONE * 0.92
			_label.add_theme_font_size_override("font_size", 15)
			_label.add_theme_color_override("font_color", Color("9aa9b8"))
			_label.add_theme_color_override("font_outline_color", Color("10243a"))
		_:
			priority = 0
			duration = 0.56
			rise_distance = 42.0
			scale = Vector2.ONE
			_label.add_theme_font_size_override("font_size", 18)
			_label.add_theme_color_override("font_color", Color("fff4d2"))
			_label.add_theme_color_override("font_outline_color", Color("30263b"))
	visible = true
	set_process(true)


func recycle() -> void:
	if not active:
		return
	active = false
	visible = false
	set_process(false)
	finished.emit(self)


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var progress := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	global_position = _origin + Vector2(0.0, -rise_distance * ease(progress, 0.72))
	if priority == 3:
		var bounce := 1.0 + maxf(0.0, 1.0 - progress / 0.20) * 0.28
		scale = Vector2.ONE * 1.42 * bounce
	_label.modulate.a = 1.0 if progress < 0.62 else 1.0 - (progress - 0.62) / 0.38
	if progress >= 1.0:
		recycle()
