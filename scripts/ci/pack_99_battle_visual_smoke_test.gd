extends SceneTree

const LEGACY_REGISTRY_SCRIPT := preload("res://scripts/runtime/asset_pack_registry.gd")
const BATTLE_VISUAL_RUNTIME_SCRIPT := preload("res://scripts/runtime/pack_99_battle_visual_runtime.gd")

func _initialize() -> void:
	await process_frame
	var runtime := BATTLE_VISUAL_RUNTIME_SCRIPT.new()
	assert(runtime.has_method("_discover_fighters"))
	assert(runtime.has_method("_spawn_vfx"))
	assert(runtime.has_method("_update_hud_for"))
	var registry := _legacy_registry()
	assert(registry.has_pack("PACK_07"))
	assert(registry.has_pack("PACK_09"))
	assert(registry.has_pack("PACK_10"))
	runtime.free()
	registry.free()
	print("PACK 99 battle visual smoke test passed")
	quit(0)

func _legacy_registry() -> Node:
	var registry := LEGACY_REGISTRY_SCRIPT.new()
	registry.legacy_adapter_enabled = true
	registry.scan_legacy_packs = true
	registry.reload_packs()
	return registry
