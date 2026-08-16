extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 480

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	if not ResourceLoader.exists(BATTLE_SCENE):
		_fail("PACK04_PRESENTER_GATE=BLOCKED battle_scene_missing")
		return
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("PACK04_PRESENTER_GATE=BLOCKED battle_instantiate")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 30.0
	root.add_child(battle)

	var context := await _wait_for_presenters(battle)
	if context.is_empty():
		_fail("PACK04_PRESENTER_GATE=BLOCKED presenter_activation_timeout", battle)
		return

	battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	var p1_runtime := context["p1_runtime"] as FirstPlayablePack04ReactionRuntime
	var p2_runtime := context["p2_runtime"] as FirstPlayablePack04ReactionRuntime
	var p1_presenter := context["p1_presenter"] as FirstPlayableSkeletalModularFighterPresenter
	var p2_presenter := context["p2_presenter"] as TrainingRivalLot01Presenter
	var pose_runtime := context["pose_runtime"] as FirstPlayableModularPoseRuntime

	if not _validate_handoff_contract(p1_presenter, p2_presenter):
		_fail("PACK04_PRESENTER_GATE=BLOCKED contract", battle)
		return

	# The PACK 04 reaction windows are intentionally short (0.14–0.20 s). A
	# headless runner may deliver a large frame delta, so semantic assertions are
	# made synchronously after entering a step. Presenters and the pose bridge are
	# then ticked manually with delta=0 to validate the production handoff without
	# making the gate dependent on host frame time.

	# BLOCK: semantic PACK 04 state must deliberately select existing GUARD art.
	p1_runtime.call("_begin_result", &"blocked")
	p2_runtime.call("_begin_result", &"blocked")
	if p1_runtime.semantic_state() != &"block_recoil" or p2_runtime.semantic_state() != &"block_recoil":
		_fail("PACK04_PRESENTER_GATE=BLOCKED block_semantic", battle)
		return
	_tick_presenters(p1_presenter, p2_presenter, pose_runtime)
	if p1_presenter.visual_state() != &"guard" or p2_presenter.active_animation() != &"guard":
		_fail("PACK04_PRESENTER_GATE=BLOCKED block_visual p1=%s p2=%s" % [
			String(p1_presenter.visual_state()),
			String(p2_presenter.active_animation()),
		], battle)
		return
	var block_pose_signature := pose_runtime.runtime_signature()
	if String(block_pose_signature.get("visual_state", "")) != "guard":
		_fail("PACK04_PRESENTER_GATE=BLOCKED block_skeleton:%s" % String(block_pose_signature.get("visual_state", "")), battle)
		return

	# PARRY intentionally shares approved GUARD art until PACK 04 authored frames exist.
	p1_runtime.call("_begin_result", &"parried")
	p2_runtime.call("_begin_result", &"parried")
	if p1_runtime.semantic_state() != &"parry" or p2_runtime.semantic_state() != &"parry":
		_fail("PACK04_PRESENTER_GATE=BLOCKED parry_semantic", battle)
		return
	_tick_presenters(p1_presenter, p2_presenter, pose_runtime)
	if p1_presenter.visual_state() != &"guard" or p2_presenter.active_animation() != &"guard":
		_fail("PACK04_PRESENTER_GATE=BLOCKED parry_visual", battle)
		return

	# POSTURE BREAK intentionally shares existing HIT art; physics remains separate.
	p1_runtime.call("_begin_result", &"posture_break")
	p2_runtime.call("_begin_result", &"posture_break")
	if p1_runtime.semantic_state() != &"posture_break" or p2_runtime.semantic_state() != &"posture_break":
		_fail("PACK04_PRESENTER_GATE=BLOCKED posture_semantic", battle)
		return
	_tick_presenters(p1_presenter, p2_presenter, pose_runtime)
	if p1_presenter.visual_state() != &"hit" or p2_presenter.active_animation() != &"hit":
		_fail("PACK04_PRESENTER_GATE=BLOCKED posture_visual p1=%s p2=%s" % [
			String(p1_presenter.visual_state()),
			String(p2_presenter.active_animation()),
		], battle)
		return
	var posture_pose_signature := pose_runtime.runtime_signature()
	if String(posture_pose_signature.get("visual_state", "")) != "hit":
		_fail("PACK04_PRESENTER_GATE=BLOCKED posture_skeleton", battle)
		return

	# KNOCKBACK is the second posture-break step and still uses approved HIT art.
	p1_runtime.call("_advance_step")
	p2_runtime.call("_advance_step")
	if p1_runtime.semantic_state() != &"knockback" or p2_runtime.semantic_state() != &"knockback":
		_fail("PACK04_PRESENTER_GATE=BLOCKED knockback_semantic", battle)
		return
	_tick_presenters(p1_presenter, p2_presenter, pose_runtime)
	if p1_presenter.visual_state() != &"hit" or p2_presenter.active_animation() != &"hit":
		_fail("PACK04_PRESENTER_GATE=BLOCKED knockback_visual", battle)
		return

	# NEUTRAL RECOVERY is the final posture-break step and explicitly uses IDLE.
	p1_runtime.call("_advance_step")
	p2_runtime.call("_advance_step")
	if p1_runtime.semantic_state() != &"neutral_recovery" or p2_runtime.semantic_state() != &"neutral_recovery":
		_fail("PACK04_PRESENTER_GATE=BLOCKED neutral_semantic", battle)
		return
	_tick_presenters(p1_presenter, p2_presenter, pose_runtime)
	if p1_presenter.visual_state() != &"idle" or p2_presenter.active_animation() != &"idle":
		_fail("PACK04_PRESENTER_GATE=BLOCKED neutral_visual p1=%s p2=%s" % [
			String(p1_presenter.visual_state()),
			String(p2_presenter.active_animation()),
		], battle)
		return
	var neutral_pose_signature := pose_runtime.runtime_signature()
	if String(neutral_pose_signature.get("visual_state", "")) != "idle":
		_fail("PACK04_PRESENTER_GATE=BLOCKED neutral_skeleton", battle)
		return

	var p1_signature := p1_presenter.runtime_signature()
	var p2_signature := p2_presenter.pack04_handoff_signature()
	if bool(p1_signature.get("pack04_art_available", true)) or bool(p2_signature.get("pack04_art_available", true)):
		_fail("PACK04_PRESENTER_GATE=BLOCKED false_art_availability", battle)
		return
	if String(p1_signature.get("pack04_art_status", "")) != "blocked_release_not_materialized":
		_fail("PACK04_PRESENTER_GATE=BLOCKED p1_art_status", battle)
		return
	if String(p2_signature.get("pack04_art_status", "")) != "blocked_release_not_materialized":
		_fail("PACK04_PRESENTER_GATE=BLOCKED p2_art_status", battle)
		return
	if String(p1_signature.get("pack04_gameplay_owner", "")) != "fighter_physics":
		_fail("PACK04_PRESENTER_GATE=BLOCKED p1_gameplay_owner", battle)
		return
	if String(p2_signature.get("gameplay_owner", "")) != "fighter_physics":
		_fail("PACK04_PRESENTER_GATE=BLOCKED p2_gameplay_owner", battle)
		return

	print("PACK04_PRESENTER_HANDOFF=PASS p1=skeletal_modular p2=training_rival")
	print("PACK04_PRESENTER_BLOCK=PASS p1=guard p2=guard")
	print("PACK04_PRESENTER_PARRY=PASS p1=guard p2=guard")
	print("PACK04_PRESENTER_POSTURE=PASS p1=hit p2=hit")
	print("PACK04_PRESENTER_KNOCKBACK=PASS p1=hit p2=hit")
	print("PACK04_PRESENTER_NEUTRAL=PASS p1=idle p2=idle")
	print("PACK04_SKELETON_HANDOFF=PASS states=guard,hit,idle authored_library_preserved=true")
	print("PACK04_PRESENTER_ART_STATUS=BLOCKED release=assets-pack-04-v1.0.0")
	print("PACK04_PRESENTER_GAMEPLAY_AUTHORITY=PASS owner=fighter_physics changes=false")
	print("PACK04_PRESENTER_HANDOFF_GATE=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _tick_presenters(
	p1_presenter: FirstPlayableSkeletalModularFighterPresenter,
	p2_presenter: TrainingRivalLot01Presenter,
	pose_runtime: FirstPlayableModularPoseRuntime
) -> void:
	# Manual zero-delta ticks preserve the exact production execution order:
	# presenter state first, Skeleton2D bridge after (process_priority=100).
	p1_presenter.call("_process", 0.0)
	p2_presenter.call("_process", 0.0)
	pose_runtime.call("_process", 0.0)

