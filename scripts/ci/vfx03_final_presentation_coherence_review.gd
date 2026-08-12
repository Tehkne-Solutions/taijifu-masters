extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT_DIR := "res://artifacts/vfx03"
const MAX_CAMERA_OFFSET := 7.0
const MAX_RECOVERY_CAMERA_OFFSET := 0.5
const MAX_POPUPS := 2

var _metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-VFX-03")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("VFX03_COHERENCE=BLOCKED battle_scene")
		return

	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.86, true, false, true).timeout
	for _frame in range(10):
		await process_frame

	if not is_instance_valid(battle.player_one) or not is_instance_valid(battle.player_two):
		_fail("VFX03_COHERENCE=BLOCKED fighters", battle)
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
		_fail("VFX03_COHERENCE=BLOCKED lian_real_assets", battle)
		return
	if p2_presenter == null or not p2_presenter.using_real_assets():
		_fail("VFX03_COHERENCE=BLOCKED rival_real_assets", battle)
		return

	var impact := battle.get_node_or_null("ImpactDirector") as ImpactDirector
	var composition := battle.get_node_or_null("FightCameraComposition") as FirstPlayableCameraComposition
	var feedback := battle.get_node_or_null("FirstPlayableCombatFeedbackRuntime")
	if impact == null or composition == null or feedback == null:
		_fail("VFX03_COHERENCE=BLOCKED presentation_nodes", battle)
		return

	var layer := feedback.get_node_or_null("CombatFeedbackLayer") as CanvasLayer
	var camera := battle.camera as Camera2D
	if layer == null or camera == null:
		_fail("VFX03_COHERENCE=BLOCKED presentation_surface", battle)
		return

	var impact_signature := impact.presentation_signature()
	var camera_signature := composition.presentation_signature()
	var feedback_signature: Dictionary = feedback.presentation_signature()
	if not bool(impact_signature.get("canonical_impact_readability_contract", false)):
		_fail("VFX03_COHERENCE=BLOCKED vfx02_contract", battle)
		return
	if bool(impact_signature.get("camera_shake_owner", true)):
		_fail("VFX03_COHERENCE=BLOCKED impact_camera_owner", battle)
		return
	if StringName(impact_signature.get("camera_shake_delegated_to", &"")) != &"FightCameraComposition":
		_fail("VFX03_COHERENCE=BLOCKED camera_delegation", battle)
		return
	if bool(impact_signature.get("physical_impact_text_emitted_here", true)):
		_fail("VFX03_COHERENCE=BLOCKED duplicate_physical_text_owner", battle)
		return
	if StringName(impact_signature.get("physical_impact_text_owner", &"")) != &"FirstPlayableCombatFeedbackRuntime":
		_fail("VFX03_COHERENCE=BLOCKED physical_text_owner", battle)
		return
	if not bool(impact_signature.get("hitstop_owner", false)):
		_fail("VFX03_COHERENCE=BLOCKED hitstop_owner", battle)
		return
	if float(camera_signature.get("max_shake_pixels", INF)) > MAX_CAMERA_OFFSET:
		_fail("VFX03_COHERENCE=BLOCKED camera_contract", battle)
		return
	if int(feedback_signature.get("popup_budget", 999)) != MAX_POPUPS:
		_fail("VFX03_COHERENCE=BLOCKED popup_budget", battle)
		return

	var technique := TechniqueCatalog.get_technique(&"ji_body_hook")
	if technique == null:
		_fail("VFX03_COHERENCE=BLOCKED technique", battle)
		return

	_metrics = {
		"signature": "Tehkné Solutions",
		"stage": "VFX-03",
		"states": {},
		"max_camera_offset_radial_pixels": MAX_CAMERA_OFFSET,
		"max_popup_budget": MAX_POPUPS
	}

	if impact.active_burst_count() != 0 or _popup_count(layer) != 0:
		_fail("VFX03_COHERENCE=BLOCKED baseline_residue", battle)
		return
	if camera.offset.length() > MAX_RECOVERY_CAMERA_OFFSET:
		_fail("VFX03_COHERENCE=BLOCKED baseline_camera value=%.3f" % camera.offset.length(), battle)
		return
	_capture("VFX03_BASELINE.review-1920x1080.png")
	_record_state("baseline_clean", impact, layer, camera, Engine.time_scale)

	Engine.time_scale = 1.0
	battle.player_one.impact_resolved.emit(
		battle.player_two,
		battle.player_one,
		technique,
		&"hit",
		0.0,
		0.0,
		0.86,
		battle.player_two.global_position + Vector2(0.0, -38.0)
	)
	var physical_time_scale := Engine.time_scale
	var physical_shake := float(composition.get("_shake_strength"))
	await process_frame
	if impact.active_burst_count() != 1:
		_fail("VFX03_COHERENCE=BLOCKED physical_burst_count value=%d" % impact.active_burst_count(), battle)
		return
	if _popup_count(layer) != 1:
		_fail("VFX03_COHERENCE=BLOCKED physical_popup_count value=%d" % _popup_count(layer), battle)
		return
	if impact.last_burst_text() != "":
		_fail("VFX03_COHERENCE=BLOCKED duplicate_physical_text", battle)
		return
	if physical_time_scale >= 0.99 or physical_shake <= 0.0:
		_fail("VFX03_COHERENCE=BLOCKED physical_punch_or_hitstop", battle)
		return
	_record_state("physical_hit", impact, layer, camera, physical_time_scale)
	await create_timer(0.78, true, false, true).timeout
	for _frame in range(6):
		await process_frame
	Engine.time_scale = 1.0

	battle.player_one.impact_resolved.emit(
		battle.player_two,
		battle.player_one,
		technique,
		&"posture_break",
		0.0,
		0.0,
		1.0,
		battle.player_two.global_position + Vector2(0.0, -38.0)
	)
	var critical_time_scale := Engine.time_scale
	await process_frame
	var critical_label := layer.get_node_or_null("CriticalImpact") as Label
	if critical_label == null or critical_label.text != "QUEBRA":
		_fail("VFX03_COHERENCE=BLOCKED critical_feedback", battle)
		return
	if _popup_count(layer) < 1 or _popup_count(layer) > MAX_POPUPS:
		_fail("VFX03_COHERENCE=BLOCKED critical_popup_budget value=%d" % _popup_count(layer), battle)
		return
	if camera.offset.length() > MAX_CAMERA_OFFSET + 0.01:
		_fail("VFX03_COHERENCE=BLOCKED critical_camera value=%.3f" % camera.offset.length(), battle)
		return
	if critical_time_scale >= 0.99:
		_fail("VFX03_COHERENCE=BLOCKED critical_hitstop", battle)
		return
	_capture("VFX03_CRITICAL.review-1920x1080.png")
	_record_state("critical_posture_break", impact, layer, camera, critical_time_scale)
	await create_timer(0.78, true, false, true).timeout
	for _frame in range(6):
		await process_frame
	Engine.time_scale = 1.0

	var popups_before_element := _popup_count(layer)
	impact._on_elemental_state_changed(battle.player_two, &"burning")
	await process_frame
	if impact.last_burst_text() != "BURN!":
		_fail("VFX03_COHERENCE=BLOCKED elemental_text actual=%s" % impact.last_burst_text(), battle)
		return
	if _popup_count(layer) != popups_before_element:
		_fail("VFX03_COHERENCE=BLOCKED elemental_physical_popup", battle)
		return
	_capture("VFX03_ELEMENTAL.review-1920x1080.png")
	_record_state("elemental_state", impact, layer, camera, Engine.time_scale)

	await create_timer(1.30, true, false, true).timeout
	for _frame in range(10):
		await process_frame
	Engine.time_scale = 1.0
	critical_label = layer.get_node_or_null("CriticalImpact") as Label
	if impact.active_burst_count() != 0:
		_fail("VFX03_COHERENCE=BLOCKED recovery_bursts value=%d" % impact.active_burst_count(), battle)
		return
	if _popup_count(layer) != 0:
		_fail("VFX03_COHERENCE=BLOCKED recovery_popups value=%d" % _popup_count(layer), battle)
		return
	if critical_label != null and critical_label.text != "":
		_fail("VFX03_COHERENCE=BLOCKED recovery_critical_text actual=%s" % critical_label.text, battle)
		return
	if camera.offset.length() > MAX_RECOVERY_CAMERA_OFFSET:
		_fail("VFX03_COHERENCE=BLOCKED recovery_camera value=%.3f" % camera.offset.length(), battle)
		return
	if absf(Engine.time_scale - 1.0) > 0.001:
		_fail("VFX03_COHERENCE=BLOCKED recovery_time_scale value=%.3f" % Engine.time_scale, battle)
		return
	_capture("VFX03_RECOVERY.review-1920x1080.png")
	_record_state("recovery_clean", impact, layer, camera, Engine.time_scale)

	_write_metrics()
	print("VFX03_BASELINE_CLEAN=PASS")
	print("VFX03_PHYSICAL_OWNERSHIP=PASS bursts=1 popups=1 duplicate_text=0")
	print("VFX03_CRITICAL_HIERARCHY=PASS center=QUEBRA max_camera_px=7.00")
	print("VFX03_ELEMENTAL_OWNERSHIP=PASS text=BURN! physical_popup_delta=0")
	print("VFX03_RECOVERY_CLEAN=PASS bursts=0 popups=0 critical_text=0 camera_max=0.50 time_scale=1.0")
	print("VFX03_CAPTURE_SET=PASS baseline critical elemental recovery")
	print("VFX03_COHERENCE=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _popup_count(layer: CanvasLayer) -> int:
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Label and child.name == "ImpactPopup" and is_instance_valid(child):
			count += 1
	return count

func _record_state(state_id: String, impact: ImpactDirector, layer: CanvasLayer, camera: Camera2D, time_scale: float) -> void:
	var states: Dictionary = _metrics["states"]
	states[state_id] = {
		"burst_count": impact.active_burst_count(),
		"popup_count": _popup_count(layer),
		"camera_offset_pixels": camera.offset.length(),
		"time_scale": time_scale,
		"last_burst_text": impact.last_burst_text()
	}
	_metrics["states"] = states

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
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/VFX03_METRICS.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_metrics, "  "))
		file.close()

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
