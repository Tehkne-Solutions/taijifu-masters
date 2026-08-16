extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 420
const EXPECTED_STATES := ["block_recoil", "parry", "posture_break", "knockback", "neutral_recovery"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	if not ResourceLoader.exists(BATTLE_SCENE):
		_fail("PACK04_RUNTIME_GATE=BLOCKED battle_scene_missing")
		return
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("PACK04_RUNTIME_GATE=BLOCKED battle_instantiate")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 30.0
	root.add_child(battle)

	var fighters_ready := await _wait_for_fighters_and_runtimes(battle)
	if not fighters_ready:
		_fail("PACK04_RUNTIME_GATE=BLOCKED runtime_activation_timeout", battle)
		return

	battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	var p1 := battle.player_one as FirstPlayableCombatFighterController
	var p2 := battle.player_two as FirstPlayableCombatFighterController
	var p1_runtime := p1.pack04_reaction_runtime()
	var p2_runtime := p2.pack04_reaction_runtime()
	if p1_runtime == null or p2_runtime == null:
		_fail("PACK04_RUNTIME_GATE=BLOCKED runtime_missing", battle)
		return

	if not _validate_static_contract(p1_runtime, "p1"):
		_fail("PACK04_RUNTIME_GATE=BLOCKED p1_contract", battle)
		return
	if not _validate_static_contract(p2_runtime, "p2"):
		_fail("PACK04_RUNTIME_GATE=BLOCKED p2_contract", battle)
		return

	# Prove the production signal is the observation source: no combat decision is
	# recomputed by PACK 04. Emit an already-resolved blocked outcome and verify
	# canonical semantic state + existing-art fallback metadata.
	var technique := TechniqueCatalog.get_technique(&"ji_body_hook")
	if technique == null:
		_fail("PACK04_RUNTIME_GATE=BLOCKED technique_missing", battle)
		return
	p1.impact_resolved.emit(
		p1,
		p2,
		technique,
		&"blocked",
		0.0,
		0.0,
		0.5,
		p1.global_position
	)
	await process_frame
	if p1_runtime.semantic_state() != &"block_recoil":
		_fail("PACK04_RUNTIME_GATE=BLOCKED blocked_semantic:%s" % String(p1_runtime.semantic_state()), battle)
		return
	if p1_runtime.visual_override() != &"guard" or not p1_runtime.fallback_active():
		_fail("PACK04_RUNTIME_GATE=BLOCKED blocked_fallback", battle)
		return
	if String(p1.get_meta(FirstPlayablePack04ReactionRuntime.META_SEMANTIC_STATE, "")) != "block_recoil":
		_fail("PACK04_RUNTIME_GATE=BLOCKED blocked_metadata", battle)
		return

	# Probe remaining canonical mappings deterministically. These calls do not
	# mutate fighter physics; they exercise the same state sequencer used by the
	# signal callback above.
	p1_runtime.call("_begin_result", &"parried")
	if p1_runtime.semantic_state() != &"parry" or p1_runtime.visual_override() != &"guard" or not p1_runtime.fallback_active():
		_fail("PACK04_RUNTIME_GATE=BLOCKED parry_mapping", battle)
		return

	p1_runtime.call("_begin_result", &"posture_break")
	if p1_runtime.semantic_state() != &"posture_break" or p1_runtime.visual_override() != &"hit" or not p1_runtime.fallback_active():
		_fail("PACK04_RUNTIME_GATE=BLOCKED posture_break_mapping", battle)
		return

	p1_runtime.call("_begin_result", &"hit")
	var hit_signature := p1_runtime.runtime_signature()
	if p1_runtime.semantic_state() != &"" or p1_runtime.visual_override() != &"hit" or p1_runtime.fallback_active():
		_fail("PACK04_RUNTIME_GATE=BLOCKED existing_hit_authority", battle)
		return
	if String(hit_signature.get("visual_source", "")) != "existing_approved_state":
		_fail("PACK04_RUNTIME_GATE=BLOCKED existing_hit_source", battle)
		return

	await create_timer(0.20, true, false, true).timeout
	for _frame in range(2):
		await process_frame
	if p1_runtime.semantic_state() != &"knockback" or p1_runtime.visual_override() != &"hit" or not p1_runtime.fallback_active():
		_fail("PACK04_RUNTIME_GATE=BLOCKED hit_to_knockback", battle)
		return

	await create_timer(0.15, true, false, true).timeout
	for _frame in range(2):
		await process_frame
	if p1_runtime.semantic_state() != &"neutral_recovery" or p1_runtime.visual_override() != &"idle" or not p1_runtime.fallback_active():
		_fail("PACK04_RUNTIME_GATE=BLOCKED knockback_to_neutral", battle)
		return

	var reaction_signature := p1.first_playable_reaction_signature()
	if bool(reaction_signature.get("pack04_art_available", true)):
		_fail("PACK04_RUNTIME_GATE=BLOCKED false_art_availability", battle)
		return
	if not bool(reaction_signature.get("pack04_fallback_observable", false)):
		_fail("PACK04_RUNTIME_GATE=BLOCKED fallback_not_observable", battle)
		return

	print("PACK04_RUNTIME_DUAL_FIGHTER=PASS p1=true p2=true")
	print("PACK04_RUNTIME_STATES=PASS states=block_recoil,parry,posture_break,knockback,neutral_recovery")
	print("PACK04_RUNTIME_SIGNAL_OBSERVER=PASS result=blocked semantic=block_recoil")
	print("PACK04_RUNTIME_SEQUENCE=PASS hit=existing_hit>knockback>neutral_recovery")
	print("PACK04_RUNTIME_FALLBACKS=PASS block_recoil=guard parry=guard posture_break=hit knockback=hit neutral_recovery=idle")
	print("PACK04_RUNTIME_ART_STATUS=BLOCKED release=assets-pack-04-v1.0.0")
	print("PACK04_RUNTIME_PHYSICS_AUTHORITY=PASS owner=fighter_physics changes=false")
	print("PACK04_RUNTIME_CONTRACT_GATE=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _validate_static_contract(runtime: FirstPlayablePack04ReactionRuntime, label: String) -> bool:
	var signature := runtime.runtime_signature()
	if String(signature.get("pack_id", "")) != "PACK_04_COMBAT_REACTIONS_AND_MOTION":
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_pack_id" % label)
		return false
	if String(signature.get("expected_release_tag", "")) != "assets-pack-04-v1.0.0":
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_release" % label)
		return false
	if bool(signature.get("pack04_art_available", true)):
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_false_art" % label)
		return false
	if String(signature.get("pack04_art_status", "")) != "blocked_release_not_materialized":
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_art_status" % label)
		return false
	if int(signature.get("required_state_count", 0)) != 5:
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_state_count" % label)
		return false
	var states_variant: Variant = signature.get("required_states", [])
	if not (states_variant is Array):
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_states_type" % label)
		return false
	var states: Array = states_variant as Array
	for state in EXPECTED_STATES:
		if not states.has(state) and not states.has(StringName(state)):
			push_error("PACK04_RUNTIME_GATE=BLOCKED %s_state_missing:%s" % [label, state])
			return false
	var sequences_variant: Variant = signature.get("result_sequences", {})
	var fallbacks_variant: Variant = signature.get("fallback_visuals", {})
	if not (sequences_variant is Dictionary) or not (fallbacks_variant is Dictionary):
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_maps" % label)
		return false
	var sequences := sequences_variant as Dictionary
	var fallbacks := fallbacks_variant as Dictionary
	if sequences.get("blocked", []) != ["block_recoil", "neutral_recovery"]:
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_block_sequence" % label)
		return false
	if sequences.get("parried", []) != ["parry", "neutral_recovery"]:
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_parry_sequence" % label)
		return false
	if sequences.get("posture_break", []) != ["posture_break", "knockback", "neutral_recovery"]:
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_posture_sequence" % label)
		return false
	if fallbacks.get("block_recoil", "") != "guard" or fallbacks.get("parry", "") != "guard":
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_guard_fallbacks" % label)
		return false
	if fallbacks.get("posture_break", "") != "hit" or fallbacks.get("knockback", "") != "hit":
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_hit_fallbacks" % label)
		return false
	if fallbacks.get("neutral_recovery", "") != "idle":
		push_error("PACK04_RUNTIME_GATE=BLOCKED %s_neutral_fallback" % label)
		return false
	for invariant in ["physics_changes", "damage_changes", "frame_data_changes", "collision_changes", "ai_changes"]:
		if bool(signature.get(invariant, true)):
			push_error("PACK04_RUNTIME_GATE=BLOCKED %s_invariant:%s" % [label, invariant])
			return false
	return true

func _wait_for_fighters_and_runtimes(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if battle.player_one is FirstPlayableCombatFighterController and battle.player_two is FirstPlayableCombatFighterController:
			var p1 := battle.player_one as FirstPlayableCombatFighterController
			var p2 := battle.player_two as FirstPlayableCombatFighterController
			if p1.pack04_reaction_runtime() != null and p2.pack04_reaction_runtime() != null:
				return true
		await process_frame
	return false

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
