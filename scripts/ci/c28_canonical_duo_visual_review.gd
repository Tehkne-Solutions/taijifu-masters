extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT := "res://artifacts/c28_duo/C28_CANONICAL_DUO.review-1920x1080.png"
const MIN_VISUAL_HEIGHT := 100.0
const MAX_VISUAL_HEIGHT := 180.0
const MAX_HEIGHT_RATIO_DRIFT := 0.25
const MAX_FOOTLINE_DRIFT := 6.0
const MIN_VISIBLE_SCREEN_FRACTION := 0.60

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

	for fighter in [battle.player_one, battle.player_two]:
		for node_name in ["FirstPlayableIdentity", "SpritePresenter"]:
			var legacy_surface := fighter.get_node_or_null(node_name) as CanvasItem
			if legacy_surface != null and legacy_surface.visible:
				_fail("C28_DUO_VISUAL=BLOCKED legacy_surface_visible player=%d node=%s" % [fighter.player_index, node_name])
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
	var p1_screen := p1_metrics["screen_rect"] as Rect2
	var p2_screen := p2_metrics["screen_rect"] as Rect2
	var viewport_size := Vector2(get_root().get_visible_rect().size)
	var gameplay_rect := Rect2(
		Vector2(0.0, viewport_size.y * 0.14),
		Vector2(viewport_size.x, viewport_size.y * 0.68)
	)
	var p1_visible_fraction := _intersection_fraction(p1_screen, gameplay_rect)
	var p2_visible_fraction := _intersection_fraction(p2_screen, gameplay_rect)

	print("C28_DUO_LIAN_METRICS height=%.3f footline=%.3f scale=%.6f" % [p1_height, p1_footline, absf(p1_sprite.scale.y)])
	print("C28_DUO_RIVAL_METRICS height=%.3f footline=%.3f scale=%.6f" % [p2_height, p2_footline, absf(p2_sprite.scale.y)])
	print("C28_DUO_HEIGHT_RATIO=%.4f" % height_ratio)
	print("C28_DUO_WORLD p1=(%.2f,%.2f) p2=(%.2f,%.2f) camera=(%.2f,%.2f) zoom=(%.3f,%.3f)" % [battle.player_one.global_position.x, battle.player_one.global_position.y, battle.player_two.global_position.x, battle.player_two.global_position.y, battle.camera.global_position.x, battle.camera.global_position.y, battle.camera.zoom.x, battle.camera.zoom.y])
	print("C28_DUO_VIEWPORT size=(%.0f,%.0f) gameplay=%s" % [viewport_size.x, viewport_size.y, str(gameplay_rect)])
	print("C28_DUO_LIAN_SCREEN rect=%s visible_fraction=%.4f" % [str(p1_screen), p1_visible_fraction])
	print("C28_DUO_RIVAL_SCREEN rect=%s visible_fraction=%.4f" % [str(p2_screen), p2_visible_fraction])

	_capture()

	var scale_ok := (
		p1_height >= MIN_VISUAL_HEIGHT and p1_height <= MAX_VISUAL_HEIGHT
		and p2_height >= MIN_VISUAL_HEIGHT and p2_height <= MAX_VISUAL_HEIGHT
		and absf(height_ratio - 1.0) <= MAX_HEIGHT_RATIO_DRIFT
	)
	var feet_ok := absf(p1_footline) <= MAX_FOOTLINE_DRIFT and absf(p2_footline) <= MAX_FOOTLINE_DRIFT
	var visibility_ok := p1_visible_fraction >= MIN_VISIBLE_SCREEN_FRACTION and p2_visible_fraction >= MIN_VISIBLE_SCREEN_FRACTION
	if not scale_ok:
		_fail("C28_DUO_VISUAL=BLOCKED scale_mismatch ratio=%.4f p1=%.3f p2=%.3f" % [height_ratio, p1_height, p2_height], false)
		return
	if not feet_ok:
		_fail("C28_DUO_VISUAL=BLOCKED footline p1=%.3f p2=%.3f" % [p1_footline, p2_footline], false)
		return
	if not visibility_ok:
		_fail("C28_DUO_VISUAL=BLOCKED viewport_visibility p1=%.4f p2=%.4f" % [p1_visible_fraction, p2_visible_fraction], false)
		return

	print("C28_DUO_REAL_ASSETS=PASS lian=true rival=true fallback_hidden=true")
	print("C28_DUO_SCALE=PASS p1=%.3f p2=%.3f ratio=%.4f" % [p1_height, p2_height, height_ratio])
	print("C28_DUO_FOOTLINE=PASS p1=%.3f p2=%.3f" % [p1_footline, p2_footline])
	print("C28_DUO_VIEWPORT_VISIBILITY=PASS p1=%.4f p2=%.4f" % [p1_visible_fraction, p2_visible_fraction])
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
	var local_origin := Vector2(rect.position) - Vector2(image.get_size()) * 0.5 if sprite.centered else Vector2(rect.position)
	var local_rect := Rect2(local_origin, Vector2(rect.size))
	var screen_transform := get_root().get_canvas_transform() * sprite.get_global_transform()
	var screen_rect := _transform_rect(local_rect, screen_transform)
	return {
		"valid": true,
		"used_rect": rect,
		"visual_height": visual_height,
		"footline_local": footline_local,
		"screen_rect": screen_rect,
	}

func _transform_rect(rect: Rect2, transform: Transform2D) -> Rect2:
	var points := [
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end,
		transform * Vector2(rect.position.x, rect.end.y),
	]
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point: Vector2 in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)

func _intersection_fraction(rect: Rect2, clip: Rect2) -> float:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 0.0
	var intersection := rect.intersection(clip)
	if intersection.size.x <= 0.0 or intersection.size.y <= 0.0:
		return 0.0
	return (intersection.size.x * intersection.size.y) / (rect.size.x * rect.size.y)

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
