extends SceneTree

const SCENE_PATH := "res://scenes/vertical_slice/first_playable.tscn"

var _instance: FirstPlayableController

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("could not load %s" % SCENE_PATH)
		return

	_instance = packed.instantiate() as FirstPlayableController
	if _instance == null:
		_fail("scene root is not FirstPlayableController")
		return
	root.add_child(_instance)
	await process_frame
	await process_frame

	if not _validate_scene_nodes(_instance):
		return
	if not _validate_arena_presentation(_instance):
		return
	if not _validate_ai_configuration(_instance):
		return
	if not _validate_hud_configuration(_instance):
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
		_instance.player_one,
		&"lian_wu",
		"Lian Wu",
		&"water",
		&"serene_katana"
	):
		return
	if not _validate_character(
		_instance.player_two,
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

	_cleanup_scene()
	await process_frame
	await process_frame
	print("FIRST_PLAYABLE_SMOKE_OK")
	quit(0)

func _cleanup_scene() -> void:
	if is_instance_valid(_instance):
		var parent := _instance.get_parent()
		if parent != null:
			parent.remove_child(_instance)
		_instance.free()
	_instance = null
	FirstPlayableSession.reset()

func _validate_scene_nodes(instance: FirstPlayableController) -> bool:
	for path in [
		"EnvironmentArt",
		"Arena",
		"ArenaDressing",
		"TacticalBotRuntime",
		"DifficultyController",
		"HudController",
		"Camera2D",
		"HUD/CenterInfo",
		"HUD/DifficultyInfo",
		"HUD/P1Health",
		"HUD/P1Posture",
		"HUD/P1Stamina",
		"HUD/P2Health",
		"HUD/P2Posture",
		"HUD/P2Stamina",
		"HUD/ResultOverlay",
		"HUD/PauseOverlay"
	]:
		if instance.get_node_or_null(path) == null:
			_fail("required node is missing: %s" % path)
			return false
	return true

func _validate_arena_presentation(instance: FirstPlayableController) -> bool:
	var environment := instance.get_node("EnvironmentArt") as FirstPlayableEnvironmentArt
	var arena := instance.get_node("Arena") as FirstPlayableArena
	var dressing := instance.get_node("ArenaDressing") as FirstPlayableArenaDressing
	var canonical := instance.get_node_or_null("CanonicalArenaParallax") as CanonicalArenaParallax
	var readability := instance.get_node_or_null("ArenaPlatformReadability") as FirstPlayablePlatformReadabilityLayer
	if not is_instance_valid(environment) or not is_instance_valid(arena) or not is_instance_valid(dressing):
		_fail("arena presentation nodes have invalid scripts")
		return false
	if not is_instance_valid(canonical):
		_fail("canonical Mountain Dojo Night parallax is missing")
		return false
	if not is_instance_valid(readability):
		_fail("canonical platform readability layer is missing")
		return false
	if environment.z_index >= arena.z_index:
		_fail("environment art must remain behind arena collision presentation")
		return false
	if arena.show_strategic_points:
		_fail("debug strategic points must be hidden in First Playable")
		return false

	var environment_signature := environment.presentation_signature()
	if not bool(environment_signature.get("canonical_arena", false)):
		_fail("Mountain Dojo Night must own the environment presentation")
		return false
	if StringName(environment_signature.get("canonical_arena_id", &"")) != &"mountain_dojo_night":
		_fail("canonical arena id is invalid")
		return false
	if int(environment_signature.get("parallax_layers", 0)) != 3:
		_fail("canonical arena must expose exactly 3 parallax layers")
		return false
	if not bool(environment_signature.get("platform_readability_layer", false)):
		_fail("canonical platform readability layer contract is missing")
		return false
	if not bool(environment_signature.get("fighter_first", false)):
		_fail("canonical arena must preserve fighter-first presentation")
		return false
	if bool(environment_signature.get("purple_tech_glow", true)):
		_fail("purple tech glow is forbidden in the canonical arena")
		return false

	var arena_signature := arena.presentation_signature()
	if not bool(arena_signature.get("canonical_stage_visual_owner", false)):
		_fail("canonical stage must own arena visuals")
		return false
	if bool(arena_signature.get("legacy_blockout_visuals", true)):
		_fail("legacy TriplePath blockout visuals must remain retired")
		return false
	if not bool(arena_signature.get("collision_blockout_preserved", false)):
		_fail("canonical visuals must preserve collision blockout")
		return false

	var dressing_signature := dressing.presentation_signature()
	if not bool(dressing_signature.get("canonical_presentation", false)):
		_fail("legacy dressing must acknowledge canonical presentation")
		return false
	if bool(dressing_signature.get("legacy_dressing_visible", true)):
		_fail("legacy dressing must be hidden under canonical presentation")
		return false
	for key in ["static_platform_overlays", "wall_overlays", "moving_platform_overlays", "spawn_shrines", "route_beacons"]:
		if int(dressing_signature.get(key, -1)) != 0:
			_fail("legacy dressing count must be zero for %s" % key)
			return false
	if bool(dressing_signature.get("collision_changes", true)):
		_fail("visual dressing must not change collision")
		return false

	var canonical_signature := canonical.presentation_signature()
	if int(canonical_signature.get("canonical_layers", 0)) != 3:
		_fail("canonical parallax runtime did not materialize 3 layers")
		return false
	if canonical_signature.get("arena_origin", Vector2.ZERO) != Vector2(440.0, 0.0):
		_fail("canonical arena origin must remain aligned at x=440")
		return false
	if absf(float(canonical_signature.get("safe_world_left", 0.0)) - 720.0) > 0.01:
		_fail("canonical left safe-zone does not align with Lian spawn")
		return false
	if absf(float(canonical_signature.get("safe_world_right", 0.0)) - 2080.0) > 0.01:
		_fail("canonical right safe-zone does not align with Rival spawn")
		return false
	if bool(canonical_signature.get("procedural_placeholder", true)):
		_fail("canonical arena cannot use procedural placeholder geometry")
		return false

	var readability_signature := readability.presentation_signature()
	if int(readability_signature.get("static_platforms", 0)) != 5:
		_fail("First Playable canonical layout must expose 5 readable static platforms")
		return false
	if int(readability_signature.get("moving_platforms", -1)) != 0:
		_fail("moving platforms must remain disabled in the First Playable")
		return false
	if not bool(readability_signature.get("simplified_first_playable_layout", false)):
		_fail("platform readability must use the simplified First Playable layout")
		return false
	if bool(readability_signature.get("route_fu_uses_purple", true)):
		_fail("Fu route cannot regress to purple tech language")
		return false
	if bool(readability_signature.get("collision_changes", true)) or bool(readability_signature.get("physics_changes", true)):
		_fail("platform readability must remain presentation-only")
		return false
	return true

func _validate_ai_configuration(instance: FirstPlayableController) -> bool:
	var difficulty := instance.get_node("DifficultyController") as FirstPlayableDifficultyController
	var bot := instance.get_node("TacticalBotRuntime") as TacticalBotRuntime
	var label := instance.get_node("HUD/DifficultyInfo") as Label
	if not is_instance_valid(difficulty) or not is_instance_valid(bot) or not is_instance_valid(label):
		_fail("AI configuration nodes are invalid")
		return false
	var signature := difficulty.selection_signature()
	var ids: Array = signature.get("difficulty_ids", [])
	if ids != [&"apprentice", &"disciple", &"master"]:
		_fail("First Playable must expose apprentice, disciple and master")
		return false
	if StringName(signature.get("default_id", &"")) != &"disciple":
		_fail("First Playable default difficulty must be disciple")
		return false
	if difficulty.selected_difficulty_id != &"disciple" or bot.difficulty_id != &"disciple":
		_fail("default AI difficulty was not applied")
		return false
	if not bool(signature.get("persists_across_rematch", false)) or not bool(signature.get("persists_from_menu", false)):
		_fail("difficulty must persist from menu and across rematch")
		return false
	if "[1]" not in label.text or "[2]" not in label.text or "[3]" not in label.text:
		_fail("difficulty HUD does not expose the three shortcuts")
		return false
	return true

func _validate_hud_configuration(instance: FirstPlayableController) -> bool:
	var hud := instance.get_node("HudController") as FirstPlayableHudController
	if not is_instance_valid(hud):
		_fail("HUD controller is invalid")
		return false
	var signature := hud.presentation_signature()
	if int(signature.get("resource_bars_per_fighter", 0)) != 3:
		_fail("each fighter must expose health, posture and stamina bars")
		return false
	for key in ["result_overlay", "rematch_button", "menu_button", "pause_overlay", "resume_button", "mouse_supported", "gamepad_focus_supported"]:
		if not bool(signature.get(key, false)):
			_fail("HUD capability is missing: %s" % key)
			return false
	if (instance.get_node("HUD/ResultOverlay") as Control).visible:
		_fail("result overlay must start hidden")
		return false
	if (instance.get_node("HUD/PauseOverlay") as Control).visible:
		_fail("pause overlay must start hidden")
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
		_fail("%s must keep the explicit procedural base render available" % String(expected_character_id))
		return false
	if CharacterVisualCatalog.sheet_path(expected_character_id) != "":
		_fail("%s inherited an unexpected legacy atlas" % String(expected_character_id))
		return false
	var presenter := fighter.get_node_or_null("SpritePresenter") as ProvisionalSpritePresenter
	if not is_instance_valid(presenter) or presenter.character_id() != expected_character_id:
		_fail("sprite presenter resolved the wrong character for %s" % expected_name)
		return false
	if presenter.has_active_sprite():
		_fail("legacy sprite presenter unexpectedly activated an atlas for %s" % expected_name)
		return false
	if fighter.get_node_or_null("FirstPlayableIdentity") == null:
		_fail("procedural identity base is missing for %s" % expected_name)
		return false
	if expected_character_id == &"lian_wu" and fighter.get_node_or_null("LianWuCanonicalPresenter") == null:
		_fail("Lian Wu canonical presenter is missing")
		return false
	if expected_character_id == &"training_rival" and fighter.get_node_or_null("TrainingRivalCanonicalPresenter") == null:
		_fail("Training Rival canonical presenter is missing")
		return false
	return true

func _fail(message: String) -> void:
	_cleanup_scene()
	printerr("FIRST_PLAYABLE_SMOKE_FAILED: %s" % message)
	quit(1)
