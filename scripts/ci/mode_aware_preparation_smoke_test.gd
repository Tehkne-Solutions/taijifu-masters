extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("ModeAwarePreparationRuntime")
	assert(runtime != null)
	assert(runtime.CHAMPION_DIFFICULTIES.size() == 3)
	assert(runtime.TRAINING_FOCUS.size() == 5)
	assert(runtime.MODE_RULES.size() == 5)
	assert(runtime.selected_champion_difficulty() == "master")
	assert(runtime.selected_training_focus() == "free")
	assert(runtime.set_champion_difficulty("legend"))
	assert(runtime.selected_champion_difficulty() == "legend")
	assert(runtime.set_training_focus("fu"))
	assert(runtime.selected_training_focus() == "fu")
	assert(not runtime.set_champion_difficulty("invalid"))
	var snapshot: Dictionary = runtime.context_snapshot()
	assert(snapshot.has("mode_id"))
	assert(snapshot.has("champion_config"))
	print("Mode-aware preparation smoke test passed")
	quit(0)
