extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-VFX-01")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.86).timeout
	for _frame in range(10):
		await process_frame

	var impact := battle.get_node_or_null("ImpactDirector") as ImpactDirector
	var composition := battle.get_node_or_null("FightCameraComposition") as FirstPlayableCameraComposition
	var feedback := battle.get_node_or_null("FirstPlayableCombatFeedbackRuntime")
	if impact == null or composition == null or feedback == null:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED runtime_nodes impact=%s camera=%s feedback=%s" % [impact != null, composition != null, feedback != null], battle)
		return

	var impact_signature := impact.presentation_signature()
	var camera_signature := composition.presentation_signature()
	var feedback_signature: Dictionary = feedback.call("presentation_signature")
	var impact_stage := String(impact_signature.get("stage", ""))
	if not impact_stage.begins_with("VFX-") or impact_stage.trim_prefix("VFX-").to_int() < 1:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED impact_stage=%s" % impact_stage, battle)
		return
	if bool(impact_signature.get("camera_shake_owner", true)):
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED impact_camera_owner", battle)
		return
	if StringName(impact_signature.get("camera_shake_delegated_to", &"")) != &"FightCameraComposition":
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED camera_delegation", battle)
		return
	if bool(impact_signature.get("physical_impact_text_emitted_here", true)):
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED duplicate_physical_text", battle)
		return
	if StringName(impact_signature.get("physical_impact_text_owner", &"")) != &"FirstPlayableCombatFeedbackRuntime":
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED physical_text_owner", battle)
		return
	if not bool(impact_signature.get("hitstop_owner", false)):
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED hitstop_owner", battle)
		return
	if not bool(camera_signature.get("impact_camera_punch", false)) or not bool(feedback_signature.get("camera_punch_on_impact", false)):
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED delegated_camera_chain", battle)
		return
	if int(feedback_signature.get("popup_budget", 0)) != 2:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED popup_budget", battle)
		return

	var technique := TechniqueCatalog.get_technique(&"ji_body_hook")
	if technique == null:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED technique", battle)
		return

	var p1_health := battle.player_one.health
	var p1_posture := battle.player_one.posture
	var p2_health := battle.player_two.health
	var p2_posture := battle.player_two.posture
	var bursts_before := impact.active_burst_count()

	battle.player_one.impact_resolved.emit(
		battle.player_two,
		battle.player_one,
		technique,
		&"evaded",
		0.0,
		0.0,
		0.64,
		battle.player_two.global_position
	)
	if impact.active_burst_count() != bursts_before + 1:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED world_burst", battle)
		return
	if impact.last_burst_text() != "":
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED impact_text=%s" % impact.last_burst_text(), battle)
		return
	var shake_strength := float(composition.get("_shake_strength"))
	if shake_strength <= 0.0:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED camera_punch_not_delegated", battle)
		return
	var layer := feedback.get_node_or_null("CombatFeedbackLayer") as CanvasLayer
	if layer == null or not _layer_has_text(layer, "ESQUIVA"):
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED feedback_text_evade", battle)
		return

	Engine.time_scale = 1.0
	battle.player_one.impact_resolved.emit(
		battle.player_two,
		battle.player_one,
		technique,
		&"hit",
		0.0,
		0.0,
		0.80,
		battle.player_two.global_position
	)
	if impact.last_burst_text() != "":
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED normal_hit_duplicate_text", battle)
		return
	var technique_label := String(technique.display_name).to_upper()
	if not _layer_has_text(layer, technique_label):
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED technique_popup=%s" % technique_label, battle)
		return
	if Engine.time_scale >= 0.99:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED hitstop_missing scale=%.3f" % Engine.time_scale, battle)
		return
	await create_timer(0.16, true, false, true).timeout
	if absf(Engine.time_scale - 1.0) > 0.001:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED hitstop_restore scale=%.3f" % Engine.time_scale, battle)
		return

	impact._on_elemental_state_changed(battle.player_one, &"burning")
	if impact.last_burst_text() != "BURN!":
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED elemental_text=%s" % impact.last_burst_text(), battle)
		return

	var gameplay_unchanged := (
		is_equal_approx(battle.player_one.health, p1_health)
		and is_equal_approx(battle.player_one.posture, p1_posture)
		and is_equal_approx(battle.player_two.health, p2_health)
		and is_equal_approx(battle.player_two.posture, p2_posture)
	)
	if not gameplay_unchanged:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED gameplay_mutation", battle)
		return

	var popup_count := _impact_popup_count(layer)
	if popup_count > 2:
		_fail("VFX01_PRESENTATION_OWNER=BLOCKED popup_over_budget=%d" % popup_count, battle)
		return

	print("VFX01_CAMERA_OWNER=PASS owner=FightCameraComposition")
	print("VFX01_PHYSICAL_TEXT_OWNER=PASS owner=FirstPlayableCombatFeedbackRuntime")
	print("VFX01_IMPACT_WORLD_SHAPES=PASS")
	print("VFX01_ELEMENT_TEXT=PASS value=BURN!")
	print("VFX01_HITSTOP_OWNER=PASS owner=ImpactDirector")
	print("VFX01_POPUP_BUDGET=PASS max=2 active=%d" % popup_count)
	print("VFX01_ZERO_GAMEPLAY_MUTATION=PASS")
	print("VFX01_PRESENTATION_OWNER=PASS stage=%s" % impact_stage)
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _layer_has_text(layer: CanvasLayer, expected: String) -> bool:
	for child in layer.get_children():
		if child is Label and (child as Label).text == expected:
			return true
	return false

func _impact_popup_count(layer: CanvasLayer) -> int:
	var count := 0
	for child in layer.get_children():
		if child is Label and child.name == "ImpactPopup" and is_instance_valid(child):
			count += 1
	return count

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
