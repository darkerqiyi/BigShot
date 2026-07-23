extends CanvasLayer

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)

const FADE_SECONDS := 0.18

var transitioning := false
var _context: Dictionary = {}
var _fade: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.015, 0.028, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func change_scene(scene_path: String, context: Dictionary = {}) -> bool:
	if transitioning:
		return false
	transitioning = true
	_context = context.duplicate(true)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_started.emit(scene_path)
	get_tree().paused = false
	await _fade_to(1.0)
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneFlow failed to load %s (error %d)" % [scene_path, error])
		await _fade_to(0.0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transitioning = false
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_context_to_scene()
	await _fade_to(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioning = false
	transition_finished.emit(scene_path)
	return true


func _apply_context_to_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if bool(_context.get("show_map_select", false)) and scene.has_method("show_map_select_from_flow"):
		scene.call("show_map_select_from_flow")
	if bool(_context.get("product_intro", false)) and scene.has_method("begin_product_intro"):
		scene.call(
			"begin_product_intro",
			str(_context.get("map_name", "DEPLOYMENT")),
			str(_context.get("objective", "SURVIVE AND COMPLETE THE OPERATION")),
			float(_context.get("countdown", 3.0))
		)
	_context.clear()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", alpha, FADE_SECONDS)
	await tween.finished
