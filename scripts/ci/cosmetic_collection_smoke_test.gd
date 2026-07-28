extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("CosmeticCollectionRuntime")
	assert(runtime != null)
	assert(runtime.SLOT_ITEMS.size() == 3)
	for slot_id in ["banner", "aura", "frame"]:
		assert(runtime.SLOT_ITEMS.has(slot_id))
		assert(runtime.has_method("available_items"))
	assert(runtime.has_method("open_collection"))
	assert(runtime.has_method("equip"))
	assert(runtime.has_method("equipped_item"))
	assert(runtime.has_method("equipped_snapshot"))
	assert(runtime.has_signal("equipment_changed"))
	assert(runtime.has_signal("equipment_rejected"))
	var snapshot: Dictionary = runtime.equipped_snapshot()
	assert(snapshot.has("banner"))
	assert(snapshot.has("aura"))
	assert(snapshot.has("frame"))
	print("Cosmetic collection smoke test passed")
	quit(0)
