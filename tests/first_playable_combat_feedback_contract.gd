extends SceneTree

const ENVIRONMENT := preload("res://scripts/vertical_slice/first_playable_environment_art.gd")
const AUDIO := preload("res://scripts/vertical_slice/first_playable_audio_director.gd")

func _init() -> void:
	var environment := ENVIRONMENT.new() as FirstPlayableEnvironmentArt
	var signature := environment.presentation_signature()
	assert(bool(signature.get("impact_director", false)))
	assert(bool(signature.get("procedural_combat_audio", false)))
	assert(not bool(signature.get("balance_changes", true)))
	var audio := AUDIO.new() as FirstPlayableAudioDirector
	var audio_signature := audio.presentation_signature()
	assert(bool(audio_signature.get("impact_audio", false)))
	assert(not bool(audio_signature.get("external_audio_assets_required", true)))
	assert(String(audio_signature.get("signature", "")) == "Tehkné Solutions")
	print("FIRST_PLAYABLE_COMBAT_FEEDBACK_CONTRACT_OK")
	quit()

# Tehkné Solutions