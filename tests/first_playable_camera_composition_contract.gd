extends SceneTree

const CAMERA_SCRIPT := preload("res://scripts/vertical_slice/first_playable_camera_composition.gd")
const IDENTITY_SCRIPT := preload("res://scripts/vertical_slice/first_playable_character_identity.gd")

func _init() -> void:
	var camera := CAMERA_SCRIPT.new() as FirstPlayableCameraComposition
	var camera_signature := camera.presentation_signature()
	assert(camera_signature.get("framing") == &"fighter_first")
	assert(float(camera_signature.get("min_zoom", 0.0)) >= 0.74)
	assert(float(camera_signature.get("max_zoom", 0.0)) <= 1.05)
	assert(float(camera_signature.get("vertical_range", 999.0)) <= 120.0)
	assert(not bool(camera_signature.get("physics_changes", true)))
	assert(not bool(camera_signature.get("collision_changes", true)))
	assert(String(camera_signature.get("signature", "")) == "Tehkné Solutions")

	var identity := IDENTITY_SCRIPT.new() as FirstPlayableCharacterIdentity
	var identity_signature := identity.presentation_signature()
	assert(float(identity_signature.get("visual_scale", 1.0)) >= 1.20)
	assert(bool(identity_signature.get("fighter_first_readability", false)))
	assert(bool(identity_signature.get("camera_composition", false)))
	assert(not bool(identity_signature.get("collision_changes", true)))
	assert(String(identity_signature.get("signature", "")) == "Tehkné Solutions")

	camera.free()
	identity.free()
	print("FIRST_PLAYABLE_CAMERA_COMPOSITION_CONTRACT_OK")
	quit()

# Tehkné Solutions
