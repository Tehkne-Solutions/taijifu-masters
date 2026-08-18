extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT_DIR := "res://artifacts/p0_2_screen_presence"
const FAR_OUTPUT := "P0_2_FIGHTER_SCREEN_PRESENCE.far-1920x1080.png"
const CLOSE_OUTPUT := "P0_2_FIGHTER_SCREEN_PRESENCE.close-1920x1080.png"
const METRICS_OUTPUT := "P0_2_FIGHTER_SCREEN_PRESENCE_METRICS.json"
const MAX_WAIT_FRAMES := 600
const MIN_CLOSE_RATIO := 0.23
const MAX_CLOSE_RATIO := 0.34
const MIN_FAR_VISIBLE_FRACTION := 0.97
const MIN_CLOSE_VISIBLE_FRACTION := 0.99
const EXPECTED_CLOSE_ZOOM := 1.46
const EXPECTED_CLOSE_ZOOM_MIN := 1.44
const EXPECTED_CLOSE_ZOOM_MAX := 1.465
const EXPECTED_FAR_ZOOM := 0.72
const EXPECTED_FAR_ZOOM_MIN := 0.70
const EXPECTED_FAR_ZOOM_MAX := 0.76
const EXPECTED_BASELINE_Y := 530.0
const EXPECTED_VERTICAL_RANGE := 60.0
const CAMERA_SETTLE_TOLERANCE := 0.008
const CAMERA_SETTLE_POLL_SECONDS := 0.05
const CAMERA_SETTLE_MAX_POLLS := 60

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)

	if not await _wait_for_battle_visuals(battle):
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED visual_timeout", battle)
		return
	battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	var p1 := battle.player_one
	var p2 := battle.player_two
	var composition := battle.get_node_or_null("FightCameraComposition") as FirstPlayableCameraComposition
	var modular := p1.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	var p2_presenter := p2.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
	if composition == null or modular == null or modular.assembler() == null or p2_presenter == null:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED presentation_nodes", battle)
		return
	var rival_sprite := p2_presenter.get_node_or_null("TrainingRivalLot01AnimatedSprite") as AnimatedSprite2D
	if rival_sprite == null:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED rival_sprite", battle)
		return
	var camera_signature := composition.presentation_signature()
	var owner_signature := battle.camera_ownership_signature()
	if bool(camera_signature.get("world_fighter_scale_changes", true)):
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED world_scale_mutation", battle)
		return
	if StringName(camera_signature.get("framing", &"")) != &"stage_premium_fighter_first":
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED framing:%s" % str(camera_signature), battle)
		return
	if absf(float(camera_signature.get("min_zoom", 0.0)) - EXPECTED_FAR_ZOOM) > 0.001:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED min_zoom:%s" % str(camera_signature), battle)
		return
	if absf(float(camera_signature.get("max_zoom", 0.0)) - EXPECTED_CLOSE_ZOOM) > 0.001:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED max_zoom:%s" % str(camera_signature), battle)
		return
	if absf(float(camera_signature.get("baseline_y", 0.0)) - EXPECTED_BASELINE_Y) > 0.01:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED baseline_y:%s" % str(camera_signature), battle)
		return
	if absf(float(camera_signature.get("vertical_range", 0.0)) - EXPECTED_VERTICAL_RANGE) > 0.01:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED vertical_range:%s" % str(camera_signature), battle)
		return
	if absf(float(camera_signature.get("horizontal_padding", 0.0)) - 220.0) > 0.01:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED horizontal_padding:%s" % str(camera_signature), battle)
		return
	if (
		not bool(owner_signature.get("composition_active", false))
		or bool(owner_signature.get("legacy_camera_writer_active", true))
		or not bool(owner_signature.get("single_production_owner", false))
		or String(owner_signature.get("production_owner", "")) != "FightCameraComposition"
	):
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED camera_owner:%s" % str(owner_signature), battle)
		return

	var guide := battle.get_node_or_null("HUD/CombatGuide") as FirstPlayableCombatGuide
	var guide_wait := 0.0
	while guide != null and (guide.guide_stage() != &"hidden" or guide.visible) and guide_wait < 3.0:
		await create_timer(0.10, true, false, true).timeout
		guide_wait += 0.10
	if guide != null and (guide.guide_stage() != &"hidden" or guide.visible):
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED onboarding_not_released", battle)
		return

	# Opening distance: tactical context and both fighters must remain fully readable.
	_set_fighters(p1, p2, Vector2(720.0, 827.0), Vector2(2080.0, 827.0))
	if not await _settle_camera(battle.camera, EXPECTED_FAR_ZOOM):
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED far_camera_settle zoom=%.4f target=%.3f" % [battle.camera.zoom.x, EXPECTED_FAR_ZOOM], battle)
		return
	var far_metrics := _screen_metrics(battle, modular.assembler(), rival_sprite)
	var far_zoom := battle.camera.zoom.x
	if far_zoom < EXPECTED_FAR_ZOOM_MIN or far_zoom > EXPECTED_FAR_ZOOM_MAX:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED far_zoom=%.4f" % far_zoom, battle)
		return
	if float(far_metrics.get("p1_visible_fraction", 0.0)) < MIN_FAR_VISIBLE_FRACTION or float(far_metrics.get("p2_visible_fraction", 0.0)) < MIN_FAR_VISIBLE_FRACTION:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED far_visibility:%s" % str(far_metrics), battle)
		return
	_capture(FAR_OUTPUT)

	# Close combat: strong presence without changing fighter world scale.
	_set_fighters(p1, p2, Vector2(1120.0, 827.0), Vector2(1580.0, 827.0))
	if not await _settle_camera(battle.camera, EXPECTED_CLOSE_ZOOM):
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED close_camera_settle zoom=%.4f target=%.3f" % [battle.camera.zoom.x, EXPECTED_CLOSE_ZOOM], battle)
		return
	var close_metrics := _screen_metrics(battle, modular.assembler(), rival_sprite)
	var close_zoom := battle.camera.zoom.x
	if close_zoom < EXPECTED_CLOSE_ZOOM_MIN or close_zoom > EXPECTED_CLOSE_ZOOM_MAX:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED close_zoom=%.4f" % close_zoom, battle)
		return
	var p1_ratio := float(close_metrics.get("p1_height_ratio", 0.0))
	var p2_ratio := float(close_metrics.get("p2_height_ratio", 0.0))
	if p1_ratio < MIN_CLOSE_RATIO or p1_ratio > MAX_CLOSE_RATIO:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED p1_close_ratio=%.4f" % p1_ratio, battle)
		return
	if p2_ratio < MIN_CLOSE_RATIO or p2_ratio > MAX_CLOSE_RATIO:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED p2_close_ratio=%.4f" % p2_ratio, battle)
		return
	if float(close_metrics.get("p1_visible_fraction", 0.0)) < MIN_CLOSE_VISIBLE_FRACTION or float(close_metrics.get("p2_visible_fraction", 0.0)) < MIN_CLOSE_VISIBLE_FRACTION:
		_fail("P0_2_SCREEN_PRESENCE=BLOCKED close_visibility:%s" % str(close_metrics), battle)
		return
	_capture(CLOSE_OUTPUT)

	_write_metrics({
		"signature": "Tehkné Solutions",
		"camera": camera_signature,
		"camera_owner": owner_signature,
		"world_fighter_scale_changes": false,
		"camera_settle_policy": {
			"mode": "condition_based",
			"tolerance": CAMERA_SETTLE_TOLERANCE,
			"poll_seconds": CAMERA_SETTLE_POLL_SECONDS,
			"max_polls": CAMERA_SETTLE_MAX_POLLS,
		},
		"far": far_metrics.merged({"zoom": far_zoom}),
		"close": close_metrics.merged({"zoom": close_zoom}),
		"far_capture": FAR_OUTPUT,
		"close_capture": CLOSE_OUTPUT,
	})

	print("P0_2_CAMERA_SINGLE_OWNER=PASS owner=FightCameraComposition legacy_writer=false")
	print("P0_2_FIGHTER_FAR_FRAMING=PASS zoom=%.3f p1_visible=%.4f p2_visible=%.4f" % [
		far_zoom,
		float(far_metrics.get("p1_visible_fraction", 0.0)),
		float(far_metrics.get("p2_visible_fraction", 0.0)),
	])
	print("P0_2_FIGHTER_CLOSE_PRESENCE=PASS zoom=%.3f p1_ratio=%.4f p2_ratio=%.4f" % [close_zoom, p1_ratio, p2_ratio])
	print("P0_2_FIGHTER_WORLD_SCALE=UNCHANGED")
	print("P0_2_FIGHTER_SCREEN_PRESENCE_REVIEW=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_battle_visuals(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if (
			int(battle.get("_state")) == FirstPlayableController.MatchState.BATTLE
			and is_instance_valid(battle.player_one)
			and is_instance_valid(battle.player_two)
		):
			var modular := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
			var rival := battle.player_two.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
			var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
			if modular != null and modular.using_modular_assets() and rival != null and rival.using_real_assets() and pose_runtime != null and pose_runtime.authority_active():
				return true
		await process_frame
	return false

