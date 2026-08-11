extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT := "res://artifacts/c28_duo/C28_CANONICAL_DUO.review-1920x1080.png"
const MIN_VISUAL_HEIGHT := 100.0
const MAX_VISUAL_HEIGHT := 180.0
const MAX_HEIGHT_RATIO_DRIFT := 0.25
const MAX_FOOTLINE_DRIFT := 6.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-C28-DUO")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("C28_DUO_VISUAL=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.20
	battle.fight_command_seconds = 0.10
	get_root().add_child(battle)
	await create_timer(0.75).timeout
	for _frame in range(8):
		await process_frame

	if not is_instance_valid(battle.player_one) or not is_instance_valid(battle.player_two):
		_fail("C28_DUO_VISUAL=BLOCKED fighters")
		return
	var p1_presenter := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	var p2_presenter := battle.player_two.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
	if p1_presenter == null or not p1_presenter.using_real_assets():
		_fail("C28_DUO_VISUAL=BLOCKED lian_presenter")
		return
	if p2_presenter == null or not p2_presenter.using_real_assets():
		_fail("C28_DUO_VISUAL=BLOCKED rival_presenter")
		return

	var p1_sprite := p1_presenter.get_node_or_null("Lot01AnimatedSprite") as AnimatedSprite2D
	var p2_sprite := p2_presenter.get_node_or_null("TrainingRivalLot01AnimatedSprite") as AnimatedSprite2D
	if p1_sprite == null or p2_sprite == null:
		_fail("C28_DUO_VISUAL=BLOCKED sprites")
		return
	if p1_sprite.sprite_frames == null or p2_sprite.sprite_frames == null:
		_fail("C28_DUO_VISUAL=BLOCKED spriteframes")
		return

	var p1_fallback := battle.player_one.get_node_or_null("FirstPlayableIdentity") as CanvasItem
	var p2_fallback := battle.player_two.get_node_or_null("FirstPlayableIdentity") as CanvasItem
	if p1_fallback != null and p1_fallback.visible:
		_fail("C28_DUO_VISUAL=BLOCKED lian_fallback_visible")
		return
	if p2_fallback != null and p2_fallback.visible:
		_fail("C28_DUO_VISUAL=BLOCKED rival_fallback_visible")
		return

	var p1_metrics := _sprite_metrics(p1_sprite)
	var p2_metrics := _sprite_metrics(p2_sprite)
	if not bool(p1_metrics.get("valid", false)) or not bool(p2_metrics.get("valid", false)):
		_fail("C28_DUO_VISUAL=BLOCKED alpha_metrics")
		return

	var p1_height := float(p1_metrics["visual_height"])
	var p2_height := float(p2_metrics["visual_height"])
	var height_ratio := p2_height / maxf(1.0, p1_height)
	var p1_footline := float(p1_metrics["footline_local"])
	var p2_footline := float(p2_metrics["footline_local"])

	print("C28_DUO_LIAN_METRICS height=%.3f footline=%.3f scale=%.6f" % [p1_height, p1_footline, absf(p1_sprite.scale.y)])
	print("C28_DUO_RIVAL_METRICS height=%.3f footline=%.3f scale=%.6f" % [p2_height, p2_footline, absf(p2_sprite.scale.y)])
	print("C28_DUO_HEIGHT_RATIO=%.4f" % height_ratio)

	_capture()

	var scale_ok := (
		p1_height >= MIN_VISUAL_HEIGHT and p1_height <= MAX_VISUAL_HEIGHT
		and p2_height >= MIN_VISUAL_HEIGHT and p2_height <= MAX_VISUAL_HEIGHT
		and absf(height_ratio - 1.0) <= MAX_HEIGHT_RATIO_DRIFT
	)
	var feet_ok := absf(p1_footline) <= MAX_FOOTLINE_DRIFT and absf(p2_footline) <= MAX_FOOTLINE_DRIFT
	if not scale_ok:
		_fail("C28_DUO_VISUAL=BLOCKED scale_mismatch ratio=%.4f p1=%.3f p2=%.3f" % [height_ratio, p1_height, p2_height], false)
		return
	if not feet_ok:
		_fail("C28_DUO_VISUAL=BLOCKED footline p1=%.3f p2=%.3f" % [p1_footline, p2_footline], false)
		return

	print("C28_DUO_REAL_ASSETS=PASS lian=true rival=true fallback_hidden=true")
	print("C28_DUO_SCALE=PASS p1=%.3f p2=%.3f ratio=%.4f" % [p1_height, p2_height, height_ratio])
	print("C28_DUO_FOOTLINE=PASS p1=%.3f p2=%.3f" % [p1_footline, p2_footline])
	print("C28_DUO_VISUAL=PASS")
	print("C28_DUO_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _sprite_metrics(sprite: AnimatedSprite2D) -> Dictionary:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"idle"):
		return {"valid": false}
	var texture := sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return {"valid": false}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"valid": false}
	var rect := image.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {"valid": false}
	var scale_y := absf(sprite.scale.y)
	var visual_height := float(rect.size.y) * scale_y
	var center_y := float(image.get_height()) * 0.5
	var alpha_bottom_from_center := float(rect.position.y + rect.size.y) - center_y
	var footline_local := sprite.position.y + alpha_bottom_from_center * sprite.scale.y
	return {
		"valid": true,
		"used_rect": rect,
		"visual_height": visual_height,
		"footline_local": footline_local,
	}

func _capture() -> void:
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	image.save_png(OUTPUT)

func _fail(message: String, capture_now: bool = true) -> void:
	if capture_now:
		_capture()
	push_error(message)
	print(message)
	print("C28_DUO_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
