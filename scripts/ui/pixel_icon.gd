extends Control
class_name PixelIcon

@export_enum("avatar", "rifle", "shotgun", "sniper", "pistol") var icon_kind := "rifle"
@export var accent := Color("45d8d0")
@export var selected := false


func configure(kind: String, color: Color, is_selected: bool) -> void:
	icon_kind = kind
	accent = color
	selected = is_selected
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var logical_size := Vector2(56, 56) if icon_kind == "avatar" else Vector2(48, 36)
	var scale_factor := minf(size.x / logical_size.x, size.y / logical_size.y)
	var origin := (size - logical_size * scale_factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	match icon_kind:
		"avatar":
			_draw_avatar()
		"shotgun":
			_draw_shotgun()
		"sniper":
			_draw_sniper()
		"pistol":
			_draw_pistol()
		_:
			_draw_rifle()


func _rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, height), color, true)


func _draw_avatar() -> void:
	_rect(8, 8, 40, 40, Color("10243a"))
	_rect(12, 8, 32, 8, accent.lightened(0.15))
	_rect(8, 16, 8, 24, accent.darkened(0.28))
	_rect(16, 16, 28, 28, accent)
	_rect(20, 20, 24, 8, Color("65c8ff"))
	_rect(24, 20, 16, 4, Color("fff4d2"))
	_rect(20, 36, 8, 8, Color("ffd35a"))
	_rect(36, 36, 8, 8, Color("ffd35a"))
	_rect(12, 48, 36, 4, Color("10243a"))


func _draw_rifle() -> void:
	_rect(4, 13, 40, 12, Color("10243a"))
	_rect(8, 9, 20, 4, accent.lightened(0.2))
	_rect(8, 13, 30, 8, accent)
	_rect(38, 16, 10, 4, Color("ffd35a"))
	_rect(14, 25, 8, 7, accent.darkened(0.28))
	_rect(30, 21, 6, 9, Color("10243a"))


func _draw_shotgun() -> void:
	_rect(2, 11, 44, 14, Color("10243a"))
	_rect(6, 15, 36, 6, accent)
	_rect(6, 9, 24, 4, accent.lightened(0.2))
	_rect(42, 13, 6, 10, Color("ffd35a"))
	_rect(12, 25, 14, 6, accent.darkened(0.3))


func _draw_sniper() -> void:
	_rect(2, 14, 46, 8, Color("10243a"))
	_rect(4, 16, 42, 4, accent)
	_rect(12, 8, 20, 6, Color("65c8ff"))
	_rect(16, 10, 12, 2, Color("fff4d2"))
	_rect(10, 22, 8, 8, accent.darkened(0.32))
	_rect(44, 12, 4, 12, Color("ffd35a"))


func _draw_pistol() -> void:
	_rect(8, 9, 34, 14, Color("10243a"))
	_rect(12, 13, 28, 6, accent)
	_rect(14, 23, 14, 10, Color("10243a"))
	_rect(18, 23, 8, 8, accent.darkened(0.3))
	_rect(40, 12, 6, 8, Color("ffd35a"))
