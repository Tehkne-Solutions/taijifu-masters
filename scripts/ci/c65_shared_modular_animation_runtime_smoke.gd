extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"c65_shared_animation_probe"
const EXPECTED_STATES := [
	"idle", "run", "jump_start", "airborne", "fall",
	"attack_light", "guard", "dodge", "hit", "ko",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-001")

	if not ResourceLoader.exists(CREATOR_SCENE) or not ResourceLoader.exists(BATTLE_SCENE):
		_fail("C65_SHARED_RUNTIME=BLOCKED scene_missing")
		return

	var creator := (load(CREATOR_SCENE) as PackedScene).instantiate() as ModularFighterCreatorScene
	if creator == null:
		_fail("C65_SHARED_RUNTIME=BLOCKED creator_instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(4):
		await process_frame

	creator.set_display_name("C65 MASTER")
	creator.set_preset_id(String(TEST_PRESET))
	var failures := PackedStringArray()
	failures.append_array(creator.set_identity(&"skin", &"skin_tone_07_deep"))
	failures.append_array(creator.set_identity(&"face", &"face_04_broad"))
	failures.append_array(creator.set_identity(&"eyes", &"eyes_03_fierce"))
	failures.append_array(creator.set_identity(&"brows", &"brows_06_sharp"))
	if not failures.is_empty():
		_fail("C65_SHARED_RUNTIME=BLOCKED creator_identity:%s" % ",".join(failures))
		return
	failures = creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C65_SHARED_RUNTIME=BLOCKED creator_save:%s" % ",".join(failures))
		return

	var prebattle := FirstPlayableSession.creator_battle_handoff_signature()
	if not bool(prebattle.get("preset_selected", false)):
		_fail("C65_SHARED_RUNTIME=BLOCKED preset_not_selected")
		return
	if bool(prebattle.get("visual_activation", true)):
		_fail("C65_SHARED_RUNTIME=BLOCKED premature_session_visual_activation")
		return
	if String(prebattle.get("visual_blocker", "")) != FirstPlayableSession.CREATOR_VISUAL_BLOCKER:
		_fail("C65_SHARED_RUNTIME=BLOCKED prebattle_blocker")
		return

	creator.queue_free()
	await process_frame

	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as FirstPlayableController
	if battle == null:
		_fail("C65_SHARED_RUNTIME=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(20):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C65_SHARED_RUNTIME=BLOCKED player_one_missing")
		return
	if String(battle.player_one.build.character_id) != "lian_wu":
		_fail("C65_SHARED_RUNTIME=BLOCKED combat_build_changed")
		return

	var lian := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	if lian == null or not lian.using_real_assets():
		_fail("C65_SHARED_RUNTIME=BLOCKED lian_fallback_unavailable")
		return
	var modular := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if modular == null or not modular.using_modular_assets():
		_fail("C65_SHARED_RUNTIME=BLOCKED modular_presenter_inactive")
		return
	if modular.active_preset_id() != TEST_PRESET:
		_fail("C65_SHARED_RUNTIME=BLOCKED preset_mismatch")
		return
	if lian.visible:
		_fail("C65_SHARED_RUNTIME=BLOCKED lian_fallback_not_hidden")
		return

	var assembler := modular.assembler()
	if assembler == null or not assembler.is_ready_for_render():
		_fail("C65_SHARED_RUNTIME=BLOCKED assembler_missing")
		return
	if assembler.active_skin_palette_id() != &"skin_tone_07_deep":
		_fail("C65_SHARED_RUNTIME=BLOCKED skin_mismatch")
		return
	if assembler.active_identity_module_id(&"face") != &"face_04_broad":
		_fail("C65_SHARED_RUNTIME=BLOCKED face_mismatch")
		return
	if assembler.active_identity_module_id(&"eyes") != &"eyes_03_fierce":
		_fail("C65_SHARED_RUNTIME=BLOCKED eyes_mismatch")
		return
	if assembler.active_identity_module_id(&"brows") != &"brows_06_sharp":
		_fail("C65_SHARED_RUNTIME=BLOCKED brows_mismatch")
		return
	if assembler.active_identity_module_id(&"face_plate") != &"neutral_face_plate_v1":
		_fail("C65_SHARED_RUNTIME=BLOCKED face_plate_policy")
		return
	for node_name in ["Module_body_base", "Module_face_plate", "Module_face", "Module_eyes", "Module_brows"]:
		if assembler.get_node_or_null(node_name) == null:
			_fail("C65_SHARED_RUNTIME=BLOCKED module_node_missing:%s" % node_name)
			return

	var signature := modular.runtime_signature()
	if String(signature.get("runtime", "")) != "shared_modular_animation_runtime_v1":
		_fail("C65_SHARED_RUNTIME=BLOCKED runtime_id")
		return
	if int(signature.get("state_count", 0)) != 10:
		_fail("C65_SHARED_RUNTIME=BLOCKED state_count")
		return
	var states = signature.get("states", [])
	if not (states is Array) or states != EXPECTED_STATES:
		_fail("C65_SHARED_RUNTIME=BLOCKED state_contract")
		return
	if bool(signature.get("preset_specific_sprite_sheet", true)):
		_fail("C65_SHARED_RUNTIME=BLOCKED preset_sprite_sheet_regression")
		return

	if not battle.player_one.has_meta("creator_battle_handoff"):
		_fail("C65_SHARED_RUNTIME=BLOCKED handoff_metadata_missing")
		return
	var handoff_value = battle.player_one.get_meta("creator_battle_handoff")
	if not (handoff_value is Dictionary):
		_fail("C65_SHARED_RUNTIME=BLOCKED handoff_metadata_invalid")
		return
	var handoff := handoff_value as Dictionary
	if not bool(handoff.get("visual_activation", false)):
		_fail("C65_SHARED_RUNTIME=BLOCKED visual_activation_not_promoted")
		return
	if not String(handoff.get("visual_blocker", "blocked")).is_empty():
		_fail("C65_SHARED_RUNTIME=BLOCKED visual_blocker_not_cleared")
		return
	if String(handoff.get("visual_runtime", "")) != "shared_modular_animation_runtime_v1":
		_fail("C65_SHARED_RUNTIME=BLOCKED handoff_runtime")
		return
	if bool(handoff.get("static_sprite_regression_allowed", true)):
		_fail("C65_SHARED_RUNTIME=BLOCKED static_sprite_regression")
		return

	print("C65_CREATOR_TO_BATTLE=PASS preset=%s" % String(TEST_PRESET))
	print("C65_MODULAR_IDENTITY=PASS skin=deep face=broad eyes=fierce brows=sharp")
	print("C65_SHARED_STATE_CONTRACT=PASS states=10")
	print("C65_VISUAL_ACTIVATION=PASS runtime=shared_modular_animation_runtime_v1")
	print("C65_LIAN_FALLBACK=PASS preserved=true hidden_when_modular_active=true")
	print("C65_COMBAT_BUILD=PASS character=lian_wu unchanged=true")
	print("C65_SHARED_MODULAR_ANIMATION_RUNTIME=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()

	var fallback_battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as FirstPlayableController
	get_root().add_child(fallback_battle)
	for _frame in range(16):
		await process_frame
	var fallback_lian := fallback_battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	if fallback_lian == null or not fallback_lian.using_real_assets() or not fallback_lian.visible:
		_fail("C65_SHARED_RUNTIME=BLOCKED no_preset_lian_fallback")
		return
	if fallback_battle.player_one.has_node("FirstPlayableModularFighterPresenter"):
		_fail("C65_SHARED_RUNTIME=BLOCKED no_preset_modular_overlay")
		return
	print("C65_NO_PRESET_FALLBACK=PASS lian_visible=true modular_absent=true")
	fallback_battle.queue_free()
	await process_frame
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
