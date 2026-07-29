extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("ElementalAdvantageRuntime")
	assert(runtime != null)
	assert(runtime.has_method("matchup_multiplier"))
	assert(runtime.has_method("system_snapshot"))
	assert(is_equal_approx(runtime.matchup_multiplier("water", "fire"), 1.18))
	assert(is_equal_approx(runtime.matchup_multiplier("fire", "water"), 0.86))
	assert(is_equal_approx(runtime.matchup_multiplier("earth", "earth"), 0.78))
	var snapshot: Dictionary = runtime.system_snapshot()
	assert(Dictionary(snapshot.get("advantage_cycle", {})).size() == 4)
	assert(bool(snapshot.get("existing_reactions_preserved", false)))
	assert(bool(snapshot.get("status_scaling", false)))
	assert(bool(snapshot.get("visual_feedback", false)))
	assert(runtime.has_signal("elemental_matchup_applied"))
	assert(runtime.has_signal("elemental_status_scaled"))
	assert(runtime.has_signal("elemental_reaction_presented"))
	print("Elemental advantage smoke test passed")
	quit(0)
