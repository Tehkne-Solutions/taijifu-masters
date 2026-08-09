extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"c62_8_battle_handoff_probe"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-001")

	if not ResourceLoader.exists(CREATOR_SCENE) or not ResourceLoader.exists(BATTLE_SCENE):
		_fail("C62_8_HANDOFF=BLOCKED scene_missing")
		return

	var creator_packed := load(CREATOR_SCENE) as PackedScene
	var creator := creator_packed.instantiate() as ModularFighterCreatorScene
	if creator == null:
		_fail("C62_8_HANDOFF=BLOCKED creator_instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(4):
		await process_frame

	creator.set_display_name("C62.8 MASTER")
	creator.set_preset_id(String(TEST_PRESET))
	var failures := PackedStringArray()
	failures.append_array(creator.set_identity(&"skin", &"skin_tone_07_deep"))
	failures.append_array(creator.set_identity(&"face", &"face_04_broad"))
	failures.append_array(creator.set_identity(&"eyes", &"eyes_03_fierce"))
	failures.append_array(creator.set_identity(&"brows", &"brows_06_sharp"))
	if not failures.is_empty():
		_fail("C62_8_HANDOFF=BLOCKED creator_identity:%s" % ",".join(failures))
		return
	failures = creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C62_8_HANDOFF=BLOCKED creator_save:%s" % ",".join(failures))
		return
	if not FirstPlayableSession.has_creator_preset() or FirstPlayableSession.creator_preset_id() != TEST_PRESET:
		_fail("C62_8_HANDOFF=BLOCKED session_selection")
		return
	var session_signature := FirstPlayableSession.creator_battle_handoff_signature()
	if not bool(session_signature.get("preset_selected", false)):
		_fail("C62_8_HANDOFF=BLOCKED signature_selection")
		return
	if bool(session_signature.get("visual_activation", true)):
		_fail("C62_8_HANDOFF=BLOCKED premature_visual_activation")
		return
	if String(session_signature.get("visual_blocker", "")) != FirstPlayableSession.CREATOR_VISUAL_BLOCKER:
		_fail("C62_8_HANDOFF=BLOCKED blocker_contract")
		return

	creator.queue_free()
	await process_frame

	var battle_packed := load(BATTLE_SCENE) as PackedScene
	var battle := battle_packed.instantiate() as FirstPlayableController
	if battle == null:
		_fail("C62_8_HANDOFF=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(12):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C62_8_HANDOFF=BLOCKED player_one_missing")
		return
	if not battle.player_one.has_meta("creator_battle_handoff"):
		_fail("C62_8_HANDOFF=BLOCKED battle_metadata_missing")
		return
	var battle_handoff = battle.player_one.get_meta("creator_battle_handoff")
	if not (battle_handoff is Dictionary):
		_fail("C62_8_HANDOFF=BLOCKED battle_metadata_invalid")
		return
	var handoff := battle_handoff as Dictionary
	if String(handoff.get("preset_id", "")) != String(TEST_PRESET):
		_fail("C62_8_HANDOFF=BLOCKED battle_preset_mismatch")
		return
	if bool(handoff.get("visual_activation", true)):
		_fail("C62_8_HANDOFF=BLOCKED static_creator_visual_regression")
		return
	if String(handoff.get("visual_blocker", "")) != "shared_modular_animation_runtime":
		_fail("C62_8_HANDOFF=BLOCKED battle_blocker_mismatch")
		return
	if String(battle.player_one.build.character_id) != "lian_wu":
		_fail("C62_8_HANDOFF=BLOCKED combat_fallback_changed")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter")
	if presenter == null or not (presenter is FirstPlayableLot01Presenter):
		_fail("C62_8_HANDOFF=BLOCKED animated_fallback_missing")
		return

	print("C62_8_CREATOR_TO_SESSION=PASS preset=%s" % String(TEST_PRESET))
	print("C62_8_SESSION_TO_BATTLE=PASS metadata=true")
	print("C62_8_CREATOR_VISUAL_ACTIVATION=BLOCKED blocker=shared_modular_animation_runtime")
	print("C62_8_ANIMATED_FALLBACK=PRESERVED character=lian_wu")
	print("C62_8_STATIC_SPRITE_REGRESSION=BLOCKED")
	print("C62_8_CREATOR_BATTLE_HANDOFF=PASS")
	print("NEXT_STAGE=C63_SHARED_MODULAR_ANIMATION_RUNTIME")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)