func _set_fighters(p1: FighterController, p2: FighterController, p1_position: Vector2, p2_position: Vector2) -> void:
	p1.global_position = p1_position
	p2.global_position = p2_position
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	p1.facing = 1.0
	p2.facing = -1.0

func _settle_camera(camera: Camera2D, target_zoom: float) -> bool:
	if camera == null:
		return false
	for _poll in range(CAMERA_SETTLE_MAX_POLLS):
		if absf(camera.zoom.x - target_zoom) <= CAMERA_SETTLE_TOLERANCE:
			for _frame in range(3):
				await process_frame
			return absf(camera.zoom.x - target_zoom) <= CAMERA_SETTLE_TOLERANCE
		await create_timer(CAMERA_SETTLE_POLL_SECONDS, true, false, true).timeout
	return false

func _screen_metrics(battle: FirstPlayableController, assembler: ModularFighterAssembler, rival_sprite: AnimatedSprite2D) -> Dictionary:
	var viewport_size := Vector2(get_root().get_visible_rect().size)
	var gameplay_rect := Rect2(Vector2(0.0, 100.0), Vector2(viewport_size.x, maxf(1.0, viewport_size.y - 100.0)))
	var p1_rect := _modular_screen_rect(assembler)
	var p2_rect := _sprite_screen_rect(rival_sprite)
	return {
		"viewport": {"w": viewport_size.x, "h": viewport_size.y},
		"gameplay_rect": _rect_dict(gameplay_rect),
		"p1_rect": _rect_dict(p1_rect),
		"p2_rect": _rect_dict(p2_rect),
		"p1_height_ratio": p1_rect.size.y / maxf(1.0, viewport_size.y),
		"p2_height_ratio": p2_rect.size.y / maxf(1.0, viewport_size.y),
		"p1_visible_fraction": _intersection_fraction(p1_rect, gameplay_rect),
		"p2_visible_fraction": _intersection_fraction(p2_rect, gameplay_rect),
		"camera_position": [battle.camera.global_position.x, battle.camera.global_position.y],
	}

