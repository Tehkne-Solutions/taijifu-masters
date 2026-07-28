extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("PurchasedItemsApplicationRuntime")
	assert(runtime != null)
	assert(runtime.BANNER_COLORS.size() == 3)
	assert(runtime.has_method("active_items"))
	assert(runtime.has_method("extra_preset_slots"))
	assert(runtime.has_signal("cosmetics_applied"))
	assert(runtime.has_signal("battle_stat_recorded"))
	assert(runtime.has_signal("training_session_recorded"))
	assert(runtime.extra_preset_slots() in [0, 1])
	print("Purchased items application smoke test passed")
	quit(0)
