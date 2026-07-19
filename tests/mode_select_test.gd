extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var configured_main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_expect(configured_main == "res://scenes/menu/mode_select.tscn", "project does not boot to mode selection")
	var menu_scene := load("res://scenes/menu/mode_select.tscn") as PackedScene
	var pve_scene := load("res://scenes/main/main.tscn") as PackedScene
	var survival_scene := load("res://scenes/survival/survival.tscn") as PackedScene
	_expect(menu_scene != null and pve_scene != null and survival_scene != null, "one or more mode scenes failed to load")
	if menu_scene != null:
		var menu := menu_scene.instantiate()
		root.add_child(menu)
		await process_frame
		_expect(menu.get_node_or_null("Center/Panel/Content/PVE") != null, "PVE mode entry is missing")
		_expect(menu.get_node_or_null("Center/Panel/Content/Survival") != null, "survival mode entry is missing")
		_expect(menu.get_node_or_null("MapCenter/Panel/Content/Cards/Industrial/Content/Start") != null, "industrial survival map card is missing")
		_expect(menu.get_node_or_null("MapCenter/Panel/Content/Cards/Sublevel/Content/Start") != null, "Sublevel-09 survival map card is missing")
		_expect(menu.pve_button.has_focus(), "mode selection did not focus the PVE entry")
		menu._show_map_select()
		_expect(menu.map_center.visible and not menu.get_node("Center").visible, "survival map selector did not replace the operation selector")
		_expect(menu.industrial_button.has_focus(), "survival map selector did not focus its first card")
		menu._hide_map_select()
		_expect(not menu.map_center.visible and menu.get_node("Center").visible, "map selector did not return to operation selection")
		menu.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MODE_SELECT_PASS project boots to PVE plus an accessible two-map survival selector")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
