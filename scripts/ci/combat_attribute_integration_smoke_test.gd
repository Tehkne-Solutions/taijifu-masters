extends SceneTree

func _initialize() -> void:
	await process_frame
	var runtime := root.get_node_or_null("CombatAttributeIntegrationRuntime")
	assert(runtime != null)
	assert(runtime.has_method("integration_snapshot"))
	var snapshot: Dictionary = runtime.integration_snapshot()
	assert(Array(snapshot.get("effects", [])).size() == 6)
	assert(Array(snapshot.get("attribute_range", [])).size() == 2)
	assert(bool(snapshot.get("dynamic", false)))
	assert(bool(snapshot.get("non_destructive", false)))
	assert(runtime.has_signal("combat_attributes_applied"))
	assert(runtime.has_signal("combat_balance_refreshed"))
	print("Combat attribute integration smoke test passed")
	quit(0)
