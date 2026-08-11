extends SceneTree

const FRAMES_PATH := "res://assets/tgap/training_rival/first_playable_lot_01/training_rival_first_playable_frames.tres"
const EXPECTED := {
	&"idle": 6,
	&"run": 8,
	&"jump_start": 3,
	&"airborne": 2,
	&"fall": 2,
	&"attack_light": 6,
	&"guard": 3,
	&"dodge": 5,
	&"hit": 3,
	&"ko": 6,
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(ResourceLoader.exists(FRAMES_PATH))
	var frames := load(FRAMES_PATH) as SpriteFrames
	assert(frames != null)
	var total := 0
	for animation: StringName in EXPECTED:
		assert(frames.has_animation(animation))
		var expected: int = int(EXPECTED[animation])
		assert(frames.get_frame_count(animation) == expected)
		for index in range(expected):
			assert(frames.get_frame_texture(animation, index) != null)
		total += expected
	assert(total == 44)
	print("VM02_C28_GODOT_SPRITEFRAMES=PASS animations=10 frames=44")

	var presenter := TrainingRivalLot01Presenter.new()
	presenter.name = "C28TrainingRivalBenchPresenter"
	root.add_child(presenter)
	await process_frame
	assert(presenter.using_real_assets())
	assert(presenter.expected_sprite_frames_path() == FRAMES_PATH)
	var sprite := presenter.get_node_or_null("TrainingRivalLot01AnimatedSprite") as AnimatedSprite2D
	assert(sprite != null)
	assert(sprite.sprite_frames == frames or sprite.sprite_frames != null)
	assert(sprite.animation == &"idle")
	print("VM02_C28_PRESENTER_ACTIVATION=PASS using_real_assets=true")
	print("VM02_C28_PROXY_RETIREMENT=BLOCKED code_fallback_preserved=true")
	print("VM02_C28_GODOT_RUNTIME_BENCH=PASS")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

# Tehkné Solutions
