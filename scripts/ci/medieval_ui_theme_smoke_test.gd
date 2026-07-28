extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("MedievalUIThemeRuntime")
	assert(runtime != null)
	assert(runtime.has_method("theme_snapshot"))
	var snapshot: Dictionary = runtime.theme_snapshot()
	assert(Array(snapshot.get("palette", [])).size() == 4)
	assert(Array(snapshot.get("button_states", [])).size() == 5)
	assert(bool(snapshot.get("gamepad_focus", false)))
	assert(float(snapshot.get("transition_duration", 0.0)) > 0.0)
	assert(runtime.has_signal("theme_applied"))
	assert(runtime.has_signal("transition_started"))
	assert(runtime.has_signal("transition_finished"))
	print("Medieval UI theme smoke test passed")
	quit(0)
