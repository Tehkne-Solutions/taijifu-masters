extends SceneTree

const PRESENTER_SCRIPT := preload("res://scripts/vertical_slice/first_playable_lot01_presenter.gd")

func _init() -> void:
	var presenter := PRESENTER_SCRIPT.new() as FirstPlayableLot01Presenter
	assert(presenter.expected_sprite_frames_path() == "res://assets/tgap/pack_01_lian_wu/first_playable_lot_01/lian_wu_first_playable_frames.tres")
	assert(not presenter.using_real_assets())
	print("FIRST_PLAYABLE_LOT01_PRESENTER_CONTRACT_OK")
	quit()

# Tehkné Solutions
