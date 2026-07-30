extends SceneTree

const SCENE_PATH := "res://scenes/vertical_slice/first_playable.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("could not load %s" % SCENE_PATH)
		return

	var instance := packed.instantiate() as FirstPlayableController
	if instance == null:
		_fail("scene root is not FirstPlayableController")
		return
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

	if not _validate_character(
		instance.player_one,
		&"lian_wu",
		"Lian Wu",
		&"water",
		&"serene_katana"
	):
		return
	if not _validate_character(
		instance.player_two,
		&"training_rival",
		"Rival de Treino",
		&"fire",
		&"breaker_gauntlets"
	):
		return

	if BuildProfile.available_prototype_presets().size() != 6:
		_fail("First Playable presets changed the complete prototype roster")
		return
	if BuildProfile.first_playable_presets() != [&"lian_wu_first_playable", &"training_rival_first_playable"]:
		_fail("First Playable preset contract is invalid")
		return

	print("FIRST_PLAYABLE_SMOKE_OK")
	quit(0)

func _validate_character(
	fighter: FighterController,
	expected_character_id: StringName,
	expected_name: String,
	expected_element: StringName,
	expected_weapon: StringName
) -> bool:
	if not is_instance_valid(fighter) or not is_instance_valid(fighter.build):
		_fail("fighter/build is invalid for %s" % String(expected_character_id))
		return false
	if fighter.build.character_id != expected_character_id:
		_fail("expected character %s, found %s" % [String(expected_character_id), String(fighter.build.character_id)])
		return false
	if fighter.build.character_name != expected_name:
		_fail("expected name %s, found %s" % [expected_name, fighter.build.character_name])
		return false
	if fighter.build.element_id != expected_element:
		_fail("expected element %s for %s" % [String(expected_element), expected_name])
		return false
	if fighter.equipped_weapon_id != expected_weapon:
		_fail("expected weapon %s for %s, found %s" % [String(expected_weapon), expected_name, String(fighter.equipped_weapon_id)])
		return false
	if not CharacterVisualCatalog.has_character(expected_character_id):
		_fail("visual catalog does not recognize %s" % String(expected_character_id))
		return false
	if not CharacterVisualCatalog.uses_procedural_fallback(expected_character_id):
		_fail("%s must use explicit procedural rendering" % String(expected_character_id))
		return false
	if CharacterVisualCatalog.sheet_path(expected_character_id) != "":
		_fail("%s inherited an unexpected atlas" % String(expected_character_id))
		return false
	var presenter := fighter.get_node_or_null("SpritePresenter") as ProvisionalSpritePresenter
	if not is_instance_valid(presenter) or presenter.character_id() != expected_character_id:
		_fail("sprite presenter resolved the wrong character for %s" % expected_name)
		return false
	if presenter.has_active_sprite():
		_fail("procedural character %s unexpectedly activated an atlas" % expected_name)
		return false
	if fighter.get_node_or_null("FirstPlayableIdentity") == null:
		_fail("procedural identity overlay is missing for %s" % expected_name)
		return false
	return true

func _fail(message: String) -> void:
	printerr("FIRST_PLAYABLE_SMOKE_FAILED: %s" % message)
	quit(1)
