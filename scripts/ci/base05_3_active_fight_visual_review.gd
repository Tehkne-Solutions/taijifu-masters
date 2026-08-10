extends SceneTree

const TEST_PRESET := &"base05_3_active_fight"
const HAIR_STYLE := &"hair_01_lian_topknot"
const UNIFORM_SET := &"uniform_01_lian_martial"
const ARMOR_SET := &"armor_01_taijifu_guard"
const BACK_ACCESSORY := &"back_01_guardian_panel"
const WEAPON_BACK := &"sheath_lian_wu_blue"
const WEAPON_MAIN := &"katana_lian_wu"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT := "res://artifacts/base05_3/BASE05_3_ACTIVE_FIGHT_ATTACK.review-1920x1080.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-BASE05-3")

	var profile := ModularFighterProfile.new()
	profile.profile_id = TEST_PRESET
	profile.display_name = "BASE-05.3 ACTIVE FIGHT REVIEW"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")
	var failures := profile.set_base01_identity_module(&"face", &"face_01_balanced")
	failures.append_array(profile.set_base01_identity_module(&"eyes", &"eyes_01_focused"))
	failures.append_array(profile.set_base01_identity_module(&"brows", &"brows_01_focused"))
	failures.append_array(ModularFighterHairRuntime.set_profile_style(profile, HAIR_STYLE))
	failures.append_array(ModularFighterUniformRuntime.set_profile_set(profile, UNIFORM_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_armor_set(profile, ARMOR_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_back_accessory(profile, BACK_ACCESSORY))
	profile.set_module(&"weapon_back", WEAPON_BACK)
	profile.set_module(&"weapon_main", WEAPON_MAIN)
	if not failures.is_empty():
		_fail("profile:%s" % ",".join(failures))
		return

	failures = ModularFighterPresetStore.save_user_preset(profile, TEST_PRESET)
	if not failures.is_empty() or not FirstPlayableSession.set_creator_preset(TEST_PRESET):
		_fail("preset")
		return

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("battle")
		return
	get_root().add_child(battle)
	await create_timer(4.0).timeout
	for _frame in range(12):
		await process_frame

	if not is_instance_valid(battle.player_one):
		_fail("player_one")
		return
	var fighter := battle.player_one as FighterController
	var presenter := fighter.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("presenter")
		return
	if presenter.active_weapon_back_id() != WEAPON_BACK or presenter.active_weapon_main_id() != WEAPON_MAIN:
		_fail("weapon_ids")
		return
	if presenter.active_hair_style_id() != HAIR_STYLE or presenter.active_uniform_set_id() != UNIFORM_SET:
		_fail("prior_pack_state")
		return
	if presenter.active_armor_set_id() != ARMOR_SET or presenter.active_back_accessory_id() != BACK_ACCESSORY:
		_fail("armor_back_state")
		return
	if fighter.build == null or fighter.build.weapon_id != &"serene_katana" or fighter.equipped_weapon_id != &"serene_katana":
		_fail("combat_owner_binding:%s:%s" % [String(fighter.build.weapon_id if fighter.build != null else &""), String(fighter.equipped_weapon_id)])
		return

	var assembler := presenter.assembler()
	var katana := assembler.get_node_or_null("Module_weapon_main") as Sprite2D
	var sheath := assembler.get_node_or_null("Module_weapon_back") as Sprite2D
	var back := assembler.get_node_or_null("Module_back_accessory") as Sprite2D
	var hair_back := assembler.get_node_or_null("Module_hair_back") as Sprite2D
	if katana == null or sheath == null or back == null or hair_back == null:
		_fail("module_missing")
		return
	if not (sheath.z_index == 3 and back.z_index == 4 and hair_back.z_index == 5 and katana.z_index == 80):
		_fail("layering:%d,%d,%d,%d" % [sheath.z_index, back.z_index, hair_back.z_index, katana.z_index])
		return
	if presenter.visual_state() != &"idle" or katana.visible:
		_fail("neutral_contract state=%s visible=%s" % [String(presenter.visual_state()), str(katana.visible)])
		return
	if not sheath.visible:
		_fail("neutral_sheath_hidden")
		return

	# Force the real FighterController attack state; presenter must resolve it
	# naturally on process and expose weapon_main without rebuilding modules.
	var sheath_instance := sheath.get_instance_id()
	var back_instance := back.get_instance_id()
	var hair_instance := hair_back.get_instance_id()
	fighter.velocity = Vector2.ZERO
	fighter._is_blocking = false
	fighter._dodge_timer = 0.0
	fighter._attack_phase = FighterController.AttackPhase.ACTIVE
	fighter._attack_phase_timer = 0.75
	for _frame in range(3):
		await process_frame
	if presenter.visual_state() != &"attack_light" or not katana.visible:
		_fail("attack_contract state=%s visible=%s" % [String(presenter.visual_state()), str(katana.visible)])
		return
	if not _same_prior_modules(assembler, sheath_instance, back_instance, hair_instance):
		_fail("attack_reassembled_prior_modules")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("capture")
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("save")
		return

	# Return to neutral and prove the same katana node is merely hidden, not
	# destroyed/recreated. This is the key state-aware idempotence contract.
	var katana_instance := katana.get_instance_id()
	fighter._attack_phase = FighterController.AttackPhase.NONE
	fighter._attack_phase_timer = 0.0
	fighter._is_blocking = false
	fighter._dodge_timer = 0.0
	fighter.velocity = Vector2.ZERO
	for _frame in range(5):
		await process_frame
	var katana_after := assembler.get_node_or_null("Module_weapon_main") as Sprite2D
	if katana_after == null or katana_after.get_instance_id() != katana_instance:
		_fail("neutral_recreated_katana")
		return
	if presenter.visual_state() != &"idle" or katana_after.visible:
		_fail("neutral_return state=%s visible=%s" % [String(presenter.visual_state()), str(katana_after.visible)])
		return
	if not _same_prior_modules(assembler, sheath_instance, back_instance, hair_instance):
		_fail("neutral_reassembled_prior_modules")
		return

	var handoff_value = fighter.get_meta("creator_battle_handoff", {})
	if not (handoff_value is Dictionary):
		_fail("handoff")
		return
	if String(handoff_value.get("weapon_main_id", "")) != String(WEAPON_MAIN):
		_fail("handoff_weapon_main")
		return
	if String(handoff_value.get("weapon_back_id", "")) != String(WEAPON_BACK):
		_fail("handoff_weapon_back")
		return
	if bool(handoff_value.get("weapon_main_neutral_visible", true)):
		_fail("handoff_neutral_policy")
		return
	if String(handoff_value.get("weapon_combat_behavior_owner", "")) != "WeaponKitCatalog":
		_fail("handoff_combat_owner")
		return
	var visible_states = handoff_value.get("weapon_main_visible_states", [])
	if not (visible_states is Array) or not visible_states.has("attack_light"):
		_fail("handoff_visible_states")
		return

	print("BASE05_3_ACTIVE_FIGHT=PASS weapon_main=katana_lian_wu weapon_back=sheath_lian_wu_blue combat=serene_katana auto_activation=true handoff=true")
	print("BASE05_3_STATE_AWARE=PASS idle=false attack_light=true idle_return=false same_node=true")
	print("BASE05_3_ACTIVE_LAYERING=PASS weapon_back=3 back_accessory=4 hair_back=5 weapon_main=80")
	print("BASE05_3_ACTIVE_COMPOSITION=PASS hair=hair_01_lian_topknot uniform=uniform_01_lian_martial armor=armor_01_taijifu_guard back=back_01_guardian_panel")
	print("BASE05_3_ACTIVE_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _same_prior_modules(assembler: ModularFighterAssembler, sheath_id: int, back_id: int, hair_id: int) -> bool:
	var sheath := assembler.get_node_or_null("Module_weapon_back")
	var back := assembler.get_node_or_null("Module_back_accessory")
	var hair := assembler.get_node_or_null("Module_hair_back")
	return (
		sheath != null and sheath.get_instance_id() == sheath_id
		and back != null and back.get_instance_id() == back_id
		and hair != null and hair.get_instance_id() == hair_id
		and assembler.get_node_or_null("Module_torso_outer") != null
		and assembler.get_node_or_null("Module_shoulders") != null
	)

func _fail(message: String) -> void:
	push_error("BASE05_3_ACTIVE_FIGHT=BLOCKED " + message)
	print("BASE05_3_ACTIVE_FIGHT=BLOCKED " + message)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
