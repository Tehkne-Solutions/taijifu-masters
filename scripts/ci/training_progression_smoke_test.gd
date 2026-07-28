extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("TrainingProgressionRuntime")
	assert(runtime != null)
	assert(runtime.REWARDS.size() == 5)
	for focus in ["free", "tai", "ji", "fu", "ghost"]:
		assert(runtime.REWARDS.has(focus))
	assert(runtime.CERTIFICATION_REQUIREMENT == 3)
	assert(runtime.has_method("grant_completion"))
	assert(runtime.has_method("progression_snapshot"))
	assert(runtime.has_method("completion_count"))
	assert(runtime.has_method("has_medal"))
	assert(runtime.has_method("has_certification"))
	var snapshot: Dictionary = runtime.progression_snapshot()
	assert(snapshot.has("total_xp"))
	assert(snapshot.has("training_tokens"))
	assert(snapshot.has("level"))
	assert(runtime.has_signal("training_reward_granted"))
	assert(runtime.has_signal("variant_reward_unlocked"))
	print("Training progression smoke test passed")
	quit(0)
