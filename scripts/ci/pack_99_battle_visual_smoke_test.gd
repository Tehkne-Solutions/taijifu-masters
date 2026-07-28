extends SceneTree

func _initialize() -> void:
	await process_frame
	assert(Engine.has_singleton("Pack99BattleVisualRuntime") or root.has_node("Pack99BattleVisualRuntime"), "PACK 99 visual autoload must exist")
	var runtime := root.get_node_or_null("Pack99BattleVisualRuntime")
	assert(runtime != null, "PACK 99 visual runtime must be mounted")
	assert(runtime.has_method("_discover_fighters"))
	assert(runtime.has_method("_spawn_vfx"))
	assert(runtime.has_method("_update_hud_for"))
	assert(AssetPackRegistry.has_pack("PACK_07"))
	assert(AssetPackRegistry.has_pack("PACK_09"))
	assert(AssetPackRegistry.has_pack("PACK_10"))
	print("PACK 99 battle visual smoke test passed")
	quit(0)
