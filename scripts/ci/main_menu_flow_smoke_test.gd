extends SceneTree

func _initialize() -> void:
	await process_frame
	var menu := root.get_node_or_null("MainMenuRuntime")
	var modes := root.get_node_or_null("GameModeRuntime")
	assert(menu != null)
	assert(modes != null)
	assert(menu.has_method("open_main_menu"))
	assert(menu.has_method("return_to_menu"))
	assert(menu.has_method("selected_mode"))
	assert(menu.has_method("selected_series_format"))
	assert(menu.selected_series_format() == 3)
	assert(modes.available_modes().size() == 5)
	print("Main menu flow smoke test passed")
	quit(0)
