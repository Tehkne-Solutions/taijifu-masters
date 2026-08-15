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

	var source := FileAccess.get_file_as_string("res://scripts/runtime/procedural_arena_pickup_runtime.gd")
	assert(source.contains("_fighters.clear()"), "autoload must prune stale fighter ownership every frame")
	assert(source.contains("_collect_fighters(current_scene, found)"), "fighter discovery must be scoped to current_scene")
	assert(not source.contains("_collect_fighters(get_tree().root, found)"), "autoload must not retain fighters through root traversal")
	assert(source.contains("get_tree().current_scene == null or _fighters.size() < 2"), "pickup spawn must fail closed outside an active two-fighter scene")

	print("PROCEDURAL_ARENA_PICKUPS_SCENE_ISOLATION_OK")
	quit(0)

# Tehkné Solutions
