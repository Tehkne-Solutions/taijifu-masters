extends SceneTree

func _initialize() -> void:
	await process_frame
	var menu := root.get_node_or_null("MainMenuRuntime")
	var hub := root.get_node_or_null("MainMenuHubRuntime")
	assert(menu != null)
	assert(hub != null)
	assert(hub.SECTIONS.size() == 3)
	assert(hub.has_method("open_section"))
	assert(hub.has_method("close_active_section"))
	assert(hub.has_method("active_section"))
	assert(menu.has_method("hide_for_hub"))
	assert(menu.has_method("restore_from_hub"))
	assert(menu.has_signal("hub_navigation_requested"))
	assert(hub.has_signal("hub_opened"))
	assert(hub.has_signal("navigation_rejected"))
	print("Main menu hub smoke test passed")
	quit(0)
