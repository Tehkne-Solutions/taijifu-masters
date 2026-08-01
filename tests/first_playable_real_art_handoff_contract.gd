extends SceneTree

const IDENTITY_SCRIPT := preload("res://scripts/vertical_slice/first_playable_character_identity.gd")
const LIAN_WU_PRESENTER_SCRIPT := preload("res://scripts/vertical_slice/first_playable_lot01_presenter.gd")
const TRAINING_RIVAL_PRESENTER_SCRIPT := preload("res://scripts/vertical_slice/training_rival_lot01_presenter.gd")

func _init() -> void:
	var identity := IDENTITY_SCRIPT.new() as FirstPlayableCharacterIdentity
	var signature := identity.presentation_signature()
	assert(bool(signature.get("real_asset_handoff", false)))
	assert(bool(signature.get("lian_wu_presenter", false)))
	assert(bool(signature.get("training_rival_presenter", false)))
	assert(bool(signature.get("procedural_fallback_until_real_assets", false)))
	assert(not bool(signature.get("collision_changes", true)))

	var lian := LIAN_WU_PRESENTER_SCRIPT.new() as FirstPlayableLot01Presenter
	assert(lian.expected_sprite_frames_path() == "res://assets/tgap/pack_01_lian_wu/first_playable_lot_01/lian_wu_first_playable_frames.tres")
	var rival := TRAINING_RIVAL_PRESENTER_SCRIPT.new() as TrainingRivalLot01Presenter
	assert(rival.expected_sprite_frames_path() == "res://assets/tgap/training_rival/first_playable_lot_01/training_rival_first_playable_frames.tres")

	print("FIRST_PLAYABLE_REAL_ART_HANDOFF_CONTRACT_OK")
	quit()

# Tehkné Solutions