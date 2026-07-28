extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("SeriesLootProgressionRuntime")
	assert(runtime != null, "series loot runtime must exist")
	assert(runtime.REWARD_POOL.size() >= 6)
	assert(runtime.MAX_INVENTORY == 5)
	assert(runtime.CHOICE_COUNT == 3)
	assert(runtime.has_method("choose_reward"))
	assert(runtime.has_method("inventory_snapshot"))
	assert(runtime.has_method("pending_choices"))
	assert(runtime.has_method("round_wins"))
	assert(runtime.has_method("reset_series"))
	print("Series loot progression smoke test passed")
	quit(0)
