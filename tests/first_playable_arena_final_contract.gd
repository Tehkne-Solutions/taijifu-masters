extends SceneTree

const ENVIRONMENT_SCRIPT := preload("res://scripts/vertical_slice/first_playable_environment_art.gd")
const FINAL_LAYER_SCRIPT := preload("res://scripts/vertical_slice/first_playable_arena_final_layer.gd")

func _init() -> void:
	var environment := ENVIRONMENT_SCRIPT.new() as FirstPlayableEnvironmentArt
	var final_layer := FINAL_LAYER_SCRIPT.new() as FirstPlayableArenaFinalLayer
	var environment_signature := environment.presentation_signature()
	var final_signature := final_layer.presentation_signature()
	assert(environment_signature["purple_tech_glow"] == false)
	assert(environment_signature["collision_changes"] == false)
	assert(final_signature["depth_layers"] >= 4)
	assert(final_signature["foreground_elements"] >= 12)
	assert(final_signature["collision_changes"] == false)
	assert(final_signature["signature"] == "Tehkné Solutions")
	print("FIRST_PLAYABLE_ARENA_FINAL_CONTRACT_OK")
	quit()

# Tehkné Solutions
