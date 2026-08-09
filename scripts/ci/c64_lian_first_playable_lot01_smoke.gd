extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const LOT_ROOT := "res://assets/tgap/pack_01_lian_wu/first_playable_lot_01"
const SPRITE_FRAMES := LOT_ROOT + "/lian_wu_first_playable_frames.tres"
const REQUIRED := [
	&"idle", &"run", &"jump_start", &"airborne", &"fall",
	&"attack_light", &"guard", &"dodge", &"hit", &"ko",
]

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	quit(2)

func _run() -> void:
	if not ResourceLoader.exists(SPRITE_FRAMES):
		_fail("C64_LOT01_GODOT=BLOCKED spriteframes_missing")
		return
	var frames := load(SPRITE_FRAMES) as SpriteFrames
	if frames == null:
		_fail("C64_LOT01_GODOT=BLOCKED spriteframes_invalid")
		return
	var total_frames := 0
	for animation_name in REQUIRED:
		if not frames.has_animation(animation_name):
			_fail("C64_LOT01_GODOT=BLOCKED missing_animation=%s" % String(animation_name))
			return
		var count := frames.get_frame_count(animation_name)
		if count <= 0:
			_fail("C64_LOT01_GODOT=BLOCKED empty_animation=%s" % String(animation_name))
			return
		total_frames += count
		print("C64_LOT01_ANIMATION=PASS name=%s frames=%d" % [String(animation_name), count])

	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		_fail("C64_LOT01_GODOT=BLOCKED battle_scene_missing")
		return
	var battle := packed.instantiate() as FirstPlayableController
	if battle == null:
		_fail("C64_LOT01_GODOT=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(16):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C64_LOT01_GODOT=BLOCKED player_one_missing")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter")
	if presenter == null or not (presenter is FirstPlayableLot01Presenter):
		_fail("C64_LOT01_GODOT=BLOCKED presenter_missing")
		return
	if not (presenter as FirstPlayableLot01Presenter).using_real_assets():
		_fail("C64_LOT01_GODOT=BLOCKED presenter_inactive")
		return
	var sprite := presenter.get_node_or_null("Lot01AnimatedSprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		_fail("C64_LOT01_GODOT=BLOCKED animated_sprite_missing")
		return
	for node_name in ["FirstPlayableIdentity", "SpritePresenter"]:
		var legacy_surface := battle.player_one.get_node_or_null(node_name) as CanvasItem
		if legacy_surface != null and legacy_surface.visible:
			_fail("C64_LOT01_GODOT=BLOCKED legacy_visual_still_visible:%s" % node_name)
			return

	print("C64_LOT01_SPRITEFRAMES=PASS animations=10 frames=%d" % total_frames)
	print("C64_LOT01_PRESENTER=PASS real_assets=true")
	print("C64_LOT01_LEGACY_VISUALS=HIDDEN surfaces=FirstPlayableIdentity,SpritePresenter")
	print("C64_LOT01_PROCEDURAL_VISUAL=HIDDEN")
	print("C64_LOT01_GODOT=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	quit(0)

# Tehkné Solutions