extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_BATTLE_WAIT_FRAMES := 420
const WATCHDOG_TEST_FRAMES := 360
const EXPECTED_AI_STATES := [
	"Observe", "Approach", "HoldRange", "Attack",
	"Defend", "Recover", "Reposition", "Punish",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	if not ResourceLoader.exists(BATTLE_SCENE):
		_fail("P0_2_PRODUCT_GATE=BLOCKED battle_scene_missing")
		return
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController
	if battle == null:
		_fail("P0_2_PRODUCT_GATE=BLOCKED battle_instantiate")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)

	if not await _wait_for_battle(battle):
		_fail("P0_2_PRODUCT_GATE=BLOCKED battle_state_timeout")
		return
	for _frame in range(24):
		await process_frame

	if not _validate_runtime_asset_truth(battle):
		return
	if not await _validate_ai_watchdog(battle):
		return

	print("P0_2_RUNTIME_ASSET_TRUTH=PASS source=production_default fallback_visible=false")
	print("P0_2_AI_STATE_MODEL=PASS states=8")
	print("P0_2_AI_INACTIVITY_WATCHDOG=PASS difficulty=apprentice")
	print("P0_2_STRUCTURAL_PRODUCT_GATE=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _validate_runtime_asset_truth(battle: FirstPlayableController) -> bool:
	if not is_instance_valid(battle.player_one):
		_fail("P0_2_PRODUCT_GATE=BLOCKED player_one_missing")
		return false
	var lot01 := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	var modular := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if lot01 == null or not lot01.using_real_assets():
		_fail("P0_2_PRODUCT_GATE=BLOCKED lot01_fail_closed_evidence_missing")
		return false
	if modular == null or not modular.using_modular_assets():
		_fail("P0_2_PRODUCT_GATE=BLOCKED production_modular_runtime_inactive")
		return false
	if lot01.visible:
		_fail("P0_2_PRODUCT_GATE=BLOCKED unintended_lot01_fallback_visible")
		return false
	if modular.active_preset_id() != FirstPlayableSession.PRODUCTION_DEFAULT_PRESET_ID:
		_fail("P0_2_PRODUCT_GATE=BLOCKED production_default_preset_not_authoritative")
		return false
	if FirstPlayableSession.battle_visual_source() != "production_default":
		_fail("P0_2_PRODUCT_GATE=BLOCKED visual_source_not_production_default")
		return false
	var assembler := modular.assembler()
	if assembler == null or not assembler.is_ready_for_render():
		_fail("P0_2_PRODUCT_GATE=BLOCKED modular_assembler_not_render_ready")
		return false
	if assembler.active_skin_palette_id() != &"skin_tone_03_warm":
		_fail("P0_2_PRODUCT_GATE=BLOCKED production_default_skin_mismatch")
		return false
	for slot_name in [&"face", &"eyes", &"brows"]:
		if assembler.active_identity_module_id(slot_name) == &"":
			_fail("P0_2_PRODUCT_GATE=BLOCKED production_identity_slot_missing:%s" % String(slot_name))
			return false
	if not battle.player_one.has_meta("creator_battle_handoff"):
		_fail("P0_2_PRODUCT_GATE=BLOCKED battle_handoff_metadata_missing")
		return false
	var handoff_value = battle.player_one.get_meta("creator_battle_handoff")
	if not (handoff_value is Dictionary):
		_fail("P0_2_PRODUCT_GATE=BLOCKED battle_handoff_metadata_invalid")
		return false
	var handoff := handoff_value as Dictionary
	if not bool(handoff.get("visual_activation", false)):
		_fail("P0_2_PRODUCT_GATE=BLOCKED modular_visual_not_promoted")
		return false
	if String(handoff.get("visual_runtime", "")) != "shared_modular_animation_runtime_v1":
		_fail("P0_2_PRODUCT_GATE=BLOCKED wrong_visual_runtime")
		return false
	if bool(handoff.get("unintended_lot01_fallback_allowed", true)):
		_fail("P0_2_PRODUCT_GATE=BLOCKED fallback_policy_not_fail_closed")
		return false
	return true

func _validate_ai_watchdog(battle: FirstPlayableController) -> bool:
	var tactical := battle.get_node_or_null("TacticalBotRuntime") as TacticalBotRuntime
	var watchdog := battle.get_node_or_null("FirstPlayableAiWatchdogRuntime") as FirstPlayableAiWatchdogRuntime
	if tactical == null or watchdog == null:
		_fail("P0_2_PRODUCT_GATE=BLOCKED ai_runtime_missing")
		return false
	if tactical.difficulty_id != &"apprentice":
		_fail("P0_2_PRODUCT_GATE=BLOCKED apprentice_not_selected")
		return false
	if not is_instance_valid(battle.player_two):
		_fail("P0_2_PRODUCT_GATE=BLOCKED player_two_missing")
		return false

	var player := battle.player_one
	var cpu := battle.player_two
	player.global_position = Vector2(1320.0, 760.0)
	cpu.global_position = Vector2(1415.0, 760.0)
	player.velocity = Vector2.ZERO
	cpu.velocity = Vector2.ZERO
	player.health = player.build.max_health()
	cpu.health = cpu.build.max_health()

	# Deliberately jam the legacy planner's decision clocks. The P0.2 watchdog
	# must recover the CPU without a human-visible multi-second dead zone.
	tactical._decision_timer = 60.0
	tactical._navigation_timer = 60.0
	tactical._route_timer = 60.0
	tactical._reaction_timer = 60.0
	tactical._strategic_target = Vector2.ZERO
	tactical._release_all_actions()

	var limit := watchdog.inactivity_limit_seconds()
	var forced := false
	var offensive_action := false
	for _frame in range(WATCHDOG_TEST_FRAMES):
		await physics_frame
		if battle._state != FirstPlayableController.MatchState.BATTLE:
			_fail("P0_2_PRODUCT_GATE=BLOCKED battle_ended_during_watchdog_probe")
			return false
		var signature := watchdog.runtime_signature()
		forced = int(signature.get("watchdog_forces", 0)) > 0
		offensive_action = (
			cpu._attack_phase != FighterController.AttackPhase.NONE
			or is_instance_valid(cpu._grabbed_target)
		)
		if forced and offensive_action:
			break
	if not forced:
		_fail("P0_2_PRODUCT_GATE=BLOCKED watchdog_did_not_force_transition")
		return false
	if not offensive_action:
		_fail("P0_2_PRODUCT_GATE=BLOCKED watchdog_did_not_restore_offense")
		return false

	var final_signature := watchdog.runtime_signature()
	var states = final_signature.get("required_states", [])
	if not (states is Array) or states != EXPECTED_AI_STATES:
		_fail("P0_2_PRODUCT_GATE=BLOCKED ai_state_contract")
		return false
	if int(final_signature.get("state_count", 0)) != 8:
		_fail("P0_2_PRODUCT_GATE=BLOCKED ai_state_count")
		return false
	if float(final_signature.get("max_combat_inactivity_seconds", 999.0)) > limit + 0.20:
		_fail("P0_2_PRODUCT_GATE=BLOCKED pathological_ai_inactivity max=%.3f limit=%.3f" % [
			float(final_signature.get("max_combat_inactivity_seconds", 999.0)),
			limit,
		])
		return false
	return true

func _wait_for_battle(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_BATTLE_WAIT_FRAMES):
		if battle._state == FirstPlayableController.MatchState.BATTLE:
			return true
		await process_frame
	return false

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(FirstPlayableSession.PRODUCTION_DEFAULT_PRESET_ID)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
