extends SceneTree

const LEGACY_REGISTRY_SCRIPT := preload("res://scripts/runtime/asset_pack_registry.gd")
const COMBAT_EVENT_RUNTIME_SCRIPT := preload("res://scripts/runtime/pack_99_combat_event_runtime.gd")

func _initialize() -> void:
	await process_frame
	var runtime := COMBAT_EVENT_RUNTIME_SCRIPT.new()
	assert(runtime.has_method("visual_for_preset"))
	assert(runtime.has_method("hero_texture_path"))
	var expected := {
		&"adaptive_staff": "MONK",
		&"aerial_flow": "RANGER",
		&"rock_guardian": "WARDEN",
		&"foundation_breaker": "REAVER",
		&"lyra_elementalist": "MYSTIC",
		&"rin_challenger": "SENTINEL"
	}
	for preset_id in expected:
		var visual: Dictionary = runtime.visual_for_preset(preset_id)
		assert(String(visual.get("class", "")) == String(expected[preset_id]))
		assert(["BASE", "ASCENDED"].has(String(visual.get("variant", ""))))
	for direction in ["NE", "SE", "SW", "NW"]:
		var path: String = runtime.hero_texture_path("MONK", direction, "BASE")
		assert(path.contains(direction))
	var registry := _legacy_registry()
	assert(registry.has_pack("PACK_07"))
	assert(registry.has_pack("PACK_09"))
	runtime.free()
	registry.free()
	print("PACK 99 directions and combat events smoke test passed")
	quit(0)

func _legacy_registry() -> Node:
	var registry := LEGACY_REGISTRY_SCRIPT.new()
	registry.legacy_adapter_enabled = true
	registry.scan_legacy_packs = true
	registry.reload_packs()
	return registry
