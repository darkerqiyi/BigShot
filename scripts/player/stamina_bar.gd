extends Node2D
class_name PlayerStaminaBar

const Tuning := preload("res://scripts/config/game_tuning.gd")

const BAR_WIDTH := 46
const BAR_HEIGHT := 6
const INNER_WIDTH := 42
const HIGH := Color("34d7b4")
const MEDIUM := Color("ffd35a")
const LOW := Color("ff724d")
const FRAME := Color("10243a")
const BACK := Color("07131d")

var current_stamina := Tuning.PLAYER_MAX_STAMINA
var max_stamina := Tuning.PLAYER_MAX_STAMINA
var is_sprinting := false
var exhausted := false
var is_recovering := false
var _full_hold_remaining := 0.0
var _opacity := 0.0
var _exhausted_flash_remaining := 0.0
var _was_exhausted := false


func _ready() -> void:
	set_process(true)
	queue_redraw()


func set_state(current: float, maximum: float, sprinting: bool, depleted: bool, recovering: bool) -> void:
	current_stamina = clampf(current, 0.0, maxf(maximum, 0.001))
	max_stamina = maxf(maximum, 0.001)
	is_sprinting = sprinting
	exhausted = depleted
	is_recovering = recovering
	if exhausted and not _was_exhausted:
		_exhausted_flash_remaining = Tuning.PLAYER_EXHAUSTED_FEEDBACK_TIME
	_was_exhausted = exhausted
	if is_sprinting or exhausted or current_stamina < max_stamina:
		_full_hold_remaining = Tuning.PLAYER_STAMINA_FULL_HIDE_DELAY
		_opacity = 1.0
	if _opacity > 0.0 or _exhausted_flash_remaining > 0.0:
		set_process(true)
	queue_redraw()


func reset_full() -> void:
	current_stamina = max_stamina
	is_sprinting = false
	exhausted = false
	is_recovering = false
	_full_hold_remaining = 0.0
	_exhausted_flash_remaining = 0.0
	_was_exhausted = false
	_opacity = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_exhausted_flash_remaining = maxf(_exhausted_flash_remaining - delta, 0.0)
	if current_stamina >= max_stamina and not is_sprinting and not exhausted:
		_full_hold_remaining = maxf(_full_hold_remaining - delta, 0.0)
		if _full_hold_remaining <= 0.0:
			_opacity = maxf(_opacity - delta * 4.0, 0.0)
	else:
		_opacity = 1.0
	if _opacity <= 0.0 and _exhausted_flash_remaining <= 0.0 and current_stamina >= max_stamina:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _opacity <= 0.0:
		return
	var flash_alpha := 1.0
	if _exhausted_flash_remaining > 0.0 and int(_exhausted_flash_remaining * 24.0) % 2 == 0:
		flash_alpha = 0.35
	var alpha := _opacity * flash_alpha
	draw_rect(Rect2(-BAR_WIDTH / 2.0, -BAR_HEIGHT / 2.0, BAR_WIDTH, BAR_HEIGHT), Color(FRAME, alpha), true)
	draw_rect(Rect2(-INNER_WIDTH / 2.0, -1.0, INNER_WIDTH, 2.0), Color(BACK, alpha), true)
	var ratio := clampf(current_stamina / max_stamina, 0.0, 1.0)
	var fill_rect := get_fill_rect()
	if fill_rect.size.x <= 0.0:
		return
	var fill_color := HIGH if ratio > 0.55 else (MEDIUM if ratio > 0.25 else LOW)
	# The left edge stays fixed, so depletion visibly retracts from right to left.
	draw_rect(fill_rect, Color(fill_color, alpha), true)


func get_fill_rect() -> Rect2:
	var ratio := clampf(current_stamina / max_stamina, 0.0, 1.0)
	return Rect2(-INNER_WIDTH / 2.0, -1.0, int(floor(float(INNER_WIDTH) * ratio)), 2.0)
