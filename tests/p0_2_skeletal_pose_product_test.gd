extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 420
const EXPECTED_BONE_COUNT := 11
const MIN_VISUAL_MODULES := 4

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	if not ResourceLoader.exists(BATTLE_SCENE):
		_fail("P0_2_SKELETAL_GATE=BLOCKED battle_scene_missing")
		return
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as FirstPlayableController
	if battle == null:
		_fail("P0_2_SKELETAL_GATE=BLOCKED battle_instantiate")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)

	var runtime := await _wait_for_runtime(battle)
	if runtime == null:
		_fail("P0_2_SKELETAL_GATE=BLOCKED runtime_activation_timeout")
		return
	for _frame in range(4):
		await process_frame

	if not runtime.active() or not runtime.authority_active():
		_fail("P0_2_SKELETAL_GATE=BLOCKED skeletal_authority_inactive")
		return
	if not is_instance_valid(battle.player_one):
		_fail("P0_2_SKELETAL_GATE=BLOCKED player_one_missing")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("P0_2_SKELETAL_GATE=BLOCKED modular_presenter_missing")
		return
	var presenter_signature := presenter.runtime_signature()
	if not bool(presenter_signature.get("skeletal_authority_aware", false)):
		_fail("P0_2_SKELETAL_GATE=BLOCKED presenter_not_skeletal_aware")
		return
	if bool(presenter_signature.get("whole_assembler_combat_pose", true)):
		_fail("P0_2_SKELETAL_GATE=BLOCKED whole_assembler_pose_regression")
		return

	var assembler := presenter.assembler()
	if assembler == null:
		_fail("P0_2_SKELETAL_GATE=BLOCKED assembler_missing")
		return
	if assembler.position.length() > 0.01 or absf(assembler.rotation) > 0.001 or absf(assembler.skew) > 0.001:
		_fail("P0_2_SKELETAL_GATE=BLOCKED root_affine_not_neutral position=%s rotation=%.5f skew=%.5f" % [
			str(assembler.position), assembler.rotation, assembler.skew,
		])
		return
	if absf(absf(assembler.scale.x) - assembler.scale.y) > 0.001:
		_fail("P0_2_SKELETAL_GATE=BLOCKED root_nonuniform_scale scale=%s" % str(assembler.scale))
		return

	var rig := runtime.pose_rig()
	if rig == null or not rig.configured():
		_fail("P0_2_SKELETAL_GATE=BLOCKED pose_rig_missing")
		return
	if rig.bone_count() != EXPECTED_BONE_COUNT:
		_fail("P0_2_SKELETAL_GATE=BLOCKED bone_count:%d" % rig.bone_count())
		return
	var visual_module_count := _visual_sprite_module_count(assembler)
	if visual_module_count < MIN_VISUAL_MODULES:
		_fail("P0_2_SKELETAL_GATE=BLOCKED visual_modules:%d" % visual_module_count)
		return
	if rig.mesh_layer_count() != visual_module_count:
		_fail("P0_2_SKELETAL_GATE=BLOCKED mesh_module_parity meshes=%d modules=%d" % [
			rig.mesh_layer_count(), visual_module_count,
		])
		return
	var rig_signature := rig.runtime_signature()
	if String(rig_signature.get("skeleton_type", "")) != "Skeleton2D":
		_fail("P0_2_SKELETAL_GATE=BLOCKED skeleton_type")
		return
	if String(rig_signature.get("mesh_type", "")) != "Polygon2D":
		_fail("P0_2_SKELETAL_GATE=BLOCKED mesh_type")
		return
	if not bool(rig_signature.get("shared_layer_deformation", false)):
		_fail("P0_2_SKELETAL_GATE=BLOCKED shared_deformation_false")
		return
	if bool(rig_signature.get("authored_animation", true)):
		_fail("P0_2_SKELETAL_GATE=BLOCKED authored_claim_regression")
		return

	# Probe the three combat phases synchronously. With no TechniqueData supplied,
	# the rig intentionally samples each phase at its midpoint, which is enough to
	# prove regionally distinct deformation without mutating combat timing.
	rig.apply_pose(&"attack_light", 0.0, FighterController.AttackPhase.STARTUP, 0.0, null)
	var anticipation := runtime.deformation_signature()
	rig.apply_pose(&"attack_light", 0.0, FighterController.AttackPhase.ACTIVE, 0.0, null)
	var contact := runtime.deformation_signature()
	rig.apply_pose(&"attack_light", 0.0, FighterController.AttackPhase.RECOVERY, 0.0, null)
	var recovery := runtime.deformation_signature()

	if String(anticipation.get("attack_pose_phase", "")) != "anticipation":
		_fail("P0_2_SKELETAL_GATE=BLOCKED anticipation_phase")
		return
	if String(contact.get("attack_pose_phase", "")) != "contact":
		_fail("P0_2_SKELETAL_GATE=BLOCKED contact_phase")
		return
	if String(recovery.get("attack_pose_phase", "")) != "recovery":
		_fail("P0_2_SKELETAL_GATE=BLOCKED recovery_phase")
		return

	var startup_torso := _bone_rotation(anticipation, "torso")
	var contact_torso := _bone_rotation(contact, "torso")
	var recovery_torso := _bone_rotation(recovery, "torso")
	var startup_forearm := _bone_rotation(anticipation, "forearm_r")
	var contact_forearm := _bone_rotation(contact, "forearm_r")
	if not (startup_torso < -0.01 and contact_torso > 0.05 and recovery_torso > 0.01 and recovery_torso < contact_torso):
		_fail("P0_2_SKELETAL_GATE=BLOCKED torso_phase_separation startup=%.4f contact=%.4f recovery=%.4f" % [
			startup_torso, contact_torso, recovery_torso,
		])
		return
	if contact_forearm <= startup_forearm + 0.20:
		_fail("P0_2_SKELETAL_GATE=BLOCKED forearm_contact_not_distinct startup=%.4f contact=%.4f" % [
			startup_forearm, contact_forearm,
		])
		return
	if int(contact.get("observed_bone_count", 0)) < 7:
		_fail("P0_2_SKELETAL_GATE=BLOCKED deformation_observability")
		return

	print("P0_2_SKELETAL_AUTHORITY=PASS presenter_bypass=true root_affine=false")
	print("P0_2_SKELETAL_LAYER_PARITY=PASS modules=%d meshes=%d" % [visual_module_count, rig.mesh_layer_count()])
	print("P0_2_SKELETAL_DEFORMATION=PASS phases=anticipation,contact,recovery bones=%d meshes=%d" % [
		rig.bone_count(), rig.mesh_layer_count(),
	])
	print("P0_2_SKELETAL_PRODUCT_GATE=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_runtime(battle: FirstPlayableController) -> FirstPlayableModularPoseRuntime:
	for _frame in range(MAX_WAIT_FRAMES):
		var runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
		if runtime != null and runtime.active():
			return runtime
		await process_frame
	return null

func _visual_sprite_module_count(assembler: ModularFighterAssembler) -> int:
	var count := 0
	for child in assembler.get_children():
		if child is Sprite2D and String(child.name).begins_with("Module_"):
			count += 1
	return count

func _bone_rotation(signature: Dictionary, bone_name: String) -> float:
	var bones = signature.get("bones", {})
	if not (bones is Dictionary):
		return 0.0
	var sample = (bones as Dictionary).get(bone_name, {})
	if not (sample is Dictionary):
		return 0.0
	return float((sample as Dictionary).get("rotation", 0.0))

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(FirstPlayableSession.PRODUCTION_DEFAULT_PRESET_ID)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions