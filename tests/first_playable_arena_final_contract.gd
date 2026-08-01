extends SceneTree

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const ENVIRONMENT_SCRIPT := preload("res://scripts/vertical_slice/first_playable_environment_art.gd")
const FINAL_LAYER_SCRIPT := preload("res://scripts/vertical_slice/first_playable_arena_final_layer.gd")
const PARALLAX_SCRIPT := preload("res://scripts/vertical_slice/first_playable_parallax_layer.gd")

func _init() -> void:
	var environment := ENVIRONMENT_SCRIPT.new() as FirstPlayableEnvironmentArt
	var final_layer := FINAL_LAYER_SCRIPT.new() as FirstPlayableArenaFinalLayer
	var environment_signature := environment.presentation_signature()
	var final_signature := final_layer.presentation_signature()
	assert(environment_signature["visual_policy"] == POLICY.DIRECTION)
	assert(environment_signature["arena_read"] == POLICY.ARENA_READ)
	assert(environment_signature["layered_parallax"] == true)
	assert(environment_signature["parallax_layers"] == 3)
	assert(environment_signature["foreground_separation"] == true)
	assert(environment_signature["fighter_first"] == true)
	assert(environment_signature["purple_tech_glow"] == false)
	assert(environment_signature["collision_changes"] == false)
	assert(final_signature["depth_layers"] >= 4)
	assert(final_signature["foreground_elements"] >= 12)
	assert(final_signature["collision_changes"] == false)
	assert(final_signature["signature"] == "Tehkné Solutions")

	var far := PARALLAX_SCRIPT.new().configure(FirstPlayableParallaxLayer.LayerKind.FAR)
	var mid := PARALLAX_SCRIPT.new().configure(FirstPlayableParallaxLayer.LayerKind.MID)
	var foreground := PARALLAX_SCRIPT.new().configure(FirstPlayableParallaxLayer.LayerKind.FOREGROUND)
	var far_signature := far.presentation_signature()
	var mid_signature := mid.presentation_signature()
	var foreground_signature := foreground.presentation_signature()
	assert(float(far_signature["follow_ratio_x"]) > float(mid_signature["follow_ratio_x"]))
	assert(float(mid_signature["follow_ratio_x"]) > float(foreground_signature["follow_ratio_x"]))
	assert(far_signature["collision_changes"] == false)
	assert(mid_signature["collision_changes"] == false)
	assert(foreground_signature["collision_changes"] == false)
	far.free()
	mid.free()
	foreground.free()
	environment.free()
	final_layer.free()

	print("FIRST_PLAYABLE_ARENA_FINAL_CONTRACT_OK")
	quit()

# Tehkné Solutions
