extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT_DIR := "res://artifacts/p0_2_lian"
const NEUTRAL_OUTPUT := "P0_2_PRODUCTION_LIAN.neutral-1920x1080.png"
const ATTACK_OUTPUT := "P0_2_PRODUCTION_LIAN.attack-1920x1080.png"
const METRICS_OUTPUT := "P0_2_PRODUCTION_LIAN_METRICS.json"
const MAX_WAIT_FRAMES := 480
const REQUIRED_PRODUCTION_NODES: Array[String] = [
	"Module_face", "Module_eyes", "Module_brows",
	"Module_hair_back", "Module_hair_front",
	"Module_torso_outer", "Module_arms", "Module_waist", "Module_legs", "Module_feet",
	"Module_head_accessory", "Module_shoulders", "Module_back_accessory",
	"Module_weapon_back", "Module_weapon_main",
]
const INTENTIONALLY_EMPTY_NODES: Array[String] = [
	"Module_torso_inner", "Module_hands", "Module_weapon_offhand",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)

	var presenter := await _wait_for_presenter(battle)
	if presenter == null:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED presenter_timeout", battle)
		return
	if battle.bot_runtime != null:
		battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	if not is_instance_valid(battle.player_one) or not is_instance_valid(battle.player_two):
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED fighters", battle)
		return
	battle.player_one.global_position = Vector2(1120.0, 827.0)
	battle.player_two.global_position = Vector2(1580.0, 827.0)
	battle.player_one.velocity = Vector2.ZERO
	battle.player_two.velocity = Vector2.ZERO
	battle.player_one.facing = 1.0
	battle.player_two.facing = -1.0

	var guide := battle.get_node_or_null("HUD/CombatGuide") as FirstPlayableCombatGuide
	var guide_wait := 0.0
	while guide != null and guide.guide_stage() != &"hidden" and guide_wait < 2.5:
		await create_timer(0.10, true, false, true).timeout
		guide_wait += 0.10
	for _frame in range(12):
		await process_frame

	var profile_result := FirstPlayableSession.creator_profile_result()
	var profile := profile_result.get("profile") as ModularFighterProfile if bool(profile_result.get("ok", false)) else null
	if profile == null:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED profile", battle)
		return
	var assembler := presenter.assembler()
	if assembler == null:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED assembler", battle)
		return
	var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
	if pose_runtime == null or not pose_runtime.authority_active():
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED pose_runtime", battle)
		return

	for node_name in REQUIRED_PRODUCTION_NODES:
		if assembler.get_node_or_null(node_name) == null:
			_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED missing_node:%s" % node_name, battle)
			return
	for node_name in INTENTIONALLY_EMPTY_NODES:
		if assembler.get_node_or_null(node_name) != null:
			_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED intentional_empty_node_present:%s" % node_name, battle)
			return

	if presenter.active_hair_style_id() != FirstPlayableSession.PRODUCTION_HAIR_STYLE:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED hair", battle)
		return
	if presenter.active_uniform_set_id() != FirstPlayableSession.PRODUCTION_UNIFORM_SET:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED uniform", battle)
		return
	if presenter.active_armor_set_id() != FirstPlayableSession.PRODUCTION_ARMOR_SET:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED armor", battle)
		return
	if presenter.active_back_accessory_id() != FirstPlayableSession.PRODUCTION_BACK_ACCESSORY:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED back", battle)
		return
	if ModularFighterEquipmentRuntime.profile_weapon_set_id(profile) != FirstPlayableSession.PRODUCTION_WEAPON_SET:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED weapon_set", battle)
		return

	var weapon_source := assembler.get_node_or_null("Module_weapon_main") as Sprite2D
	var weapon_mesh := assembler.get_node_or_null("Module_weapon_main_Deformed") as Polygon2D
	if weapon_source == null or weapon_mesh == null:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED weapon_visual_bridge", battle)
		return
	if weapon_source.visible or weapon_mesh.visible:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED weapon_neutral_visibility", battle)
		return

	_capture(NEUTRAL_OUTPUT)

	# Visual-only probe of the already existing attack state. This does not execute
	# damage or collision logic; it verifies that BASE-05 visibility crosses the
	# Sprite2D -> Polygon2D skeletal bridge on the same production composition.
	var technique := TechniqueCatalog.get_technique(&"ji_body_hook")
	battle.player_one._current_technique = technique
	battle.player_one._attack_phase = FighterController.AttackPhase.ACTIVE
	# Keep the phase alive long enough for deterministic Xvfb capture. The value is
	# test-local and never enters product frame-data or combat execution.
	battle.player_one._attack_phase_timer = 999.0
	for _frame in range(5):
		await process_frame
	if presenter.visual_state() != &"attack_light":
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED attack_visual_state", battle)
		return
	if not weapon_source.visible or not weapon_mesh.visible:
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED weapon_attack_visibility source=%s mesh=%s" % [
			str(weapon_source.visible), str(weapon_mesh.visible),
		], battle)
		return
	if pose_runtime.pose_rig().attack_pose_phase() != "contact":
		_fail("P0_2_PRODUCTION_LIAN_REVIEW=BLOCKED attack_pose_phase:%s" % pose_runtime.pose_rig().attack_pose_phase(), battle)
		return
	_capture(ATTACK_OUTPUT)

	var module_count := _nonempty_module_count(profile)
	var mesh_count := pose_runtime.pose_rig().mesh_layer_count()
	_write_metrics({
		"signature": "Tehkné Solutions",
		"preset_id": String(FirstPlayableSession.creator_preset_id()),
		"profile_stack": FirstPlayableSession.production_default_visual_signature().get("profile_stack", []),
		"module_count": module_count,
		"mesh_count": mesh_count,
		"required_production_nodes": REQUIRED_PRODUCTION_NODES,
		"intentionally_empty_nodes": INTENTIONALLY_EMPTY_NODES,
		"hair_style": String(presenter.active_hair_style_id()),
		"uniform_set": String(presenter.active_uniform_set_id()),
		"armor_set": String(presenter.active_armor_set_id()),
		"back_accessory": String(presenter.active_back_accessory_id()),
		"weapon_back": String(presenter.active_weapon_back_id()),
		"weapon_main": String(presenter.active_weapon_main_id()),
		"weapon_set": String(ModularFighterEquipmentRuntime.profile_weapon_set_id(profile)),
		"combat_loadout": String(profile.combat_loadout_id),
		"weapon_neutral_visible": false,
		"weapon_attack_visible": true,
		"skeletal_authority": pose_runtime.authority_active(),
		"authored_animation": false,
	})

	print("P0_2_PRODUCTION_LIAN_VISUAL_STACK=PASS modules=%d meshes=%d hair=true uniform=true armor=true back=true intentional_empty=torso_inner,hands,weapon_offhand" % [module_count, mesh_count])
	print("P0_2_PRODUCTION_LIAN_WEAPON_VISIBILITY=PASS neutral=false attack=true bridge=Sprite2D_to_Polygon2D")
	print("P0_2_PRODUCTION_LIAN_NEUTRAL_CAPTURE=res://artifacts/p0_2_lian/%s" % NEUTRAL_OUTPUT)
	print("P0_2_PRODUCTION_LIAN_ATTACK_CAPTURE=res://artifacts/p0_2_lian/%s" % ATTACK_OUTPUT)
	print("P0_2_PRODUCTION_LIAN_VISUAL_REVIEW=PASS")
	print("SIGNATURE=Tehkné Solutions")
	Engine.time_scale = 1.0
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_presenter(battle: FirstPlayableController) -> FirstPlayableModularFighterPresenter:
	for _frame in range(MAX_WAIT_FRAMES):
		if is_instance_valid(battle.player_one):
			var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
			if presenter != null and presenter.using_modular_assets():
				return presenter
		await process_frame
	return null

func _nonempty_module_count(profile: ModularFighterProfile) -> int:
	var count := 0
	for raw_slot in profile.modules.keys():
		if not String(profile.modules.get(raw_slot, "")).is_empty():
			count += 1
	return count

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