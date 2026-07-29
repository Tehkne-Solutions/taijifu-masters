extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("CinematicMainMenuRuntime")
	assert(runtime != null)
	assert(runtime.has_method("presentation_snapshot"))
	var snapshot: Dictionary = runtime.presentation_snapshot()
	assert(int(snapshot.get("crests", 0)) == 3)
	assert(bool(snapshot.get("arena_backdrop", false)))
	assert(bool(snapshot.get("profile_summary", false)))
	assert(int(snapshot.get("mode_glyphs", 0)) >= 5)
	assert(runtime.has_signal("presentation_applied"))
	assert(runtime.has_signal("profile_summary_refreshed"))
	print("Cinematic main menu smoke test passed")
	quit(0)
