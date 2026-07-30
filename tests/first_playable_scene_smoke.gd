extends SceneTree

const SCENE_PATH := "res://scenes/vertical_slice/first_playable.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("could not load %s" % SCENE_PATH)
		return

	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	if instance.get_node_or_null("Arena") == null:
		_fail("Arena node is missing")
		return
	if instance.get_node_or_null("TacticalBotRuntime") == null:
		_fail("TacticalBotRuntime node is missing")
		return
	if instance.get_node_or_null("Camera2D") == null:
		_fail("Camera2D node is missing")
		return
	if instance.get_node_or_null("HUD/CenterInfo") == null:
		_fail("HUD/CenterInfo node is missing")
		return

	var fighters := get_nodes_in_group("fighters")
	if fighters.size() != 2:
		_fail("expected 2 fighters, found %d" % fighters.size())
		return

	var indexes: Array[int] = []
	for fighter in fighters:
		if fighter is FighterController:
			indexes.append((fighter as FighterController).player_index)
	indexes.sort()
	if indexes != [1, 2]:
		_fail("expected player indexes [1, 2], found %s" % str(indexes))
		return

	print("FIRST_PLAYABLE_SMOKE_OK")
	quit(0)

func _fail(message: String) -> void:
	printerr("FIRST_PLAYABLE_SMOKE_FAILED: %s" % message)
	quit(1)
