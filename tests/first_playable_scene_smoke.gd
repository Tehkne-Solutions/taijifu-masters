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

	if not _validate_scene_nodes(instance):
		return
	if not _validate_arena_presentation(instance):
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

func _validate_scene_nodes(instance: FirstPlayableController) -> bool:
	for path in ["EnvironmentArt", "Arena", "ArenaDressing", "TacticalBotRuntime", "Camera2D", "HUD/CenterInfo"]:
		if instance.get_node_or_null(path) == null:
			_fail("required node is missing: %s" % path)
			return false
	return true

func _validate_arena_presentation(instance: FirstPlayableController) -> bool:
	var environment := instance.get_node("EnvironmentArt") as FirstPlayableEnvironmentArt
	var arena := instance.get_node("Arena") as FirstPlayableArena
	var dressing := instance.get_node("ArenaDressing") as FirstPlayableArenaDressing
	if not is_instance_valid(environment) or not is_instance_valid(arena) or not is_instance_valid(dressing):
		_fail("arena presentation nodes have invalid scripts")
		return false
	if environment.z_index >= arena.z_index:
		_fail("environment art must remain behind arena collision presentation")
		return false
	if dressing.z_index <= arena.z_index:
		_fail("arena dressing must remain above blockout surfaces")
		return false
	if arena.show_strategic_points:
		_fail("debug strategic points must be hidden in First Playable")
		return false
	var environment_signature := environment.environment_signature()
	if int(environment_signature.get("ink_mountains", 0)) < 3 or int(environment_signature.get("waterfalls", 0)) < 3:
		_fail("environment background is incomplete")
		return false
	if not bool(environment_signature.get("animated_clouds", false)):
		_fail("animated atmosphere is missing")
		return false
	var dressing_signature := dressing.presentation_signature()
	if int(dressing_signature.get("static_platform_overlays", 0)) != 15:
		_fail("expected 15 platform overlays")
		return false
	if int(dressing_signature.get("wall_overlays", 0)) != 3:
		_fail("expected 3 wall overlays")
		return false
	if int(dressing_signature.get("route_beacons", 0)) != 3:
		_fail("expected 3 route beacons")
		return false
	if int(dressing_signature.get("spawn_shrines", 0)) != 2:
		_fail("expected 2 spawn shrines")
		return false
	if bool(dressing_signature.get("collision_changes", true)):
		_fail("visual dressing must not change collision")
		return false
	return true

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
