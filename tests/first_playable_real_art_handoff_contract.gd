extends SceneTree

const IDENTITY_SCRIPT := preload("res://scripts/vertical_slice/first_playable_character_identity.gd")
const LIAN_WU_PRESENTER_SCRIPT := preload("res://scripts/vertical_slice/first_playable_lot01_presenter.gd")
const TRAINING_RIVAL_PRESENTER_SCRIPT := preload("res://scripts/vertical_slice/training_rival_lot01_presenter.gd")
const ALIASES_PATH := "res://assets/tgap/aliases.json"

func _init() -> void:
	var identity := IDENTITY_SCRIPT.new() as FirstPlayableCharacterIdentity
	var signature := identity.presentation_signature()
	assert(bool(signature.get("real_asset_handoff", false)))
	assert(bool(signature.get("lian_wu_presenter", false)))
	assert(bool(signature.get("training_rival_presenter", false)))
	assert(not bool(signature.get("procedural_character_renderer", true)))
	assert(not bool(signature.get("procedural_fallback_until_real_assets", true)))
	assert(bool(signature.get("canonical_visual_cutover_required", false)))
	assert(not bool(signature.get("collision_changes", true)))

	# Lian Wu now resolves through the TGAP logical loader. The release contract
	# must freeze alias -> logical path -> fallback rather than ask an unattached
	# presenter for a runtime path before autoload initialization.
	var aliases := _json(ALIASES_PATH)
	assert(FirstPlayableLot01Presenter.TGAP_PACK_ALIAS == "lian_wu")
	assert(FirstPlayableLot01Presenter.SPRITE_FRAMES_LOGICAL == "first_playable_spriteframes")
	assert(String(aliases.get("aliases", {}).get("lian_wu", {}).get("pack_id", "")) == "pack_01_lian_wu")
	assert(String(aliases.get("path_aliases", {}).get("pack_01_lian_wu", {}).get("first_playable_spriteframes", "")) == "first_playable_lot_01/lian_wu_first_playable_frames.tres")
	assert(String(aliases.get("fallbacks", {}).get("pack_01_lian_wu", {}).get("paths", {}).get("first_playable_spriteframes", "")) == "res://assets/tgap/pack_01_lian_wu/first_playable_lot_01/lian_wu_first_playable_frames.tres")

	# Training Rival has not moved to the logical TGAP alias boundary yet; keep
	# its existing explicit handoff contract unchanged.
	var rival := TRAINING_RIVAL_PRESENTER_SCRIPT.new() as TrainingRivalLot01Presenter
	assert(rival.expected_sprite_frames_path() == "res://assets/tgap/training_rival/first_playable_lot_01/training_rival_first_playable_frames.tres")

	print("FIRST_PLAYABLE_REAL_ART_HANDOFF_CONTRACT_OK")
	quit()

func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

# Missing canonical art remains a release blocker; the runtime does not silently
# reactivate the removed procedural renderer.
# Tehkné Solutions
