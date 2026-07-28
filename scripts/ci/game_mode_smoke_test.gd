extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("GameModeRuntime")
	assert(runtime != null, "game mode runtime must exist")
	assert(runtime.DEFAULT_MODE == "arena_loot")
	assert(runtime.available_modes().size() == 5)
	for mode_id in ["competitive_duel", "arena_loot", "roguelite_series", "training", "champion_challenge"]:
		assert(runtime.MODES.has(mode_id))
	assert(runtime.apply_mode("competitive_duel"))
	assert(not runtime.is_feature_enabled("pickups"))
	assert(runtime.apply_mode("roguelite_series"))
	assert(runtime.is_feature_enabled("series"))
	assert(runtime.apply_mode("training"))
	assert(runtime.is_feature_enabled("training"))
	assert(not runtime.apply_mode("invalid_mode"))
	print("Game mode runtime smoke test passed")
	quit(0)
