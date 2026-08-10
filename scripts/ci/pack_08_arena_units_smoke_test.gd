extends SceneTree

const LEGACY_REGISTRY_SCRIPT := preload("res://scripts/runtime/asset_pack_registry.gd")
const ARENA_UNIT_RUNTIME_SCRIPT := preload("res://scripts/runtime/pack_08_arena_unit_runtime.gd")

func _initialize() -> void:
	await process_frame
	var runtime := ARENA_UNIT_RUNTIME_SCRIPT.new()
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
	var registry := _legacy_registry()
	assert(registry.has_pack("PACK_08"))
	runtime.free()
	registry.free()
	print("PACK 08 arena units smoke test passed")
	quit(0)

func _legacy_registry() -> Node:
	var registry := LEGACY_REGISTRY_SCRIPT.new()
	registry.legacy_adapter_enabled = true
	registry.scan_legacy_packs = true
	registry.reload_packs()
	return registry
