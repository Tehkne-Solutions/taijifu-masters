extends SceneTree

func _init() -> void:
	var presenter := TrainingRivalLot01Presenter.new()
	assert(presenter.expected_sprite_frames_path() == "res://assets/tgap/training_rival/first_playable_lot_01/training_rival_first_playable_frames.tres")
	assert(not presenter.using_real_assets())
	print("TRAINING_RIVAL_LOT01_PRESENTER_CONTRACT_OK")
	quit(0)

# Tehkné Solutions
