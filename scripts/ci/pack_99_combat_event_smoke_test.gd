extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("Pack99CombatEventRuntime")
	assert(runtime != null, "PACK 99 combat event runtime must be mounted")
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
	assert(AssetPackRegistry.has_pack("PACK_07"))
	assert(AssetPackRegistry.has_pack("PACK_09"))
	print("PACK 99 directions and combat events smoke test passed")
	quit(0)