func _validate_handoff_contract(
	p1_presenter: FirstPlayableSkeletalModularFighterPresenter,
	p2_presenter: TrainingRivalLot01Presenter
) -> bool:
	var p1_signature := p1_presenter.runtime_signature()
	var p2_signature := p2_presenter.pack04_handoff_signature()
	if not bool(p1_signature.get("pack04_reaction_handoff", false)):
		push_error("PACK04_PRESENTER_GATE=BLOCKED p1_handoff_inactive")
		return false
	if not bool(p2_signature.get("active", false)):
		push_error("PACK04_PRESENTER_GATE=BLOCKED p2_handoff_inactive")
		return false
	if bool(p1_signature.get("pack04_art_available", true)):
		push_error("PACK04_PRESENTER_GATE=BLOCKED p1_false_art")
		return false
	if bool(p2_signature.get("pack04_art_available", true)):
		push_error("PACK04_PRESENTER_GATE=BLOCKED p2_false_art")
		return false
	if bool(p1_signature.get("collision_changes", true)):
		push_error("PACK04_PRESENTER_GATE=BLOCKED p1_collision_changes")
		return false
	if bool(p2_signature.get("collision_changes", true)) or bool(p2_signature.get("combat_logic_changes", true)):
		push_error("PACK04_PRESENTER_GATE=BLOCKED p2_gameplay_changes")
		return false
	return true

func _wait_for_presenters(battle: FirstPlayableController) -> Dictionary:
	for _frame in range(MAX_WAIT_FRAMES):
		if battle.player_one is FirstPlayableCombatFighterController and battle.player_two is FirstPlayableCombatFighterController:
			var p1 := battle.player_one as FirstPlayableCombatFighterController
			var p2 := battle.player_two as FirstPlayableCombatFighterController
			var p1_runtime := p1.pack04_reaction_runtime()
			var p2_runtime := p2.pack04_reaction_runtime()
			var p1_presenter := p1.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableSkeletalModularFighterPresenter
			var p2_presenter := p2.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
			var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
			if (
				p1_runtime != null
				and p2_runtime != null
				and p1_presenter != null
				and p1_presenter.using_modular_assets()
				and p2_presenter != null
				and p2_presenter.using_real_assets()
				and pose_runtime != null
				and pose_runtime.active()
				and pose_runtime.authority_active()
			):
				return {
					"p1_runtime": p1_runtime,
					"p2_runtime": p2_runtime,
					"p1_presenter": p1_presenter,
					"p2_presenter": p2_presenter,
					"pose_runtime": pose_runtime,
				}
		await process_frame
	return {}

func _fail(marker: String, battle: FirstPlayableController = null) -> void:
	push_error(marker)
	print(marker)
	print("SIGNATURE=Tehkné Solutions")
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
