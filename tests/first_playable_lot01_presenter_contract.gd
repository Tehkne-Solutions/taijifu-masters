extends SceneTree

const PRESENTER_SCRIPT := preload("res://scripts/vertical_slice/first_playable_lot01_presenter.gd")
const ALIASES_PATH := "res://assets/tgap/aliases.json"

func _init() -> void:
	var presenter := PRESENTER_SCRIPT.new() as FirstPlayableLot01Presenter
	assert(FirstPlayableLot01Presenter.TGAP_PACK_ALIAS == "lian_wu")
	assert(FirstPlayableLot01Presenter.SPRITE_FRAMES_LOGICAL == "first_playable_spriteframes")
	assert(not presenter.using_real_assets())

	# The presenter no longer owns a physical TGAP path. Freeze the logical
	# resolution contract instead, including the current fallback used when the
	# installed catalog is unavailable. Runtime activation itself is covered by
	# First Playable Smoke and the active-fight gates.
	var aliases := _json(ALIASES_PATH)
	assert(String(aliases.get("aliases", {}).get("lian_wu", {}).get("pack_id", "")) == "pack_01_lian_wu")
	assert(String(aliases.get("path_aliases", {}).get("pack_01_lian_wu", {}).get("first_playable_spriteframes", "")) == "first_playable_lot_01/lian_wu_first_playable_frames.tres")
	assert(String(aliases.get("fallbacks", {}).get("pack_01_lian_wu", {}).get("paths", {}).get("first_playable_spriteframes", "")) == "res://assets/tgap/pack_01_lian_wu/first_playable_lot_01/lian_wu_first_playable_frames.tres")

	print("FIRST_PLAYABLE_LOT01_PRESENTER_CONTRACT_OK")
	quit()

func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

# Tehkné Solutions
