extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("Pack08ArenaUnitRuntime")
	assert(runtime != null, "PACK 08 arena runtime must be mounted")
	assert(runtime.ARCHETYPES.size() >= 6)
	assert(runtime.ARCHETYPES.has("soldier"))
	assert(runtime.ARCHETYPES.has("archer"))
	assert(runtime.ARCHETYPES.has("guardian"))
	assert(runtime.ARCHETYPES.has("wraith"))
	assert(runtime.ARCHETYPES.has("golem"))
	assert(runtime.ARCHETYPES.has("champion_dragon"))
	assert(runtime.has_method("_spawn_unit"))
	assert(runtime.has_method("_update_units"))
	assert(runtime.has_method("_resolve_fighter_hits"))
	assert(AssetPackRegistry.has_pack("PACK_08"))
	print("PACK 08 arena units smoke test passed")
	quit(0)
