extends SceneTree

func _initialize() -> void:
	await process_frame
	var loot := root.get_node_or_null("SeriesLootProgressionRuntime")
	var series := root.get_node_or_null("CompleteSeriesModeRuntime")
	assert(loot != null)
	assert(series != null)
	assert(series.SUPPORTED_FORMATS == [3, 5])
	assert(series.best_of == 3)
	assert(series.wins_required == 2)
	assert(series.has_method("set_series_format"))
	assert(series.has_method("series_summary"))
	assert(series.has_method("is_series_over"))
	assert(loot.has_method("protect_item"))
	assert(loot.has_method("discard_item"))
	assert(loot.has_method("protected_item_id"))
	assert(loot.has_signal("round_resolved"))
	assert(series.set_series_format(5))
	assert(series.wins_required == 3)
	print("Complete series mode smoke test passed")
	quit(0)
