extends SceneTree

func _initialize() -> void:
	await process_frame
	var pickup_runtime := root.get_node_or_null("ProceduralArenaPickupRuntime")
	var synergy_runtime := root.get_node_or_null("PickupSynergyRuntime")
	assert(pickup_runtime != null, "pickup runtime must exist")
	assert(synergy_runtime != null, "synergy runtime must exist")
	assert(pickup_runtime.has_method("add_external_buff"))
	assert(pickup_runtime.has_method("active_sources_for"))
	assert(pickup_runtime.RARITIES.has("cursed"))
	for item_id in ["blood_crown", "void_feather", "oracle_mask"]:
		assert(pickup_runtime.ITEMS.has(item_id))
	assert(synergy_runtime.synergy_count() == 4)
	assert(synergy_runtime.cursed_conflict_count() == 3)
	for synergy_id in ["storm_dancer", "iron_titan", "flowing_echo", "perfect_balance"]:
		assert(synergy_runtime.SYNERGIES.has(synergy_id))
	print("Pickup synergy and cursed items smoke test passed")
	quit(0)
