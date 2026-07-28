extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("CombatDifficultyTrainingRuntime")
	assert(runtime != null)
	assert(runtime.TRAINING_TARGETS.size() == 5)
	for focus in ["free", "tai", "ji", "fu", "ghost"]:
		assert(runtime.TRAINING_TARGETS.has(focus))
	var snapshot: Dictionary = runtime.objective_snapshot()
	assert(snapshot.has("focus"))
	assert(snapshot.has("progress"))
	assert(snapshot.has("target"))
	assert(runtime.has_method("reset_objectives"))
	assert(runtime.has_signal("combat_scaling_applied"))
	assert(runtime.has_signal("training_objective_completed"))
	print("Combat difficulty and training objectives smoke test passed")
	quit(0)