func _modular_screen_rect(assembler: ModularFighterAssembler) -> Rect2:
	var initialized := false
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for child in assembler.get_children():
		if child is not Polygon2D:
			continue
		var mesh := child as Polygon2D
		if not mesh.visible or mesh.polygon.is_empty():
			continue
		var transform := get_root().get_canvas_transform() * mesh.get_global_transform()
		for local_point: Vector2 in mesh.polygon:
			var point := transform * local_point
			if not initialized:
				min_point = point
				max_point = point
				initialized = true
			else:
				min_point.x = minf(min_point.x, point.x)
				min_point.y = minf(min_point.y, point.y)
				max_point.x = maxf(max_point.x, point.x)
				max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point) if initialized else Rect2()

func _sprite_screen_rect(sprite: AnimatedSprite2D) -> Rect2:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"idle"):
		return Rect2()
	var texture := sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2()
	var used := image.get_used_rect()
	var local_origin := Vector2(used.position) - Vector2(image.get_size()) * 0.5 if sprite.centered else Vector2(used.position)
	var local_rect := Rect2(local_origin, Vector2(used.size))
	var transform := get_root().get_canvas_transform() * sprite.get_global_transform()
	return _transform_rect(local_rect, transform)

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

func _capture(filename: String) -> void:
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename))

func _write_metrics(metrics: Dictionary) -> void:
	var dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + METRICS_OUTPUT), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
		file.close()

func _rect_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(FirstPlayableSession.PRODUCTION_DEFAULT_PRESET_ID)

func _fail(message: String, battle: Node = null) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions