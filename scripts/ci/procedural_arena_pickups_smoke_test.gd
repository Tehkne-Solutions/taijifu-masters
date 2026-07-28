extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("ProceduralArenaPickupRuntime")
	assert(runtime != null, "pickup runtime must be mounted")
	assert(runtime.has_method("_spawn_random_pickup"))
	assert(runtime.has_method("_roll_rarity"))
	assert(runtime.has_method("_apply_buff"))
	assert(runtime.has_method("active_pickup_count"))
	assert(runtime.has_method("active_buff_count"))
	for rarity in ["common", "rare", "epic", "legendary"]:
		assert(runtime.RARITIES.has(rarity))
	for item_id in ["vital_orb", "focus_charm", "iron_guard", "wind_step", "titan_force", "echo_scroll"]:
		assert(runtime.ITEMS.has(item_id))
	print("Procedural arena pickups smoke test passed")
	quit(0)
