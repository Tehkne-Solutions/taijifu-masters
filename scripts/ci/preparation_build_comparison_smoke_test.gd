extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("PreparationBuildComparisonRuntime")
	assert(runtime != null)
	assert(runtime.has_method("comparison_snapshot"))
	assert(runtime.has_method("system_snapshot"))
	var snapshot: Dictionary = runtime.system_snapshot()
	assert(Array(snapshot.get("attributes", [])).size() == 3)
	assert(int(snapshot.get("weapon_modifiers", 0)) >= 5)
	assert(int(snapshot.get("element_modifiers", 0)) == 4)
	assert(bool(snapshot.get("dynamic", false)))
	assert(runtime.has_signal("comparison_refreshed"))
	assert(runtime.has_signal("dominant_attribute_changed"))
	print("Preparation build comparison smoke test passed")
	quit(0)
