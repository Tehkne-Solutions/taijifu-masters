extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("PlayerProgressionProfileRuntime")
	assert(runtime != null)
	assert(runtime.SHOP_ITEMS.size() == 6)
	assert(runtime.has_method("open_profile"))
	assert(runtime.has_method("purchase"))
	assert(runtime.has_method("profile_snapshot"))
	assert(runtime.has_method("record_battle_result"))
	assert(runtime.has_method("record_training_session"))
	var snapshot: Dictionary = runtime.profile_snapshot()
	assert(snapshot.has("level"))
	assert(snapshot.has("training_tokens"))
	assert(snapshot.has("battle_stats"))
	assert(snapshot.has("owned_items"))
	assert(runtime.has_signal("shop_purchase_completed"))
	assert(runtime.has_signal("shop_purchase_failed"))
	print("Player progression profile smoke test passed")
	quit(0)
