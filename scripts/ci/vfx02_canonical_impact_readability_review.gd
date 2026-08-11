extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT_DIR := "res://artifacts/vfx02"
const GAMEPLAY_SAFE_RECT := Rect2(8.0, 158.0, 1264.0, 432.0)
const MAX_EFFECT_EXTENT_TO_FIGHTER_HEIGHT := 0.70
const MAX_ELEMENT_RADIUS_TO_FIGHTER_HEIGHT := 0.50
const MAX_SHAKE_TO_MIN_FIGHTER_SCREEN_HEIGHT := 0.08
const MAX_HITSTOP_SECONDS := 0.110

var _metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-VFX-02")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("VFX02_READABILITY=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.86, true, false, true).timeout
	for _frame in range(10):
		await process_frame

	if not is_instance_valid(battle.player_one) or not is_instance_valid(battle.player_two):
		_fail("VFX02_READABILITY=BLOCKED fighters", battle)
		return
	battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	battle.player_one.global_position = Vector2(1120.0, 827.0)
	battle.player_two.global_position = Vector2(1580.0, 827.0)
	battle.player_one.velocity = Vector2.ZERO
	battle.player_two.velocity = Vector2.ZERO
	battle.player_one.facing = 1.0
	battle.player_two.facing = -1.0
	await create_timer(0.24, true, false, true).timeout
	for _frame in range(8):
		await process_frame

	var p1_presenter := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	var p2_presenter := battle.player_two.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
	if p1_presenter == null or not p1_presenter.using_real_assets():
		_fail("VFX02_READABILITY=BLOCKED lian_real_assets", battle)
		return
	if p2_presenter == null or not p2_presenter.using_real_assets():
		_fail("VFX02_READABILITY=BLOCKED rival_real_assets", battle)
		return

	var p1_sprite := p1_presenter.get_node_or_null("Lot01AnimatedSprite") as AnimatedSprite2D
	var p2_sprite := p2_presenter.get_node_or_null("TrainingRivalLot01AnimatedSprite") as AnimatedSprite2D
	var p1_height := _visual_height_world(p1_sprite)
	var p2_height := _visual_height_world(p2_sprite)
	if p1_height <= 0.0 or p2_height <= 0.0:
		_fail("VFX02_READABILITY=BLOCKED fighter_metrics", battle)
		return

	var impact := battle.get_node_or_null("ImpactDirector") as ImpactDirector
	var composition := battle.get_node_or_null("FightCameraComposition") as FirstPlayableCameraComposition
	var feedback := battle.get_node_or_null("FirstPlayableCombatFeedbackRuntime")
	if impact == null or composition == null or feedback == null:
		_fail("VFX02_READABILITY=BLOCKED presentation_nodes", battle)
		return
	var impact_signature := impact.presentation_signature()
	var camera_signature := composition.presentation_signature()
	if String(impact_signature.get("stage", "")) != "VFX-02":
		_fail("VFX02_READABILITY=BLOCKED impact_stage", battle)
		return
	if not bool(impact_signature.get("canonical_impact_readability_contract", false)):
		_fail("VFX02_READABILITY=BLOCKED readability_contract", battle)
		return

	var reference_height := minf(p1_height, p2_height)
	var physical_extent := float(impact_signature.get("max_physical_impact_extent_world", INF))
	var element_radius := float(impact_signature.get("max_element_radius_world", INF))
	var max_hitstop := float(impact_signature.get("max_hitstop_seconds", INF))
	var max_shake := float(camera_signature.get("max_shake_pixels", INF))
	var min_zoom := float(camera_signature.get("min_zoom", 0.0))
	var min_screen_height := reference_height * min_zoom
	var physical_ratio := physical_extent / maxf(1.0, reference_height)
	var element_ratio := element_radius / maxf(1.0, reference_height)
	var shake_ratio := max_shake / maxf(1.0, min_screen_height)
	if physical_ratio > MAX_EFFECT_EXTENT_TO_FIGHTER_HEIGHT:
		_fail("VFX02_READABILITY=BLOCKED physical_extent ratio=%.4f" % physical_ratio, battle)
		return
	if element_ratio > MAX_ELEMENT_RADIUS_TO_FIGHTER_HEIGHT:
		_fail("VFX02_READABILITY=BLOCKED element_radius ratio=%.4f" % element_ratio, battle)
		return
	if shake_ratio > MAX_SHAKE_TO_MIN_FIGHTER_SCREEN_HEIGHT:
		_fail("VFX02_READABILITY=BLOCKED camera_shake ratio=%.4f" % shake_ratio, battle)
		return
	if max_hitstop > MAX_HITSTOP_SECONDS:
		_fail("VFX02_READABILITY=BLOCKED hitstop=%.4f" % max_hitstop, battle)
		return

	var technique := TechniqueCatalog.get_technique(&"ji_body_hook")
	if technique == null:
		_fail("VFX02_READABILITY=BLOCKED technique", battle)
		return

	_metrics = {
		"signature": "Tehkné Solutions",
		"stage": "VFX-02",
		"fighter_heights_world": {"lian": p1_height, "rival": p2_height},
		"reference_height_world": reference_height,
		"max_physical_impact_extent_world": physical_extent,
		"physical_extent_to_fighter_height": physical_ratio,
		"max_element_radius_world": element_radius,
		"element_radius_to_fighter_height": element_ratio,
		"max_shake_pixels": max_shake,
		"min_fighter_screen_height": min_screen_height,
		"shake_to_min_fighter_screen_height": shake_ratio,
		"max_hitstop_seconds": max_hitstop,
		"gameplay_safe_rect": _rect_dict(GAMEPLAY_SAFE_RECT),
		"states": {}
	}

	var states := [
		{"id": &"hit", "expected": String(technique.display_name).to_upper(), "critical": false},
		{"id": &"blocked", "expected": "BLOQUEIO", "critical": false},
		{"id": &"parried", "expected": "PARRY", "critical": true},
		{"id": &"posture_break", "expected": "QUEBRA", "critical": true},
	]
	for state in states:
		var ok := await _review_state(battle, impact, composition, feedback, technique, state)
		if not ok:
			return

	_write_metrics()
	print("VFX02_CANONICAL_DUO=PASS lian=%.3f rival=%.3f" % [p1_height, p2_height])
	print("VFX02_EFFECT_SCALE=PASS physical=%.4f elemental=%.4f" % [physical_ratio, element_ratio])
	print("VFX02_CAMERA_PUNCH=PASS max_px=%.2f ratio=%.4f" % [max_shake, shake_ratio])
	print("VFX02_HITSTOP=PASS max_seconds=%.3f" % max_hitstop)
	print("VFX02_SAFE_AREA=PASS states=4")
	print("VFX02_CAPTURE_SET=PASS hit block parry posture_break")
	print("VFX02_READABILITY=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _review_state(
	battle: FirstPlayableController,
	impact: ImpactDirector,
	composition: FirstPlayableCameraComposition,
	feedback: Node,
	technique: TechniqueData,
	state: Dictionary
) -> bool:
	var state_id := StringName(state["id"])
	var expected := String(state["expected"])
	var critical := bool(state["critical"])
	Engine.time_scale = 1.0
	battle.player_one.impact_resolved.emit(
		battle.player_two,
		battle.player_one,
		technique,
		state_id,
		0.0,
		0.0,
		0.86,
		battle.player_two.global_position + Vector2(0.0, -38.0)
	)
	await process_frame
	var layer := feedback.get_node_or_null("CombatFeedbackLayer") as CanvasLayer
	var popup := _latest_popup(layer)
	if popup == null:
		_fail("VFX02_READABILITY=BLOCKED popup_missing state=%s" % state_id, battle)
		return false
	if popup.text != expected:
		_fail("VFX02_READABILITY=BLOCKED popup_text state=%s expected=%s actual=%s" % [state_id, expected, popup.text], battle)
		return false
	var popup_rect := Rect2(popup.position, popup.size)
	var safe_fraction := _intersection_fraction(popup_rect, GAMEPLAY_SAFE_RECT)
	if safe_fraction < 0.96:
		_fail("VFX02_READABILITY=BLOCKED popup_safe state=%s fraction=%.4f rect=%s" % [state_id, safe_fraction, popup_rect], battle)
		return false
	var critical_label := layer.get_node_or_null("CriticalImpact") as Label
	if critical and (critical_label == null or critical_label.text != expected):
		_fail("VFX02_READABILITY=BLOCKED critical_label state=%s" % state_id, battle)
		return false
	var shake_strength := float(composition.get("_shake_strength"))
	var camera := battle.camera as Camera2D
	var camera_offset := camera.offset.length() if camera != null else INF
	if camera_offset > 7.15:
		_fail("VFX02_READABILITY=BLOCKED camera_offset state=%s value=%.3f" % [state_id, camera_offset], battle)
		return false
	if state_id != &"blocked" and shake_strength <= 0.0:
		_fail("VFX02_READABILITY=BLOCKED camera_punch_missing state=%s" % state_id, battle)
		return false
	var time_scale_immediate := Engine.time_scale
	if time_scale_immediate >= 0.99:
		_fail("VFX02_READABILITY=BLOCKED hitstop_missing state=%s" % state_id, battle)
		return false
	if impact.last_burst_text() != "":
		_fail("VFX02_READABILITY=BLOCKED duplicate_text state=%s" % state_id, battle)
		return false
	var filename := "VFX02_%s.review-1920x1080.png" % String(state_id).to_upper()
	_capture(filename)
	var states_dict: Dictionary = _metrics["states"]
	states_dict[String(state_id)] = {
		"popup_text": popup.text,
		"popup_rect": _rect_dict(popup_rect),
		"popup_safe_fraction": safe_fraction,
		"critical_center_feedback": critical,
		"shake_strength": shake_strength,
		"camera_offset_pixels": camera_offset,
		"time_scale_immediate": time_scale_immediate,
		"impact_burst_count": impact.active_burst_count(),
		"capture": filename
	}
	_metrics["states"] = states_dict
	await create_timer(0.72, true, false, true).timeout
	for _frame in range(8):
		await process_frame
	Engine.time_scale = 1.0
	return true

func _visual_height_world(sprite: AnimatedSprite2D) -> float:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"idle"):
		return -1.0
	var texture := sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return -1.0
	var image := texture.get_image()
	if image == null or image.is_empty():
		return -1.0
	var rect := image.get_used_rect()
	return float(rect.size.y) * absf(sprite.scale.y)

func _latest_popup(layer: CanvasLayer) -> Label:
	if layer == null:
		return null
	var found: Label = null
	for child in layer.get_children():
		if child is Label and child.name == "ImpactPopup" and is_instance_valid(child):
			found = child as Label
	return found

func _intersection_fraction(rect: Rect2, safe: Rect2) -> float:
	var area := maxf(1.0, rect.size.x * rect.size.y)
	var intersection := rect.intersection(safe)
	return (intersection.size.x * intersection.size.y) / area

func _capture(filename: String) -> void:
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename))

func _write_metrics() -> void:
	var dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/VFX02_METRICS.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_metrics, "  "))
		file.close()

func _rect_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}

func _fail(message: String, battle: Node = null) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
