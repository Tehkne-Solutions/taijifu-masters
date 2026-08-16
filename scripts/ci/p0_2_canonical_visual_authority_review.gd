extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT_DIR := "res://artifacts/p0_2_visual_authority"
const NEUTRAL_OUTPUT := "P0_2_CANONICAL_FIGHTERS.neutral-1920x1080.png"
const ATTACK_OUTPUT := "P0_2_CANONICAL_FIGHTERS.attack-1920x1080.png"
const METRICS_OUTPUT := "P0_2_CANONICAL_VISUAL_AUTHORITY_METRICS.json"
const MAX_WAIT_FRAMES := 600
const AUTHORITY_META := &"canonical_visual_authority"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)

	if not await _wait_for_battle_and_authority(battle):
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED authority_timeout", battle)
		return
	battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	var p1 := battle.player_one
	var p2 := battle.player_two
	p1.global_position = Vector2(1120.0, 827.0)
	p2.global_position = Vector2(1580.0, 827.0)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	p1.facing = 1.0
	p2.facing = -1.0

	# Slice 04 intentionally shows a compact hint for the first 1.8 s of battle.
	# This review waits until that onboarding window is actually over so the
	# evidence represents the active-round composition, not the intro state.
	var guide := battle.get_node_or_null("HUD/CombatGuide") as FirstPlayableCombatGuide
	var guide_wait := 0.0
	while guide != null and (guide.guide_stage() != &"hidden" or guide.visible) and guide_wait < 3.0:
		await create_timer(0.10, true, false, true).timeout
		guide_wait += 0.10
	if guide != null and (guide.guide_stage() != &"hidden" or guide.visible):
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED onboarding_not_released stage=%s" % String(guide.guide_stage()), battle)
		return
	for _frame in range(18):
		await process_frame

	var p1_presenter := p1.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	var p2_presenter := p2.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
	var modular := p1.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
	if p1_presenter == null or p2_presenter == null or modular == null or pose_runtime == null:
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED presenters", battle)
		return
	if not bool(p1.get_meta(AUTHORITY_META, false)) or not bool(p2.get_meta(AUTHORITY_META, false)):
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED authority_meta", battle)
		return
	if p1.self_modulate.a > 0.001 or p2.self_modulate.a > 0.001:
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED provisional_parent_alpha p1=%.4f p2=%.4f" % [p1.self_modulate.a, p2.self_modulate.a], battle)
		return
	if not modular.assembler().is_visible_in_tree():
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED p1_canonical_hidden", battle)
		return
	var rival_sprite := p2_presenter.get_node_or_null("TrainingRivalLot01AnimatedSprite") as AnimatedSprite2D
	if rival_sprite == null or not rival_sprite.is_visible_in_tree():
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED p2_canonical_hidden", battle)
		return
	rival_sprite.stop()

	_capture(NEUTRAL_OUTPUT)

	var technique := TechniqueCatalog.get_technique(&"ji_body_hook")
	p1._current_technique = technique
	p1._attack_phase = FighterController.AttackPhase.ACTIVE
	p1._attack_phase_timer = 999.0
	for _frame in range(6):
		await process_frame
	if modular.visual_state() != &"attack_light" or pose_runtime.pose_rig().attack_pose_phase() != "contact":
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED attack_pose", battle)
		return
	var weapon_mesh := modular.assembler().get_node_or_null("Module_weapon_main_Deformed") as Polygon2D
	if weapon_mesh == null or not weapon_mesh.visible:
		_fail("P0_2_VISUAL_AUTHORITY_REVIEW=BLOCKED attack_weapon", battle)
		return
	_capture(ATTACK_OUTPUT)

	_write_metrics({
		"signature": "Tehkné Solutions",
		"p1_authority": p1_presenter.canonical_visual_authority_signature(),
		"p2_authority": p2_presenter.canonical_visual_authority_signature(),
		"p1_modular_visible": modular.assembler().is_visible_in_tree(),
		"p2_canonical_visible": rival_sprite.is_visible_in_tree(),
		"skeletal_authority": pose_runtime.authority_active(),
		"onboarding_guide_stage": String(guide.guide_stage()) if guide != null else "missing",
		"onboarding_guide_visible": guide.visible if guide != null else false,
		"provisional_parent_draw_alpha_p1": p1.self_modulate.a,
		"provisional_parent_draw_alpha_p2": p2.self_modulate.a,
		"neutral_capture": NEUTRAL_OUTPUT,
		"attack_capture": ATTACK_OUTPUT,
	})

	print("P0_2_PROVISIONAL_FIGHTER_DRAW=RETIRED p1=true p2=true")
	print("P0_2_CANONICAL_CHILD_RENDER=PASS p1=modular_polygon p2=lot01_sprite")
	print("P0_2_ACTIVE_ROUND_ONBOARDING=RELEASED guide=hidden")
	print("P0_2_CANONICAL_VISUAL_NEUTRAL_CAPTURE=res://artifacts/p0_2_visual_authority/%s" % NEUTRAL_OUTPUT)
	print("P0_2_CANONICAL_VISUAL_ATTACK_CAPTURE=res://artifacts/p0_2_visual_authority/%s" % ATTACK_OUTPUT)
	print("P0_2_CANONICAL_VISUAL_AUTHORITY_REVIEW=PASS")
	print("SIGNATURE=Tehkné Solutions")
	Engine.time_scale = 1.0
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_battle_and_authority(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if (
			int(battle.get("_state")) == FirstPlayableController.MatchState.BATTLE
			and is_instance_valid(battle.player_one)
			and is_instance_valid(battle.player_two)
		):
			var p1_presenter := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
			var p2_presenter := battle.player_two.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
			var modular := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
			var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
			if (
				p1_presenter != null and p1_presenter.using_real_assets()
				and p2_presenter != null and p2_presenter.using_real_assets()
				and modular != null and modular.using_modular_assets()
				and pose_runtime != null and pose_runtime.authority_active()
				and bool(battle.player_one.get_meta(AUTHORITY_META, false))
				and bool(battle.player_two.get_meta(AUTHORITY_META, false))
			):
				return true
		await process_frame
	return false

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